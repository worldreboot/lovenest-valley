import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

enum TileType {
  grass,
  tilled,
  crop,
  water,
  tree,
  wood,
  grassSand, // grass to sand transition
  sand,      // sand fill
}

class FarmTile extends PositionComponent {
  final TileType tileType;
  final String? growthStage;
  final String? plantType;
  final bool? isWatered; // Add watering state
  static const double tileSize = 32.0;
  static SpriteSheet? _groundSheet;
  static SpriteSheet? _woodSheet;
  static Sprite? _grassSandSprite;
  static Sprite? _sandSprite;
  static Sprite? _waterSprite;
  static bool _isLoading = false;

  FarmTile(Vector2 position, this.tileType, {this.growthStage, this.plantType, this.isWatered})
      : super(position: position, size: Vector2.all(tileSize));

  static Future<void> loadTileSheets() async {
    if (_isLoading) {
      // Wait for existing load to complete
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
      return;
    }
    
    if (_groundSheet != null && _woodSheet != null && _grassSandSprite != null && _sandSprite != null && _waterSprite != null) {
      return; // Already loaded
    }
    
    _isLoading = true;
    try {
      debugPrint('[FarmTile] Loading tile sheets...');
      if (_groundSheet == null) {
        debugPrint('[FarmTile] Loading ground.png...');
        final image = await Flame.images.load('ground.png');
        _groundSheet = SpriteSheet(image: image, srcSize: Vector2(48, 48));
        debugPrint('[FarmTile] Ground sheet loaded successfully');
      }
      if (_woodSheet == null) {
        debugPrint('[FarmTile] Loading wood.png...');
        final image = await Flame.images.load('wood.png');
        _woodSheet = SpriteSheet(image: image, srcSize: Vector2(48, 48));
        debugPrint('[FarmTile] Wood sheet loaded successfully');
      }
      if (_grassSandSprite == null) {
        debugPrint('[FarmTile] Loading grass_sand.png...');
        final image = await Flame.images.load('grass_sand.png');
        _grassSandSprite = Sprite(image);
      }
      if (_sandSprite == null) {
        debugPrint('[FarmTile] Loading sand_fill.png...');
        final image = await Flame.images.load('sand_fill.png');
        _sandSprite = Sprite(image);
      }
      if (_waterSprite == null) {
        debugPrint('[FarmTile] Loading water_still.png...');
        final image = await Flame.images.load('water_still.png');
        _waterSprite = Sprite(image);
        debugPrint('[FarmTile] Water sprite loaded successfully: ${_waterSprite != null}');
      }
      debugPrint('[FarmTile] All tile sheets loaded');
    } catch (e) {
      debugPrint('Error loading tile sheets: $e');
    } finally {
      _isLoading = false;
    }
  }

  @override
  Future<void> onLoad() async {
    await loadTileSheets();
    super.onLoad();
  }

  @override
  void render(Canvas canvas) {
    Sprite? sprite;
    
    // Debug: Log what tile type we're rendering
    // if (tileType == TileType.water) {
    //   debugPrint('[FarmTile] Rendering WATER tile at position ${position.x}, ${position.y}');
    // }
    
    // Ensure sprites are loaded before trying to render
    if (_groundSheet == null || _woodSheet == null || _grassSandSprite == null || _sandSprite == null || _waterSprite == null) {
      // Fallback rendering while sprites are loading
      debugPrint('[FarmTile] Using fallback color for $tileType - sprites not loaded yet');
      final paint = Paint()..color = _getFallbackColor();
      canvas.drawRect(size.toRect(), paint);
      return;
    }
    
    // Map tileType to tile index in ground.png or use custom sprites
    try {
      if (tileType == TileType.grass) {
        sprite = _groundSheet?.getSprite(0, 0);
      } else if (tileType == TileType.tilled) {
        sprite = _groundSheet?.getSprite(0, 1);
      } else if (tileType == TileType.crop) {
        // Handle different growth stages for crops
        if (growthStage == 'fully_grown') {
          sprite = _groundSheet?.getSprite(2, 0); // Fully grown sprite
        } else {
          // Check watering state for planted crops
          if (isWatered == true) {
            sprite = _groundSheet?.getSprite(1, 1); // Watered crop sprite
          } else {
            sprite = _groundSheet?.getSprite(1, 0); // Unwatered crop sprite
          }
        }
      } else if (tileType == TileType.water) {
        sprite = _waterSprite;
        // debugPrint('[FarmTile] Rendering water tile - sprite: ${sprite != null ? "loaded" : "null"}');
      } else if (tileType == TileType.tree) {
        sprite = _groundSheet?.getSprite(2, 1); // Use a tree/obstacle tile from ground.png
      } else if (tileType == TileType.wood) {
        sprite = _woodSheet?.getSprite(0, 1);
      } else if (tileType == TileType.grassSand) {
        sprite = _grassSandSprite;
      } else if (tileType == TileType.sand) {
        sprite = _sandSprite;
      }
      
      if (sprite != null) {
        sprite.renderRect(canvas, size.toRect());
      } else {
        // Fallback if sprite is null
        debugPrint('[FarmTile] Sprite is null for $tileType, using fallback color');
        final paint = Paint()..color = _getFallbackColor();
        canvas.drawRect(size.toRect(), paint);
      }
    } catch (e) {
      debugPrint('Error rendering tile $tileType: $e');
      // Fallback rendering on error
      final paint = Paint()..color = _getFallbackColor();
      canvas.drawRect(size.toRect(), paint);
    }
  }
  
  Color _getFallbackColor() {
    switch (tileType) {
      case TileType.grass:
        return Colors.green;
      case TileType.tilled:
        return Colors.brown;
      case TileType.crop:
        // Different colors for watered vs unwatered crops
        if (isWatered == true) {
          return Colors.lightBlue; // Watered crop color
        } else {
          return Colors.lightGreen; // Unwatered crop color
        }
      case TileType.water:
        return Colors.blue;
      case TileType.tree:
        return Colors.green[900]!;
      case TileType.wood:
        return Colors.brown[600]!;
      case TileType.grassSand:
        return Colors.yellow;
      case TileType.sand:
        return Colors.brown;
    }
  }
} 