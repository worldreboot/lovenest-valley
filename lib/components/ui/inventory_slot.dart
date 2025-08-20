import 'package:flutter/material.dart';
import '../../models/inventory.dart';
import '../../utils/seed_color_generator.dart';

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
            // Selection indicator (behind everything)
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
          ],
        ),
      ),
    );
  }

  Widget _buildItemIcon() {
    // Special case: Daily Question Seed should look like the Owl UI seed
    if (item != null && (item!.id == 'daily_question_seed' || item!.id.startsWith('daily_question_seed'))) {
      // Use stored tint if present, otherwise derive from questionId embedded in the inventory id
      final String rawId = item!.id;
      String seedKey = rawId;
      const String prefix = 'daily_question_seed_';
      if (rawId.startsWith(prefix) && rawId.length > prefix.length) {
        seedKey = rawId.substring(prefix.length);
      }
      final Color tint = item!.itemColor ?? SeedColorGenerator.generateSeedColor(seedKey);
      return Image.asset(
        'assets/images/items/seeds.png',
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        color: tint,
        colorBlendMode: BlendMode.modulate,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[InventorySlot] Failed to load daily seed asset icon, using default: $error');
          return _buildDefaultIcon();
        },
      );
    }

    if (item?.iconPath != null) {
      final path = item!.iconPath!;
      final isNetwork = path.startsWith('http');
      debugPrint('[InventorySlot] Loading custom icon (${isNetwork ? 'network' : 'asset'}): $path');

      // Special handling for colored seeds (assets only)
      if (!isNetwork && item!.name.toLowerCase().contains('seed') && item!.itemColor != null) {
        return Image.asset(
          path,
          width: 40,
          height: 40,
          fit: BoxFit.contain,
          color: item!.itemColor,
          colorBlendMode: BlendMode.modulate,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('[InventorySlot] Failed to load custom asset icon: $path, Error: $error');
            return _buildDefaultIcon();
          },
        );
      }

      final imageWidget = isNetwork
          ? Image.network(
              path,
              width: 40,
              height: 40,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('[InventorySlot] Failed to load network icon: $path, Error: $error');
                return _buildDefaultIcon();
              },
            )
          : Image.asset(
              path,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                debugPrint('[InventorySlot] Failed to load asset icon: $path, Error: $error');
                return _buildDefaultIcon();
              },
            );

      return imageWidget;
    } else {
      debugPrint('[InventorySlot] No custom icon path, using default icon for: ${item?.name}');
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
      case 'watering_can':
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