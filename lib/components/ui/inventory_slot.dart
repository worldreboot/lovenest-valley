import 'package:flutter/material.dart';
import '../../models/inventory.dart';

class InventorySlot extends StatelessWidget {
  final int slotIndex;
  final InventoryItem? item;
  final bool isSelected;
  final VoidCallback onTap;

  const InventorySlot({
    super.key,
    required this.slotIndex,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.black.withOpacity(0.6),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: isSelected ? 3 : 2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Item icon or empty slot
            Center(
              child: item != null
                  ? _buildItemIcon()
                  : Icon(
                      Icons.add,
                      color: Colors.grey.withOpacity(0.5),
                      size: 24,
                    ),
            ),
            
            // Quantity badge
            if (item != null && item!.quantity > 1)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item!.quantity.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              
            // Selection indicator
            if (isSelected)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemIcon() {
    if (item?.iconPath != null) {
      // Try to load custom icon from assets
      return Image.asset(
        item!.iconPath!,
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultIcon();
        },
      );
    } else {
      return _buildDefaultIcon();
    }
  }

  Widget _buildDefaultIcon() {
    // Default icons based on item type/name
    IconData iconData;
    Color iconColor;

    switch (item?.name.toLowerCase()) {
      case 'seed':
      case 'seeds':
        iconData = Icons.eco;
        iconColor = Colors.green;
        break;
      case 'water':
      case 'watering can':
      case 'watering_can_full':
      case 'watering_can_empty':
        iconData = Icons.water_drop;
        iconColor = item?.id == 'watering_can_empty' ? Colors.grey : Colors.blue;
        break;
      case 'tool':
      case 'hoe':
        iconData = Icons.construction;
        iconColor = Colors.brown;
        break;
      case 'crop':
      case 'wheat':
      case 'corn':
        iconData = Icons.grass;
        iconColor = Colors.orange;
        break;
      default:
        iconData = Icons.category;
        iconColor = Colors.grey;
    }

    return Icon(
      iconData,
      color: iconColor,
      size: 32,
    );
  }
} 