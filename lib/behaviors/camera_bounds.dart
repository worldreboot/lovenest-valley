import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:lovenest_valley/game/farm_game.dart';
import 'package:lovenest_valley/game/tiled_farm_game.dart';
import 'package:lovenest_valley/game/base/game_with_grid.dart';
import 'package:lovenest_valley/game/simple_enhanced_farm_game.dart';

class CameraBoundsBehavior extends Component with HasGameRef<GameWithGrid> {
  bool _loggedViewportWarning = false;
  
  @override
  void update(double dt) {
    final viewfinder = game.camera.viewfinder;
    final camera = game.camera;

    // Get the actual map dimensions from the game
    double worldWidth, worldHeight;
    
    if (game is SimpleEnhancedFarmGame) {
      // Use the actual map dimensions from SimpleEnhancedFarmGame
      worldWidth = SimpleEnhancedFarmGame.mapWidth * SimpleEnhancedFarmGame.tileSize;
      worldHeight = SimpleEnhancedFarmGame.mapHeight * SimpleEnhancedFarmGame.tileSize;
    } else {
      // Fallback for other game types
      worldWidth = 30 * 32.0;
      worldHeight = 20 * 32.0;
    }

    // Calculate the visible area of the camera
    final visibleRect = camera.visibleWorldRect;
    final halfViewportWidth = visibleRect.width / 2;
    final halfViewportHeight = visibleRect.height / 2;

    // Clamp the camera position to keep the map fully visible
    // The camera should never show areas beyond the map boundaries
    
    // Calculate bounds
    final minX = halfViewportWidth;
    final maxX = worldWidth - halfViewportWidth;
    final minY = halfViewportHeight;
    final maxY = worldHeight - halfViewportHeight;
    
    // Ensure bounds are valid (min <= max) before clamping
    if (minX <= maxX && minY <= maxY) {
      // Normal case: viewport fits within world, apply bounds
      final clampedX = viewfinder.position.x.clamp(minX, maxX);
      final clampedY = viewfinder.position.y.clamp(minY, maxY);
      viewfinder.position = Vector2(clampedX, clampedY);
    } else {
      // Viewport is larger than world - allow free movement but keep camera within world bounds
      // This prevents the camera from going completely outside the world
      final clampedX = viewfinder.position.x.clamp(0.0, worldWidth);
      final clampedY = viewfinder.position.y.clamp(0.0, worldHeight);
      viewfinder.position = Vector2(clampedX, clampedY);
      
      // Only log this once to avoid spam
      if (!_loggedViewportWarning) {
        debugPrint('[CameraBoundsBehavior] ⚠️ Viewport larger than world - allowing free camera movement within bounds');
        _loggedViewportWarning = true;
      }
    }
  }
} 
