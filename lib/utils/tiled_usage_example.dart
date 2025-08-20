import 'package:flame_tiled/flame_tiled.dart';
import 'package:lovenest/components/world/enhanced_dynamic_tilemap.dart';
import 'package:lovenest/utils/tiled_parser.dart' as custom_parser;

/// Example usage of the custom Tiled parsers and enhanced dynamic tilemap
class TiledUsageExample {
  
  /// Example of how to use the custom parsers directly
  static Future<void> demonstrateParsers() async {
    print('=== Custom Tiled Parser Demo ===');
    
    // Parse the tileset (.tsx) file
    final tilesetParser = custom_parser.TilesetParser('assets/ground.tsx');
    await tilesetParser.load();
    
    // Get basic tileset information
    final tilesetInfo = tilesetParser.getTilesetInfo();
    print('Tileset info: $tilesetInfo');
    
    // Get image source
    final imageSource = tilesetParser.getImageSource();
    print('Image source: $imageSource');
    
    // Get wang tiles for auto-tiling
    final wangTiles = tilesetParser.getWangTiles();
    print('Found ${wangTiles.length} wang tiles for auto-tiling');

    // Print some example wang tiles
    for (int i = 0; i < wangTiles.length && i < 5; i++) {
      final wangTile = wangTiles[i];
      print('Wang tile ${i + 1}: ID=${wangTile.tileId}, WangID=${wangTile.wangId}');
    }
    
    // Get tile properties
    final tileProperties = tilesetParser.getTileProperties();
    print('Found ${tileProperties.length} tiles with properties');
    
    // Print some example properties
    tileProperties.forEach((tileId, properties) {
      print('Tile $tileId properties: $properties');
    });
    
    // Parse the map (.tmx) file
    final mapParser = custom_parser.MapParser('assets/tiles/valley.tmx');
    await mapParser.load();
    
    // Get map information
    final mapInfo = mapParser.getMapInfo();
    print('Map info: $mapInfo');
    
    // Get tilesets referenced in the map
    final tilesets = mapParser.getTilesets();
    print('Map references ${tilesets.length} tilesets');
    
    // Get layer data
    final groundLayer = mapParser.getLayerData('Ground');
    if (groundLayer != null) {
      print('Ground layer: ${groundLayer.width}x${groundLayer.height}');
      print('Sample tile data: ${groundLayer.data[0][0]}');
    }
    
    // Get object groups
    final objectGroups = mapParser.getObjectGroups();
    print('Found ${objectGroups.length} object groups');
    
    for (final group in objectGroups) {
      print('Object group "${group.name}" has ${group.objects.length} objects');
    }
  }
  
  /// Example of how to use the auto-tiler
  static void demonstrateAutoTiling() {
    print('\n=== Auto-Tiling Demo ===');
    
    // Create some sample wang tiles (simplified)
    final wangTiles = [
      custom_parser.WangTile(
        tileId: 1,
        wangId: '0,0,0,0',
        wangColors: [],
      ),
      custom_parser.WangTile(
        tileId: 2,
        wangId: '1,0,0,0',
        wangColors: [],
      ),
      custom_parser.WangTile(
        tileId: 3,
        wangId: '1,1,0,0',
        wangColors: [],
      ),
    ];
    
    final autoTiler = custom_parser.AutoTiler(wangTiles);
    
    // Example 3x3 grid where center tile needs auto-tiling
    final surroundingTiles = [
      [1, 1, 0], // Top row
      [1, 0, 0], // Middle row (center is what we're determining)
      [0, 0, 0], // Bottom row
    ];
    
    final appropriateTile = autoTiler.getTileForSurroundings(surroundingTiles);
    print('For the given surroundings, appropriate tile ID: $appropriateTile');
  }
  
  /// Example of how to integrate with your game
  static Future<void> demonstrateGameIntegration() async {
    print('\n=== Game Integration Demo ===');
    
    // This would typically be done in your game's onLoad method
    // For demonstration, we'll show the structure:
    
    /*
    // 1. Load the Tiled map with flame_tiled (for initial layout)
    final tiledMap = await TiledComponent.load('assets/tiles/valley.tmx', Vector2.all(16));
    
    // 2. Create your enhanced dynamic tilemap
    final dynamicTilemap = EnhancedDynamicTilemap(tiledMap, tileSize: 16.0);
    
    // 3. Add it to your game
    game.add(dynamicTilemap);
    
    // 4. Later, when user interacts with tiles:
    await dynamicTilemap.updateTileWithAutoTiling(10, 10, 28); // Place tilled soil
    
    // 5. Check tile properties
    if (dynamicTilemap.hasTileProperty(10, 10, 'isTillable')) {
      print('This tile can be tilled!');
    }
    
    // 6. Get current tile
    final currentGid = dynamicTilemap.getGidAt(10, 10);
    print('Current tile GID: $currentGid');
    */
    
    print('Integration would involve:');
    print('1. Loading Tiled map with flame_tiled for initial layout');
    print('2. Creating EnhancedDynamicTilemap component');
    print('3. Using updateTileWithAutoTiling() for dynamic updates');
    print('4. Checking tile properties for game logic');
  }
}

/// Example of how to use the enhanced tilemap in a game component
class ExampleGameComponent {
  late EnhancedDynamicTilemap _tilemap;
  
  Future<void> initialize(RenderableTiledMap map) async {
    // Create the enhanced tilemap
    _tilemap = EnhancedDynamicTilemap(map, tileSize: 16.0);
    
    // The tilemap will automatically load and parse the .tsx and .tmx files
    // and set up auto-tiling
  }
  
  /// Example: Player tills the soil
  Future<void> tillSoil(int x, int y) async {
    // Check if the tile can be tilled
    if (_tilemap.hasTileProperty(x, y, 'isTillable')) {
      // Update to tilled soil (GID 28) with auto-tiling
      await _tilemap.updateTileWithAutoTiling(x, y, 28);
      print('Tilled soil at ($x, $y)');
    } else {
      print('Cannot till soil at ($x, $y)');
    }
  }
  
  /// Example: Player plants a crop
  Future<void> plantCrop(int x, int y) async {
    // Check if the tile is tilled soil
    final currentGid = _tilemap.getGidAt(x, y);
    if (currentGid == 28) { // Tilled soil
      // Plant crop (you'd use a different GID for crops)
      await _tilemap.updateTile(x, y, 29); // Example crop GID
      print('Planted crop at ($x, $y)');
    } else {
      print('Cannot plant crop at ($x, $y) - not tilled soil');
    }
  }
  
  /// Example: Get information about a tile
  void inspectTile(int x, int y) {
    final gid = _tilemap.getGidAt(x, y);
    final properties = _tilemap.getTilePropertiesAt(x, y);
    
    print('Tile at ($x, $y):');
    print('  GID: $gid');
    print('  Properties: $properties');
    
    if (_tilemap.hasTileProperty(x, y, 'isTillable')) {
      print('  This tile can be tilled!');
    }
  }
} 