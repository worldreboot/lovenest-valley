import 'package:flutter/material.dart';
import '../../models/inventory.dart';
import 'inventory_slot.dart';

class InventoryBar extends StatelessWidget {
  final InventoryManager inventoryManager;

  const InventoryBar({
    super.key,
    required this.inventoryManager,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: inventoryManager,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              InventoryManager.maxSlots,
              (index) => InventorySlot(
                slotIndex: index,
                item: inventoryManager.slots[index],
                isSelected: inventoryManager.selectedSlotIndex == index,
                onTap: () => inventoryManager.selectSlot(index),
              ),
            ),
          ),
        );
      },
    );
  }
} 
