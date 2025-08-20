import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/chest_storage.dart';
import '../../services/chest_storage_service.dart';
import '../../models/inventory.dart';
import '../../services/inventory_service.dart';

class ChestStorageUI extends StatefulWidget {
  final ChestStorage chest;
  final VoidCallback? onClose;
  final Function(ChestItem)? onItemSelected;
  final InventoryManager? inventoryManager;

  const ChestStorageUI({
    super.key,
    required this.chest,
    this.onClose,
    this.onItemSelected,
    this.inventoryManager,
  });

  @override
  State<ChestStorageUI> createState() => _ChestStorageUIState();
}

class _ChestStorageUIState extends State<ChestStorageUI> {
  final ChestStorageService _chestService = ChestStorageService();
  bool _isLoading = false;
  late ChestStorage _currentChest;
  StreamSubscription<ChestStorage>? _chestSub;

  @override
  void initState() {
    super.initState();
    _currentChest = widget.chest;
    // Ensure we display the freshest state when opening the UI
    _refreshChest();
    // Subscribe to realtime chest updates (from partner) and keep UI in sync
    _subscribeToChestUpdates();
  }

  @override
  void dispose() {
    _chestSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshChest() async {
    try {
      final fresh = await _chestService.getChest(_currentChest.id);
      if (fresh != null && mounted) {
        setState(() => _currentChest = fresh);
      }
    } catch (_) {}
  }

  Future<void> _subscribeToChestUpdates() async {
    try {
      // Initialize realtime for this couple if not already initialized
      await _chestService.initializeRealtime(_currentChest.coupleId);
      _chestSub?.cancel();
      _chestSub = _chestService.chestUpdates.listen((updated) async {
        if (!mounted) return;
        if (updated.id == _currentChest.id) {
          // Fetch authoritative state to avoid any payload shape/race issues
          await _refreshChest();
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 600,
        height: 500, // Reduced from 700 to 500
        decoration: BoxDecoration(
          // Brighter Stardew Valley chest appearance
          color: const Color(0xFF8B4513), // Warmer, brighter brown base
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFD2691E), // Brighter orange-brown border
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header - Brighter Stardew Valley style
            Container(
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFCD853F), // Brighter medium brown header
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5),
                  topRight: Radius.circular(5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Only the close button remains
                  Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDEB887), // Brighter light brown
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: const Color(0xFFD2691E),
                        width: 1,
                      ),
                    ),
                    child: IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(
                        Icons.close,
                        color: Color(0xFF2F1B14), // Darker text for contrast
                        size: 20,
                      ),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Existing inventory overlay remains on the hosting screen; do not duplicate here
            
            // Items grid - Brighter Stardew Valley style
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5DEB3), // Much brighter wheat-colored background
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFD2691E),
                    width: 2,
                  ),
                ),
                child: _buildItemsGrid(),
              ),
            ),

            // No footer buttons; use tap-to-store/tap-to-withdraw
          ],
        ),
      ),
    );
  }

  Widget _buildStardewButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: onPressed != null ? color : const Color(0xFF6D4C41),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: onPressed != null 
              ? color.withOpacity(0.8)
              : const Color(0xFF5D4037),
          width: 2,
        ),
        boxShadow: onPressed != null ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: const Color(0xFFD7CCC8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFD7CCC8),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF6D4C41),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF5D4037),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Color(0xFFD7CCC8),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chest is Empty',
            style: TextStyle(
              color: Color(0xFFD7CCC8),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add some items to get started!',
            style: TextStyle(
              color: Color(0xFFBCAAA4),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsGrid() {
    // Always show all slots (filled and empty)
    final int totalSlots = 16; // 4 columns x 4 rows
    final items = List<ChestItem?>.filled(totalSlots, null);
    for (int i = 0; i < _currentChest.items.length && i < totalSlots; i++) {
      items[i] = _currentChest.items[i];
    }
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // Now 4 columns per row
        crossAxisSpacing: 8, // More space between slots
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: totalSlots,
      itemBuilder: (context, index) {
        final item = items[index];
        return GestureDetector(
          onTap: () => _onSlotTap(index, item),
          child: _buildItemSlot(item),
        );
      },
    );
  }

  bool _canStoreSelected() {
    final inv = widget.inventoryManager;
    if (inv == null) return false;
    final selected = inv.selectedItem;
    if (selected == null) return false;
    // Prevent storing chest inside chest for now
    if (selected.id == 'chest') return false;
    // Check capacity
    return _currentChest.hasSpace;
  }

  Future<void> _onSlotTap(int index, ChestItem? slotItem) async {
    // If slot has an item: take one out to inventory
    if (slotItem != null) {
      final inv = widget.inventoryManager;
      if (inv == null) return;
      // Try adding to inventory first
      final added = await inv.addItem(InventoryItem(
        id: slotItem.id,
        name: slotItem.name,
        iconPath: slotItem.iconPath,
        quantity: 1,
      ));
      if (!added) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inventory full'), backgroundColor: Color(0xFFF44336)),
          );
        }
        return;
      }
      // Remove one from chest (backend if synced)
      try {
        if (_currentChest.syncStatus == 'local_only') {
          setState(() {
            _currentChest = _currentChest.removeItem(slotItem.id, quantity: 1);
          });
        } else {
          final updated = await _chestService.removeItemFromChest(_currentChest.id, slotItem.id, quantity: 1);
          setState(() => _currentChest = updated);
          // Ensure we render authoritative state from DB (handles concurrent partner updates)
          await _refreshChest();
        }
      } catch (e) {
        // Roll back inventory add on failure
        final slotIdx = inv.slots.indexWhere((it) => it?.id == slotItem.id);
        if (slotIdx != -1) {
          final it = inv.slots[slotIdx]!;
          if (it.quantity > 1) {
            await InventoryService.updateItemQuantity(it.id, it.quantity - 1);
            inv.setItem(slotIdx, it.copyWith(quantity: it.quantity - 1));
          } else {
            await inv.removeItem(slotIdx);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove from chest: $e'), backgroundColor: const Color(0xFFF44336)),
          );
        }
      }
      return;
    }

    // If slot is empty: store selected inventory item into chest (1 unit)
    final inv = widget.inventoryManager;
    final selected = inv?.selectedItem;
    if (inv == null || selected == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select an item first'), backgroundColor: Color(0xFFFF9800)),
        );
      }
      return;
    }
    if (!_currentChest.hasSpace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chest is full'), backgroundColor: Color(0xFFF44336)),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final item = ChestItem(
        id: selected.id,
        name: selected.name,
        iconPath: selected.iconPath,
        quantity: 1,
      );
      if (_currentChest.syncStatus == 'local_only') {
        setState(() => _currentChest = _currentChest.addItem(item));
      } else {
        final updated = await _chestService.addItemToChest(_currentChest.id, item);
        setState(() => _currentChest = updated);
        // Extra safety: fetch fresh from DB to avoid any race with optimistic locking
        await _refreshChest();
      }

      // Decrement inventory selected item by 1
      if (selected.quantity > 1) {
        await InventoryService.updateItemQuantity(selected.id, selected.quantity - 1);
        inv.setItem(inv.selectedSlotIndex, selected.copyWith(quantity: selected.quantity - 1));
      } else {
        await inv.removeItem(inv.selectedSlotIndex);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to store item: $e'), backgroundColor: const Color(0xFFF44336)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  Future<void> _storeSelectedItem() async {
    if (_isLoading) return;
    final inv = widget.inventoryManager;
    final selected = inv?.selectedItem;
    if (inv == null || selected == null) return;

    setState(() => _isLoading = true);
    try {
      final item = ChestItem(
        id: selected.id,
        name: selected.name,
        iconPath: selected.iconPath,
        quantity: 1,
      );
      if (_currentChest.syncStatus == 'local_only') {
        // Update locally only
        setState(() => _currentChest = _currentChest.addItem(item));
      } else {
        final updated = await _chestService.addItemToChest(_currentChest.id, item);
        setState(() => _currentChest = updated);
      }

      // Remove one from inventory
      inv.removeItem(inv.selectedSlotIndex);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stored ${selected.name} in chest'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to store item: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildItemSlot(ChestItem? item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF6D4C41), // Medium brown slot
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: item != null ? const Color(0xFFBCAAA4) : const Color(0xFF5D4037),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: item != null
          ? Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8D6E63),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF6D4C41),
                            width: 1,
                          ),
                        ),
                        child: _buildChestItemIcon(item),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            color: Color(0xFFD7CCC8),
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (item.quantity > 1)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFF1565C0),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: Color(0xFFD7CCC8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Opacity(
                opacity: 0.18,
                child: Icon(
                  Icons.crop_square,
                  size: 32,
                  color: const Color(0xFFD7CCC8),
                ),
              ),
            ),
    );
  }

  IconData _getItemIcon(String itemName) {
    switch (itemName.toLowerCase()) {
      case 'wood':
        return Icons.forest;
      case 'seeds':
        return Icons.local_florist;
      case 'watering_can':
      case 'watering_can_full':
        return Icons.water_drop;
      case 'watering_can_empty':
        return Icons.water_drop_outlined;
      case 'hoe':
        return Icons.agriculture;
      case 'stone':
        return Icons.landscape;
      case 'food':
        return Icons.restaurant;
      case 'tool':
        return Icons.build;
      case 'flower':
        return Icons.eco;
      case 'gem':
        return Icons.diamond;
      case 'coin':
        return Icons.monetization_on;
      default:
        return Icons.inventory;
    }
  }

  Widget _buildChestItemIcon(ChestItem item) {
    final path = item.iconPath;
    if (path == null || path.isEmpty) {
      return Icon(
        _getItemIcon(item.name),
        color: const Color(0xFFD7CCC8),
        size: 20,
      );
    }

    final isNetwork = path.startsWith('http');
    return isNetwork
        ? Image.network(
            path,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Icon(
              _getItemIcon(item.name),
              color: const Color(0xFFD7CCC8),
              size: 20,
            ),
          )
        : Image.asset(
            path,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stack) => Icon(
              _getItemIcon(item.name),
              color: const Color(0xFFD7CCC8),
              size: 20,
            ),
          );
  }

  Future<void> _addTestItem() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final testItems = [
        ChestItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: 'Wood',
          quantity: 5,
          description: 'Basic building material',
        ),
        ChestItem(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          name: 'Stone',
          quantity: 3,
          description: 'Solid foundation material',
        ),
        ChestItem(
          id: (DateTime.now().millisecondsSinceEpoch + 2).toString(),
          name: 'Seeds',
          quantity: 2,
          description: 'Plant this to grow something beautiful',
        ),
      ];

      final randomItem = testItems[DateTime.now().millisecond % testItems.length];
      
      await _chestService.addItemToChest(widget.chest.id, randomItem);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${randomItem.name} to chest'),
            backgroundColor: const Color(0xFF4CAF50),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding item: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _clearChest() async {
    if (_isLoading) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF4E342E),
        title: const Text(
          'Clear Chest',
          style: TextStyle(color: Color(0xFFD7CCC8)),
        ),
        content: const Text(
          'Are you sure you want to remove all items from this chest?',
          style: TextStyle(color: Color(0xFFD7CCC8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFFD7CCC8)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFF44336)),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Remove all items one by one
      for (final item in widget.chest.items) {
        await _chestService.removeItemFromChest(
          widget.chest.id,
          item.id,
          quantity: item.quantity,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chest cleared'),
            backgroundColor: Color(0xFFFF9800),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing chest: $e'),
            backgroundColor: const Color(0xFFF44336),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 