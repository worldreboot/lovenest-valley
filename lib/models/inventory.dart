import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lovenest/services/inventory_service.dart';

/// Represents an item that can be stored in inventory
class InventoryItem {
  final String id;
  final String name;
  final String? iconPath;
  final int quantity;
  final Color? itemColor;

  const InventoryItem({
    required this.id,
    required this.name,
    this.iconPath,
    this.quantity = 1,
    this.itemColor,
  });

  InventoryItem copyWith({
    String? id,
    String? name,
    String? iconPath,
    int? quantity,
    Color? itemColor,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      iconPath: iconPath ?? this.iconPath,
      quantity: quantity ?? this.quantity,
      itemColor: itemColor ?? this.itemColor,
    );
  }
}

/// Manages the player's inventory state with backend sync
class InventoryManager extends ChangeNotifier {
  static const int maxSlots = 4;
  
  // Inventory slots - null means empty slot
  final List<InventoryItem?> _slots = List.filled(maxSlots, null);
  
  // Currently selected slot index
  int _selectedSlotIndex = 0;

  // Getters
  List<InventoryItem?> get slots => List.unmodifiable(_slots);
  int get selectedSlotIndex => _selectedSlotIndex;
  InventoryItem? get selectedItem => _slots[_selectedSlotIndex];
  
  /// Returns true if there is at least one empty slot
  bool get hasEmptySlot => _slots.any((slot) => slot == null);
  
  /// Returns true if the inventory can accept an item with the given ID
  /// Either by stacking with an existing item or using an empty slot
  bool canAcceptItemId(String itemId) {
    for (int i = 0; i < maxSlots; i++) {
      final slot = _slots[i];
      if (slot == null) return true; // empty slot available
      if (slot.id == itemId) return true; // stackable with same id
    }
    return false;
  }
  
  /// Initialize inventory from backend
  Future<void> initialize() async {
    debugPrint('[InventoryManager] 🔄 Initializing inventory from backend');
    final inventory = await InventoryService.loadInventory();
    _updateSlots(inventory);
    notifyListeners();
  }

  /// Selects a slot by index
  void selectSlot(int index) {
    if (index >= 0 && index < maxSlots) {
      _selectedSlotIndex = index;
      notifyListeners();
    }
  }

  /// Adds an item to the inventory (backend sync)
  Future<bool> addItem(InventoryItem item) async {
    debugPrint('[InventoryManager] ➕ Adding item to inventory: ${item.name}');
    
    // First try to stack with existing items
    for (int i = 0; i < maxSlots; i++) {
      if (_slots[i]?.id == item.id) {
        final newQuantity = _slots[i]!.quantity + item.quantity;
        final success = await InventoryService.updateItemQuantity(item.id, newQuantity);
        if (success) {
          // Ensure icon/tint are set when stacking if missing or different
          final needsIconUpdate = (_slots[i]!.iconPath == null && item.iconPath != null) ||
              (_slots[i]!.itemColor == null && item.itemColor != null);

          if (needsIconUpdate) {
            await InventoryService.updateItemAppearance(
              itemId: item.id,
              iconPath: item.iconPath,
              itemColor: item.itemColor,
            );
            _slots[i] = _slots[i]!.copyWith(
              quantity: newQuantity,
              iconPath: item.iconPath ?? _slots[i]!.iconPath,
              itemColor: item.itemColor ?? _slots[i]!.itemColor,
            );
          } else {
            _slots[i] = _slots[i]!.copyWith(quantity: newQuantity);
          }
          notifyListeners();
          return true;
        }
        return false;
      }
    }

    // Find first empty slot
    for (int i = 0; i < maxSlots; i++) {
      if (_slots[i] == null) {
        final success = await InventoryService.addItem(item, i);
        if (success) {
          _slots[i] = item;
          // Normalize chest icon path to chest asset if missing/wrong
          if (item.id == 'chest' && (item.iconPath == null || !item.iconPath!.contains('Chests/1.png'))) {
            await InventoryService.updateItemIconPath(item.id, 'assets/images/Chests/1.png');
            _slots[i] = item.copyWith(iconPath: 'assets/images/Chests/1.png');
          }
          notifyListeners();
          return true;
        }
        return false;
      }
    }

    return false; // Inventory full
  }

  /// Removes an item from a specific slot (backend sync)
  Future<void> removeItem(int slotIndex) async {
    if (slotIndex >= 0 && slotIndex < maxSlots && _slots[slotIndex] != null) {
      final itemId = _slots[slotIndex]!.id;
      final success = await InventoryService.removeItem(itemId);
      if (success) {
        _slots[slotIndex] = null;
        notifyListeners();
      }
    }
  }

  /// Sets an item in a specific slot (for testing/debugging)
  void setItem(int slotIndex, InventoryItem? item) {
    if (slotIndex >= 0 && slotIndex < maxSlots) {
      _slots[slotIndex] = item;
      notifyListeners();
    }
  }

  /// Clears all inventory slots (backend sync)
  Future<void> clearInventory() async {
    final success = await InventoryService.clearInventory();
    if (success) {
      for (int i = 0; i < maxSlots; i++) {
        _slots[i] = null;
      }
      _selectedSlotIndex = 0;
      notifyListeners();
    }
  }

  /// Update slots from backend data
  void _updateSlots(List<InventoryItem?> newSlots) {
    for (int i = 0; i < maxSlots && i < newSlots.length; i++) {
      _slots[i] = newSlots[i];
    }
  }

  /// Refresh inventory from backend
  Future<void> refresh() async {
    debugPrint('[InventoryManager] 🔄 Refreshing inventory from backend');
    final inventory = await InventoryService.loadInventory();
    _updateSlots(inventory);
    notifyListeners();
  }
} 