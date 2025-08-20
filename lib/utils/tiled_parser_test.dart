import 'package:flutter/foundation.dart';
import 'package:lovenest/utils/tiled_parser.dart' as custom_parser;

/// Simple test to verify the custom Tiled parsers work correctly
class TiledParserTest {
  
  /// Test the tileset parser with the actual ground.tsx file
  static Future<void> testTilesetParser() async {
    debugPrint('=== Testing Tileset Parser ===');
    
    try {
      // Test parsing the tileset file
      final tilesetParser = custom_parser.TilesetParser('assets/ground.tsx');
      await tilesetParser.load();
      
      // Get basic tileset information
      final tilesetInfo = tilesetParser.getTilesetInfo();
      debugPrint('✅ Tileset info loaded: $tilesetInfo');
      
      // Get image source
      final imageSource = tilesetParser.getImageSource();
      debugPrint('✅ Image source: $imageSource');
      
      // Get wang tiles for auto-tiling
      final wangTiles = tilesetParser.getWangTiles();
      debugPrint('✅ Found ${wangTiles.length} wang tiles for auto-tiling');
      
      // Print first few wang tiles for verification
      for (int i = 0; i < wangTiles.length && i < 3; i++) {
        final wangTile = wangTiles[i];
        debugPrint('  Wang tile ${i + 1}: ID=${wangTile.tileId}, WangID=${wangTile.wangId}');
      }
      
      // Get tile properties
      final tileProperties = tilesetParser.getTileProperties();
      debugPrint('✅ Found ${tileProperties.length} tiles with properties');
      
      // Print some example properties
      tileProperties.forEach((tileId, properties) {
        debugPrint('  Tile $tileId properties: $properties');
      });
      
      debugPrint('✅ Tileset parser test completed successfully!');
      
    } catch (e) {
      debugPrint('❌ Tileset parser test failed: $e');
      rethrow;
    }
  }
  
  /// Test the map parser with the actual valley.tmx file
  static Future<void> testMapParser() async {
    debugPrint('\n=== Testing Map Parser ===');
    
    try {
      // Test parsing the map file
      final mapParser = custom_parser.MapParser('assets/tiles/valley.tmx');
      await mapParser.load();
      
      // Get map information
      final mapInfo = mapParser.getMapInfo();
      debugPrint('✅ Map info loaded: $mapInfo');
      
      // Get tilesets referenced in the map
      final tilesets = mapParser.getTilesets();
      debugPrint('✅ Map references ${tilesets.length} tilesets');
      
      for (final tileset in tilesets) {
        debugPrint('  Tileset: firstGid=${tileset.firstGid}, source=${tileset.source}');
      }
      
      // Get layer data
      final groundLayer = mapParser.getLayerData('Ground');
      if (groundLayer != null) {
        debugPrint('✅ Ground layer: ${groundLayer.width}x${groundLayer.height}');
        debugPrint('✅ Sample tile data: ${groundLayer.data[0][0]}');
      } else {
        debugPrint('❌ Ground layer not found!');
      }
      
      // Get object groups
      final objectGroups = mapParser.getObjectGroups();
      debugPrint('✅ Found ${objectGroups.length} object groups');
      
      for (final group in objectGroups) {
        debugPrint('  Object group "${group.name}" has ${group.objects.length} objects');
      }
      
      debugPrint('✅ Map parser test completed successfully!');
      
    } catch (e) {
      debugPrint('❌ Map parser test failed: $e');
      rethrow;
    }
  }
  
  /// Test the auto-tiler with sample data
  static void testAutoTiler() {
    debugPrint('\n=== Testing Auto-Tiler ===');
    
    try {
      // Create some sample wang tiles (simplified)
      final wangTiles = [
        custom_parser.WangTile(
          tileId: 1,
          wangId: '0,0,0,0,0,0,0,0',
          wangColors: [custom_parser.WangColor(id: 1, name: 'Grass', color: '#00ff00', tile: -1, probability: 1.0)],
        ),
        custom_parser.WangTile(
          tileId: 2,
          wangId: '1,0,0,0,0,0,0,0',
          wangColors: [custom_parser.WangColor(id: 1, name: 'Grass', color: '#00ff00', tile: -1, probability: 1.0)],
        ),
        custom_parser.WangTile(
          tileId: 3,
          wangId: '1,1,0,0,0,0,0,0',
          wangColors: [custom_parser.WangColor(id: 1, name: 'Grass', color: '#00ff00', tile: -1, probability: 1.0)],
        ),
      ];
      
      final gidToTerrain = {1: 'Grass', 2: 'Grass', 3: 'Grass'};
      final autoTiler = custom_parser.AutoTiler(wangTiles, gidToTerrain);
      
      // Test with different 3x3 grids
      final testCases = [
        [
          [1, 1, 0], // Top row
          [1, 0, 0], // Middle row (center is what we're determining)
          [0, 0, 0], // Bottom row
        ],
        [
          [1, 1, 1], // Top row
          [1, 0, 1], // Middle row
          [1, 1, 1], // Bottom row
        ],
      ];
      
      for (int i = 0; i < testCases.length; i++) {
        final surroundingTiles = testCases[i];
        final appropriateTile = autoTiler.getTileForSurroundings(surroundingTiles);
        debugPrint('✅ Test case ${i + 1}: Appropriate tile ID: $appropriateTile');
      }
      
      debugPrint('✅ Auto-tiler test completed successfully!');
      
    } catch (e) {
      debugPrint('❌ Auto-tiler test failed: $e');
      rethrow;
    }
  }
  

  
  /// Run all tests
  static Future<void> runAllTests() async {
    debugPrint('🚀 Starting Tiled Parser Tests...\n');
    
    try {
      await testTilesetParser();
      await testMapParser();
      testAutoTiler();
      
      debugPrint('\n🎉 All tests completed successfully!');
      
    } catch (e) {
      debugPrint('\n💥 Test suite failed: $e');
      rethrow;
    }
  }
}
