import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

class HighlightManager {
  final Component world;
  final double tileSize;

  final Map<String, RectangleComponent> _hoeHighlights = {};
  final Map<String, RectangleComponent> _wateringHighlights = {};

  HighlightManager({required this.world, required this.tileSize});

  void clearHoe() {
    for (final h in _hoeHighlights.values) {
      h.removeFromParent();
    }
    _hoeHighlights.clear();
  }

  void clearWatering() {
    for (final h in _wateringHighlights.values) {
      h.removeFromParent();
    }
    _wateringHighlights.clear();
  }

  void showHoeAt(Iterable<math.Point> positions) {
    clearHoe();
    for (final p in positions) {
      final key = '${p.x}_${p.y}';
      final rect = RectangleComponent(
        position: Vector2(p.x * tileSize, p.y * tileSize),
        size: Vector2(tileSize, tileSize),
        paint: Paint()
          ..color = Colors.orange.withOpacity(0.4)
          ..style = PaintingStyle.fill,
      );
      _hoeHighlights[key] = rect;
      world.add(rect);
    }
  }

  void showWateringAt(Iterable<math.Point> positions) {
    clearWatering();
    for (final p in positions) {
      final key = '${p.x}_${p.y}';
      final rect = RectangleComponent(
        position: Vector2(p.x * tileSize, p.y * tileSize),
        size: Vector2(tileSize, tileSize),
        paint: Paint()
          ..color = Colors.blue.withOpacity(0.4)
          ..style = PaintingStyle.fill,
      );
      _wateringHighlights[key] = rect;
      world.add(rect);
    }
  }
}


