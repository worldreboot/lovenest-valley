import 'dart:math' as math;
import 'package:flame/components.dart';

/// Convert a screen-space position to world-space, given camera position, zoom and screen size.
Vector2 screenToWorld(
  Vector2 screenPos,
  Vector2 cameraPos,
  double zoom,
  Vector2 screenSize,
) {
  final screenCenter = Vector2(screenSize.x / 2, screenSize.y / 2);
  final offsetFromCenter = screenPos - screenCenter;
  return Vector2(
    cameraPos.x + (offsetFromCenter.x / zoom),
    cameraPos.y + (offsetFromCenter.y / zoom),
  );
}

/// Convert a world-space position to integer grid coordinates, given tile size.
math.Point<int> worldToGrid(Vector2 worldPosition, double tileSize) {
  return math.Point<int>(
    (worldPosition.x / tileSize).floor(),
    (worldPosition.y / tileSize).floor(),
  );
}


