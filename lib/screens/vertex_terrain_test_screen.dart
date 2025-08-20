import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:lovenest/game/vertex_terrain_game.dart';
import 'package:lovenest/models/inventory.dart';

class VertexTerrainTestScreen extends StatefulWidget {
  const VertexTerrainTestScreen({super.key});

  @override
  State<VertexTerrainTestScreen> createState() => _VertexTerrainTestScreenState();
}

class _VertexTerrainTestScreenState extends State<VertexTerrainTestScreen> {
  late InventoryManager inventoryManager;

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
        title: const Text('Vertex Terrain System Test'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Game area
          Expanded(
            child: GameWidget(
              game: VertexTerrainGame(
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
                const Text(
                  'Vertex Terrain System Demo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Tap tiles to till them with the hoe\n'
                  '• The system uses vertex-based terrain\n'
                  '• Each tile is determined by its 4 corner vertices\n'
                  '• Changes automatically update surrounding tiles',
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
                  ],
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