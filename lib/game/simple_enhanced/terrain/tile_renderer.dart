import 'dart:math';
import 'package:flame/components.dart' show Component, SpriteComponent, Vector2, PositionComponent;
import 'package:flame/cache.dart' show Images;
import 'package:flame/sprite.dart';
import 'package:lovenest/game/base/game_with_grid.dart';

class TileRenderer {
  final Images images;
  final double tileSize;
  final Component world;
  final GameWithGrid game;

  late SpriteSheet _groundTileSpriteSheet;
  late SpriteSheet _beachTileSpriteSheet;
  final Map<String, SpriteComponent> _tileSprites = {};

  // Layer containers for tile sprites
  late PositionComponent _groundSpriteLayer;
  late PositionComponent _decorationSpriteLayer;
  List<List<int>>? _groundTileData;
  List<List<int>>? _decorationTileData;
  final Set<String> _loadedGroundTileKeys = <String>{};
  final Set<String> _loadedDecorationTileKeys = <String>{};
  double _sinceLastVisibilityUpdate = 0.0;

  TileRenderer({required this.images, required this.tileSize, required this.world, required this.game});

  Future<void> initialize() async {
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
        _updateVisibleTiles();
      }
    }));
  }

  Future<void> renderTilemap(List<List<int>> groundTileData, [List<List<int>>? decorationTileData]) async {
    // Store data for both layers
    _groundTileData = groundTileData;
    _decorationTileData = decorationTileData;
    await _updateVisibleTiles(force: true);
  }

  Future<void> renderGroundTile(int x, int y, int gid) async {
    final tileKey = 'ground_$x,$y';
    Sprite? sprite;

    if (gid >= 1 && gid <= 180) {
      final tileId = gid - 1;
      sprite = _groundTileSpriteSheet.getSpriteById(tileId);
    } else if (gid >= 181) {
      final tileId = gid - 181;
      sprite = _beachTileSpriteSheet.getSpriteById(tileId);
    }

    if (sprite != null) {
      final tileSprite = SpriteComponent(
        sprite: sprite,
        position: Vector2(x * tileSize, y * tileSize),
        size: Vector2.all(tileSize),
        priority: -10, // Ground layer has lower priority
      );
      _groundSpriteLayer.add(tileSprite);
      _tileSprites[tileKey] = tileSprite;
    }
  }

  Future<void> renderDecorationTile(int x, int y, int gid) async {
    final tileKey = 'decoration_$x,$y';
    Sprite? sprite;

    if (gid >= 1 && gid <= 180) {
      final tileId = gid - 1;
      sprite = _groundTileSpriteSheet.getSpriteById(tileId);
    } else if (gid >= 181) {
      final tileId = gid - 181;
      sprite = _beachTileSpriteSheet.getSpriteById(tileId);
    }

    if (sprite != null) {
      final tileSprite = SpriteComponent(
        sprite: sprite,
        position: Vector2(x * tileSize, y * tileSize),
        size: Vector2.all(tileSize),
        priority: -5, // Decoration layer has higher priority (rendered on top)
      );
      _decorationSpriteLayer.add(tileSprite);
      _tileSprites[tileKey] = tileSprite;
    }
  }

  // Backward compatibility method
  Future<void> renderTile(int x, int y, int gid) async {
    await renderGroundTile(x, y, gid);
  }

  Future<void> updateTileVisual(List<List<int>> tileData, int x, int y, int newGid) async {
    final tileKey = 'ground_$x,$y';
    final oldGid = tileData[y][x];
    if (oldGid == newGid) return;
    tileData[y][x] = newGid;
    _tileSprites[tileKey]?.removeFromParent();
    _tileSprites.remove(tileKey);
    // Only re-add if tile is within visible range
    if (newGid > 0) {
      final visible = _isTileVisible(x, y);
      if (visible) {
        await renderGroundTile(x, y, newGid);
        _loadedGroundTileKeys.add(tileKey);
      }
    }
  }

  bool _isTileVisible(int x, int y) {
    final view = game.camera.visibleWorldRect;
    final left = (view.left / tileSize).floor() - 2;
    final right = (view.right / tileSize).ceil() + 2;
    final top = (view.top / tileSize).floor() - 2;
    final bottom = (view.bottom / tileSize).ceil() + 2;
    return x >= max(0, left) && x <= right && y >= max(0, top) && y <= bottom;
  }

  Future<void> _updateVisibleTiles({bool force = false}) async {
    if (_groundTileData == null) return;
    
    final view = game.camera.visibleWorldRect;
    final startX = max(0, (view.left / tileSize).floor() - 4);
    final endX = min(_groundTileData![0].length - 1, (view.right / tileSize).ceil() + 4);
    final startY = max(0, (view.top / tileSize).floor() - 4);
    final endY = min(_groundTileData!.length - 1, (view.bottom / tileSize).ceil() + 4);

    // Update ground layer
    final desiredGround = <String>{};
    for (var y = startY; y <= endY; y++) {
      for (var x = startX; x <= endX; x++) {
        final gid = _groundTileData![y][x];
        if (gid == 0) continue;
        final key = 'ground_$x,$y';
        desiredGround.add(key);
        if (!_loadedGroundTileKeys.contains(key) || force) {
          await renderGroundTile(x, y, gid);
          _loadedGroundTileKeys.add(key);
        }
      }
    }

    // Update decoration layer
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
            _loadedDecorationTileKeys.add(key);
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
    }

    // Remove offscreen decoration tiles
    final toRemoveDecoration = _loadedDecorationTileKeys.difference(desiredDecoration).toList(growable: false);
    for (final key in toRemoveDecoration) {
      final comp = _tileSprites[key];
      comp?.removeFromParent();
      _tileSprites.remove(key);
      _loadedDecorationTileKeys.remove(key);
    }
  }
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


