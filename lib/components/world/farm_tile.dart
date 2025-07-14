import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

enum TileType {
  grass,
  tilled,
  crop,
  water,
  tree,
  wood,
}

class FarmTile extends PositionComponent {
  final TileType tileType;
  static const double tileSize = 32.0;
  static SpriteSheet? _groundSheet;
  static SpriteSheet? _woodSheet;

  FarmTile(Vector2 position, this.tileType)
      : super(position: position, size: Vector2.all(tileSize));

  static Future<void> loadTileSheets() async {
    if (_groundSheet == null) {
      final image = await Flame.images.load('ground.png');
      _groundSheet = SpriteSheet(image: image, srcSize: Vector2(48, 48));
    }
    if (_woodSheet == null) {
      final image = await Flame.images.load('wood.png');
      _woodSheet = SpriteSheet(image: image, srcSize: Vector2(48, 48));
    }
  }

  @override
  Future<void> onLoad() async {
    await loadTileSheets();
    super.onLoad();
  }

  @override
  void render(Canvas canvas) {
    Sprite? sprite;
    // Map tileType to tile index in ground.png
    if (tileType == TileType.grass) {
      sprite = _groundSheet?.getSprite(0, 0);
    } else if (tileType == TileType.tilled) {
      sprite = _groundSheet?.getSprite(0, 1);
    } else if (tileType == TileType.crop) {
      sprite = _groundSheet?.getSprite(1, 0);
    } else if (tileType == TileType.water) {
      sprite = _groundSheet?.getSprite(1, 1);
    } else if (tileType == TileType.wood) {
      sprite = _woodSheet?.getSprite(0, 1);
    }
    if (sprite != null) {
      sprite.renderRect(canvas, size.toRect());
    } else if (tileType == TileType.tree) {
      final paint = Paint()..color = Colors.green[900]!;
      canvas.drawRect(size.toRect(), paint);
    } else {
      final paint = Paint()..color = Colors.grey;
      canvas.drawRect(size.toRect(), paint);
    }
  }
} 