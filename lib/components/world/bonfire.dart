import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/timer.dart';
import 'package:flutter/material.dart';
import 'package:lovenest/components/world/fire_effect.dart';
import 'package:flame/collisions.dart';

class Bonfire extends PositionComponent with TapCallbacks {
  final double maxWoodCapacity;
  final double woodBurnRate;
  final double maxFlameSize;
  final double maxIntensity;

  double _currentWood = 0;
  double _flameSize = 0; // reserved for future sprite scaling
  double _intensity = 0;
  bool _isLit = false;
  double _time = 0; // animation time accumulator

  Timer? _burnTimer;
  Timer? _animationTimer;
  FireEffect? _fireEffect;
  SpriteComponent? _bonfireSprite;

  Bonfire({
    super.position,
    super.size,
    required this.maxWoodCapacity,
    required this.woodBurnRate,
    required this.maxFlameSize,
    required this.maxIntensity,
  });

  double get currentWood => _currentWood;
  double get intensity => _intensity;
  bool get isLit => _isLit;
  double get woodPercentage => _currentWood / maxWoodCapacity;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    // Enable tap hit-testing across the bonfire's bounds
    add(RectangleHitbox());

    // Load bonfire.png sprite (just the wood)
    final sprite = await Sprite.load('bonfire.png');
    _bonfireSprite = SpriteComponent(
      sprite: sprite,
      size: Vector2(32, 32), // 32x32 to match new asset
      anchor: Anchor.center,
      position: Vector2(size.x / 2, size.y * 0.8), // Place at base
    );
    add(_bonfireSprite!);

    // Create fire effect component (flame on top)
    _fireEffect = FireEffect(
      position: Vector2(0, 0),
      size: Vector2(size.x, size.y),
    );
    add(_fireEffect!);

    // Timer for burning wood
    _burnTimer = Timer(
      1.0, // Update every second
      onTick: () {
        if (_isLit && _currentWood > 0) {
          _currentWood = (_currentWood - woodBurnRate).clamp(0, maxWoodCapacity);
          _updateFlame();

          if (_currentWood <= 0) {
            _extinguish();
          }
        }
      },
      repeat: true,
    );

    // Timer for flame animation
    _animationTimer = Timer(
      0.016, // 60 FPS
      onTick: () {
        _time += 0.016;
        _updateFireEffect();
      },
      repeat: true,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _burnTimer?.update(dt);
    _animationTimer?.update(dt);
  }

  @override
  void render(Canvas canvas) {
    // No custom base/wood drawing; handled by bonfire.png sprite
    // Only draw wood indicator if desired (optional)
    _drawWoodIndicator(canvas);
  }

  void _drawWoodIndicator(Canvas canvas) {
    final indicatorWidth = size.x * 0.8;
    final indicatorHeight = 4;
    final indicatorX = (size.x - indicatorWidth) / 2;
    final indicatorY = size.y - 8;

    // Background
    final bgPaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(indicatorX, indicatorY, indicatorWidth, indicatorHeight.toDouble()),
        const Radius.circular(2),
      ),
      bgPaint,
    );

    // Wood level
    final woodPaint = Paint()
      ..color = Colors.orange.shade600
      ..style = PaintingStyle.fill;

    final woodWidth = indicatorWidth * woodPercentage;
    if (woodWidth > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(indicatorX, indicatorY, woodWidth, indicatorHeight.toDouble()),
          const Radius.circular(2),
        ),
        woodPaint,
      );
    }
  }

  void addWood(double amount) {
    _currentWood = (_currentWood + amount).clamp(0, maxWoodCapacity);
    _updateFlame();

    if (_currentWood > 0 && !_isLit) {
      _light();
    }
  }

  void _light() {
    _isLit = true;
    _updateFlame();
  }

  void _extinguish() {
    _isLit = false;
    _flameSize = 0;
    _intensity = 0;
    _updateFireEffect();
  }

  void _updateFlame() {
    if (!_isLit || _currentWood <= 0) {
      _flameSize = 0;
      _intensity = 0;
    } else {
      // Flame size and intensity based on wood amount
      final woodRatio = _currentWood / maxWoodCapacity;
      _flameSize = maxFlameSize * woodRatio;
      _intensity = maxIntensity * woodRatio;
    }

    _updateFireEffect();
  }

  void _updateFireEffect() {
    if (_fireEffect != null) {
      _fireEffect!.setFireIntensity(_intensity);
    }
  }

  @override
  bool onTapDown(TapDownEvent event) {
    // Delegate to external interaction if provided
    if (_interactionCallback != null) {
      _interactionCallback!.call();
    } else {
      // Default behavior: simple interaction
      _showInteractionDialog();
    }
    return true;
  }

  void _showInteractionDialog() {
    // This will be handled by the game screen
    // For now, we'll just add some wood when tapped
    addWood(2);
  }

  /// Set callback for interaction dialog
  void setInteractionCallback(Function()? callback) {
    _interactionCallback = callback;
  }

  Function()? _interactionCallback;

  @override
  void onRemove() {
    _burnTimer?.stop();
    _animationTimer?.stop();
    super.onRemove();
  }
} 