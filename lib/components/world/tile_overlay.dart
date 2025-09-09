import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

enum TileOverlayType {
  tilled,
  planted,
  watered,
  grown,
}

class TileOverlay extends PositionComponent {
  final TileOverlayType type;
  final String? plantType;
  final String? growthStage;
  final bool isWatered;
  
  static Sprite? _tilledSprite;
  static Sprite? _plantedSprite;
  static Sprite? _wateredSprite;
  static Sprite? _grownSprite;
  static bool _isLoading = false;

  TileOverlay({
    required Vector2 position,
    required Vector2 size,
    required this.type,
    this.plantType,
    this.growthStage,
    this.isWatered = false,
  }) : super(position: position, size: size);

  static Future<void> loadSprites() async {
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return;
    }
    
    if (_tilledSprite != null && _plantedSprite != null && _wateredSprite != null && _grownSprite != null) {
      return; // Already loaded
    }
    
    _isLoading = true;
    try {
      debugPrint('[TileOverlay] Loading overlay sprites...');
      
      // Load sprites for different tile states
      // For now, we'll use colored rectangles as placeholders
      // In the future, you can load actual sprite images
      
      debugPrint('[TileOverlay] All overlay sprites loaded');
    } catch (e) {
      debugPrint('[TileOverlay] Error loading sprites: $e');
    } finally {
      _isLoading = false;
    }
  }

  @override
  Future<void> onLoad() async {
    await loadSprites();
    super.onLoad();
  }

  @override
  void render(Canvas canvas) {
    // Render the appropriate overlay based on type
    final paint = Paint();
    
    switch (type) {
      case TileOverlayType.tilled:
        paint.color = const Color(0xFF8B4513); // Brown for tilled soil
        break;
      case TileOverlayType.planted:
        paint.color = const Color(0xFF228B22); // Green for planted
        break;
      case TileOverlayType.watered:
        paint.color = const Color(0xFF4169E1); // Blue for watered
        break;
      case TileOverlayType.grown:
        paint.color = const Color(0xFF32CD32); // Lime green for grown
        break;
    }
    
    // Add some transparency
    paint.color = paint.color.withOpacity(0.7);
    
    // Draw the overlay
    canvas.drawRect(size.toRect(), paint);
    
    // Add a border to make it more visible
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawRect(size.toRect(), borderPaint);
    
    // Add text label for debugging
    final textPainter = TextPainter(
      text: TextSpan(
        text: type.name.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.x - textPainter.width) / 2,
        (size.y - textPainter.height) / 2,
      ),
    );
  }
} 
