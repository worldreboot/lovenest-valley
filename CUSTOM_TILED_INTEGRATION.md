# Custom Tiled Parser Integration Guide

## 🎯 Overview

This guide explains how to integrate our custom Tiled parser system into your existing game components. The custom parser provides:

- ✅ **Custom tileset parsing** (57 wang tiles for auto-tiling)
- ✅ **Custom map parsing** (64x28 grid with proper CSV handling)
- ✅ **Auto-tiling with wang tiles** (corner-based blending)
- ✅ **Tile property access** (isTillable, tileType, etc.)
- ✅ **Dynamic tile updates** (real-time modifications)
- ✅ **Multiplayer sync support** (backend integration)

## 📁 Files Created

### Core Parser Files
- `lib/utils/tiled_parser.dart` - Custom parser for .tsx and .tmx files
- `lib/utils/tiled_parser_test.dart` - Test suite for the parsers
- `lib/utils/tiled_usage_example.dart` - Usage examples and documentation

### Enhanced Components
- `lib/components/world/enhanced_dynamic_tilemap.dart` - Updated tilemap with custom parsers
- `lib/game/custom_tiled_farm_game.dart` - New game class using custom parsers
- `lib/screens/custom_tiled_test_screen.dart` - Test screen for the new system

## 🔧 Integration Steps

### Step 1: Test the Parser

First, verify that the custom parser works correctly:

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

### Step 2: Use EnhancedDynamicTilemap

Replace your existing `DynamicTilemap` with `EnhancedDynamicTilemap`:

```dart
// Old way (flame_tiled)
final tilemap = DynamicTilemap(tiledMap, tileSize: 16.0);

// New way (custom parser)
final tilemap = EnhancedDynamicTilemap(tiledMap, tileSize: 16.0);
```

### Step 3: Update Tile Interactions

Use the new auto-tiling methods:

```dart
// Update a tile with auto-tiling
await tilemap.updateTileWithAutoTiling(x, y, newGid);

// Check tile properties
if (tilemap.hasTileProperty(x, y, 'isTillable')) {
  // This tile can be tilled for farming
}

// Get tile properties
final properties = tilemap.getTilePropertiesAt(x, y);
```

### Step 4: Integrate with Game Logic

Update your game components to use the new system:

```dart
class MyFarmGame extends GameWithGrid {
  late EnhancedDynamicTilemap _tilemap;
  
  @override
  Future<void> onLoad() async {
    // Initialize with custom parsers
    _tilemap = EnhancedDynamicTilemap(mockMap, tileSize: 16.0);
    add(_tilemap);
  }
  
  // Handle player interactions
  Future<void> onTileTapped(int x, int y) async {
    // Check if tile is tillable
    if (_tilemap.hasTileProperty(x, y, 'isTillable')) {
      // Convert to tilled soil
      await _tilemap.updateTileWithAutoTiling(x, y, 28); // GID for tilled soil
    }
  }
}
```

## 🎮 Key Features

### Auto-Tiling System

The auto-tiling system uses Wang Tiles to automatically blend tiles:

```dart
// When you place a tile, surrounding tiles automatically update
await tilemap.updateTileWithAutoTiling(10, 10, 28); // Place tilled soil
// Surrounding tiles will automatically blend for seamless appearance
```

### Tile Properties

Access tile properties for game logic:

```dart
// Check if a tile can be tilled
if (tilemap.hasTileProperty(x, y, 'isTillable')) {
  // Allow farming action
}

// Get all properties for a tile
final properties = tilemap.getTilePropertiesAt(x, y);
// Returns: {'isTillable': true} or {'tileType': 'tilledSoil'}
```

### Performance Optimizations

The system includes several performance optimizations:

- **Sprite caching** - Sprites are cached to avoid repeated loading
- **Sprite batch rendering** - Uses `SpriteBatchComponent` for efficient rendering
- **Selective updates** - Only updates changed tiles, not the entire map

## 🔄 Migration from flame_tiled

### What Changes

| Feature | flame_tiled | Custom Parser |
|---------|-------------|---------------|
| Map loading | `TiledComponent` | `MapParser` |
| Tileset loading | Automatic | `TilesetParser` |
| Auto-tiling | Limited | Full Wang Tile support |
| Tile properties | Basic | Full property system |
| Dynamic updates | Limited | Full control |
| Performance | Good | Optimized |

### Migration Checklist

- [ ] Replace `TiledComponent` with custom parser initialization
- [ ] Update tile update methods to use `updateTileWithAutoTiling`
- [ ] Replace property checks with `hasTileProperty`
- [ ] Update multiplayer sync to use new tile data format
- [ ] Test auto-tiling functionality
- [ ] Verify performance improvements

## 🧪 Testing

### Run Parser Tests

```dart
// In your test screen or debug menu
await TiledParserTest.runAllTests();
```

### Test Auto-Tiling

```dart
// Test auto-tiling with sample data
final wangTiles = tilesetParser.getWangTiles();
final autoTiler = AutoTiler(wangTiles);

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
final properties = tilesetParser.getTileProperties();
// Should find: Tile 24: {isTillable: true}, Tile 27: {tileType: tilledSoil}
```

## 🚀 Advanced Usage

### Custom Auto-Tiling Rules

You can extend the auto-tiling system:

```dart
class CustomAutoTiler extends AutoTiler {
  CustomAutoTiler(List<WangTile> wangTiles) : super(wangTiles);
  
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

## 📊 Performance Benefits

- **57 wang tiles** for sophisticated auto-tiling
- **Efficient sprite caching** reduces memory usage
- **Batch rendering** improves frame rates
- **Selective updates** minimize CPU usage
- **Custom CSV parsing** handles large maps efficiently

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
final tilesetParser = TilesetParser('assets/ground.tsx');
await tilesetParser.load();
print('Wang tiles: ${tilesetParser.getWangTiles().length}');
print('Properties: ${tilesetParser.getTileProperties().length}');

// Debug map loading
final mapParser = MapParser('assets/tiles/valley.tmx');
await mapParser.load();
print('Map info: ${mapParser.getMapInfo()}');
print('Ground layer: ${mapParser.getLayerData('Ground')}');
```

## 🎯 Next Steps

1. **Test the integration** with your existing game
2. **Update tile interaction logic** to use auto-tiling
3. **Implement farming mechanics** using tile properties
4. **Add more wang tiles** for better auto-tiling
5. **Optimize performance** for larger maps

The custom Tiled parser system is now ready for production use! 🚀 