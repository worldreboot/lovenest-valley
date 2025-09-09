import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';

class OwlNpcComponent extends SpriteComponent with TapCallbacks {
  final void Function()? onTapOwl;
  final Sprite idleSprite;
  final Sprite notificationSprite;
  bool _showNotification = false;
  SpriteComponent? _notificationIndicator;

  OwlNpcComponent({
    required this.idleSprite,
    required this.notificationSprite,
    required Vector2 position,
    required Vector2 size,
    this.onTapOwl,
  }) : super(sprite: idleSprite, position: position, size: size) {
    // Initial priority; will be adjusted dynamically by Y-sort in update()
    priority = 10;
    debugPrint('[OwlNpcComponent] 🦉 Owl created at position $position with size $size and priority $priority');
  }

  void showNotification(bool show) {
    _showNotification = show;
    
    if (show) {
      // Create notification indicator if it doesn't exist
      if (_notificationIndicator == null) {
        _notificationIndicator = SpriteComponent(
          sprite: notificationSprite,
          position: Vector2(size.x / 2 - 12, -20), // Centered above the owl's head
          size: Vector2(24, 24), // Smaller size for the notification icon
        );
        add(_notificationIndicator!);
        
        // Add smooth hovering animation
        _startHoverAnimation();
      }
    } else {
      // Remove notification indicator if it exists
      if (_notificationIndicator != null) {
        _notificationIndicator!.removeFromParent();
        _notificationIndicator = null;
      }
    }
  }

  void _startHoverAnimation() {
    if (_notificationIndicator != null) {
      // Create a smooth up-and-down floating motion that loops
      final hoverEffect = SequenceEffect([
        MoveByEffect(
          Vector2(0, -3), // Move up by 3 pixels
          EffectController(duration: 1.0, curve: Curves.easeInOut),
        ),
        MoveByEffect(
          Vector2(0, 3), // Move back down by 3 pixels
          EffectController(duration: 1.0, curve: Curves.easeInOut),
        ),
      ]);
      
      // Add the effect and make it repeat by re-adding it when it completes
      _notificationIndicator!.add(hoverEffect);
      
      // Set up a timer to restart the animation when it completes
      hoverEffect.onComplete = () {
        if (_notificationIndicator != null && _showNotification) {
          _startHoverAnimation();
        }
      };
    }
  }

  @override
  bool onTapDown(TapDownEvent event) {
    debugPrint('[OwlNpcComponent] 🦉 Owl tapped at ${event.canvasPosition}');
    debugPrint('[OwlNpcComponent] 🦉 Owl position: $position, size: $size');
    debugPrint('[OwlNpcComponent] 🦉 Owl priority: $priority');
    debugPrint('[OwlNpcComponent] 🦉 onTapOwl callback exists: ${onTapOwl != null}');
    debugPrint('[OwlNpcComponent] 🦉 Tap event device position: ${event.devicePosition}');
    debugPrint('[OwlNpcComponent] 🦉 Tap event canvas position: ${event.canvasPosition}');
    
    // Check if the tap is within the owl's bounds
    final tapInBounds = event.canvasPosition.x >= position.x && 
                       event.canvasPosition.x <= position.x + size.x &&
                       event.canvasPosition.y >= position.y && 
                       event.canvasPosition.y <= position.y + size.y;
    debugPrint('[OwlNpcComponent] 🦉 Tap within owl bounds: $tapInBounds');
    
    if (onTapOwl != null) {
      debugPrint('[OwlNpcComponent] 🦉 Calling onTapOwl callback');
      onTapOwl?.call();
    } else {
      debugPrint('[OwlNpcComponent] 🦉 WARNING: onTapOwl callback is null!');
    }
    
    return true; // Return true to indicate we handled the tap
  }

  @override
  void update(double dt) {
    super.update(dt);
    // Dynamic Y-sort: objects with greater screen Y render above
    final baselineY = position.y + size.y;
    priority = 1000 + baselineY.toInt();
  }
} 
