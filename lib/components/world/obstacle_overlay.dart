import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:lovenest_valley/config/feature_flags.dart';
// Avoid direct dependency on specific Game class; use GameWithGrid hooks
import 'package:lovenest_valley/game/base/game_with_grid.dart';
import 'package:lovenest_valley/components/world/decoration_object.dart';

/// Renders semi-transparent overlays over obstacle tiles for debugging
class ObstacleOverlay extends Component with HasGameRef<GameWithGrid> {
  final double tileSize;
  ObstacleOverlay({required this.tileSize});

  @override
  void render(Canvas canvas) {
    if (!kShowDecorationFootprints) return;
    final grid = gameRef.pathfindingGrid;
    final view = gameRef.camera.visibleWorldRect;

    final int startX = (view.left / tileSize).floor().clamp(0, grid.width - 1);
    final int endX = (view.right / tileSize).ceil().clamp(0, grid.width - 1);
    final int startY = (view.top / tileSize).floor().clamp(0, grid.height - 1);
    final int endY = (view.bottom / tileSize).ceil().clamp(0, grid.height - 1);

    // Purple collision boxes disabled - only show red decoration object collision boxes
    // debugPrint('[ObstacleOverlay] Purple collision boxes disabled - only decoration object red boxes will show');
    
    // Count obstacles for debugging but don't render purple boxes
    int obstacleCount = 0;
    int decorationObstacleCount = 0;
    int objectObstacleCount = 0;
    
    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        if (grid.isObstacle(x, y)) {
          obstacleCount++;
          if (gameRef.isDecorationObstacleTile(x, y)) {
            decorationObstacleCount++;
          }
          if (_isObjectOccupiedTile(x, y)) {
            objectObstacleCount++;
          }
        }
      }
    }
    // debugPrint('[ObstacleOverlay] Found $obstacleCount obstacles, $decorationObstacleCount were decoration obstacles, $objectObstacleCount were object obstacles (purple boxes disabled)');
  }

  /// Check if a tile is occupied by an object (owl, bonfire, etc.)
  /// This prevents purple overlays from showing on object tiles
  bool _isObjectOccupiedTile(int gridX, int gridY) {
    return gameRef.hasObjectAtPosition(gridX, gridY);
  }
}


