import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

enum BuildingType {
  house,
  barn,
}

class Building extends RectangleComponent with CollisionCallbacks {
  final BuildingType buildingType;
  
  Building(Vector2 position, this.buildingType) : super(
    position: position,
    size: buildingType == BuildingType.house ? Vector2(96, 64) : Vector2(64, 48),
    priority: 5, // Render buildings above tiles but priority can vary with player
  );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    paint = Paint()..color = _getBuildingColor();
    add(RectangleHitbox());
  }

  Color _getBuildingColor() {
    switch (buildingType) {
      case BuildingType.house:
        return const Color(0xFFCD853F);
      case BuildingType.barn:
        return const Color(0xFF8B4513);
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Draw building details
    switch (buildingType) {
      case BuildingType.house:
        // Draw roof
        final path = Path()
          ..moveTo(size.x * 0.1, size.y * 0.3)
          ..lineTo(size.x * 0.5, 0)
          ..lineTo(size.x * 0.9, size.y * 0.3)
          ..close();
        canvas.drawPath(path, Paint()..color = const Color(0xFF8B0000));
        
        // Draw door
        canvas.drawRect(
          Rect.fromLTWH(size.x * 0.4, size.y * 0.5, size.x * 0.2, size.y * 0.5),
          Paint()..color = const Color(0xFF654321),
        );
        
        // Draw windows
        canvas.drawRect(
          Rect.fromLTWH(size.x * 0.15, size.y * 0.4, size.x * 0.15, size.y * 0.15),
          Paint()..color = Colors.lightBlue,
        );
        canvas.drawRect(
          Rect.fromLTWH(size.x * 0.7, size.y * 0.4, size.x * 0.15, size.y * 0.15),
          Paint()..color = Colors.lightBlue,
        );
        break;
      case BuildingType.barn:
        // Draw barn doors
        canvas.drawRect(
          Rect.fromLTWH(size.x * 0.3, size.y * 0.3, size.x * 0.4, size.y * 0.7),
          Paint()..color = const Color(0xFF654321),
        );
        
        // Draw hay loft window
        canvas.drawCircle(
          Offset(size.x * 0.5, size.y * 0.2),
          6,
          Paint()..color = Colors.black,
        );
        break;
    }
  }
} 