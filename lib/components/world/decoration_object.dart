import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:lovenest_valley/config/feature_flags.dart';

class DecorationObject extends SpriteComponent {
  final int gid;
  final String objectType; // e.g., 'tree', 'house', 'wooden', etc.
  final bool isWalkable;
  final double footprintHeight; // height of the solid footprint at the bottom of the sprite
  final Vector2 footprintSize; // precise hitbox size
  final Vector2 footprintOffset; // local offset of hitbox
  
  DecorationObject({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.gid,
    required this.objectType,
    required this.footprintHeight,
    required this.footprintSize,
    required this.footprintOffset,
    this.isWalkable = true,
  }) : super(
    sprite: sprite,
    position: position,
    size: size,
    priority: -5, // Initial decoration layer priority
  );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    anchor = Anchor.topLeft;
    
    // No runtime hitboxes - collision detection handled by player's manual system
    // This allows for more precise control over collision behavior
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Dynamic Y-sort: objects with greater screen Y render above
    final baselineY = position.y + size.y;
    
    // Give smoke sprites a much higher priority so they always render on top
    if (objectType == 'smoke') {
      priority = 2000 + baselineY.toInt(); // Higher base priority for smoke
    } else {
      priority = 1000 + baselineY.toInt(); // Normal priority for other objects
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (kShowDecorationObjectFootprints && !isWalkable) {
      final double clampedHeight = footprintHeight.clamp(0, size.y);
      final Vector2 clampedSize = Vector2(
        footprintSize.x.clamp(0, size.x),
        footprintSize.y.clamp(0, clampedHeight),
      );
      final Paint p = Paint()
        ..color = Colors.red.withOpacity(0.25)
        ..style = PaintingStyle.fill;
      // topLeft anchor: center the footprint horizontally at the bottom of the sprite
      final double left = (size.x - clampedSize.x) / 2;
      final double top = size.y - clampedHeight;
      final Rect r = Rect.fromLTWH(left, top, clampedSize.x, clampedHeight);
      canvas.drawRect(r, p);
      final Paint border = Paint()
        ..color = Colors.red
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawRect(r, border);
    }
  }
}
