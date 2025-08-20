import 'package:flame/flame.dart';
import 'package:flame/sprite.dart';
import 'package:flame/widgets.dart';
import 'package:flutter/material.dart';
import 'package:lovenest/game/simple_enhanced/seeds/seed_sprites.dart';

class SeedSpritePreview extends StatefulWidget {
  final String growthStage; // 'planted' | 'growing' | 'fully_grown'
  final double scale;

  const SeedSpritePreview({
    super.key,
    required this.growthStage,
    this.scale = 3.0,
  });

  @override
  State<SeedSpritePreview> createState() => _SeedSpritePreviewState();
}

class _SeedSpritePreviewState extends State<SeedSpritePreview> {
  late final SeedSpriteManager _manager;
  Future<Sprite>? _spriteFuture;

  @override
  void initState() {
    super.initState();
    _manager = SeedSpriteManager();
    _spriteFuture = _loadSprite();
  }

  Future<Sprite> _loadSprite() async {
    final sprite = await _manager.getPlantSprite(
      Flame.images,
      'regular_seed',
      widget.growthStage,
      null,
    );
    return sprite;
  }

  @override
  Widget build(BuildContext context) {
    final baseSize = 16.0 * widget.scale;
    return SizedBox(
      width: baseSize + 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Soil strip background
          Container(
            width: baseSize,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.brown.shade400,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.brown.shade600, width: 1),
            ),
          ),
          const SizedBox(height: 6),
          FutureBuilder<Sprite>(
            future: _spriteFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return SizedBox(
                  width: baseSize,
                  height: baseSize,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              if (!snapshot.hasData) {
                return SizedBox(
                  width: baseSize,
                  height: baseSize,
                  child: const Center(child: Icon(Icons.image_not_supported)),
                );
              }
              final sprite = snapshot.data!;
              return SizedBox(
                width: baseSize,
                height: baseSize,
                child: SpriteWidget(
                  sprite: sprite,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}


