import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:flame/components.dart';

class PathfindingGrid {
  final int width;
  final int height;
  final double tileSize;
  late List<List<bool>> obstacles;
  
  PathfindingGrid(this.width, this.height, this.tileSize) {
    obstacles = List.generate(width, (_) => List.generate(height, (_) => false));
  }
  
  void setObstacle(int x, int y, bool isObstacle) {
    if (x >= 0 && x < width && y >= 0 && y < height) {
      obstacles[x][y] = isObstacle;
    }
  }
  
  bool isObstacle(int x, int y) {
    if (x < 0 || x >= width || y < 0 || y >= height) return true;
    return obstacles[x][y];
  }
  
  List<Vector2> findPath(Vector2 start, Vector2 end) {
    final startGrid = Vector2((start.x / tileSize).floor().toDouble(), (start.y / tileSize).floor().toDouble());
    final endGrid = Vector2(end.x.toDouble(), end.y.toDouble());
    
    return _aStar(startGrid, endGrid);
  }
  
  List<Vector2> _aStar(Vector2 start, Vector2 end) {
    final openSet = PriorityQueue<PathNode>((a, b) => a.fCost.compareTo(b.fCost));
    // Companion map for fast lookups
    final openSetMap = <String, PathNode>{};
    
    final closedSet = <String, PathNode>{};
    final startNode = PathNode(start.x.toInt(), start.y.toInt(), 0, _heuristic(start, end), null);
    
    openSet.add(startNode);
    openSetMap['${startNode.x},${startNode.y}'] = startNode;
    
    while (openSet.isNotEmpty) {
      final currentNode = openSet.removeFirst();
      final currentKey = '${currentNode.x},${currentNode.y}';
      openSetMap.remove(currentKey);
      
      if (closedSet.containsKey(currentKey)) continue;
      closedSet[currentKey] = currentNode;
      
      // Check if we reached the goal
      if (currentNode.x == end.x.toInt() && currentNode.y == end.y.toInt()) {
        return _reconstructPath(currentNode);
      }
      
      // Check all neighbors
      for (final direction in [
        Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), // Cardinal directions
        Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1), // Diagonal directions
      ]) {
        final neighborX = currentNode.x + direction.x.toInt();
        final neighborY = currentNode.y + direction.y.toInt();
        final neighborKey = '$neighborX,$neighborY';
        
        if (isObstacle(neighborX, neighborY) || closedSet.containsKey(neighborKey)) {
          continue;
        }
        
        final moveCost = direction.x != 0 && direction.y != 0 ? 1.4 : 1.0; // Diagonal movement costs more
        final gCost = currentNode.gCost + moveCost;
        final hCost = _heuristic(Vector2(neighborX.toDouble(), neighborY.toDouble()), end);
        
        final existingNode = openSetMap[neighborKey];
        
        if (existingNode == null || gCost < existingNode.gCost) {
          final newNode = PathNode(neighborX, neighborY, gCost, hCost, currentNode);
          
          if (existingNode != null) {
            // The PriorityQueue does not have a direct way to update an element,
            // so we remove the old one and add the new one.
            openSet.remove(existingNode);
          }
          openSet.add(newNode);
          openSetMap[neighborKey] = newNode;
        }
      }
    }
    
    return []; // No path found
  }
  
  double _heuristic(Vector2 a, Vector2 b) {
    return math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
  }
  
  List<Vector2> _reconstructPath(PathNode endNode) {
    final path = <Vector2>[];
    PathNode? currentNode = endNode;
    
    while (currentNode != null) {
      path.add(Vector2(
        currentNode.x * tileSize + tileSize / 2,
        currentNode.y * tileSize + tileSize / 2,
      ));
      currentNode = currentNode.parent;
    }
    
    return path.reversed.toList();
  }
}

class PathNode {
  final int x;
  final int y;
  final double gCost;
  final double hCost;
  final PathNode? parent;
  
  PathNode(this.x, this.y, this.gCost, this.hCost, this.parent);
  
  double get fCost => gCost + hCost;
} 
