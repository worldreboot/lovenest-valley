part of '../../simple_enhanced_farm_game.dart';

extension ToolsAndHighlightingExtension on SimpleEnhancedFarmGame {
  void _playHoeAnimation(int gridX, int gridY) {
    final playerGridX = (player.position.x / SimpleEnhancedFarmGame.tileSize).floor();
    final playerGridY = (player.position.y / SimpleEnhancedFarmGame.tileSize).floor();
    final deltaX = gridX - playerGridX;
    final deltaY = gridY - playerGridY;
    int swingDirection = 1;
    bool shouldFlip = false;
    if (deltaX > 0) {
      swingDirection = 0;
      shouldFlip = false;
    } else if (deltaX < 0) {
      swingDirection = 0;
      shouldFlip = true;
    } else if (deltaY > 0) {
      swingDirection = 1;
      shouldFlip = false;
    } else if (deltaY < 0) {
      swingDirection = 2;
      shouldFlip = false;
    }
    _makePlayerFaceHoeDirection(deltaX, deltaY);
    final animationPosition = Vector2(gridX * SimpleEnhancedFarmGame.tileSize, gridY * SimpleEnhancedFarmGame.tileSize);
    final hoeAnimation = HoeAnimation(
      position: animationPosition,
      size: Vector2(SimpleEnhancedFarmGame.tileSize, SimpleEnhancedFarmGame.tileSize),
      swingDirection: swingDirection,
      shouldFlip: shouldFlip,
      onAnimationComplete: () {
        _tillTileAt(gridX, gridY);
        _resetPlayerDirection();
      },
    );
    world.add(hoeAnimation);
  }

  void _playWateringCanAnimation(int gridX, int gridY) {
    debugPrint('[SimpleEnhancedFarmGame] 💧 Starting watering animation at ($gridX, $gridY)');
    final playerGridX = (player.position.x / SimpleEnhancedFarmGame.tileSize).floor();
    final playerGridY = (player.position.y / SimpleEnhancedFarmGame.tileSize).floor();
    final deltaX = gridX - playerGridX;
    final deltaY = gridY - playerGridY;
    int wateringDirection = 1;
    bool shouldFlip = false;
    if (deltaX > 0) {
      wateringDirection = 0;
      shouldFlip = false;
    } else if (deltaX < 0) {
      wateringDirection = 0;
      shouldFlip = true;
    } else if (deltaY > 0) {
      wateringDirection = 1;
      shouldFlip = false;
    } else if (deltaY < 0) {
      wateringDirection = 2;
      shouldFlip = false;
    }
    _makePlayerFaceWateringCanDirection(deltaX, deltaY);
    final animationPosition = Vector2(gridX * SimpleEnhancedFarmGame.tileSize, gridY * SimpleEnhancedFarmGame.tileSize);
    final wateringCanAnimation = WateringCanAnimation(
      position: animationPosition,
      size: Vector2(SimpleEnhancedFarmGame.tileSize, SimpleEnhancedFarmGame.tileSize),
      wateringDirection: wateringDirection,
      shouldFlip: shouldFlip,
      onAnimationComplete: () {
        _waterTileAt(gridX, gridY);
        _resetPlayerDirection();
      },
    );
    world.add(wateringCanAnimation);
  }

  // Hoe highlighting helpers are implemented in the main class

  // Highlighting updates are event-driven via onPositionChanged debounce in the main class

  // Watering highlighting helpers are implemented in the main class

  void _makePlayerFaceHoeDirection(int deltaX, int deltaY) {
    _isHoeAnimationPlaying = true;
    player.disableAutoAnimation();
    player.disableKeyboardInput();
    player.velocity = Vector2.zero();
    if (deltaX > 0) {
      player.setDirection(PlayerDirection.right);
    } else if (deltaX < 0) {
      player.setDirection(PlayerDirection.left);
    } else if (deltaY > 0) {
      player.setDirection(PlayerDirection.down);
    } else if (deltaY < 0) {
      player.setDirection(PlayerDirection.up);
    }
  }

  void _makePlayerFaceWateringCanDirection(int deltaX, int deltaY) {
    _isWateringCanAnimationPlaying = true;
    player.disableAutoAnimation();
    player.disableKeyboardInput();
    player.velocity = Vector2.zero();
    if (deltaX > 0) {
      player.setDirection(PlayerDirection.right);
    } else if (deltaX < 0) {
      player.setDirection(PlayerDirection.left);
    } else if (deltaY > 0) {
      player.setDirection(PlayerDirection.down);
    } else if (deltaY < 0) {
      player.setDirection(PlayerDirection.up);
    }
  }

  void _resetPlayerDirection() {
    _isHoeAnimationPlaying = false;
    _isWateringCanAnimationPlaying = false;
    player.enableAutoAnimation();
    player.enableKeyboardInput();
    player.setDirection(PlayerDirection.idle);
  }
}


