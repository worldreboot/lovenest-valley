import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:lovenest/game/simple_enhanced_farm_game.dart';
import 'package:lovenest/models/inventory.dart';
import 'package:lovenest/components/ui/inventory_bar.dart';
import 'package:lovenest/services/question_service.dart';
import 'package:lovenest/models/memory_garden/question.dart';
import 'package:lovenest/screens/memory_garden/daily_question_letter_sheet.dart';
import 'package:lovenest/services/daily_question_seed_collection_service.dart';
import 'package:lovenest/utils/seed_color_generator.dart';
import 'package:lovenest/components/ui/daily_question_planting_dialog.dart';
import 'package:lovenest/services/daily_question_seed_service.dart';
import 'package:lovenest/services/seed_service.dart';
import 'package:lovenest/services/farm_service.dart';
import 'package:lovenest/config/supabase_config.dart';
import 'package:lovenest/screens/shop_screen.dart';
import 'package:lovenest/services/pending_gift_service.dart';
import 'package:lovenest/screens/widgets/gifts_inbox_dialog.dart';
import 'package:lovenest/components/ui/chest_storage_ui.dart';
import 'package:lovenest/models/chest_storage.dart';

class TiledTestScreen extends StatefulWidget {
  const TiledTestScreen({super.key});

  @override
  State<TiledTestScreen> createState() => _TiledTestScreenState();
}

class _TiledTestScreenState extends State<TiledTestScreen> {
  late InventoryManager inventoryManager;
  SimpleEnhancedFarmGame? gameInstance;
  String? farmId;
  bool _isLoadingFarm = true;
  OverlayEntry? _chestOverlay;

  @override
  void initState() {
    super.initState();
    inventoryManager = InventoryManager();
    _initializeInventory();
    _initializeFarm();
  }

  Future<void> _initializeFarm() async {
    debugPrint('[TiledTestScreen] 🔄 Initializing farm for current user...');
    
    try {
      // Check if user is authenticated first
      final currentUser = SupabaseConfig.currentUser;
      debugPrint('[TiledTestScreen] 👤 Current user: ${currentUser?.email ?? 'null'}');
      debugPrint('[TiledTestScreen] 🆔 Current user ID: ${SupabaseConfig.currentUserId}');
      
      farmId = await FarmService.getCurrentUserFarmId();
      if (farmId != null) {
        debugPrint('[TiledTestScreen] ✅ Farm initialized: $farmId');
      } else {
        debugPrint('[TiledTestScreen] ❌ Failed to get farm ID - user may not be authenticated');
      }
    } catch (e) {
      debugPrint('[TiledTestScreen] ❌ Error initializing farm: $e');
      debugPrint('[TiledTestScreen] ❌ Error type: ${e.runtimeType}');
    } finally {
      setState(() {
        _isLoadingFarm = false;
      });
    }
  }


  Future<void> _initializeInventory() async {
    debugPrint('[TiledTestScreen] 🔄 Starting inventory initialization');
    
    // Initialize inventory from backend
    await inventoryManager.initialize();
    
    debugPrint('[TiledTestScreen] 📊 Inventory after backend load: ${inventoryManager.slots.map((item) => item?.name ?? 'null').toList()}');
    
    // Add default items to the inventory if it's empty
    if (inventoryManager.slots.every((item) => item == null)) {
      debugPrint('[TiledTestScreen] ➕ Adding default items to empty inventory');
      await inventoryManager.addItem(const InventoryItem(
        id: 'hoe',
        name: 'Hoe',
        iconPath: 'assets/images/items/hoe.png',
      ));
      await inventoryManager.addItem(const InventoryItem(
        id: 'watering_can',
        name: 'Watering Can',
        iconPath: 'assets/images/items/watering_can.png',
      ));
      debugPrint('[TiledTestScreen] ✅ Default items added');
    } else {
      debugPrint('[TiledTestScreen] 📦 Inventory not empty, skipping default items');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while farm is being initialized
    if (_isLoadingFarm) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading farm...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Show error if farm failed to load
    if (farmId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load farm',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'User may not be authenticated',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoadingFarm = true;
                  });
                  _initializeFarm();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Sync due gifts (DB -> completed) on first build
          Builder(builder: (ctx) {
            Future.microtask(() => PendingGiftService.syncDueGifts());
            return const SizedBox.shrink();
          }),
          GameWidget(
            game: gameInstance ??= SimpleEnhancedFarmGame(
              farmId: farmId!,
              inventoryManager: inventoryManager,
              onExamine: (String text, ChestStorage? chest) {
                if (chest != null) {
                  _showChestOverlay(chest);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
                }
              },
              onOwlTapped: (Question question) async {
                debugPrint('[TiledTestScreen] 🦉 Owl tapped for question: ${question.id}');
                final hasCollected = await DailyQuestionSeedCollectionService.hasUserCollectedSeed(question.id);
                final answer = await showModalBottomSheet<String>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => DailyQuestionLetterSheet(
                    question: question,
                    onCollectSeed: hasCollected ? null : () async {
                      final seedColor = SeedColorGenerator.generateSeedColor(question.id);
                      final success = await DailyQuestionSeedCollectionService.collectDailyQuestionSeed(
                        questionId: question.id,
                        questionText: question.text ?? 'Daily Question',
                        answer: '',
                        seedColor: seedColor,
                      );
                      if (success) {
                        final uniqueSeedId = 'daily_question_seed_${question.id}';
                        final hasSeed = inventoryManager.slots.any((item) => item?.id == uniqueSeedId);
                        if (!hasSeed) {
                          await inventoryManager.addItem(InventoryItem(
                            id: uniqueSeedId,
                            name: 'Daily Question Seed',
                            quantity: 1,
                            iconPath: 'assets/images/items/seeds.png',
                            itemColor: seedColor,
                          ));
                        }
                        
                        // Close the modal bottom sheet after successful collection
                        Navigator.of(context).pop();
                        
                        // Update owl notification to hide it
                        if (gameInstance != null) {
                          await gameInstance!.updateOwlNotification(false);
                          debugPrint('[TiledTestScreen] 🦉 Updated owl notification: OFF');
                        }
                        
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily Question Seed collected!'), backgroundColor: Colors.green));
                      }
                    },
                  ),
                );
                if (answer != null && answer.trim().isNotEmpty) {
                  await QuestionService.saveDailyQuestionAnswer(question.id, answer);
                  await DailyQuestionSeedCollectionService.updateSeedAnswer(question.id, answer);
                }
              },
              onPlantSeed: (int gridX, int gridY, InventoryItem? selectedItem) async {
                if (selectedItem == null) return;
                if (selectedItem.id.startsWith('daily_question_seed_')) {
                  final question = await QuestionService.fetchDailyQuestion();
                  if (question == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No daily question found. Please try again.'), backgroundColor: Colors.red));
                    return;
                  }
                  // Show planting dialog with answer field (answering happens here, not via owl)
                  final planted = await showDialog<bool>(
                    context: context,
                    builder: (context) => DailyQuestionPlantingDialog(
                      question: question,
                      onPlant: (String answer) async {
                        final success = await DailyQuestionSeedService.plantDailyQuestionSeed(
                          questionId: question.id,
                          answer: answer,
                          plotX: gridX,
                          plotY: gridY,
                          farmId: farmId!,
                        );
                        if (success) {
                          await inventoryManager.removeItem(inventoryManager.selectedSlotIndex);
                          if (gameInstance != null) {
                            Color? seedColor;
                            final qid = selectedItem.id.replaceFirst('daily_question_seed_', '');
                            seedColor = SeedColorGenerator.generateSeedColor(qid);
                            await gameInstance!.addPlantedSeed(gridX, gridY, selectedItem.id, 'planted', seedColor: seedColor);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Daily Question Seed planted! Water it for 3 days to see it bloom!'), backgroundColor: Colors.green));
                          Navigator.of(context).pop(true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to plant seed. Please try again.'), backgroundColor: Colors.red));
                          Navigator.of(context).pop(false);
                        }
                      },
                    ),
                  );
                  if (planted == true) {
                    // nothing else needed
                  }
                } else {
                  final success = await SeedService.plantRegularSeed(
                    seedId: selectedItem.id,
                    seedName: selectedItem.name,
                    plotX: gridX,
                    plotY: gridY,
                    farmId: farmId!,
                  );
                  if (success) {
                    await inventoryManager.removeItem(inventoryManager.selectedSlotIndex);
                    if (gameInstance != null) {
                      await gameInstance!.addPlantedSeed(gridX, gridY, selectedItem.id, 'planted');
                    }
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${selectedItem.name} planted! Water it to help it grow.'), backgroundColor: Colors.green));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to plant seed. Please try again.'), backgroundColor: Colors.red));
                  }
                }
              },
            ),
            loadingBuilder: (context) => const Center(
              child: CircularProgressIndicator(),
            ),
            errorBuilder: (context, error) => Center(
              child: Text('Error: $error'),
            ),
          ),

          // Right side buttons (top-right)
          Positioned(
            top: 40,
            right: 16,
            child: SafeArea(
              child: IconButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ShopScreen(
                        inventoryManager: inventoryManager,
                        onItemPurchased: () {
                          setState(() {});
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(
                  Icons.shopping_bag,
                  color: Colors.white,
                  size: 24,
                ),
                tooltip: 'Shop',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
          ),
          Positioned(
            top: 88,
            right: 16,
            child: SafeArea(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: PendingGiftService.fetchCollectibleGifts(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  final badgeText = count > 9 ? '9+' : '$count';
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () async {
                          await showDialog(
                            context: context,
                            builder: (context) => GiftsInboxDialog(
                              inventoryManager: inventoryManager,
                              parentContext: context,
                            ),
                          );
                          setState(() {});
                        },
                        icon: const Icon(
                          Icons.card_giftcard,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Gifts Received',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.purple,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Text(
                            badgeText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Inventory bar at the bottom
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: InventoryBar(
                  inventoryManager: inventoryManager,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showChestOverlay(ChestStorage chest) {
    _chestOverlay?.remove();
    _chestOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Only the chest panel should capture taps; outside taps go through to the game/inventory
          Center(
            child: Material(
              type: MaterialType.transparency,
              child: ChestStorageUI(
                chest: chest,
                inventoryManager: inventoryManager,
                onClose: () {
                  _chestOverlay?.remove();
                  _chestOverlay = null;
                },
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_chestOverlay!);
  }
} 