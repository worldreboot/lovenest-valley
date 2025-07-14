import 'package:flutter/foundation.dart';

/// Represents an item that can be stored in inventory
class InventoryItem {
  final String id;
  final String name;
  final String? iconPath;
  final int quantity;

  const InventoryItem({
    required this.id,
    required this.name,
    this.iconPath,
    this.quantity = 1,
  });

  InventoryItem copyWith({
    String? id,
    String? name,
    String? iconPath,
    int? quantity,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      iconPath: iconPath ?? this.iconPath,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// Manages the player's inventory state
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
  
  /// Selects a slot by index
  void selectSlot(int index) {
    if (index >= 0 && index < maxSlots) {
      _selectedSlotIndex = index;
      notifyListeners();
    }
  }

  /// Adds an item to the inventory
  /// Returns true if successful, false if inventory is full
  bool addItem(InventoryItem item) {
    // First try to stack with existing items
    for (int i = 0; i < maxSlots; i++) {
      if (_slots[i]?.id == item.id) {
        _slots[i] = _slots[i]!.copyWith(
          quantity: _slots[i]!.quantity + item.quantity,
        );
        notifyListeners();
        return true;
      }
    }

    // Find first empty slot
    for (int i = 0; i < maxSlots; i++) {
      if (_slots[i] == null) {
        _slots[i] = item;
        notifyListeners();
        return true;
      }
    }

    return false; // Inventory full
  }

  /// Removes an item from a specific slot
  void removeItem(int slotIndex) {
    if (slotIndex >= 0 && slotIndex < maxSlots) {
      _slots[slotIndex] = null;
      notifyListeners();
    }
  }

  /// Sets an item in a specific slot (for testing/debugging)
  void setItem(int slotIndex, InventoryItem? item) {
    if (slotIndex >= 0 && slotIndex < maxSlots) {
      _slots[slotIndex] = item;
      notifyListeners();
    }
  }

  /// Clears all inventory slots
  void clearInventory() {
    for (int i = 0; i < maxSlots; i++) {
      _slots[i] = null;
    }
    _selectedSlotIndex = 0;
    notifyListeners();
  }
} 