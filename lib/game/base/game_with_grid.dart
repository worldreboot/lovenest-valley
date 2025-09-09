import 'package:flame/game.dart';
import 'package:lovenest_valley/utils/pathfinding.dart';

abstract class GameWithGrid extends FlameGame {
  PathfindingGrid get pathfindingGrid;

  // Debug/extension hooks: decoration footprint obstacle tracking
  // Default no-ops so engines that don't care can ignore
  void markDecorationObstacle(int gridX, int gridY) {}
  bool isDecorationObstacleTile(int gridX, int gridY) => false;
  
  /// Check if a tile is occupied by an object (owl, bonfire, etc.)
  /// Override this in game implementations to prevent purple overlays on object tiles
  bool hasObjectAtPosition(int gridX, int gridY) => false;
} 
