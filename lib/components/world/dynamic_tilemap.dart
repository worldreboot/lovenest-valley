import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import 'package:lovenest_valley/game/base/game_with_grid.dart';

/// A component that renders a Tiled map layer using a single SpriteBatchComponent
/// for optimal performance. This allows for dynamic updates to individual tiles
/// while maintaining high frame rates.
class DynamicTilemap extends PositionComponent with HasGameRef<GameWithGrid> {
  final RenderableTiledMap map;
  final double tileSize;

  // Cache for spritesheets to avoid reloading images.
  final Map<String, SpriteSheet> _spriteSheetCache = {};

  // 2D array to hold the current GID of each tile. This is our source of truth.
  late List<List<Gid>> _tileData;

  // Single sprite batch for efficient rendering
  late SpriteBatchComponent _spriteBatch;

  // Map to track which sprites are at which positions
  final Map<String, Sprite> _spriteCache = {};

  DynamicTilemap(this.map, {required this.tileSize});

  @override
  Future<void> onLoad() async {
    debugPrint('[DynamicTilemap] Initializing...');

    // 1. Pre-load all the necessary tileset images into a cache for performance.
    await _cacheTilesetImages();

    // 2. Get the "Ground" layer which we want to render dynamically.
    final groundLayer = map.getLayer<TileLayer>('Ground');
    if (groundLayer == null) {
      debugPrint('[DynamicTilemap] ERROR: "Ground" layer not found!');
      return;
    }

    // 3. Initialize our internal data grid.
    _tileData = List.generate(
      groundLayer.height,
      (y) => List.generate(
        groundLayer.width,
        (x) => groundLayer.tileData![y][x],
      ),
    );

    // 4. Create a single sprite batch for efficient rendering
    _spriteBatch = SpriteBatchComponent();
    add(_spriteBatch);

    // 5. Pre-cache all unique sprites we'll need
    await _cacheAllSprites();

    // 6. Render the initial tile grid efficiently
    debugPrint('[DynamicTilemap] Rendering initial tile grid...');
    await _renderInitialGrid();
    debugPrint('[DynamicTilemap] Initial tile grid rendered successfully.');
  }

  /// Pre-cache all unique sprites to avoid repeated sprite creation
  Future<void> _cacheAllSprites() async {
    final imageSource = 'Tiles/Tile.png';
    final spriteSheet = _spriteSheetCache[imageSource];
    
    if (spriteSheet == null) {
      throw Exception('Spritesheet for "$imageSource" not found in cache.');
    }

    // Cache sprites for the most common tile types
    const commonGids = [25, 28]; // Grass and tilled soil
    for (final gid in commonGids) {
      final tileId = gid - 1;
      final sprite = spriteSheet.getSpriteById(tileId);
      _spriteCache['gid_$gid'] = sprite;
    }
  }

  /// Render the initial grid efficiently using the sprite batch
  Future<void> _renderInitialGrid() async {
    for (var y = 0; y < _tileData.length; y++) {
      for (var x = 0; x < _tileData[0].length; x++) {
        final gid = _tileData[y][x].tile;
        if (gid != 0) { // GID 0 means an empty tile.
          await _addTileToBatch(x, y, gid);
        }
      }
    }
  }

  /// Add a single tile to the sprite batch
  Future<void> _addTileToBatch(int x, int y, int gid) async {
    final sprite = await _getSpriteFromGid(gid);
    final position = Vector2(x * tileSize, y * tileSize);
    final size = Vector2.all(tileSize);
    
    _spriteBatch.add(
      SpriteComponent(
        sprite: sprite,
        position: position,
        size: size,
      ),
    );
  }

  /// Updates the visual sprite for a single tile at the given coordinates.
  /// This efficiently updates the sprite batch instead of creating new components.
  Future<void> _updateTileSprite(int x, int y) async {
    final gid = _tileData[y][x].tile;
    if (gid == 0) {
      return; // Empty tile, nothing to render
    }

    // Remove the old sprite component from the batch
    final oldComponent = _findSpriteComponentAt(x, y);
    if (oldComponent != null) {
      oldComponent.removeFromParent();
    }

    // Add the new sprite component to the batch
    await _addTileToBatch(x, y, gid);
  }

  /// Find the sprite component at the given coordinates
  SpriteComponent? _findSpriteComponentAt(int x, int y) {
    final targetPosition = Vector2(x * tileSize, y * tileSize);
    
    for (final child in _spriteBatch.children) {
      if (child is SpriteComponent && child.position == targetPosition) {
        return child;
      }
    }
    return null;
  }

  /// Public method to update a tile's GID and its visual representation.
  /// This is the primary way to interact with the dynamic map.
  Future<void> updateTile(int x, int y, int newGid) async {
    if (x < 0 || x >= _tileData[0].length || y < 0 || y >= _tileData.length) {
      debugPrint('[DynamicTilemap] ERROR: Update coordinates ($x, $y) are out of bounds.');
      return;
    }

    final oldGid = _tileData[y][x];
    _tileData[y][x] = Gid(newGid, oldGid.flips);
    await _updateTileSprite(x, y);

    debugPrint('[DynamicTilemap] Updated tile at ($x, $y) from GID ${oldGid.tile} to $newGid.');
  }

  /// Gets the current GID for a tile at the given coordinates from our internal data.
  int getGidAt(int x, int y) {
    if (x < 0 || x >= _tileData[0].length || y < 0 || y >= _tileData.length) {
      return 0;
    }
    return _tileData[y][x].tile;
  }

  /// Caches the SpriteSheet for each tileset image to prevent redundant loads.
  Future<void> _cacheTilesetImages() async {
    // For now, we'll hardcode the tileset information since we know it's "ground.tsx"
    // This is a simplified approach - in a production system, you'd want to parse the tileset data
    final imageSource = 'Tiles/Tile.png';
    if (!_spriteSheetCache.containsKey(imageSource)) {
      final image = await game.images.load(imageSource);
      _spriteSheetCache[imageSource] = SpriteSheet(
        image: image,
        srcSize: Vector2(16.0, 16.0), // Tile size from ground.tsx
        spacing: 0.0,
        margin: 0.0,
      );
      debugPrint('[DynamicTilemap] Cached spritesheet for: $imageSource');
    }
  }

  /// Retrieves a specific Sprite from the cached SpriteSheet based on a GID.
  Future<Sprite> _getSpriteFromGid(int gid) async {
    // Check if we have this sprite cached
    final cacheKey = 'gid_$gid';
    if (_spriteCache.containsKey(cacheKey)) {
      return _spriteCache[cacheKey]!;
    }

    // For the ground tileset, GID 25 = grass, GID 28 = tilled soil
    // We need to convert GID to tile ID (subtract firstGid which is 1)
    final tileId = gid - 1; // firstGid is 1 for ground.tsx
    
    final imageSource = 'Tiles/Tile.png';
    final spriteSheet = _spriteSheetCache[imageSource];

    if (spriteSheet == null) {
        throw Exception('Spritesheet for "$imageSource" not found in cache.');
    }

    final sprite = spriteSheet.getSpriteById(tileId);
    
    // Cache this sprite for future use
    _spriteCache[cacheKey] = sprite;
    
    return sprite;
  }
}
