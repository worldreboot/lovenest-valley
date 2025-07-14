import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lovenest/components/world/building.dart';
import 'package:lovenest/components/world/farm_tile.dart';
import 'package:lovenest/game/base/game_with_grid.dart';
import 'package:lovenest/utils/pathfinding.dart';

enum PlayerDirection {
  up,
  down,
  left,
  right,
  idle,
}

class Player extends SpriteAnimationComponent with HasGameRef<GameWithGrid>, CollisionCallbacks {
  late Vector2 velocity;
  final double speed = 100.0;
  List<Vector2> currentPath = [];
  int currentPathIndex = 0;
  Vector2? manualTarget;
  
  // Animation related properties
  late SpriteAnimation upAnimation;
  late SpriteAnimation downAnimation;
  late SpriteAnimation leftAnimation;
  late SpriteAnimation rightAnimation;
  late SpriteAnimation idleAnimation;
  PlayerDirection currentDirection = PlayerDirection.idle;
  
  Player() : super(
    size: Vector2(32, 42),
    priority: 10, // Render player above tiles and other ground elements
  );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Load the spritesheet animations
    await _loadAnimations();
    
    // Set initial position and properties
    anchor = Anchor.center;
    velocity = Vector2.zero();
    
    // Set initial animation to idle (down-facing)
    animation = idleAnimation;
    
    add(RectangleHitbox());
  }

  Future<void> _loadAnimations() async {
    // Load the spritesheet using Flame's default image loading
    final spriteSheet = await game.images.load('user.png');
    
    // Spritesheet dimensions: 904x1038, 3 rows, 4 frames per row
    const frameWidth = 904 / 4; // 226 pixels
    const frameHeight = 1038 / 3; // 346 pixels
    
    // Create animations for each direction
    // Top row: up movement
    upAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.15,
        textureSize: Vector2(frameWidth, frameHeight),
        texturePosition: Vector2(0, 0), // Top row
      ),
    );
    
    // Middle row: right movement
    rightAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.15,
        textureSize: Vector2(frameWidth, frameHeight),
        texturePosition: Vector2(0, frameHeight), // Middle row
      ),
    );
    
    // Bottom row: down movement
    downAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.15,
        textureSize: Vector2(frameWidth, frameHeight),
        texturePosition: Vector2(0, frameHeight * 2), // Bottom row
      ),
    );
    
    // Left movement: flip the right animation
    leftAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.15,
        textureSize: Vector2(frameWidth, frameHeight),
        texturePosition: Vector2(0, frameHeight), // Same as right, but will be flipped
      ),
    );
    
    // Idle animation: first frame of down animation
    idleAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 1,
        stepTime: 1.0,
        textureSize: Vector2(frameWidth, frameHeight),
        texturePosition: Vector2(0, frameHeight * 2), // First frame of bottom row
      ),
    );
  }

  void _updateAnimation() {
    PlayerDirection newDirection = PlayerDirection.idle;
    
    // Determine direction based on velocity
    if (!velocity.isZero()) {
      if (velocity.y < 0 && velocity.y.abs() >= velocity.x.abs()) {
        newDirection = PlayerDirection.up;
      } else if (velocity.y > 0 && velocity.y.abs() >= velocity.x.abs()) {
        newDirection = PlayerDirection.down;
      } else if (velocity.x < 0) {
        newDirection = PlayerDirection.left;
      } else if (velocity.x > 0) {
        newDirection = PlayerDirection.right;
      }
    }
    
    // Only change animation if direction changed
    if (newDirection != currentDirection) {
      currentDirection = newDirection;
      
      switch (currentDirection) {
        case PlayerDirection.up:
          animation = upAnimation;
          scale.x = 1; // Normal orientation
          break;
        case PlayerDirection.down:
          animation = downAnimation;
          scale.x = 1; // Normal orientation
          break;
        case PlayerDirection.left:
          animation = leftAnimation;
          scale.x = -1; // Flip horizontally
          break;
        case PlayerDirection.right:
          animation = rightAnimation;
          scale.x = 1; // Normal orientation
          break;
        case PlayerDirection.idle:
          animation = idleAnimation;
          scale.x = 1; // Normal orientation
          break;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // Handle pathfinding movement
    if (currentPath.isNotEmpty && currentPathIndex < currentPath.length) {
      final target = currentPath[currentPathIndex];
      final direction = (target - position)..normalize();
      final distance = position.distanceTo(target);
      
      if (distance < 5) {
        currentPathIndex++;
        if (currentPathIndex >= currentPath.length) {
          // Reached the end of the path
          currentPath.clear();
          currentPathIndex = 0;
          velocity = Vector2.zero();
        }
      } else {
        velocity = direction * speed;
      }
    }
    // Handle manual target movement (for tap without pathfinding)
    else if (manualTarget != null) {
      final direction = (manualTarget! - position)..normalize();
      final distance = position.distanceTo(manualTarget!);
      
      if (distance < 5) {
        manualTarget = null;
        velocity = Vector2.zero();
      } else {
        velocity = direction * speed;
      }
    }
    
    // Apply movement
    if (!velocity.isZero()) {
      position += velocity * dt;
    }
    
    // Update animation based on current movement
    _updateAnimation();
  }

  KeyEventResult handleKeyEvent(Set<LogicalKeyboardKey> keysPressed) {
    // Stop pathfinding when using keyboard
    currentPath.clear();
    currentPathIndex = 0;
    manualTarget = null;
    
    velocity = Vector2.zero();
    
    // Handle keyboard input
    if (keysPressed.contains(LogicalKeyboardKey.arrowLeft) ||
        keysPressed.contains(LogicalKeyboardKey.keyA)) {
      velocity.x -= speed;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowRight) ||
        keysPressed.contains(LogicalKeyboardKey.keyD)) {
      velocity.x += speed;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowUp) ||
        keysPressed.contains(LogicalKeyboardKey.keyW)) {
      velocity.y -= speed;
    }
    if (keysPressed.contains(LogicalKeyboardKey.arrowDown) ||
        keysPressed.contains(LogicalKeyboardKey.keyS)) {
      velocity.y += speed;
    }
    
    return velocity != Vector2.zero() ? KeyEventResult.handled : KeyEventResult.ignored;
  }

  void pathfindTo(int gridX, int gridY) {
    // Stop any current movement
    manualTarget = null;
    velocity = Vector2.zero();
    
    // Calculate path using A* pathfinding
    final path = game.pathfindingGrid.findPath(position, Vector2(gridX.toDouble(), gridY.toDouble()));
    
    if (path.isNotEmpty) {
      currentPath = path;
      currentPathIndex = 0;
    }
  }

  void moveTowards(Vector2 target) {
    // Stop pathfinding and use direct movement
    currentPath.clear();
    currentPathIndex = 0;
    manualTarget = target;
  }

  @override
  bool onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    // Simple collision - stop movement
    if (other is FarmTile && other.tileType == TileType.tree) {
      velocity = Vector2.zero();
      manualTarget = null;
      // Don't stop pathfinding on collision, let it navigate around
      return false;
    }
    if (other is Building) {
      velocity = Vector2.zero();
      manualTarget = null;
      // Don't stop pathfinding on collision, let it navigate around
      return false;
    }
    return true;
  }
} 