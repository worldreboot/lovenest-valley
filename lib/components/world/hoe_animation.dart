import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame/timer.dart';
import 'package:flutter/material.dart';

class HoeAnimation extends PositionComponent {
  late SpriteAnimationComponent _animationComponent;
  late Timer _durationTimer;
  
  // Animation properties
  static const double animationDuration = 1.0; // 1 second
  static const int frameCount = 6; // 6 frames per row
  static const double frameTime = animationDuration / frameCount;
  
  // Swing direction (0 = right, 1 = front, 2 = behind)
  final int swingDirection;
  final bool shouldFlip; // Whether to flip the animation horizontally
  final VoidCallback? onAnimationComplete; // Callback when animation finishes
  
  HoeAnimation({
    required Vector2 position,
    required Vector2 size,
    this.swingDirection = 1, // Default to front swing
    this.shouldFlip = false, // Default to no flip
    this.onAnimationComplete, // Optional callback when animation completes
  }) : super(position: position, size: size);

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Load the hoe spritesheet
    await _loadHoeAnimation();
    
    // Set up timer to remove the animation after completion
    _durationTimer = Timer(animationDuration, onTick: () {
      // Call the completion callback if provided
      onAnimationComplete?.call();
      removeFromParent();
    });
  }

  Future<void> _loadHoeAnimation() async {
    try {
      // Load the Iron_Hoe.png spritesheet
      final gameInstance = findGame();
      if (gameInstance == null) {
        debugPrint('[HoeAnimation] ❌ Game instance not found');
        _createFallbackAnimation();
        return;
      }
      
      final spriteSheet = await gameInstance.images.load('animations/Iron_Hoe.png');
      
      // Create sprite sheet with 6 columns and 3 rows, each frame is 48x48
      final spriteSheetComponent = SpriteSheet(
        image: spriteSheet,
        srcSize: Vector2(48, 48), // Each sprite is 48x48
      );
      
      // Create frames for the specified swing direction
      final frames = <Sprite>[];
      debugPrint('[HoeAnimation] Loading frames for swing direction: $swingDirection');
      debugPrint('[HoeAnimation] Spritesheet dimensions: ${spriteSheet.width}x${spriteSheet.height}');
      debugPrint('[HoeAnimation] Frame size: 48x48');
      debugPrint('[HoeAnimation] Expected grid: 6 columns x 3 rows');
      
      for (int i = 0; i < frameCount; i++) {
        // Get sprite from the specified row (swingDirection) and column (i)
        final sprite = spriteSheetComponent.getSprite(swingDirection, i);
        frames.add(sprite);
        
        // Log the frame position for debugging
        final column = i;
        final row = swingDirection;
        final frameX = column * 48;
        final frameY = row * 48;
        debugPrint('[HoeAnimation] Frame $i: column: $column, row: $row at position (${frameX}, ${frameY}) in spritesheet');
      }
      
      debugPrint('[HoeAnimation] Loaded ${frames.length} frames for direction $swingDirection');
      
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
        debugPrint('[HoeAnimation] Applied horizontal flip for left swing');
      }
      
      debugPrint('[HoeAnimation] ✅ Loaded hoe animation for direction: $swingDirection (size: ${spriteSize.x}x${spriteSize.y})');
    } catch (e) {
      debugPrint('[HoeAnimation] ❌ Error loading hoe spritesheet: $e');
      // Fallback to simple colored rectangle if sprite loading fails
      _createFallbackAnimation();
    }
  }

  void _createFallbackAnimation() {
    // Create a simple fallback animation using colored rectangles
    debugPrint('[HoeAnimation] Using fallback animation');
    
    // For now, just create a simple colored rectangle component
    // This will show a brown rectangle as a placeholder
    final fallbackComponent = RectangleComponent(
      size: size,
      paint: Paint()..color = const Color(0xFF8B4513),
    );
    
    add(fallbackComponent);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _durationTimer.update(dt);
  }

  Color _getHoeColor(int frameIndex) {
    // Different colors for different animation frames
    switch (frameIndex) {
      case 0:
        return const Color(0xFF8B4513); // Brown - hoe handle
      case 1:
        return const Color(0xFFD2691E); // Orange - hoe in motion
      case 2:
        return const Color(0xFFCD853F); // Tan - hoe hitting ground
      case 3:
        return const Color(0xFF654321); // Dark brown - final position
      case 4:
        return const Color(0xFF8B7355); // Light brown - recovery
      case 5:
        return const Color(0xFF8B4513); // Brown - back to start
      default:
        return Colors.brown;
    }
  }
} 