import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:lovenest_valley/game/custom_tiled_farm_game.dart';
import 'package:lovenest_valley/utils/tiled_parser_test.dart';
import 'package:lovenest_valley/services/farm_service.dart';

/// A test screen that demonstrates the custom Tiled parser integration
class CustomTiledTestScreen extends StatefulWidget {
  const CustomTiledTestScreen({super.key});

  @override
  State<CustomTiledTestScreen> createState() => _CustomTiledTestScreenState();
}

class _CustomTiledTestScreenState extends State<CustomTiledTestScreen> {
  bool _isLoading = true;
  String _testResults = '';

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _testResults = 'Running tests...\n';
    });

    try {
      // Run the parser tests
      await TiledParserTest.runAllTests();
      
      setState(() {
        _isLoading = false;
        _testResults = '✅ All tests passed!\n\nCustom Tiled parser is ready for integration.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _testResults = '❌ Tests failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Tiled Parser Test'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Test Results Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isLoading ? Icons.hourglass_empty : Icons.check_circle,
                          color: _isLoading ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isLoading ? 'Running Tests...' : 'Test Results',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _testResults,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Game Integration Section
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.games,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Game Integration Demo',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'This demonstrates the custom Tiled parser integration:',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      _buildFeatureList(),
                      const SizedBox(height: 16),
                      const Text(
                        'Tap the game area to test tile interactions:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Tap to place tiles\n'
                        '• Auto-tiling will blend tiles\n'
                        '• Tile properties are accessible\n'
                        '• Real-time updates work',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _runTests,
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildFeatureList() {
    final features = [
      '✅ Custom tileset parsing (57 wang tiles)',
      '✅ Custom map parsing (64x28 grid)',
      '✅ Auto-tiling with wang tiles',
      '✅ Tile property access (isTillable, tileType)',
      '✅ Dynamic tile updates',
      '✅ Multiplayer sync support',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: features.map((feature) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          feature,
          style: const TextStyle(fontSize: 12),
        ),
      )).toList(),
    );
  }
}

/// A simple game widget for testing the custom parser
class CustomTiledGameWidget extends StatefulWidget {
  const CustomTiledGameWidget({super.key});

  @override
  State<CustomTiledGameWidget> createState() => _CustomTiledGameWidgetState();
}

class _CustomTiledGameWidgetState extends State<CustomTiledGameWidget> {
  String? farmId;
  bool _isLoadingFarm = true;

  @override
  void initState() {
    super.initState();
    _initializeFarm();
  }

  Future<void> _initializeFarm() async {
    try {
      farmId = await FarmService.getCurrentUserFarmId();
    } catch (e) {
      debugPrint('[CustomTiledGameWidget] ❌ Error getting farm: $e');
    } finally {
      setState(() {
        _isLoadingFarm = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFarm || farmId == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return GameWidget(
      game: CustomTiledFarmGame(
        farmId: farmId!,
      ),
      loadingBuilder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorBuilder: (context, error) => Center(
        child: Text('Error: $error'),
      ),
    );
  }
} 
