import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../../models/memory_garden/seed.dart';

class PlotComponent extends RectangleComponent with TapCallbacks {
  final PlotPosition plotPosition;
  final Seed? seed;
  final VoidCallback onTap;
  
  static const double plotSize = 64.0;
  
  PlotComponent({
    required this.plotPosition,
    this.seed,
    required this.onTap,
  }) : super(
    size: Vector2.all(plotSize),
    paint: Paint()..color = const Color(0xFF8B4513), // Brown soil color
  );

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    // Position the plot in the garden grid
    position = Vector2(
      plotPosition.x * plotSize + 10, // 10px margin
      plotPosition.y * plotSize + 10,
    );
    
    // Add a border
    add(RectangleComponent(
      size: size,
      paint: Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFF654321),
    ));
    
    // Add the appropriate content based on seed state
    await _updateContent();
  }

  Future<void> _updateContent() async {
    // Clear existing content (except border)
    removeWhere((component) => component is! RectangleComponent);
    
    if (seed == null) {
      // Empty plot - show soil texture
      add(TextComponent(
        text: '🌱',
        position: Vector2(plotSize / 2 - 8, plotSize / 2 - 8),
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 16,
            color: Colors.brown,
          ),
        ),
      ));
    } else {
      // Add content based on seed state
      await _addSeedContent();
    }
  }

  Future<void> _addSeedContent() async {
    if (seed == null) return;
    
    switch (seed!.state) {
      case SeedState.sprout:
        add(SproutComponent(seed: seed!));
        break;
      case SeedState.wilted:
        add(WiltedComponent(seed: seed!));
        break;
      case SeedState.bloomStage1:
      case SeedState.bloomStage2:
      case SeedState.bloomStage3:
        add(BloomComponent(seed: seed!));
        break;
      case SeedState.archived:
        // Show faded bloom
        final bloom = BloomComponent(seed: seed!);
        bloom.add(OpacityEffect.to(0.5, EffectController(duration: 0.1)));
        add(bloom);
        break;
    }
  }

  @override
  bool onTapDown(TapDownEvent event) {
    onTap();
    return true;
  }

  void updateSeed(Seed? newSeed) {
    if (seed != newSeed) {
      // Update content when seed changes
      _updateContent();
    }
  }
}

class SproutComponent extends PositionComponent {
  final Seed seed;
  late final SpriteComponent sprite;
  
  SproutComponent({required this.seed});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    size = Vector2.all(PlotComponent.plotSize);
    
    // Create sprout sprite (for now using emoji, replace with actual sprites later)
    add(TextComponent(
      text: '🌱',
      position: Vector2(PlotComponent.plotSize / 2 - 16, PlotComponent.plotSize / 2 - 16),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 32,
        ),
      ),
    ));
    
    // Add shimmer effect for sprouts
    add(CircleComponent(
      radius: PlotComponent.plotSize / 4,
      position: Vector2(PlotComponent.plotSize / 2, PlotComponent.plotSize / 2),
      anchor: Anchor.center,
      paint: Paint()
        ..color = Colors.lightGreen.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    ));
  }
}

class BloomComponent extends PositionComponent {
  final Seed seed;
  
  BloomComponent({required this.seed});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    size = Vector2.all(PlotComponent.plotSize);
    
    // Different bloom appearance based on stage and media type
    String bloomEmoji = _getBloomEmoji();
    
    add(TextComponent(
      text: bloomEmoji,
      position: Vector2(PlotComponent.plotSize / 2 - 16, PlotComponent.plotSize / 2 - 16),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 32,
        ),
      ),
    ));
    
    // Add glow effect for higher stages
    if (seed.state == SeedState.bloomStage2 || seed.state == SeedState.bloomStage3) {
      add(CircleComponent(
        radius: PlotComponent.plotSize / 3,
        position: Vector2(PlotComponent.plotSize / 2, PlotComponent.plotSize / 2),
        anchor: Anchor.center,
        paint: Paint()
          ..color = Colors.yellow.withOpacity(0.4)
          ..style = PaintingStyle.fill,
      ));
    }
  }

  String _getBloomEmoji() {
    // Simple procedural generation based on media type and growth
    switch (seed.mediaType) {
      case MediaType.photo:
        return ['🌸', '🌺', '🌻'][seed.state.index % 3];
      case MediaType.voice:
        return ['🎵', '🎶', '🎼'][seed.state.index % 3];
      case MediaType.text:
        return ['📝', '📖', '✨'][seed.state.index % 3];
      case MediaType.link:
        return ['🔗', '🌐', '💫'][seed.state.index % 3];
    }
  }
}

class WiltedComponent extends PositionComponent {
  final Seed seed;
  
  WiltedComponent({required this.seed});

  @override
  Future<void> onLoad() async {
    super.onLoad();
    
    size = Vector2.all(PlotComponent.plotSize);
    
    add(TextComponent(
      text: '🥀',
      position: Vector2(PlotComponent.plotSize / 2 - 16, PlotComponent.plotSize / 2 - 16),
      textRenderer: TextPaint(
        style: const TextStyle(
          fontSize: 32,
          color: Colors.grey,
        ),
      ),
    ));
  }
} 
