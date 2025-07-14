import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:lovenest/components/player.dart';
import 'package:lovenest/utils/pathfinding.dart';
import 'package:lovenest/game/base/game_with_grid.dart';

class FarmhouseInteriorGame extends GameWithGrid with HasCollisionDetection, TapCallbacks {
  static const int roomWidth = 15;
  static const int roomHeight = 10;
  static const double tileSize = 32.0;

  final VoidCallback? onExitHouse;

  late Player player;
  late PathfindingGrid pathfindingGrid;
  late List<List<InteriorTile?>> tileGrid;

  FarmhouseInteriorGame({this.onExitHouse});

  @override
  Color backgroundColor() => const Color(0xFF000000); // Black background

  @override
  Future<void> onLoad() async {
    super.onLoad();
    tileGrid = List.generate(roomWidth, (_) => List.filled(roomHeight, null));
    await _createRoom();
    pathfindingGrid = PathfindingGrid(roomWidth, roomHeight, tileSize);
    _updatePathfindingGrid();
    player = Player();
    // Start player near the exit
    player.position = Vector2((roomWidth ~/ 2) * tileSize + tileSize / 2, (roomHeight - 2) * tileSize + tileSize / 2);
    add(player);

    // Use the same camera setup as the farm
    camera.follow(player);
    camera.viewfinder.zoom = 2.0;
  }

  Future<void> _createRoom() async {
    for (int x = 0; x < roomWidth; x++) {
      for (int y = 0; y < roomHeight; y++) {
        final position = Vector2(x * tileSize, y * tileSize);
        InteriorTileType type;
        if (y == 0 || y == roomHeight - 1 || x == 0 || x == roomWidth - 1) {
          type = InteriorTileType.wall;
        } else if (y == roomHeight - 1 && x == roomWidth ~/ 2) {
          type = InteriorTileType.exit;
        } else if (x > 1 && x < 5 && y > 1 && y < 4) {
          // Add a bed
          type = InteriorTileType.furniture;
        } else if (x > 9 && x < 12 && y > 4 && y < 6) {
          // Add a table
          type = InteriorTileType.furniture;
        } else {
          type = InteriorTileType.floor;
        }
        final tile = InteriorTile(position, type);
        tileGrid[x][y] = tile;
        add(tile);
      }
    }
  }

  void _updatePathfindingGrid() {
    for (int x = 0; x < roomWidth; x++) {
      for (int y = 0; y < roomHeight; y++) {
        final type = tileGrid[x][y]?.type;
        pathfindingGrid.setObstacle(x, y, type == InteriorTileType.wall || type == InteriorTileType.furniture);
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    int gridX = (event.canvasPosition.x / tileSize).floor();
    int gridY = (event.canvasPosition.y / tileSize).floor();
    if (gridX < 0 || gridX >= roomWidth || gridY < 0 || gridY >= roomHeight) {
      return;
    }
    // If player is adjacent to exit and taps exit, trigger exit
    if (tileGrid[gridX][gridY]?.type == InteriorTileType.exit && _isPlayerAdjacentTo(gridX, gridY)) {
      onExitHouse?.call();
      return;
    }
    // Otherwise, move player to tapped floor tile using pathfinding
    if (tileGrid[gridX][gridY]?.type == InteriorTileType.floor) {
      player.pathfindTo(gridX, gridY);
    }
  }

  bool _isPlayerAdjacentTo(int tileX, int tileY) {
    final playerGridX = (player.position.x / tileSize).floor();
    final playerGridY = (player.position.y / tileSize).floor();
    final deltaX = (tileX - playerGridX).abs();
    final deltaY = (tileY - playerGridY).abs();
    return deltaX <= 1 && deltaY <= 1 && !(deltaX == 0 && deltaY == 0);
  }
}

enum InteriorTileType { wall, floor, exit, furniture }

class InteriorTile extends PositionComponent {
  final InteriorTileType type;
  InteriorTile(Vector2 position, this.type)
      : super(position: position, size: Vector2.all(FarmhouseInteriorGame.tileSize));

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = type == InteriorTileType.wall
          ? Colors.brown
          : type == InteriorTileType.exit
              ? Colors.red
              : type == InteriorTileType.furniture
              ? Colors.orange
              : Colors.yellow[100]!;
    canvas.drawRect(size.toRect(), paint);
    if (type == InteriorTileType.exit) {
      final doorPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(size.x / 4, size.y / 2, size.x / 2, size.y / 2), doorPaint);
    }
  }
} 