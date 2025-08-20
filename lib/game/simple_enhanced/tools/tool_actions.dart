import 'package:flame/components.dart';

typedef TileSetter = Future<void> Function(int x, int y);

class ToolActions {
  final Component world;
  final double tileSize;

  ToolActions({required this.world, required this.tileSize});

  bool isAdjacent(Vector2 playerPos, int gridX, int gridY) {
    final playerGridX = (playerPos.x / tileSize).floor();
    final playerGridY = (playerPos.y / tileSize).floor();
    final dx = (gridX - playerGridX).abs();
    final dy = (gridY - playerGridY).abs();
    return dx <= 1 && dy <= 1 && !(dx == 0 && dy == 0);
  }
}


