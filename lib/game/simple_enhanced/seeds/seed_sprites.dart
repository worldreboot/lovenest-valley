import 'package:flame/cache.dart' show Images;
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';
import 'package:flame/components.dart' show Vector2;

class SeedSpriteManager {
  bool _seedSpritesLoaded = false;
  late SpriteSheet _cropsSpriteSheet;
  late Sprite _defaultSeedSprite;

  Future<void> initialize(Images images) async {
    if (_seedSpritesLoaded) return;
    try {
      debugPrint('[SeedSpriteManager] 🔄 Initializing seed sprites...');
      // Flame's Images loader prefixes paths with 'assets/images/',
      // so we pass the path relative to that prefix.
      final cropsPath = 'V1.5/Farm Expansion/Crops/crops 16x16.png';
      debugPrint('[SeedSpriteManager] 📦 Loading crops spritesheet: $cropsPath');
      final cropsImage = await images.load(cropsPath);
      _cropsSpriteSheet = SpriteSheet(image: cropsImage, srcSize: Vector2.all(16.0));
      _defaultSeedSprite = _cropsSpriteSheet.getSpriteById(3);
      _seedSpritesLoaded = true;
      debugPrint('[SeedSpriteManager] ✅ Seed sprites initialized');
    } catch (_) {
      // Fallback to the default seeds icon using Flame's prefix
      final fallbackPath = 'items/seeds.png';
      debugPrint('[SeedSpriteManager] ⚠️ Crops spritesheet failed, loading fallback: $fallbackPath');
      final seedImage = await images.load(fallbackPath);
      _defaultSeedSprite = Sprite(seedImage);
      _seedSpritesLoaded = true;
      debugPrint('[SeedSpriteManager] ✅ Fallback seed sprite loaded');
    }
  }

  Future<Sprite> getPlantSprite(
    Images images,
    String seedId,
    String growthStage,
    Color? seedColor,
  ) async {
    debugPrint('[SeedSpriteManager] 🔍 getPlantSprite seedId=$seedId stage=$growthStage');
    await initialize(images);
    // Use the same, known-visible mapping for both regular and daily seeds
    switch (growthStage) {
      case 'planted':
        debugPrint('[SeedSpriteManager] 🎨 Using planted sprite (default)');
        return _cropsSpriteSheet.getSpriteById(3);
      case 'growing':
        debugPrint('[SeedSpriteManager] 🎨 Using growing sprite (id 11)');
        return _cropsSpriteSheet.getSpriteById(11);
      case 'fully_grown':
        debugPrint('[SeedSpriteManager] 🎨 Using fully grown sprite (id 19)');
        return _cropsSpriteSheet.getSpriteById(19);
      default:
        debugPrint('[SeedSpriteManager] 🎨 Fallback to default seed sprite');
        return _defaultSeedSprite;
    }
  }
}


