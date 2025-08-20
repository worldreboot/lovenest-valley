import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame/timer.dart';
import 'package:flutter/material.dart';

class WateringCanAnimation extends PositionComponent {
  late SpriteAnimationComponent _animationComponent;
  late Timer _durationTimer;
  
  // Animation properties
  static const double animationDuration = 1.0; // 1 second
  static const int frameCount = 6; // 6 frames per row
  static const double frameTime = animationDuration / frameCount;
  
  // Watering direction (0 = right, 1 = front, 2 = behind)
  final int wateringDirection;
  final bool shouldFlip; // Whether to flip the animation horizontally
  final VoidCallback? onAnimationComplete; // Callback when animation finishes
  
  WateringCanAnimation({
    required Vector2 position,
    required Vector2 size,
    this.wateringDirection = 1, // Default to front watering
    this.shouldFlip = false, // Default to no flip
    this.onAnimationComplete, // Optional callback when animation completes
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Load the watering can spritesheet
    await _loadWateringCanAnimation();
    
    // Set up timer to remove the animation after completion
    _durationTimer = Timer(animationDuration, onTick: () {
      // Call the completion callback if provided
      onAnimationComplete?.call();
      removeFromParent();
    });
  }

  Future<void> _loadWateringCanAnimation() async {
    try {
      // Load the Iron_WateringCan.png spritesheet
      final gameInstance = findGame();
      if (gameInstance == null) {
        debugPrint('[WateringCanAnimation] ❌ Game instance not found');
        _createFallbackAnimation();
        return;
      }
      
      final spriteSheet = await gameInstance.images.load('animations/Iron_WateringCan.png');
      
      // Create sprite sheet with 6 columns and 3 rows, each frame is 48x48
      final spriteSheetComponent = SpriteSheet(
        image: spriteSheet,
        srcSize: Vector2(48, 48), // Each sprite is 48x48
      );
      
      // Create frames for the specified watering direction
      final frames = <Sprite>[];
      debugPrint('[WateringCanAnimation] Loading frames for watering direction: $wateringDirection');
      debugPrint('[WateringCanAnimation] Spritesheet dimensions: ${spriteSheet.width}x${spriteSheet.height}');
      debugPrint('[WateringCanAnimation] Frame size: 48x48');
      debugPrint('[WateringCanAnimation] Expected grid: 6 columns x 3 rows');
      
      for (int i = 0; i < frameCount; i++) {
        // Get sprite from the specified row (wateringDirection) and column (i)
        final sprite = spriteSheetComponent.getSprite(wateringDirection, i);
        frames.add(sprite);
        
        // Log the frame position for debugging
        final column = i;
        final row = wateringDirection;
        final frameX = column * 48;
        final frameY = row * 48;
        debugPrint('[WateringCanAnimation] Frame $i: column: $column, row: $row at position (${frameX}, ${frameY}) in spritesheet');
      }
      
      debugPrint('[WateringCanAnimation] Loaded ${frames.length} frames for direction $wateringDirection');
      
      // Create the animation
      final animation = SpriteAnimation.spriteList(
        frames,
        stepTime: frameTime,
      );
      
      // Use the actual sprite size (48x48) without additional scaling
      final spriteSize = Vector2(48, 48);
      
      _animationComponent = SpriteAnimationComponent(
        animation: animation,
        size: spriteSize,
        anchor: Anchor.center,
      );
      
      add(_animationComponent);
      
      // Apply horizontal flip if needed
      if (shouldFlip) {
        _animationComponent.flipHorizontally();
        debugPrint('[WateringCanAnimation] Applied horizontal flip for left watering');
      }
      
      debugPrint('[WateringCanAnimation] ✅ Loaded watering can animation for direction: $wateringDirection (size: ${spriteSize.x}x${spriteSize.y})');
    } catch (e) {
      debugPrint('[WateringCanAnimation] ❌ Error loading watering can spritesheet: $e');
      // Fallback to simple colored rectangle if sprite loading fails
      _createFallbackAnimation();
    }
  }

  void _createFallbackAnimation() {
    // Create a simple fallback animation using colored rectangles
    debugPrint('[WateringCanAnimation] Using fallback animation');
    
    // For now, just create a simple colored rectangle component
    // This will show a blue rectangle as a placeholder
    final fallbackComponent = RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFF4169E1),
    );
    
    add(fallbackComponent);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _durationTimer.update(dt);
  }

  Color _getWateringCanColor(int frameIndex) {
    // Different colors for different animation frames
    switch (frameIndex) {
      case 0:
        return const Color(0xFF4169E1); // Blue - watering can handle
      case 1:
        return const Color(0xFF1E90FF); // Dodger blue - watering can in motion
      case 2:
        return const Color(0xFF00BFFF); // Deep sky blue - water flowing
      case 3:
        return const Color(0xFF87CEEB); // Sky blue - water hitting ground
      case 4:
        return const Color(0xFFB0E0E6); // Powder blue - water settling
      case 5:
        return const Color(0xFF4169E1); // Blue - back to start
      default:
        return Colors.blue;
    }
  }
} 