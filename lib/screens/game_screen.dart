import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:lovenest/game/farm_game.dart';
import '../models/inventory.dart';
import '../components/ui/inventory_bar.dart';
import 'package:lovenest/screens/memory_garden/planting_sheet.dart';
import 'package:lovenest/screens/memory_garden/nurturing_sheet.dart';
import 'package:lovenest/screens/memory_garden/bloom_viewer_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/garden_providers.dart';
import '../models/memory_garden/seed.dart';
import 'package:lovenest/game/farmhouse_interior_game.dart';
import 'package:lovenest/screens/memory_garden/daily_question_letter_sheet.dart';
import 'package:lovenest/models/memory_garden/question.dart';
import 'package:lovenest/services/question_service.dart';
import 'package:lovenest/services/garden_repository.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final InventoryManager inventoryManager;
  FarmGame? _farmGameInstance;
  FarmhouseInteriorGame? _interiorGameInstance;
  bool _inInterior = false;

  // Store pending daily question answer info
  Map<String, dynamic>? _pendingDailyQuestionAnswer;

  @override
  void initState() {
    super.initState();
    inventoryManager = InventoryManager();
    
    // Add some sample items for testing
    _initializeSampleItems();
    _checkForUnplantedDailyQuestionSeed();
  }

  void _initializeSampleItems() {
    // Add some sample items to demonstrate the inventory
    inventoryManager.addItem(const InventoryItem(
      id: 'seeds',
      name: 'Seeds',
      quantity: 5,
    ));
    
    inventoryManager.addItem(const InventoryItem(
      id: 'watering_can_full',
      name: 'Watering Can',
      quantity: 5, // 5 uses of water
    ));
    
    inventoryManager.addItem(const InventoryItem(
      id: 'hoe',
      name: 'Hoe',
      quantity: 1,
    ));
  }

  Future<void> _checkForUnplantedDailyQuestionSeed() async {
    final answer = await QuestionService.getUnplantedDailyQuestionAnswer();
    if (answer != null) {
      // Add seed to inventory if not already present
      final hasSeed = inventoryManager.slots.any((item) => item?.id == 'daily_question_seed');
      if (!hasSeed) {
        inventoryManager.addItem(
          InventoryItem(
            id: 'daily_question_seed',
            name: 'Daily Question Seed',
            quantity: 1,
          ),
        );
      }
      setState(() {
        _pendingDailyQuestionAnswer = answer;
      });
    }
  }

  @override
  void dispose() {
    inventoryManager.dispose();
    super.dispose();
  }

  void _handlePlant(int gridX, int gridY) async {
    final selectedItem = inventoryManager.selectedItem;
    if (selectedItem?.id == 'daily_question_seed' && _pendingDailyQuestionAnswer != null) {
      // Plant the daily question seed
      final plotPosition = PlotPosition(gridX.toDouble(), gridY.toDouble());
      final answer = _pendingDailyQuestionAnswer!;
      final questionId = answer['question_id'] as String;
      final answerText = answer['answer'] as String;
      // Create the seed in the backend
      final seed = await GardenRepository().plantSeed(
        mediaType: MediaType.text, // or 'daily_question' if you add to enum
        plotPosition: plotPosition,
        textContent: answerText,
        secretHope: '',
        questionId: questionId,
      );
      // Mark the answer as planted
      await QuestionService.markDailyQuestionAnswerPlanted(answer['id'] as String, seed.id);
      // Remove the seed from inventory
      inventoryManager.removeItem(inventoryManager.selectedSlotIndex);
      setState(() {
        _pendingDailyQuestionAnswer = null;
      });
      // Update the tile visually to planted (crop)
      _farmGameInstance?.updateTileToCrop(gridX, gridY);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily Question Seed planted! Water it to help it grow.'),
          backgroundColor: Colors.green,
        ),
      );
      return;
    }
    final planted = _farmGameInstance?.plantSeedAt(gridX, gridY) ?? false;
    if (planted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memory planted! Water it to help it grow.'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to plant memory. Make sure you are next to tilled soil and have seeds selected.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The game widget (swap between farm and interior)
          if (!_inInterior)
            GameWidget<FarmGame>.controlled(
              gameFactory: () {
                final game = FarmGame(
                  inventoryManager: inventoryManager,
                  onPlotTapped: (gridX, gridY, seed) {
                    debugPrint('onPlotTapped: gridX=$gridX, gridY=$gridY, seed=${seed != null ? seed.id : 'null'}');
                    if (seed != null) {
                      debugPrint('Seed state: ${seed.state}, textContent: ${seed.textContent}');
                    }
                    final plotPosition = PlotPosition(gridX.toDouble(), gridY.toDouble());
                    final selectedItem = inventoryManager.selectedItem;
                    // Test reveal dialog for dummy daily question plant
                    if (seed != null && seed.state == SeedState.bloomStage3 && seed.textContent != null) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Daily Question Answer'),
                          content: Text(seed.textContent!),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    // If planting a daily question seed, skip the memory dialog
                    if (selectedItem != null && selectedItem.id == 'daily_question_seed') {
                      _handlePlant(gridX, gridY);
                      return;
                    }
                    // Otherwise, show the plant a memory dialog for regular seeds
                    // ... existing code to show the memory dialog ...
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: PlantingSheet(
                          plotPosition: plotPosition,
                          onPlant: () => _handlePlant(gridX, gridY),
                        ),
                      ),
                    );
                  },
                  onEnterFarmhouse: () {
                    setState(() {
                      _inInterior = true;
                    });
                  },
                  onOwlTapped: (Question question) async {
                    final answer = await showModalBottomSheet<String>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => DailyQuestionLetterSheet(
                        question: question,
                      ),
                    );
                    if (answer != null && answer.trim().isNotEmpty) {
                      // Save the answer in the backend
                      await QuestionService.saveDailyQuestionAnswer(question.id, answer);
                      // Add the daily question seed to inventory if not already present
                      final hasSeed = inventoryManager.slots.any((item) => item?.id == 'daily_question_seed');
                      if (!hasSeed) {
                        inventoryManager.addItem(
                          InventoryItem(
                            id: 'daily_question_seed',
                            name: 'Daily Question Seed',
                            quantity: 1,
                          ),
                        );
                      }
                      // Refresh pending answer
                      await _checkForUnplantedDailyQuestionSeed();
                    }
                  },
                );
                _farmGameInstance = game;
                return game;
              },
            )
          else
            GameWidget<FarmhouseInteriorGame>.controlled(
              gameFactory: () {
                final interior = FarmhouseInteriorGame(
                  onExitHouse: () {
                    setState(() {
                      _inInterior = false;
                    });
                    // Place player at farmhouse door
                    _farmGameInstance?.player.position = Vector2(
                      (FarmGame.farmhouseDoorX * FarmGame.tileSize) + (FarmGame.tileSize / 2),
                      ((FarmGame.farmhouseDoorY + 1) * FarmGame.tileSize) + (FarmGame.tileSize / 2),
                    );
                  },
                );
                _interiorGameInstance = interior;
                return interior;
              },
            ),
          
          // Back button overlay
          Positioned(
            top: 40,
            left: 16,
            child: SafeArea(
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                  size: 28,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
          ),
          
          // Inventory bar at the bottom (only show in farm)
          if (!_inInterior)
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
} 