import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:lovenest/game/simple_enhanced_farm_game.dart';
import 'package:lovenest/models/inventory.dart';
import 'package:lovenest/models/chest_storage.dart';
import 'package:lovenest/config/supabase_config.dart';

class MapTestScreen extends StatefulWidget {
  const MapTestScreen({super.key});

  @override
  State<MapTestScreen> createState() => _MapTestScreenState();
}

class _MapTestScreenState extends State<MapTestScreen> {
  late final SimpleEnhancedFarmGame _gameInstance;
  late final InventoryManager _inventoryManager;
  bool _isLoading = false;
  String? _lastError;
  String? _lastSuccess;
  int _reloadCount = 0;

  @override
  void initState() {
    super.initState();
    _inventoryManager = InventoryManager();
    _initializeGame();
  }

  void _initializeGame() {
    // Use a test farm ID for the map test screen
    const testFarmId = 'map-test-farm';
    
    _gameInstance = SimpleEnhancedFarmGame(
      farmId: testFarmId,
      inventoryManager: _inventoryManager,
      onOwlTapped: (question) {
        // Handle owl tap if needed for testing
        debugPrint('[MapTestScreen] Owl tapped with question: ${question.text}');
      },
      onExamine: (text, chest) {
        // Handle examine if needed for testing
        debugPrint('[MapTestScreen] Examine: $text');
        if (chest != null) {
          debugPrint('[MapTestScreen] Chest found: ${chest.id}');
        }
      },
      onPlantSeed: (gridX, gridY, selectedItem) {
        // Handle planting if needed for testing
        debugPrint('[MapTestScreen] Plant seed at ($gridX, $gridY)');
      },
    );
  }

  Future<void> _reloadMap() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
      _lastSuccess = null;
    });

    try {
      await _gameInstance.reloadMap();
      setState(() {
        _reloadCount++;
        _lastSuccess = 'Map reloaded successfully from valley.tmx (Reload #$_reloadCount)';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _lastError = 'Error reloading map: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _resetGame() async {
    setState(() {
      _isLoading = true;
      _lastError = null;
      _lastSuccess = null;
    });

    try {
      // Reinitialize the game instance
      _initializeGame();
      setState(() {
        _lastSuccess = 'Game reset successfully';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _lastError = 'Error resetting game: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showLayerInfo() async {
    try {
      final groundData = _gameInstance.groundTileData;
      final decorationData = _gameInstance.decorationTileData;
      
      String info = 'Layer Information:\n\n';
      
      if (groundData != null) {
        final groundTileCounts = <int, int>{};
        int totalGroundTiles = 0;
        for (int y = 0; y < groundData.length; y++) {
          for (int x = 0; x < groundData[0].length; x++) {
            final gid = groundData[y][x];
            if (gid > 0) {
              groundTileCounts[gid] = (groundTileCounts[gid] ?? 0) + 1;
              totalGroundTiles++;
            }
          }
        }
        info += 'Ground Layer:\n';
        info += '- Size: ${groundData.length}x${groundData[0].length}\n';
        info += '- Total tiles: $totalGroundTiles\n';
        info += '- Unique tile types: ${groundTileCounts.length}\n';
        info += '- Top 5 tile types: ${groundTileCounts.entries.take(5).map((e) => 'GID${e.key}:${e.value}').join(', ')}\n\n';
      } else {
        info += 'Ground Layer: Not loaded\n\n';
      }
      
      if (decorationData != null) {
        final decorationTileCounts = <int, int>{};
        int totalDecorationTiles = 0;
        for (int y = 0; y < decorationData.length; y++) {
          for (int x = 0; x < decorationData[0].length; x++) {
            final gid = decorationData[y][x];
            if (gid > 0) {
              decorationTileCounts[gid] = (decorationTileCounts[gid] ?? 0) + 1;
              totalDecorationTiles++;
            }
          }
        }
        info += 'Decoration Layer:\n';
        info += '- Size: ${decorationData.length}x${decorationData[0].length}\n';
        info += '- Total tiles: $totalDecorationTiles\n';
        info += '- Unique tile types: ${decorationTileCounts.length}\n';
        if (decorationTileCounts.isNotEmpty) {
          info += '- Tile types: ${decorationTileCounts.entries.map((e) => 'GID${e.key}:${e.value}').join(', ')}\n';
        }
      } else {
        info += 'Decoration Layer: Not loaded';
      }
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Layer Information'),
          content: SingleChildScrollView(
            child: Text(info, style: const TextStyle(fontFamily: 'monospace')),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error showing layer info: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Test Screen'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.close),
            tooltip: 'Close Test Screen',
          ),
        ],
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Map Testing Controls',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Status indicators
                Row(
                  children: [
                    Icon(
                      _isLoading ? Icons.hourglass_empty : Icons.check_circle,
                      color: _isLoading ? Colors.orange : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isLoading ? 'Loading...' : 'Ready',
                      style: TextStyle(
                        color: _isLoading ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Reloads: $_reloadCount',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _reloadMap,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reload Map'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _resetGame,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset Game'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Debug info button
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _showLayerInfo,
                  icon: const Icon(Icons.info),
                  label: const Text('Show Layer Info'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Status messages
                if (_lastSuccess != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lastSuccess!,
                            style: TextStyle(color: Colors.green.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (_lastError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _lastError!,
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Game View
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: GameWidget<SimpleEnhancedFarmGame>.controlled(
                gameFactory: () => _gameInstance,
                loadingBuilder: (context) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading Map Test...'),
                    ],
                  ),
                ),
                errorBuilder: (context, error) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Error Loading Game',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Clean up any resources if needed
    super.dispose();
  }
}
