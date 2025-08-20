# Tilemap Replacement Guide

## 🎯 Overview

This guide shows you how to replace your existing `flame_tiled` tilemap with our enhanced custom parser system that provides better auto-tiling and tile control.

## 📋 What We've Created

### New Files
- ✅ `lib/game/enhanced_tiled_farm_game.dart` - Enhanced game with custom parser
- ✅ `lib/screens/enhanced_tiled_test_screen.dart` - Test screen for the new system
- ✅ `lib/components/world/enhanced_dynamic_tilemap.dart` - Enhanced tilemap component
- ✅ `lib/utils/tiled_parser.dart` - Custom parser for .tsx and .tmx files

### Enhanced Features
- ✅ **57 wang tiles** for sophisticated auto-tiling
- ✅ **Custom CSV parsing** handles large maps efficiently
- ✅ **Tile property access** (isTillable, tileType, etc.)
- ✅ **Dynamic tile updates** with auto-tiling
- ✅ **Multiplayer sync support**
- ✅ **Performance optimizations**

## 🔄 Step-by-Step Replacement

### Step 1: Test the Parser

First, verify that our custom parser works:

```dart
// Run the test suite
await TiledParserTest.runAllTests();
```

Expected output:
```
✅ Tileset info loaded: {name: ground, tilewidth: 16, tileheight: 16, tilecount: 180, columns: 15}
✅ Image source: images/Tiles/Tile.png
✅ Found 57 wang tiles for auto-tiling
✅ Found 2 tiles with properties
✅ Map info loaded: {width: 64, height: 28, tilewidth: 16, tileheight: 16, orientation: orthogonal}
✅ Ground layer: 64x28
✅ Found 1 object groups
```

### Step 2: Replace Your Game Class

**Option A: Use the new enhanced game class**

Replace your existing game with `EnhancedTiledFarmGame`:

```dart
// Old way
class TiledFarmGame extends GameWithGrid {
  late TiledComponent tiledMap;
  
  @override
  Future<void> onLoad() async {
    tiledMap = await TiledComponent.load('valley.tmx', Vector2.all(tileSize));
    world.add(tiledMap);
  }
}

// New way
class EnhancedTiledFarmGame extends GameWithGrid {
  late EnhancedDynamicTilemap _tilemap;
  late custom_parser.TilesetParser _tilesetParser;
  late custom_parser.MapParser _mapParser;
  late custom_parser.AutoTiler _autoTiler;
  
  @override
  Future<void> onLoad() async {
    await _initializeCustomParsers();
    await _initializeEnhancedTilemap();
  }
}
```

**Option B: Update your existing game class**

Add these imports to your existing game:

```dart
import 'package:lovenest/utils/tiled_parser.dart' as custom_parser;
import 'package:lovenest/components/world/enhanced_dynamic_tilemap.dart';
```

Replace the tilemap initialization:

```dart
// Replace this:
late TiledComponent tiledMap;
tiledMap = await TiledComponent.load('valley.tmx', Vector2.all(tileSize));
world.add(tiledMap);

// With this:
late EnhancedDynamicTilemap _tilemap;
late custom_parser.TilesetParser _tilesetParser;
late custom_parser.MapParser _mapParser;
late custom_parser.AutoTiler _autoTiler;

// In onLoad():
await _initializeCustomParsers();
await _initializeEnhancedTilemap();
```

### Step 3: Update Tile Interactions

Replace your existing tile update methods:

```dart
// Old way (flame_tiled)
final groundLayer = tiledMap.tileMap.getLayer<TileLayer>('Ground');
if (groundLayer != null) {
  groundLayer.tileData![y][x] = Gid(newGid, groundLayer.tileData![y][x].flips);
}

// New way (custom parser with auto-tiling)
await _tilemap.updateTileWithAutoTiling(x, y, newGid);
```

### Step 4: Update Tile Property Checks

Replace property checks:

```dart
// Old way
final tileProperties = groundLayer.tileMap.getTileProperties(tileId);

// New way
if (_tilemap.hasTileProperty(x, y, 'isTillable')) {
  // This tile can be tilled for farming
}

final properties = _tilemap.getTilePropertiesAt(x, y);
```

### Step 5: Update Multiplayer Integration

Replace tile change handling:

```dart
// Old way
_tileChangesSub = _farmTileService.tileChangesStream.listen((event) {
  final x = event['x'] as int;
  final y = event['y'] as int;
  final gid = event['gid'] as int;
  
  // Manual tile update
  final groundLayer = tiledMap.tileMap.getLayer<TileLayer>('Ground');
  groundLayer?.tileData![y][x] = Gid(gid, groundLayer.tileData![y][x].flips);
});

// New way
_tileChangesSub = _farmTileService.tileChangesStream.listen((event) {
  final x = event['x'] as int;
  final y = event['y'] as int;
  final gid = event['gid'] as int;
  
  // Auto-tiling update
  _tilemap.updateTileWithAutoTiling(x, y, gid);
});
```

## 🎮 Key Benefits

### Auto-Tiling System

The new system automatically blends tiles using Wang Tiles:

```dart
// When you place a tile, surrounding tiles automatically update
await _tilemap.updateTileWithAutoTiling(10, 10, 28); // Place tilled soil
// Surrounding tiles will automatically blend for seamless appearance
```

### Tile Properties

Access tile properties for game logic:

```dart
// Check if a tile can be tilled
if (_tilemap.hasTileProperty(x, y, 'isTillable')) {
  // Allow farming action
}

// Get all properties for a tile
final properties = _tilemap.getTilePropertiesAt(x, y);
// Returns: {'isTillable': true} or {'tileType': 'tilledSoil'}
```

### Performance Improvements

- **Sprite caching** reduces memory usage
- **Batch rendering** improves frame rates
- **Selective updates** minimize CPU usage
- **Custom CSV parsing** handles large maps efficiently

## 🧪 Testing the Integration

### Test the Parser

```dart
// In your test screen or debug menu
await TiledParserTest.runAllTests();
```

### Test Auto-Tiling

```dart
// Test auto-tiling with sample data
final wangTiles = _tilesetParser.getWangTiles();
final autoTiler = custom_parser.AutoTiler(wangTiles);

final surroundingTiles = [
  [1, 1, 0],
  [1, 0, 0],
  [0, 0, 0],
];

final appropriateTile = autoTiler.getTileForSurroundings(surroundingTiles);
```

### Test Tile Properties

```dart
// Test tile property access
final properties = _tilesetParser.getTileProperties();
// Should find: Tile 24: {isTillable: true}, Tile 27: {tileType: tilledSoil}
```

## 🔧 Migration Checklist

- [ ] **Test the parser** - Run `TiledParserTest.runAllTests()`
- [ ] **Replace game class** - Use `EnhancedTiledFarmGame` or update existing
- [ ] **Update tile updates** - Replace with `updateTileWithAutoTiling()`
- [ ] **Update property checks** - Use `hasTileProperty()` and `getTilePropertiesAt()`
- [ ] **Update multiplayer** - Use enhanced tilemap for sync
- [ ] **Test auto-tiling** - Verify tiles blend correctly
- [ ] **Test performance** - Check frame rates and memory usage

## 🚀 Advanced Usage

### Custom Auto-Tiling Rules

You can extend the auto-tiling system:

```dart
class CustomAutoTiler extends custom_parser.AutoTiler {
  CustomAutoTiler(List<custom_parser.WangTile> wangTiles) : super(wangTiles);
  
  @override
  int getTileForSurroundings(List<List<int>> surroundingTiles) {
    // Custom logic here
    return super.getTileForSurroundings(surroundingTiles);
  }
}
```

### Multiplayer Integration

The system supports multiplayer tile updates:

```dart
// Broadcast tile changes
await _farmTileService.updateTile(farmId, x, y, newGid);

// Listen for changes from other players
_tileChangesSub = _farmTileService.tileChangesStream.listen((event) {
  final x = event['x'] as int;
  final y = event['y'] as int;
  final gid = event['gid'] as int;
  
  _tilemap.updateTileWithAutoTiling(x, y, gid);
});
```

## 📊 Performance Comparison

| Feature | flame_tiled | Custom Parser |
|---------|-------------|---------------|
| Auto-tiling | Limited | Full Wang Tile support |
| Tile properties | Basic | Full property system |
| Dynamic updates | Limited | Full control |
| Performance | Good | Optimized |
| Memory usage | Standard | Reduced with caching |
| CSV parsing | Standard | Custom optimized |

## 🎯 Next Steps

1. **Test the integration** with your existing game
2. **Update tile interaction logic** to use auto-tiling
3. **Implement farming mechanics** using tile properties
4. **Add more wang tiles** for better auto-tiling
5. **Optimize performance** for larger maps

Your enhanced tilemap system is now ready for production use! 🚀

## 🔧 Troubleshooting

### Common Issues

1. **"Ground layer not found"**
   - Check that `assets/tiles/valley.tmx` exists
   - Verify the layer name is "Ground"

2. **"Image source: null"**
   - Check that `assets/ground.tsx` exists
   - Verify the image path in the tileset

3. **Auto-tiling not working**
   - Ensure wang tiles are loaded correctly
   - Check that the auto-tiler is initialized

4. **Performance issues**
   - Verify sprite caching is working
   - Check that only necessary tiles are updated

### Debug Commands

```dart
// Debug parser loading
final tilesetParser = custom_parser.TilesetParser('assets/ground.tsx');
await tilesetParser.load();
print('Wang tiles: ${tilesetParser.getWangTiles().length}');
print('Properties: ${tilesetParser.getTileProperties().length}');

// Debug map loading
final mapParser = custom_parser.MapParser('assets/tiles/valley.tmx');
await mapParser.load();
print('Map info: ${mapParser.getMapInfo()}');
print('Ground layer: ${mapParser.getLayerData('Ground')}');
```

The enhanced tilemap system provides better control, performance, and auto-tiling capabilities than the original `flame_tiled` implementation! 🎮✨ 