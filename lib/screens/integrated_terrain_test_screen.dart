import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:lovenest/game/simple_enhanced_farm_game.dart';
import 'package:lovenest/models/inventory.dart';

class IntegratedTerrainTestScreen extends StatefulWidget {
  const IntegratedTerrainTestScreen({super.key});

  @override
  State<IntegratedTerrainTestScreen> createState() => _IntegratedTerrainTestScreenState();
}

class _IntegratedTerrainTestScreenState extends State<IntegratedTerrainTestScreen> {
  late InventoryManager inventoryManager;
  SimpleEnhancedFarmGame? gameInstance;

  @override
  void initState() {
    super.initState();
    inventoryManager = InventoryManager();
    
    // Add some test items to inventory
    inventoryManager.addItem(const InventoryItem(
      id: 'hoe',
      name: 'Iron Hoe',
      iconPath: 'images/items/hoe.png',
    ));
    inventoryManager.addItem(const InventoryItem(
      id: 'watering_can',
      name: 'Watering Can',
      iconPath: 'images/items/watering_can.png',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Integrated Terrain System Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          // Add a toggle button in the app bar
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            onPressed: () {
              gameInstance?.toggleTerrainSystem();
              setState(() {
                // Rebuild to update the UI
              });
            },
            tooltip: 'Toggle Terrain System',
          ),
        ],
      ),
      body: Column(
        children: [
          // Game area
          Expanded(
            child: GameWidget(
              game: SimpleEnhancedFarmGame(
                farmId: 'test_farm',
                inventoryManager: inventoryManager,
              ),
            ),
          ),
          // Controls area
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Integrated Terrain System Demo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // System indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        gameInstance?.currentTerrainSystem ?? 'Loading...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                                 const Text(
                   '• Use hoe to convert grass to dirt\n'
                   '• Use watering can to convert dirt to tilled soil\n'
                   '• Use the toggle button to switch between systems\n'
                   '• Vertex-based: Uses corner vertices for terrain\n'
                   '• Auto-tiling: Uses procedural auto-tiling\n'
                   '• Both systems work with the same game logic',
                   style: TextStyle(fontSize: 14),
                 ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Selected Tool: '),
                    DropdownButton<String>(
                      value: inventoryManager.selectedItem?.id,
                      items: inventoryManager.slots
                          .where((item) => item != null)
                          .map((item) => DropdownMenuItem(
                                value: item!.id,
                                child: Text(item.name),
                              ))
                          .toList(),
                      onChanged: (String? itemId) {
                        if (itemId != null) {
                          final index = inventoryManager.slots
                              .indexWhere((item) => item?.id == itemId);
                          if (index != -1) {
                            inventoryManager.selectSlot(index);
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () {
                        gameInstance?.toggleTerrainSystem();
                        setState(() {
                          // Rebuild to update the UI
                        });
                      },
                      child: const Text('Toggle System'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Current System: ${gameInstance?.currentTerrainSystem ?? 'Loading...'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    inventoryManager.dispose();
    super.dispose();
  }
} 