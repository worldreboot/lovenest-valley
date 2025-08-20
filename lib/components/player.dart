import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:lovenest/services/avatar_generation_service.dart';
import 'package:lovenest/config/supabase_config.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:typed_data';
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
  
  // Static directional sprites (first frame of each animation)
  late Sprite upSprite;
  late Sprite downSprite;
  late Sprite leftSprite;
  late Sprite rightSprite;
  late Sprite idleSprite;
  
  // Store the spriteSheet image for creating static animations
  late ui.Image spriteSheetImage;
  
  PlayerDirection currentDirection = PlayerDirection.idle;
  
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
  
  // Flag to disable automatic animation updates during actions
  bool _disableAutoAnimation = false;
  
  // Flag to disable keyboard input during actions (like hoe animation)
  bool _disableKeyboardInput = false;
  
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
    // Optimize pixel-art sampling
    paint.filterQuality = FilterQuality.none;
    
    // Set initial animation to idle (down-facing)
    animation = idleAnimation;
    
    add(RectangleHitbox());
  }

  Future<void> _loadAnimations() async {
    // Try to load a normalized/custom spritesheet from Supabase first; fallback to bundled asset
    ui.Image spriteSheet;
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId != null) {
        final avatarService = AvatarGenerationService();
        final url = await avatarService.getSpritesheetUrl(userId);
        if (url != null && url.isNotEmpty) {
          // ignore: avoid_print
          print('[Player] Loading normalized/custom spritesheet from URL');
          if (url.startsWith('http')) {
            final resp = await http.get(Uri.parse(url));
            if (resp.statusCode == 200) {
              final bytes = resp.bodyBytes;
              // Decode via Flutter's image decoder (compatible with Flame 1.30.1)
              final completer = Completer<ui.Image>();
              ui.decodeImageFromList(Uint8List.fromList(bytes), (img) => completer.complete(img));
              spriteSheet = await completer.future;
            } else {
              // ignore: avoid_print
              print('[Player] Network load failed (${resp.statusCode}), falling back to asset');
              spriteSheet = await game.images.load('user.png');
            }
          } else {
            // Fallback for non-http keys (unlikely here)
            spriteSheet = await game.images.load(url);
          }
        } else {
          // ignore: avoid_print
          print('[Player] No custom spritesheet URL found; using default asset');
          spriteSheet = await game.images.load('user.png');
        }
      } else {
        // ignore: avoid_print
        print('[Player] No authenticated user; using default asset');
        spriteSheet = await game.images.load('user.png');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Player] Failed to load custom spritesheet, falling back. Error: $e');
      spriteSheet = await game.images.load('user.png');
    }
    spriteSheetImage = spriteSheet; // Store the image for static animations
    
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
    
    // Load static directional sprites (first frame of each animation)
    upSprite = Sprite(spriteSheet, srcPosition: Vector2(0, 0), srcSize: Vector2(frameWidth, frameHeight));
    rightSprite = Sprite(spriteSheet, srcPosition: Vector2(0, frameHeight), srcSize: Vector2(frameWidth, frameHeight));
    downSprite = Sprite(spriteSheet, srcPosition: Vector2(0, frameHeight * 2), srcSize: Vector2(frameWidth, frameHeight));
    leftSprite = Sprite(spriteSheet, srcPosition: Vector2(0, frameHeight), srcSize: Vector2(frameWidth, frameHeight)); // Same as right, will be flipped
    idleSprite = Sprite(spriteSheet, srcPosition: Vector2(0, frameHeight * 2), srcSize: Vector2(frameWidth, frameHeight)); // Same as down
  }

  void _updateAnimation() {
    // Skip automatic animation updates if disabled
    if (_disableAutoAnimation) {
      return;
    }
    
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
  
  // Public method to disable automatic animation updates
  void disableAutoAnimation() {
    _disableAutoAnimation = true;
  }
  
  // Public method to enable automatic animation updates
  void enableAutoAnimation() {
    _disableAutoAnimation = false;
  }
  
  // Public method to disable keyboard input
  void disableKeyboardInput() {
    _disableKeyboardInput = true;
  }
  
  // Public method to enable keyboard input
  void enableKeyboardInput() {
    _disableKeyboardInput = false;
  }
  
  // Public method to set player direction manually
  void setDirection(PlayerDirection direction) {
    currentDirection = direction;
    
    switch (currentDirection) {
      case PlayerDirection.up:
        animation = SpriteAnimation.fromFrameData(
          spriteSheetImage,
          SpriteAnimationData.sequenced(
            amount: 1,
            stepTime: 1.0,
            textureSize: upSprite.srcSize,
            texturePosition: upSprite.srcPosition,
          ),
        );
        scale.x = 1; // Normal orientation
        break;
      case PlayerDirection.down:
        animation = SpriteAnimation.fromFrameData(
          spriteSheetImage,
          SpriteAnimationData.sequenced(
            amount: 1,
            stepTime: 1.0,
            textureSize: downSprite.srcSize,
            texturePosition: downSprite.srcPosition,
          ),
        );
        scale.x = 1; // Normal orientation
        break;
      case PlayerDirection.left:
        animation = SpriteAnimation.fromFrameData(
          spriteSheetImage,
          SpriteAnimationData.sequenced(
            amount: 1,
            stepTime: 1.0,
            textureSize: leftSprite.srcSize,
            texturePosition: leftSprite.srcPosition,
          ),
        );
        scale.x = -1; // Flip horizontally
        break;
      case PlayerDirection.right:
        animation = SpriteAnimation.fromFrameData(
          spriteSheetImage,
          SpriteAnimationData.sequenced(
            amount: 1,
            stepTime: 1.0,
            textureSize: rightSprite.srcSize,
            texturePosition: rightSprite.srcPosition,
          ),
        );
        scale.x = 1; // Normal orientation
        break;
      case PlayerDirection.idle:
        animation = SpriteAnimation.fromFrameData(
          spriteSheetImage,
          SpriteAnimationData.sequenced(
            amount: 1,
            stepTime: 1.0,
            textureSize: idleSprite.srcSize,
            texturePosition: idleSprite.srcPosition,
          ),
        );
        scale.x = 1; // Normal orientation
        break;
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
    // Disable keyboard input if flag is set
    if (_disableKeyboardInput) {
      return KeyEventResult.ignored;
    }
    
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
} 