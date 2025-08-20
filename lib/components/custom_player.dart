import 'dart:ui' as ui;
import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lovenest/components/world/building.dart';
import 'package:lovenest/components/world/farm_tile.dart';
import 'package:lovenest/game/base/game_with_grid.dart';
import 'package:lovenest/utils/pathfinding.dart';
import 'package:lovenest/services/avatar_generation_service.dart';
import 'package:lovenest/config/supabase_config.dart';

enum PlayerDirection {
  up,
  down,
  left,
  right,
  idle,
}

class CustomPlayer extends SpriteAnimationComponent with HasGameRef<GameWithGrid>, CollisionCallbacks {
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
  
  // Custom avatar properties
  final String userId;
  final AvatarGenerationService _avatarService = AvatarGenerationService();
  bool _customSpritesheetLoaded = false;
  String? _customSpritesheetUrl;
  
  // Smooth movement properties
  Vector2? _targetPosition;
  Vector2? _interpolationStart;
  double _interpolationTime = 0.0;
  static const double _interpolationDuration = 0.1; // 100ms interpolation
  
  // Movement prediction
  Vector2? _predictedPosition;
  static const double _predictionTime = 0.05; // 50ms prediction
  
  // Add a callback for position changes (for multiplayer broadcast)
  void Function(Vector2 pos, {String? animationState})? onPositionChanged;
  
  // Rate limiting for position broadcasts
  DateTime? _lastPositionBroadcast;
  static const double _broadcastInterval = 1.0 / 30.0; // 30 FPS
  
  CustomPlayer({required this.userId}) : super(
    size: Vector2(32, 42),
    priority: 10, // Render player above tiles and other ground elements
  );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Try to load custom spritesheet first
    await _loadCustomSpritesheet();
    
    // If custom spritesheet failed, load default
    if (!_customSpritesheetLoaded) {
      await _loadDefaultAnimations();
    }
    
    // Set initial position and properties
    anchor = Anchor.center;
    velocity = Vector2.zero();
    
    // Set initial animation to idle (down-facing)
    animation = idleAnimation;
    
    add(RectangleHitbox());
  }

  /// Load custom spritesheet from user's profile
  Future<void> _loadCustomSpritesheet() async {
    try {
      // Get the custom spritesheet URL
      _customSpritesheetUrl = await _avatarService.getSpritesheetUrl(userId);
      
      if (_customSpritesheetUrl != null) {
        // Load the custom spritesheet
        final spriteSheet = await game.images.load(_customSpritesheetUrl!);
        await _createAnimationsFromSpritesheet(spriteSheet);
        _customSpritesheetLoaded = true;
        print('Custom spritesheet loaded successfully for user: $userId');
      } else {
        print('No custom spritesheet found for user: $userId');
      }
    } catch (e) {
      print('Failed to load custom spritesheet: $e');
      _customSpritesheetLoaded = false;
    }
  }

  /// Load default animations as fallback
  Future<void> _loadDefaultAnimations() async {
    // Load the default spritesheet using Flame's default image loading
    final spriteSheet = await game.images.load('user.png');
    await _createAnimationsFromSpritesheet(spriteSheet);
    print('Default spritesheet loaded for user: $userId');
  }

  /// Create animations from a spritesheet
  Future<void> _createAnimationsFromSpritesheet(ui.Image spriteSheet) async {
    // Spritesheet dimensions: 904x1038, 3 rows, 4 frames per row
    const frameWidth = 904 / 4; // 226 pixels
    const frameHeight = 1038 / 3; // 346 pixels
    
    // Create animations for each direction with optimized frame rates
    // Top row: up movement
    upAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.12, // Slightly faster for smoother animation
        textureSize: Vector2(frameWidth, frameHeight),
        texturePosition: Vector2(0, 0), // Top row
      ),
    );
    
    // Middle row: right movement
    rightAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.12,
        textureSize: Vector2(frameWidth, frameHeight),
        texturePosition: Vector2(0, frameHeight), // Middle row
      ),
    );
    
    // Bottom row: down movement
    downAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.12,
        textureSize: Vector2(frameWidth, frameHeight),
        texturePosition: Vector2(0, frameHeight * 2), // Bottom row
      ),
    );
    
    // Left movement: flip the right animation
    leftAnimation = SpriteAnimation.fromFrameData(
      spriteSheet,
      SpriteAnimationData.sequenced(
        amount: 4,
        stepTime: 0.12,
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

  /// Reload custom spritesheet (useful when avatar generation completes)
  Future<void> reloadCustomSpritesheet() async {
    await _loadCustomSpritesheet();
    if (_customSpritesheetLoaded) {
      // Update current animation to use new spritesheet
      _updateAnimation();
    }
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
  
  // Public method to update animation (for multiplayer)
  void updateAnimation() {
    _updateAnimation();
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
    
    // Apply movement with smooth interpolation
    if (!velocity.isZero()) {
      // Store current position for interpolation
      if (_interpolationStart == null) {
        _interpolationStart = position.clone();
        _interpolationTime = 0.0;
      }
      
      // Update position
      position += velocity * dt;
      _interpolationTime += dt;
      
      // Broadcast position with rate limiting
      _broadcastPosition();
    } else {
      // Reset interpolation when stopped
      _interpolationStart = null;
      _interpolationTime = 0.0;
    }
    
    // Update animation based on current movement
    _updateAnimation();
  }
  
  void _broadcastPosition() {
    final now = DateTime.now();
    if (_lastPositionBroadcast != null) {
      final timeSinceLastBroadcast = now.difference(_lastPositionBroadcast!).inMilliseconds / 1000.0;
      if (timeSinceLastBroadcast < _broadcastInterval) {
        return; // Skip this broadcast
      }
    }
    _lastPositionBroadcast = now;
    
    // Get animation state for broadcast
    String? animationState;
    switch (currentDirection) {
      case PlayerDirection.up:
        animationState = 'up';
        break;
      case PlayerDirection.down:
        animationState = 'down';
        break;
      case PlayerDirection.left:
        animationState = 'left';
        break;
      case PlayerDirection.right:
        animationState = 'right';
        break;
      case PlayerDirection.idle:
        animationState = 'idle';
        break;
    }
    
    onPositionChanged?.call(position, animationState: animationState);
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
  
  // Smooth movement to target position (for multiplayer)
  void moveToPosition(Vector2 targetPosition) {
    _targetPosition = targetPosition;
    _interpolationStart = position.clone();
    _interpolationTime = 0.0;
  }
  
  // Get predicted position based on current velocity
  Vector2 getPredictedPosition(double predictionTime) {
    if (velocity.isZero()) return position;
    return position + velocity * predictionTime;
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

  /// Get whether the player is using a custom spritesheet
  bool get isUsingCustomSpritesheet => _customSpritesheetLoaded;
  
  /// Get the custom spritesheet URL
  String? get customSpritesheetUrl => _customSpritesheetUrl;
} 