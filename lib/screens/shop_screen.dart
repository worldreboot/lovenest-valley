import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lovenest_valley/models/shop_item.dart';
import 'package:lovenest_valley/services/pending_gift_service.dart';
import 'package:lovenest_valley/config/supabase_config.dart';
import 'package:lovenest_valley/services/image_generation_service.dart';
import 'package:lovenest_valley/services/shop_service.dart';
import 'package:lovenest_valley/models/inventory.dart';
import 'package:lovenest_valley/services/currency_service.dart';

class ShopScreen extends StatefulWidget {
  final InventoryManager inventoryManager;
  final VoidCallback? onItemPurchased;

  const ShopScreen({
    super.key,
    required this.inventoryManager,
    this.onItemPurchased,
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  String _searchQuery = '';
  List<ShopItem> _filteredItems = [];
  int _playerGold = 0;

  @override
  void initState() {
    super.initState();
    _filteredItems = ShopService.getAllItems();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    final balance = await CurrencyService.getBalance();
    if (!mounted) return;
    setState(() => _playerGold = balance);
  }

  void _filterItems() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredItems = ShopService.getAllItems();
      });
    } else {
      setState(() {
        _filteredItems = ShopService.searchItems(_searchQuery);
      });
    }
  }

  Future<void> _purchaseItem(ShopItem item) async {
    if (item.id == 'gift') {
      // Spend coins first
      if (_playerGold < item.price) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough coins')),
        );
        return;
      }
      final newBalance = await CurrencyService.spend(
        amount: item.price,
        reason: 'gift_purchase',
        metadata: {'item_id': item.id},
      );
      if (newBalance == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase failed')),
        );
        return;
      }
      setState(() => _playerGold = newBalance);
      _showGiftCreationDialog();
      return;
    }
    if (_playerGold < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins')),
      );
      return;
    }
    final newBalance = await CurrencyService.spend(
      amount: item.price,
      reason: 'shop_purchase',
      metadata: {'item_id': item.id},
    );
    if (newBalance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase failed')),
      );
      return;
    }
    setState(() => _playerGold = newBalance);

    final inventoryItem = InventoryItem(id: item.id, name: item.name, quantity: 1);
    widget.inventoryManager.addItem(inventoryItem);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.name} added to inventory!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    widget.onItemPurchased?.call();
  }

  Future<void> _showGiftCreationDialog() async {
    String mode = 'text'; // 'text' or 'image'
    final descriptionController = TextEditingController();
    XFile? pickedImage;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Create a Gift'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How do you want to generate the gift sprite?'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Describe it'),
                      selected: mode == 'text',
                      onSelected: (v) => setState(() => mode = 'text'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Use an image'),
                      selected: mode == 'image',
                      onSelected: (v) => setState(() => mode = 'image'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (mode == 'text') ...[
                  const Text('Describe what you want to gift your partner:'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'e.g., A cute plush penguin with a little heart',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else ...[
                  if (pickedImage != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Selected image:'),
                        const SizedBox(height: 8),
                        Image.file(
                          File(pickedImage!.path),
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ElevatedButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final picker = ImagePicker();
                            final image = await picker.pickImage(source: ImageSource.gallery);
                            if (image != null) {
                              setState(() => pickedImage = image);
                            }
                          },
                    icon: const Icon(Icons.image),
                    label: const Text('Pick image'),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        try {
                          await _createGift(mode: mode, description: descriptionController.text.trim(), image: pickedImage);
                          if (mounted) Navigator.of(context).pop();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to create gift: $e'), backgroundColor: Colors.red),
                          );
                        } finally {
                          if (mounted) setState(() => isSubmitting = false);
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _createGift({required String mode, required String description, required XFile? image}) async {
    try {
      final imageService = ImageGenerationService();
      Map<String, dynamic> result;
      if (mode == 'text') {
        if (description.isEmpty) {
          throw Exception('Please enter a description');
        }
        result = await imageService.generate(
          presetName: 'GAME_ITEM_SPRITE_V1', // use existing item preset
          userDescription: description,
        );
      } else {
        if (image == null) {
          throw Exception('Please pick an image');
        }
        result = await imageService.generate(
          presetName: 'GAME_ITEM_SPRITE_V1',
          sourceImage: image,
        );
      }

      final jobId = (result['jobId'] ?? result['job_id'])?.toString();

      // Insert gift into DB for durable next-day delivery
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) {
        throw Exception('Not authenticated');
      }
      final today = DateTime.now().toUtc();
      final deliverOn = DateTime.utc(today.year, today.month, today.day).add(const Duration(days: 1));

      await SupabaseConfig.client
          .from('gifts')
          .insert({
            'user_id': userId,
            'preset_name': 'GAME_ITEM_SPRITE_V1',
            'prompt': mode == 'text' ? description : null,
            'status': 'generating',
            'deliver_on': deliverOn.toIso8601String().substring(0, 10),
            'job_id': jobId,
            'price': 100,
            'metadata': {'mode': mode},
          });

      // Also schedule local delivery as fallback
      if (jobId != null) {
        await PendingGiftService.scheduleGiftDelivery(jobId: jobId, description: description);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gift ordered! It will arrive tomorrow.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.5),
      body: Center(
        child: Container(
          width: 500,
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF8E7C9),
            border: Border.all(color: const Color(0xFF8B6F3A), width: 8),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar: Gold and Close
                  Row(
                    children: [
                      const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        '$_playerGold',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.brown, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                        tooltip: 'Close Shop',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Shop title
                  Center(
                    child: Text(
                      'Shop',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade700,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(
                            color: Colors.brown.shade200,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Search bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.brown.shade200, width: 2),
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                        _filterItems();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Search items...',
                        prefixIcon: Icon(Icons.search, color: Colors.brown),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Items list
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E1B6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.brown.shade200, width: 2),
                      ),
                      child: _filteredItems.isEmpty
                          ? Center(
                              child: Text(
                                'No items found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.brown.shade400,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _filteredItems.length,
                              separatorBuilder: (_, __) => Divider(
                                color: Colors.brown.shade200,
                                height: 1,
                              ),
                              itemBuilder: (context, index) {
                                final item = _filteredItems[index];
                                return _buildStardewShopRow(item);
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStardewShopRow(ShopItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.brown.shade100, width: 1.5),
        ),
        child: InkWell(
          onTap: () => _purchaseItem(item),
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            leading: item.id == 'gift' 
              ? Image.asset(
                  'assets/images/gift_1.png',
                  width: 32,
                  height: 32,
                  fit: BoxFit.contain,
                )
              : Text(
                  item.iconEmoji ?? '📦',
                  style: const TextStyle(fontSize: 32),
                ),
            title: Text(
              item.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.brown,
              ),
            ),
            subtitle: Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.brown.shade400, fontSize: 14),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                const SizedBox(width: 2),
                Text(
                  '${item.price}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.brown,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
    );
  }
} 
