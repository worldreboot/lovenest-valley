import 'dart:math';
import 'package:flame/components.dart' show Component, SpriteComponent, Vector2, PositionComponent;
import 'package:flame/cache.dart' show Images;
import 'package:flame/sprite.dart';
import 'package:lovenest_valley/game/base/game_with_grid.dart';
import 'package:lovenest_valley/utils/tiled_parser.dart' as custom_parser;
import 'package:lovenest_valley/components/world/decoration_object.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/widgets.dart' show WidgetsBinding;

// Enum for tileset types
enum TilesetType {
  ground,
  beach,
  stairs,
  houses,
  smoke,
  trees,
  wooden,
  beachObjects,
}

// Helper class to hold tile data
class _TileData {
  final Sprite? sprite;
  final List<custom_parser.TilesetAnimationFrame>? frames;
  final TilesetType tilesetType;
  Vector2? _overrideSize; // used for image-collection tiles
  
  _TileData({
    required this.sprite,
    required this.frames,
    required this.tilesetType,
  });
}

class TileRenderer {
  final Images images;
  final double tileSize;
  final Component world;
  final GameWithGrid game;

  // Sprite sheets for all tilesets
  late SpriteSheet _groundTileSpriteSheet;
  late SpriteSheet _beachTileSpriteSheet;
  late SpriteSheet _stairsTileSpriteSheet;
  late SpriteSheet _housesTileSpriteSheet;
  late SpriteSheet _smokeTileSpriteSheet;
  late SpriteSheet _treesTileSpriteSheet;
  late SpriteSheet _woodenTileSpriteSheet;
  late SpriteSheet _beachObjectsTileSpriteSheet;
  
  final Map<String, SpriteComponent> _tileSprites = {};
  
  // Animation data for all tilesets
  late final Map<int, List<custom_parser.TilesetAnimationFrame>> _groundAnimations;
  late final Map<int, List<custom_parser.TilesetAnimationFrame>> _beachAnimations;
  late final Map<int, List<custom_parser.TilesetAnimationFrame>> _stairsAnimations;
  late final Map<int, List<custom_parser.TilesetAnimationFrame>> _housesAnimations;
  late final Map<int, List<custom_parser.TilesetAnimationFrame>> _smokeAnimations;
  late final Map<int, List<custom_parser.TilesetAnimationFrame>> _treesAnimations;
  late final Map<int, List<custom_parser.TilesetAnimationFrame>> _woodenAnimations;
  late final Map<int, List<custom_parser.TilesetAnimationFrame>> _beachObjectsAnimations;
  
  final Map<String, _AnimState> _animStates = {};
  int _animationFrameCount = 0; // For debug logging
  
  // Performance optimization: Cache for pre-calculated frame sprites
  final Map<String, List<Sprite?>> _frameSpriteCache = {};
  
  // Layer containers for tile sprites
  late PositionComponent _groundSpriteLayer;
  late PositionComponent _decorationSpriteLayer;
  List<List<int>>? _groundTileData;
  List<List<int>>? _decorationTileData;
  final Set<String> _loadedGroundTileKeys = <String>{};
  final Set<String> _loadedDecorationTileKeys = <String>{};
  double _sinceLastVisibilityUpdate = 0.0;
  // Non-destructive per-cell GID overrides (do not mutate TMX data)
  final Map<String, int> _gidOverrides = <String, int>{};
  bool _postFrameRefreshScheduled = false;

  // Public getters for debugging
  List<List<int>>? get groundTileData => _groundTileData;
  List<List<int>>? get decorationTileData => _decorationTileData;

  /// Check if a tile is tilled (simple approach)
  bool _isTileTilled(int x, int y) {
    // Simple approach: Check if the ground tile GID indicates it's tilled
    // Based on ground.tsx, tiles with GID 27-35 are tilled soil
    final groundGid = _effectiveGroundGidAt(x, y);
    return groundGid >= 27 && groundGid <= 35;
  }

  // GID ranges for each tileset (from valley.tmx)
  static const int _groundFirstGid = 1;
  static const int _groundLastGid = 180;
  static const int _beachFirstGid = 181;
  static const int _beachLastGid = 264;
  static const int _stairsFirstGid = 265;
  static const int _stairsLastGid = 280;
  static const int _housesFirstGid = 281;
  static const int _housesLastGid = 302;
  static const int _smokeFirstGid = 303;
  static const int _smokeLastGid = 316;
  static const int _treesFirstGid = 317;
  static const int _treesLastGid = 323;
  static const int _woodenFirstGid = 324;
  static const int _woodenLastGid = 329;
  static const int _beachObjectsFirstGid = 330;
  static const int _beachObjectsLastGid = 373;

  TileRenderer({required this.images, required this.tileSize, required this.world, required this.game});

  Future<void> initialize() async {
    // Load all tileset images
    final groundTilesetImage = await images.load('Tiles/Tile.png');
    _groundTileSpriteSheet = SpriteSheet(
      image: groundTilesetImage,
      srcSize: Vector2.all(tileSize),
    );
    

    final beachTilesetImage = await images.load('Beach/Tiles/Tiles.png');
    _beachTileSpriteSheet = SpriteSheet(
      image: beachTilesetImage,
      srcSize: Vector2.all(tileSize),
    );

    // Load stairs tileset (sprite-sheet based)
    final stairsTilesetImage = await images.load('V1.1/Stairs.png');
    _stairsTileSpriteSheet = SpriteSheet(
      image: stairsTilesetImage,
      srcSize: Vector2.all(tileSize),
    );

    // For now, use ground tileset as fallback for image-collection tilesets
    // since they use individual image files rather than sprite sheets
    _housesTileSpriteSheet = _groundTileSpriteSheet;
    _smokeTileSpriteSheet = _groundTileSpriteSheet;
    _treesTileSpriteSheet = _groundTileSpriteSheet;
    _woodenTileSpriteSheet = _groundTileSpriteSheet;
    _beachObjectsTileSpriteSheet = _groundTileSpriteSheet;

    // Parse TSX animations for all tilesets
    final groundParser = custom_parser.TilesetParser('assets/ground.tsx');
    await groundParser.load();
    _groundAnimations = groundParser.getTileAnimations();
    debugPrint('[TileRenderer] Ground animations loaded: ${_groundAnimations.length} animated tiles');

    final beachParser = custom_parser.TilesetParser('assets/beach.tsx');
    await beachParser.load();
    _beachAnimations = beachParser.getTileAnimations();
    debugPrint('[TileRenderer] Beach animations loaded: ${_beachAnimations.length} animated tiles');

    // Load other tileset parsers with error handling
    try {
      final stairsParser = custom_parser.TilesetParser('assets/stairs.tsx');
      await stairsParser.load();
      _stairsAnimations = stairsParser.getTileAnimations();
    } catch (e) {
      _stairsAnimations = {};
    }

    try {
      final housesParser = custom_parser.TilesetParser('assets/houses.tsx');
      await housesParser.load();
      _housesAnimations = housesParser.getTileAnimations();
    } catch (e) {
      _housesAnimations = {};
    }

    try {
      final smokeParser = custom_parser.TilesetParser('assets/smoke.tsx');
      await smokeParser.load();
      _smokeAnimations = smokeParser.getTileAnimations();
      debugPrint('[TileRenderer] Smoke animations loaded: ${_smokeAnimations.length} animated tiles');
    } catch (e) {
      _smokeAnimations = {};
      debugPrint('[TileRenderer] Failed to load smoke animations: $e');
    }

    try {
      final treesParser = custom_parser.TilesetParser('assets/trees.tsx');
      await treesParser.load();
      _treesAnimations = treesParser.getTileAnimations();
    } catch (e) {
      _treesAnimations = {};
    }

    try {
      final woodenParser = custom_parser.TilesetParser('assets/wooden.tsx');
      await woodenParser.load();
      _woodenAnimations = woodenParser.getTileAnimations();
    } catch (e) {
      _woodenAnimations = {};
    }

    try {
      final beachObjectsParser = custom_parser.TilesetParser('assets/beach_objects.tsx');
      await beachObjectsParser.load();
      _beachObjectsAnimations = beachObjectsParser.getTileAnimations();
    } catch (e) {
      _beachObjectsAnimations = {};
    }

    // Create containers to hold tile sprites for different layers
    _groundSpriteLayer = PositionComponent();
    _decorationSpriteLayer = PositionComponent();
    world.add(_groundSpriteLayer);
    world.add(_decorationSpriteLayer);

    // Add a lightweight updater to periodically refresh visibility
    world.add(_VisibilityUpdater(onTick: (dt) {
      _sinceLastVisibilityUpdate += dt;
      if (_sinceLastVisibilityUpdate >= 0.2) { // ~5 Hz
        _sinceLastVisibilityUpdate = 0.0;
        updateVisibleTiles();
      }
      _tickAnimations(dt);
    }));
  }

  // Helper method to get the first GID for a given GID
  int _getFirstGidForType(int gid) {
    if (gid >= _groundFirstGid && gid <= _groundLastGid) {
      return _groundFirstGid;
    } else if (gid >= _beachFirstGid && gid <= _beachLastGid) {
      return _beachFirstGid;
    } else if (gid >= _stairsFirstGid && gid <= _stairsLastGid) {
      return _stairsFirstGid;
    } else if (gid >= _housesFirstGid && gid <= _housesLastGid) {
      return _housesFirstGid;
    } else if (gid >= _smokeFirstGid && gid <= _smokeLastGid) {
      return _smokeFirstGid;
    } else if (gid >= _treesFirstGid && gid <= _treesLastGid) {
      return _treesFirstGid;
    } else if (gid >= _woodenFirstGid && gid <= _woodenLastGid) {
      return _woodenFirstGid;
    } else if (gid >= _beachObjectsFirstGid && gid <= _beachObjectsLastGid) {
      return _beachObjectsFirstGid;
    }
    return gid; // Fallback
  }

  // Helper method to get sprite and animations for a given GID
  _TileData? _getTileData(int gid) {
    if (gid >= _groundFirstGid && gid <= _groundLastGid) {
      final tileId = gid - _groundFirstGid;
      final sprite = _groundTileSpriteSheet.getSpriteById(tileId);
      final frames = _groundAnimations[tileId];
      
      return _TileData(
        sprite: sprite,
        frames: frames,
        tilesetType: TilesetType.ground,
      );
    } else if (gid >= _beachFirstGid && gid <= _beachLastGid) {
      final tileId = gid - _beachFirstGid;
      final frames = _beachAnimations[tileId];
      return _TileData(
        sprite: _beachTileSpriteSheet.getSpriteById(tileId),
        frames: frames,
        tilesetType: TilesetType.beach,
      );
    } else if (gid >= _stairsFirstGid && gid <= _stairsLastGid) {
      // stairs is a sprite-sheet; we keep sheet-based rendering
      final tileId = gid - _stairsFirstGid;
      final frames = _stairsAnimations[tileId];
      return _TileData(
        sprite: _stairsTileSpriteSheet.getSpriteById(tileId),
        frames: frames,
        tilesetType: TilesetType.stairs,
      );
    } else if (gid >= _housesFirstGid && gid <= _housesLastGid) {
      return _getImageCollectionTileData('assets/houses.tsx', gid, _housesFirstGid, TilesetType.houses);
    } else if (gid >= _smokeFirstGid && gid <= _smokeLastGid) {
      return _getImageCollectionTileData('assets/smoke.tsx', gid, _smokeFirstGid, TilesetType.smoke);
    } else if (gid >= _treesFirstGid && gid <= _treesLastGid) {
      return _getImageCollectionTileData('assets/trees.tsx', gid, _treesFirstGid, TilesetType.trees);
    } else if (gid >= _woodenFirstGid && gid <= _woodenLastGid) {
      return _getImageCollectionTileData('assets/wooden.tsx', gid, _woodenFirstGid, TilesetType.wooden);
    } else if (gid >= _beachObjectsFirstGid && gid <= _beachObjectsLastGid) {
      return _getImageCollectionTileData('assets/beach_objects.tsx', gid, _beachObjectsFirstGid, TilesetType.beachObjects);
    }
    return null;
  }

  // Cache for image-collection tiles (tsxPath -> map of tileId -> sprite)
  final Map<String, Map<int, Sprite>> _imageCollectionSpriteCache = {};
  final Map<String, Map<int, Vector2>> _imageCollectionSizeCache = {};

  String _normalizeAssetPath(String src) {
    String p = src.trim();

    // Handle TSX paths that might have various prefixes
    if (p.startsWith('./')) p = p.substring(2);
    if (p.startsWith('../')) p = p.substring(3);

    // The TSX files have paths like 'images/V1.1/Smoke/Smoke1.png'
    // But Flame's images.load() adds 'assets/images/' as a prefix, not just 'assets/'
    // So we need to remove the 'images/' prefix to avoid duplication
    if (p.startsWith('images/')) {
      // Remove 'images/' prefix - Flame will add 'assets/images/' back
      return p.substring(7);
    }

    // If it doesn't start with 'images/', it might be a direct path
    if (p.startsWith('assets/')) {
      p = p.substring(7); // Remove 'assets/' prefix
    }

    // Clean up any double slashes
    while (p.contains('//')) {
      p = p.replaceAll('//', '/');
    }

    return p;
  }

  _TileData? _getImageCollectionTileData(String tsxPath, int gid, int firstGid, TilesetType type) {
    final tileIdInSet = gid - firstGid;
    
    // Load metadata first time
    if (!_imageCollectionSpriteCache.containsKey(tsxPath)) {
      _imageCollectionSpriteCache[tsxPath] = {};
      _imageCollectionSizeCache[tsxPath] = {};
      final parser = custom_parser.TilesetParser(tsxPath);
      // Note: image loading is async; but getTileData is used from rendering path.
      // We return null now if not ready; caller will request again next frame.
      // Kick off async population
      () async {
        try {
          await parser.load();
        } catch (e) {
          return; // TSX not bundled; keep fallback
        }
        final tiles = parser.getImageCollectionTiles();
        for (final entry in tiles.entries) {
          final src = entry.value.source;
          final normalizedPath = _normalizeAssetPath(src);
          try {
            final image = await images.load(normalizedPath);
            final sprite = Sprite(image);
            _imageCollectionSpriteCache[tsxPath]![entry.key] = sprite;
            _imageCollectionSizeCache[tsxPath]![entry.key] = Vector2(entry.value.width.toDouble(), entry.value.height.toDouble());
          } catch (e) {
            // Ignore load failures; will fallback
          }
        }
      }();
      return null; // Not ready yet
    }

    final sprite = _imageCollectionSpriteCache[tsxPath]![tileIdInSet];
    if (sprite == null) {
      return null; // still loading
    }
    final size = _imageCollectionSizeCache[tsxPath]![tileIdInSet] ?? Vector2.all(tileSize);
    
    // Get animations for this tileset type
    List<custom_parser.TilesetAnimationFrame>? frames;
    switch (type) {
      case TilesetType.houses:
        frames = _housesAnimations[tileIdInSet];
        break;
      case TilesetType.smoke:
        frames = _smokeAnimations[tileIdInSet];
        break;
      case TilesetType.trees:
        frames = _treesAnimations[tileIdInSet];
        break;
      case TilesetType.wooden:
        frames = _woodenAnimations[tileIdInSet];
        break;
      case TilesetType.beachObjects:
        frames = _beachObjectsAnimations[tileIdInSet];
        break;
      default:
        frames = null;
    }
    
    return _TileData(sprite: sprite, frames: frames, tilesetType: type).._overrideSize = size;
  }

  void _tickAnimations(double dt) {
    if (_animStates.isEmpty) {
      return; // Early exit if no animations
    }
    
    final addMs = (dt * 1000).toInt();
    _animationFrameCount++;
    
    // Performance monitoring - only log every 5 seconds
    if (_animationFrameCount % 300 == 0) {
      debugPrint('[TileRenderer] Performance: ${_animStates.length} active animations, ${_tileSprites.length} total sprites');
    }
    
    // Use a more efficient iteration
    final keysToUpdate = <String>[];
    final statesToUpdate = <_AnimState>[];
    
    // First pass: collect animations that need updates
    _animStates.forEach((key, state) {
      if (state.frames.isEmpty) return;
      
      state.elapsedMs += addMs;
      final current = state.frames[state.currentIndex];
      if (current.durationMs > 0 && state.elapsedMs >= current.durationMs) {
        keysToUpdate.add(key);
        statesToUpdate.add(state);
      }
    });
    
    // Second pass: update sprites (batch operations)
    for (int i = 0; i < keysToUpdate.length; i++) {
      final key = keysToUpdate[i];
      final state = statesToUpdate[i];
      
      state.elapsedMs = 0;
      state.currentIndex = (state.currentIndex + 1) % state.frames.length;
      
      final comp = _tileSprites[key];
      if (comp != null) {
        _updateAnimationSprite(key, state);
      }
    }
  }

  // Pre-calculate frame sprites for animations to avoid repeated lookups
  void _precalculateFrameSprites(String tileKey, _AnimState state) {
    if (_frameSpriteCache.containsKey(tileKey)) return; // Already cached
    
    final frameSprites = <Sprite?>[];
    final firstGid = _getFirstGidForType(state.gid);
    
    for (final frame in state.frames) {
      final frameGid = firstGid + frame.tileId;
      final tileData = _getTileData(frameGid);
      frameSprites.add(tileData?.sprite);
    }
    
    _frameSpriteCache[tileKey] = frameSprites;
  }

  // Optimized animation update using pre-calculated sprites
  void _updateAnimationSprite(String tileKey, _AnimState state) {
    final comp = _tileSprites[tileKey];
    if (comp == null) return;
    
    // Use cached sprites if available
    final cachedSprites = _frameSpriteCache[tileKey];
    if (cachedSprites != null && state.currentIndex < cachedSprites.length) {
      final sprite = cachedSprites[state.currentIndex];
      if (sprite != null) {
        comp.sprite = sprite;
        return;
      }
    }
    
    // Fallback to dynamic lookup
    final frameTileId = state.frames[state.currentIndex].tileId;
    final firstGid = _getFirstGidForType(state.gid);
    final frameGid = firstGid + frameTileId;
    final tileData = _getTileData(frameGid);
    if (tileData?.sprite != null) {
      comp.sprite = tileData!.sprite;
    }
  }

  Future<void> renderTilemap(List<List<int>> groundTileData, [List<List<int>>? decorationTileData]) async {
    // Store data for both layers
    _groundTileData = groundTileData;
    _decorationTileData = decorationTileData;
    // Reset any stale overrides on new map load
    _gidOverrides.clear();

    debugPrint('[TileRenderer] 🎨 Starting initial tilemap render...');
    debugPrint('[TileRenderer] 📊 Ground data: ${groundTileData.length}x${groundTileData[0].length}');
    debugPrint('[TileRenderer] 🎨 Decoration data: ${decorationTileData?.length ?? 0}x${decorationTileData?[0].length ?? 0}');
    debugPrint('[TileRenderer] 📷 Camera view: ${game.camera.visibleWorldRect}');

    await updateVisibleTiles(force: true);
    
    debugPrint('[TileRenderer] ✅ Initial tilemap render complete');
  }

  // Set a visual override for a ground tile without mutating the base TMX grid
  Future<void> setTileOverride(int x, int y, int newGid) async {
    final key = '$x,$y';
    final spriteKey = 'ground_$x,$y';
    _gidOverrides[key] = newGid;
    // Remove old sprite so it can be redrawn with the override
    _tileSprites[spriteKey]?.removeFromParent();
    _tileSprites.remove(spriteKey);
    if (newGid > 0 && _isTileVisible(x, y)) {
      await renderGroundTile(x, y, newGid);
      _loadedGroundTileKeys.add(spriteKey);
    }
  }

  // Clear all overrides (optional utility)
  void clearOverrides() {
    _gidOverrides.clear();
  }

  // Clear all overrides and refresh visual state
  Future<void> clearOverridesAndRefresh() async {
    debugPrint('[TileRenderer] 🧹 Clearing all overrides and refreshing visual state');
    _gidOverrides.clear();
    // Force refresh all visible tiles to show original TMX data
    await updateVisibleTiles(force: true);
    debugPrint('[TileRenderer] ✅ Overrides cleared and visual state refreshed');
  }

  // Effective ground gid considering overrides
  int _effectiveGroundGidAt(int x, int y) {
    final override = _gidOverrides['$x,$y'];
    if (override != null) return override;
    return _groundTileData![y][x];
  }

  // Public: read effective GID at a coordinate (null if out of bounds or no data)
  int? getEffectiveGidAt(int x, int y) {
    if (_groundTileData == null) return null;
    if (y < 0 || y >= _groundTileData!.length) return null;
    if (x < 0 || x >= _groundTileData![y].length) return null;
    return _effectiveGroundGidAt(x, y);
  }

  Future<void> renderGroundTile(int x, int y, int gid) async {
    final tileKey = 'ground_$x,$y';
    final tileData = _getTileData(gid);

    if (tileData?.sprite != null) {
      final tileSprite = SpriteComponent(
        sprite: tileData!.sprite,
        // Bottom alignment for tall objects: place sprite so its bottom sits on tile bottom
        position: Vector2(x * tileSize, (y + 1) * tileSize - (tileData._overrideSize?.y ?? tileSize)),
        size: tileData._overrideSize ?? Vector2.all(tileSize),
        priority: -10, // Ground layer has lower priority
      );
      _groundSpriteLayer.add(tileSprite);
      _tileSprites[tileKey] = tileSprite;
      if (tileData.frames != null && tileData.frames!.isNotEmpty) {
        _animStates[tileKey] = _AnimState(
          frames: tileData.frames!,
          elapsedMs: 0,
          currentIndex: 0,
          gid: gid,
        );
        _precalculateFrameSprites(tileKey, _animStates[tileKey]!);
      }
    }
  }

  Future<void> renderDecorationTile(int x, int y, int gid) async {
    final tileKey = 'decoration_$x,$y';
    final tileData = _getTileData(gid);

    // Simple approach: Skip rendering decorations on tilled tiles
    if (_isTileTilled(x, y)) {
      // debugPrint('[TileRenderer] ⏭️ Skipping decoration at ($x, $y) - tile is tilled');
      return;
    }

    if (tileData?.sprite != null) {
      // Check if this decoration object is walkable
      final isWalkable = _isDecorationWalkable(gid);
      final objectType = _getDecorationObjectType(gid);
      final Vector2 finalSize = tileData!._overrideSize ?? Vector2.all(tileSize);
      final double footprintHeight = _getDecorationFootprintHeight(gid, finalSize);
      final MapEntry<Vector2, Vector2> fp = _getDecorationFootprintBox(gid, finalSize, footprintHeight);

      // Place with top-left anchor: bottom-align tall sprites to tile bottom
      final Vector2 topLeftPos = Vector2(x * tileSize, (y + 1) * tileSize - finalSize.y);
      final decorationObject = DecorationObject(
        sprite: tileData.sprite!,
        position: topLeftPos,
        size: finalSize,
        gid: gid,
        objectType: objectType,
        footprintHeight: footprintHeight,
        footprintSize: fp.key,
        footprintOffset: fp.value,
        isWalkable: isWalkable,
      );
      // Add directly to world instead of decoration layer for proper y-axis sorting
      game.world.add(decorationObject);
      _tileSprites[tileKey] = decorationObject;

      // Debug logging for houses and wooden objects
      if (objectType == 'house' || objectType == 'wooden') {
        debugPrint('[TileRenderer] 🏠 Rendered $objectType at ($x, $y): GID $gid, size ${finalSize.x}x${finalSize.y}');
      }

      // Mark footprint area as obstacles in the grid (owl-like behavior)
      if (!isWalkable) {
        final double gridSize = game.pathfindingGrid.tileSize;
        final double footprintLeft = topLeftPos.x + (finalSize.x - fp.key.x) / 2;
        final double footprintTop = topLeftPos.y + finalSize.y - footprintHeight;
        final double footprintRight = footprintLeft + fp.key.x;
        final double footprintBottom = footprintTop + footprintHeight;

        final int gx0 = (footprintLeft / gridSize).floor();
        final int gy0 = (footprintTop / gridSize).floor();
        final int gx1 = ((footprintRight - 0.001) / gridSize).floor();
        final int gy1 = ((footprintBottom - 0.001) / gridSize).floor();

        debugPrint('[TileRenderer] Marking decoration obstacles for ${objectType} at ($x, $y): footprint covers grid tiles ($gx0,$gy0) to ($gx1,$gy1)');
        for (int gy = gy0; gy <= gy1; gy++) {
          for (int gx = gx0; gx <= gx1; gx++) {
            // DISABLED: Purple collision logic for decoration objects
            // game.pathfindingGrid.setObstacle(gx, gy, true);
            // game.markDecorationObstacle(gx, gy);
            debugPrint('[TileRenderer] DISABLED: Would have marked decoration obstacle at grid ($gx, $gy)');
          }
        }
      }
      if (tileData.frames != null && tileData.frames!.isNotEmpty) {
        _animStates[tileKey] = _AnimState(
          frames: tileData.frames!,
          elapsedMs: 0,
          currentIndex: 0,
          gid: gid,
        );
        _precalculateFrameSprites(tileKey, _animStates[tileKey]!);
      }
    }
  }

  // Helper method to determine if a decoration object is walkable
  bool _isDecorationWalkable(int gid) {
    // Use hardcoded defaults based on tileset ranges
    // This matches the logic used in the pathfinding system
    if (gid >= _housesFirstGid && gid <= _housesLastGid) {
      return false; // Houses are typically not walkable
    } else if (gid >= _treesFirstGid && gid <= _treesLastGid) {
      return false; // Trees are typically not walkable
    } else if (gid >= _smokeFirstGid && gid <= _smokeLastGid) {
      return true; // Smoke is typically walkable (visual effect)
    } else if (gid >= _woodenFirstGid && gid <= _woodenLastGid) {
      return false; // Wooden objects are NOT walkable (all have walkable=false in .tsx)
    } else if (gid >= _beachObjectsFirstGid && gid <= _beachObjectsLastGid) {
      return false; // Beach objects are NOT walkable (all have walkable=false in .tsx)
    }
    return true; // Default to walkable
  }

  // Helper method to get the decoration object type
  String _getDecorationObjectType(int gid) {
    if (gid >= _housesFirstGid && gid <= _housesLastGid) {
      return 'house';
    } else if (gid >= _treesFirstGid && gid <= _treesLastGid) {
      return 'tree';
    } else if (gid >= _woodenFirstGid && gid <= _woodenLastGid) {
      return 'wooden';
    } else if (gid >= _beachObjectsFirstGid && gid <= _beachObjectsLastGid) {
      return 'beach_object';
    } else if (gid >= _smokeFirstGid && gid <= _smokeLastGid) {
      return 'smoke';
    }
    return 'unknown';
  }

  // Estimate the solid footprint height (in pixels) for decoration objects.
  // This defines the bottom portion of the sprite that should block movement.
  double _getDecorationFootprintHeight(int gid, Vector2 size) {
    // Default footprint: one tile high, but not exceeding sprite height
    double defaultFootprint = tileSize;

    if (gid >= _housesFirstGid && gid <= _housesLastGid) {
      // Houses: larger footprint, roughly half of sprite or 1.5 tiles, whichever is smaller
      final double halfSprite = size.y * 0.5;
      final double tilesFootprint = tileSize * 1.5;
      return halfSprite < tilesFootprint ? halfSprite : tilesFootprint;
    } else if (gid >= _treesFirstGid && gid <= _treesLastGid) {
      // Trees: small trunk footprint, around 0.6 tile or 35% of sprite (min)
      final double spriteFrac = size.y * 0.35;
      final double tilesFootprint = tileSize * 0.6;
      return spriteFrac < tilesFootprint ? spriteFrac : tilesFootprint;
    } else if (gid >= _woodenFirstGid && gid <= _woodenLastGid) {
      // Wooden props: typically walkable; if not, small footprint
      final double tilesFootprint = tileSize * 0.5;
      return tilesFootprint < size.y ? tilesFootprint : size.y;
    } else if (gid >= _beachObjectsFirstGid && gid <= _beachObjectsLastGid) {
      // Beach objects: usually walkable; if not, small footprint
      final double tilesFootprint = tileSize * 0.5;
      return tilesFootprint < size.y ? tilesFootprint : size.y;
    }
    return defaultFootprint < size.y ? defaultFootprint : size.y;
  }

  // Internal struct for precise footprint box

  // Compute a precise footprint rectangle (size and local offset)
  MapEntry<Vector2, Vector2> _getDecorationFootprintBox(int gid, Vector2 size, double footprintHeight) {
    final double h = footprintHeight < size.y ? footprintHeight : size.y;
    if (gid >= _housesFirstGid && gid <= _housesLastGid) {
      // Full width, tall footprint near bottom
      return MapEntry(Vector2(size.x, h), Vector2(0, 0));
    } else if (gid >= _treesFirstGid && gid <= _treesLastGid) {
      // Narrow trunk: ~40% width, centered
      final double w = size.x * 0.4;
      final double xOffset = (size.x - w) / 2;
      return MapEntry(Vector2(w, h), Vector2(xOffset, 0));
    } else if (gid >= _woodenFirstGid && gid <= _woodenLastGid) {
      // Medium width objects: ~70% width, centered
      final double w = size.x * 0.7;
      final double xOffset = (size.x - w) / 2;
      return MapEntry(Vector2(w, h), Vector2(xOffset, 0));
    } else if (gid >= _beachObjectsFirstGid && gid <= _beachObjectsLastGid) {
      // Light props: ~60% width
      final double w = size.x * 0.6;
      final double xOffset = (size.x - w) / 2;
      return MapEntry(Vector2(w, h), Vector2(xOffset, 0));
    }
    // Default: full width
    return MapEntry(Vector2(size.x, h), Vector2(0, 0));
  }

  // Backward compatibility method
  Future<void> renderTile(int x, int y, int gid) async {
    await renderGroundTile(x, y, gid);
  }

  Future<void> updateTileVisual(List<List<int>> tileData, int x, int y, int newGid) async {
    // Non-destructive: route to overrides instead of mutating tileData
    await setTileOverride(x, y, newGid);
  }

  bool _isTileVisible(int x, int y) {
    final view = game.camera.visibleWorldRect;
    final left = (view.left / tileSize).floor() - 2;
    final right = (view.right / tileSize).ceil() + 2;
    final top = (view.top / tileSize).floor() - 2;
    final bottom = (view.bottom / tileSize).ceil() + 2;
    return x >= max(0, left) && x <= right && y >= max(0, top) && y <= bottom;
  }

  Future<void> updateVisibleTiles({bool force = false}) async {
    if (_groundTileData == null) return;
    
    final view = game.camera.visibleWorldRect;
    
    // Check if camera view is properly initialized
    if (view.width <= 0 || view.height <= 0) {
      debugPrint('[TileRenderer] ⚠️ Camera view not properly initialized, using fallback visibility area');
      // Use a fallback area around the camera's viewfinder (player-centered) for initial load
      final vfPos = game.camera.viewfinder.position;
      final approxSpawnX = (vfPos.x / tileSize).round();
      final approxSpawnY = (vfPos.y / tileSize).round();
      final spawnX = approxSpawnX;
      final spawnY = approxSpawnY;
      final fallbackRadius = 12; // Large enough to include nearby decoration objects
      
      final startX = max(0, spawnX - fallbackRadius);
      final endX = min(_groundTileData![0].length - 1, spawnX + fallbackRadius);
      final startY = max(0, spawnY - fallbackRadius);
      final endY = min(_groundTileData!.length - 1, spawnY + fallbackRadius);
      
      debugPrint('[TileRenderer] 🔄 Using fallback visibility area: ($startX,$startY) to ($endX,$endY)');
      
      // Render ground layer with fallback area
      final desiredGround = <String>{};
      for (var y = startY; y <= endY; y++) {
        for (var x = startX; x <= endX; x++) {
          final gid = _effectiveGroundGidAt(x, y);
          if (gid == 0) continue;
          final key = 'ground_$x,$y';
          desiredGround.add(key);
          if (!_loadedGroundTileKeys.contains(key) || force) {
            await renderGroundTile(x, y, gid);
            _loadedGroundTileKeys.add(key);
          }
        }
      }
      
      // Render decoration layer with fallback area
      final desiredDecoration = <String>{};
      if (_decorationTileData != null) {
        for (var y = startY; y <= endY; y++) {
          for (var x = startX; x <= endX; x++) {
            final gid = _decorationTileData![y][x];
            if (gid == 0) continue;
            final key = 'decoration_$x,$y';
            desiredDecoration.add(key);
            if (!_loadedDecorationTileKeys.contains(key) || force) {
              await renderDecorationTile(x, y, gid);
              // Only mark as loaded if a sprite was actually created
              if (_tileSprites.containsKey(key)) {
                _loadedDecorationTileKeys.add(key);
              }
            }
          }
        }
      }
      
      // Schedule a guaranteed post-frame refresh to re-evaluate with a valid camera view
      if (!_postFrameRefreshScheduled) {
        _postFrameRefreshScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          _postFrameRefreshScheduled = false;
          await updateVisibleTiles(force: true);
        });
      }

      return;
    }
    
    // Use a larger buffer for decoration objects since they can be much larger than base tiles
    // Houses can be up to 122x99 pixels, so we need a larger buffer to ensure they're visible
    final decorationBuffer = 8; // Increased from 4 to 8 tiles for decoration objects
    final groundBuffer = 4; // Keep ground buffer smaller for performance
    
    final startX = max(0, (view.left / tileSize).floor() - groundBuffer);
    final endX = min(_groundTileData![0].length - 1, (view.right / tileSize).ceil() + groundBuffer);
    final startY = max(0, (view.top / tileSize).floor() - groundBuffer);
    final endY = min(_groundTileData!.length - 1, (view.bottom / tileSize).ceil() + groundBuffer);

    // Update ground layer
    final desiredGround = <String>{};
    for (var y = startY; y <= endY; y++) {
      for (var x = startX; x <= endX; x++) {
        final gid = _effectiveGroundGidAt(x, y);
        if (gid == 0) continue;
        final key = 'ground_$x,$y';
        desiredGround.add(key);
        if (!_loadedGroundTileKeys.contains(key) || force) {
          await renderGroundTile(x, y, gid);
          _loadedGroundTileKeys.add(key);
        }
      }
    }

    // Update decoration layer with larger buffer
    final desiredDecoration = <String>{};
    if (_decorationTileData != null) {
      // Use larger buffer for decoration objects to account for their size
      final decorationStartX = max(0, (view.left / tileSize).floor() - decorationBuffer);
      final decorationEndX = min(_decorationTileData![0].length - 1, (view.right / tileSize).ceil() + decorationBuffer);
      final decorationStartY = max(0, (view.top / tileSize).floor() - decorationBuffer);
      final decorationEndY = min(_decorationTileData!.length - 1, (view.bottom / tileSize).ceil() + decorationBuffer);
      
      // Debug logging for decoration visibility update
      if (force) {
        debugPrint('[TileRenderer] 🔍 Updating decoration visibility: area ($decorationStartX,$decorationStartY) to ($decorationEndX,$decorationEndY)');
      }
      
      for (var y = decorationStartY; y <= decorationEndY; y++) {
        for (var x = decorationStartX; x <= decorationEndX; x++) {
          final gid = _decorationTileData![y][x];
          if (gid == 0) continue;
          final key = 'decoration_$x,$y';
          desiredDecoration.add(key);
          if (!_loadedDecorationTileKeys.contains(key) || force) {
            await renderDecorationTile(x, y, gid);
            // Only mark as loaded if a sprite was actually created
            if (_tileSprites.containsKey(key)) {
              _loadedDecorationTileKeys.add(key);
            }
          }
        }
      }
    }

    // Remove offscreen ground tiles
    final toRemoveGround = _loadedGroundTileKeys.difference(desiredGround).toList(growable: false);
    for (final key in toRemoveGround) {
      final comp = _tileSprites[key];
      comp?.removeFromParent();
      _tileSprites.remove(key);
      _loadedGroundTileKeys.remove(key);
      // Clean up animation state and frame cache
      _animStates.remove(key);
      _frameSpriteCache.remove(key);
    }

    // Remove offscreen decoration tiles
    final toRemoveDecoration = _loadedDecorationTileKeys.difference(desiredDecoration).toList(growable: false);
    for (final key in toRemoveDecoration) {
      final comp = _tileSprites[key];
      comp?.removeFromParent();
      _tileSprites.remove(key);
      _loadedDecorationTileKeys.remove(key);
      // Clean up animation state and frame cache
      _animStates.remove(key);
      _frameSpriteCache.remove(key);
    }
  }

  // Performance monitoring method
  void logPerformanceStats() {
    debugPrint('[TileRenderer] Performance Stats:');
    debugPrint('  - Active animations: ${_animStates.length}');
    debugPrint('  - Total sprites: ${_tileSprites.length}');
    debugPrint('  - Frame sprite cache entries: ${_frameSpriteCache.length}');
    debugPrint('  - Image collection cache entries: ${_imageCollectionSpriteCache.length}');
    debugPrint('  - Ground tiles loaded: ${_loadedGroundTileKeys.length}');
    debugPrint('  - Decoration tiles loaded: ${_loadedDecorationTileKeys.length}');
  }

  // Cleanup method for memory management
  void cleanup() {
    _animStates.clear();
    _frameSpriteCache.clear();
    _imageCollectionSpriteCache.clear();
    _imageCollectionSizeCache.clear();
    _tileSprites.clear();
    _loadedGroundTileKeys.clear();
    _loadedDecorationTileKeys.clear();
    _gidOverrides.clear();
  }
}

class _AnimState {
  final List<custom_parser.TilesetAnimationFrame> frames;
  int elapsedMs;
  int currentIndex;
  final int gid;
  _AnimState({required this.frames, required this.elapsedMs, required this.currentIndex, required this.gid});
}

/// Lightweight component to periodically call a tick function
class _VisibilityUpdater extends PositionComponent {
  _VisibilityUpdater({required this.onTick});
  final void Function(double dt) onTick;

  @override
  void update(double dt) {
    super.update(dt);
    onTick(dt);
  }
}


