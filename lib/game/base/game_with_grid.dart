import 'package:flame/game.dart';
import 'package:lovenest/utils/pathfinding.dart';

abstract class GameWithGrid extends FlameGame {
  PathfindingGrid get pathfindingGrid;
} 