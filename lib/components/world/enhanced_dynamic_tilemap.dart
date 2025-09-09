import 'dart:math';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter/foundation.dart';
import 'package:lovenest_valley/game/base/game_with_grid.dart';
import 'package:lovenest_valley/utils/tiled_parser.dart' as custom_parser;

/// Enhanced dynamic tilemap that uses our custom Tiled parser
/// This provides better control over tile updates and auto-tiling
class EnhancedDynamicTilemap extends PositionComponent with HasGameRef<GameWithGrid> {
  final RenderableTiledMap map;
  final double tileSize;

  // Cache for spritesheets to avoid reloading images.
  final Map<String, SpriteSheet> _spriteSheetCache = {};

  // 2D array to hold the current GID of each tile. This is our source of truth.
  late List<List<int>> _tileData;

  // Layer container for tile sprites (placeholder until true batching)
  late PositionComponent _spriteLayer;

  // Map to track which sprites are at which positions
  final Map<String, Sprite> _spriteCache = {};

  // Track which tile sprites are currently instantiated for basic culling
  final Set<String> _loadedTileKeys = <String>{};
  double _sinceLastVisibilityUpdate = 0.0;

  // Custom parser instances
  late custom_parser.TilesetParser _tilesetParser;
  late custom_parser.MapParser _mapParser;
  late custom_parser.AutoTiler _autoTiler;

  // Wang tiles for auto-tiling
  List<custom_parser.WangTile> _wangTiles = [];

  // Tile properties
  Map<int, Map<String, dynamic>> _tileProperties = {};

  EnhancedDynamicTilemap(this.map, {required this.tileSize});

  @override
  Future<void> onLoad() async {
    debugPrint('[EnhancedDynamicTilemap] Initializing with custom parsers...');

    // 1. Initialize custom parsers
    await _initializeCustomParsers();

    // 2. Pre-load all the necessary tileset images into a cache for performance.
    await _cacheTilesetImages();

    // 3. Initialize our internal data grid from custom parser
    await _initializeTileData();

    // 4. Create a container layer for tile sprites (no SpriteBatch required)
    _spriteLayer = PositionComponent();
    add(_spriteLayer);

    // 5. Pre-cache all unique sprites we'll need
    await _cacheAllSprites();

    // 6. Render only the initial visible tile grid (basic culling)
    await _updateVisibleTiles(force: true);
  }

  @override
  void render(ui.Canvas canvas) {
    super.render(canvas);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _sinceLastVisibilityUpdate += dt;
    if (_sinceLastVisibilityUpdate >= 0.2) { // update culling ~5 Hz
      _sinceLastVisibilityUpdate = 0.0;
      _updateVisibleTiles();
    }
  }

  Future<void> _updateVisibleTiles({bool force = false}) async {
    if (!isMounted) return;
    if (_tileData.isEmpty) return;
    final cam = game.camera;
    final view = cam.visibleWorldRect;

    final startX = max(0, (view.left / tileSize).floor() - 4);
    final endX = min(_tileData[0].length - 1, (view.right / tileSize).ceil() + 4);
    final startY = max(0, (view.top / tileSize).floor() - 4);
    final endY = min(_tileData.length - 1, (view.bottom / tileSize).ceil() + 4);

    final desired = <String>{};
    for (var y = startY; y <= endY; y++) {
      for (var x = startX; x <= endX; x++) {
        final gid = _tileData[y][x];
        if (gid == 0) continue;
        desired.add('$x,$y');
        if (!_loadedTileKeys.contains('$x,$y') || force) {
          await _addTileToBatch(x, y, gid);
          _loadedTileKeys.add('$x,$y');
        }
      }
    }

    // Remove tiles that are no longer desired
    final toRemove = _loadedTileKeys.difference(desired).toList(growable: false);
    for (final key in toRemove) {
      final parts = key.split(',');
      final x = int.parse(parts[0]);
      final y = int.parse(parts[1]);
      final comp = _findSpriteComponentAt(x, y);
      if (comp != null) {
        comp.removeFromParent();
      }
      _loadedTileKeys.remove(key);
    }
  }

  /// Initialize our custom Tiled parsers
  Future<void> _initializeCustomParsers() async {
    debugPrint('[EnhancedDynamicTilemap] Initializing custom parsers...');

    // Load tileset data
    _tilesetParser = custom_parser.TilesetParser('assets/ground.tsx');
    await _tilesetParser.load();

    // Load map data
    _mapParser = custom_parser.MapParser('assets/tiles/valley.tmx');
    await _mapParser.load();

    // Get wang tiles for auto-tiling
    _wangTiles = _tilesetParser.getWangTiles();
    debugPrint('[EnhancedDynamicTilemap] Loaded ${_wangTiles.length} wang tiles');

    // Get tile properties
    _tileProperties = _tilesetParser.getTileProperties();
    debugPrint('[EnhancedDynamicTilemap] Loaded ${_tileProperties.length} tile properties');

    // Create auto-tiler
    _autoTiler = custom_parser.AutoTiler(_wangTiles, {}); // Pass an empty map for legacy compatibility

    // Log map info
    final mapInfo = _mapParser.getMapInfo();
    debugPrint('[EnhancedDynamicTilemap] Map info: $mapInfo');
  }

  /// Initialize tile data from our custom parser
  Future<void> _initializeTileData() async {
    final groundLayer = _mapParser.getLayerData('Ground');
    if (groundLayer == null) {
      debugPrint('[EnhancedDynamicTilemap] ERROR: "Ground" layer not found!');
      return;
    }

    _tileData = groundLayer.data;
    debugPrint('[EnhancedDynamicTilemap] Initialized tile data: ${_tileData.length}x${_tileData[0].length}');
  }

  /// Pre-cache all unique sprites to avoid repeated sprite creation
  Future<void> _cacheAllSprites() async {
    final imageSource = 'Tiles/Tile.png';
    final spriteSheet = _spriteSheetCache[imageSource];
    
    if (spriteSheet == null) {
      throw Exception('Spritesheet for "$imageSource" not found in cache.');
    }

    // Cache sprites for all wang tiles
    for (final wangTile in _wangTiles) {
      final gid = wangTile.tileId + 1; // Convert tile ID to GID
      final sprite = spriteSheet.getSpriteById(wangTile.tileId);
      _spriteCache['gid_$gid'] = sprite;
    }

    // Cache sprites for tiles with properties
    for (final tileId in _tileProperties.keys) {
      final gid = tileId + 1; // Convert tile ID to GID
      final sprite = spriteSheet.getSpriteById(tileId);
      _spriteCache['gid_$gid'] = sprite;
    }

    debugPrint('[EnhancedDynamicTilemap] Cached ${_spriteCache.length} sprites');
  }

  /// Render the initial grid efficiently using the sprite batch
  Future<void> _renderInitialGrid() async {
    for (var y = 0; y < _tileData.length; y++) {
      for (var x = 0; x < _tileData[0].length; x++) {
        final gid = _tileData[y][x];
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
    
      _spriteLayer.add(
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
    final gid = _tileData[y][x];
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
    
    for (final child in _spriteLayer.children) {
      if (child is SpriteComponent && child.position == targetPosition) {
        return child;
      }
    }
    return null;
  }

  /// Public method to update a tile's GID and its visual representation with auto-tiling.
  /// This is the primary way to interact with the dynamic map.
  Future<void> updateTileWithAutoTiling(int x, int y, int newGid) async {
    if (x < 0 || x >= _tileData[0].length || y < 0 || y >= _tileData.length) {
      debugPrint('[EnhancedDynamicTilemap] ERROR: Update coordinates ($x, $y) are out of bounds.');
      return;
    }

    final oldGid = _tileData[y][x];
    _tileData[y][x] = newGid;
    await _updateTileSprite(x, y);

    // Apply auto-tiling to surrounding tiles
    await _applyAutoTilingToSurroundings(x, y);

    debugPrint('[EnhancedDynamicTilemap] Updated tile at ($x, $y) from GID $oldGid to $newGid with auto-tiling.');
  }

  /// Apply auto-tiling to tiles surrounding the updated position
  Future<void> _applyAutoTilingToSurroundings(int centerX, int centerY) async {
    // Fix: Apply changes in a specific order to ensure consistency
    // Order: corners first, then edges
    final changes = <String, int>{};

    // Calculate the correct GID for all 8 surrounding tiles (skip the center tile).
    for (int dy = -1; dy <= 1; dy++) {
      for (int dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue; // Skip the center tile
        
        final x = centerX + dx;
        final y = centerY + dy;
        
        if (x >= 0 && x < _tileData[0].length && y >= 0 && y < _tileData.length) {
          final oldGid = _tileData[y][x];
          final newGid = _calculateAutoTileGid(x, y);
          
          if (oldGid != newGid) {
            changes['$x,$y'] = newGid;
            debugPrint('[EnhancedDynamicTilemap] 🎯 Position ($x, $y): GID $oldGid -> GID $newGid');
          }
        }
      }
    }

    // Apply changes in order: corners first, then edges
    final cornerPositions = [
      [centerX - 1, centerY - 1], // top-left
      [centerX + 1, centerY - 1], // top-right
      [centerX - 1, centerY + 1], // bottom-left
      [centerX + 1, centerY + 1], // bottom-right
    ];
    
    final edgePositions = [
      [centerX, centerY - 1],     // top
      [centerX - 1, centerY],     // left
      [centerX + 1, centerY],     // right
      [centerX, centerY + 1],     // bottom
    ];
    
    // Apply corner changes first
    for (final position in cornerPositions) {
      final x = position[0];
      final y = position[1];
      final key = '$x,$y';
      if (changes.containsKey(key)) {
        final newGid = changes[key]!;
        _tileData[y][x] = newGid;
        await _updateTileSprite(x, y);
        debugPrint('[EnhancedDynamicTilemap] ✅ Applied corner auto-tile at ($x, $y): GID $newGid');
      }
    }
    
    // Then apply edge changes
    for (final position in edgePositions) {
      final x = position[0];
      final y = position[1];
      final key = '$x,$y';
      if (changes.containsKey(key)) {
        final newGid = changes[key]!;
        _tileData[y][x] = newGid;
        await _updateTileSprite(x, y);
        debugPrint('[EnhancedDynamicTilemap] ✅ Applied edge auto-tile at ($x, $y): GID $newGid');
      }
    }
  }

  /// Calculate the appropriate auto-tiled GID for a position
  int _calculateAutoTileGid(int x, int y) {
    // Get 3x3 grid around the position
    final surroundingTiles = <List<int>>[];
    
    for (int dy = -1; dy <= 1; dy++) {
      final row = <int>[];
      for (int dx = -1; dx <= 1; dx++) {
        final checkX = x + dx;
        final checkY = y + dy;
        
        if (checkX >= 0 && checkX < _tileData[0].length && 
            checkY >= 0 && checkY < _tileData.length) {
          row.add(_tileData[checkY][checkX]);
        } else {
          row.add(0); // Empty tile for out-of-bounds
        }
      }
      surroundingTiles.add(row);
    }

    // Get the appropriate tile for this situation
    final appropriateTile = _autoTiler.getTileForSurroundings(surroundingTiles);
    
    if (appropriateTile > 0) {
      return appropriateTile + 1; // Convert tile ID to GID
    }
    
    return _tileData[y][x]; // Return current GID if no change needed
  }

  /// Auto-tile a specific position based on its surroundings
  Future<void> _autoTilePosition(int x, int y) async {
    // Get 3x3 grid around the position
    final surroundingTiles = <List<int>>[];
    
    for (int dy = -1; dy <= 1; dy++) {
      final row = <int>[];
      for (int dx = -1; dx <= 1; dx++) {
        final checkX = x + dx;
        final checkY = y + dy;
        
        if (checkX >= 0 && checkX < _tileData[0].length && 
            checkY >= 0 && checkY < _tileData.length) {
          row.add(_tileData[checkY][checkX]);
        } else {
          row.add(0); // Empty tile for out-of-bounds
        }
      }
      surroundingTiles.add(row);
    }

    // Get the appropriate tile for this situation
    final appropriateTile = _autoTiler.getTileForSurroundings(surroundingTiles);
    
    if (appropriateTile > 0) {
      final newGid = appropriateTile + 1; // Convert tile ID to GID
      if (_tileData[y][x] != newGid) {
        _tileData[y][x] = newGid;
        await _updateTileSprite(x, y);
      }
    }
  }

  /// Public method to update a tile's GID and its visual representation without auto-tiling.
  Future<void> updateTile(int x, int y, int newGid) async {
    if (x < 0 || x >= _tileData[0].length || y < 0 || y >= _tileData.length) {
      debugPrint('[EnhancedDynamicTilemap] ERROR: Update coordinates ($x, $y) are out of bounds.');
      return;
    }

    final oldGid = _tileData[y][x];
    _tileData[y][x] = newGid;
    await _updateTileSprite(x, y);

    debugPrint('[EnhancedDynamicTilemap] Updated tile at ($x, $y) from GID $oldGid to $newGid.');
  }

  /// Gets the current GID for a tile at the given coordinates from our internal data.
  int getGidAt(int x, int y) {
    if (x < 0 || x >= _tileData[0].length || y < 0 || y >= _tileData.length) {
      return 0;
    }
    return _tileData[y][x];
  }

  /// Get tile properties at a specific position
  Map<String, dynamic>? getTilePropertiesAt(int x, int y) {
    final gid = getGidAt(x, y);
    if (gid > 0) {
      final tileId = gid - 1; // Convert GID to tile ID
      return _tileProperties[tileId];
    }
    return null;
  }

  /// Check if a tile has a specific property
  bool hasTileProperty(int x, int y, String propertyName) {
    final properties = getTilePropertiesAt(x, y);
    return properties?.containsKey(propertyName) ?? false;
  }

  /// Get all tile properties
  Map<int, Map<String, dynamic>> getAllTileProperties() => _tileProperties;

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
      debugPrint('[EnhancedDynamicTilemap] Cached spritesheet for: $imageSource');
    }
  }

  /// Retrieves a specific Sprite from the cached SpriteSheet based on a GID.
  Future<Sprite> _getSpriteFromGid(int gid) async {
    // Check if we have this sprite cached
    final cacheKey = 'gid_$gid';
    if (_spriteCache.containsKey(cacheKey)) {
      return _spriteCache[cacheKey]!;
    }

    // Convert GID to tile ID (subtract firstGid which is 1)
    final tileId = gid - 1;
    
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
