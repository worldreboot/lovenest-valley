import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:lovenest_valley/components/world/relationship_bonfire.dart';
import 'package:lovenest_valley/game/base/game_with_grid.dart';
import 'dart:async';

/// Screen-space overlay that renders additive lights for emissive objects
/// (e.g., bonfires) so they brighten the scene even during nighttime.
///
/// Add this to the camera viewport so it renders above world contents and
/// the day/night color-grading overlay.
class LightOverlay extends PositionComponent with HasGameRef<GameWithGrid> {
  LightOverlay({
    required this.tileSize,
  }) : super(priority: 100010);

  /// Base tile size for consistent light radii across maps
  final double tileSize;
  /// Current time of day (0..1, where 0 = 00:00, 0.5 = noon)
  double _currentTime01 = 0.0;
  Timer? _timeUpdateTimer;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Start covering the whole viewport; kept in sync via onGameResize
    size = gameRef.camera.viewport.size;
    position = Vector2.zero();
    anchor = Anchor.topLeft;
    
    // Start updating time every second
    _timeUpdateTimer = Timer(1.0, onTick: () {
      _updateCurrentTime();
    }, repeat: true);
    _updateCurrentTime();
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    size = gameSize;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _timeUpdateTimer?.update(dt);
  }

  void _updateCurrentTime() {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute + now.second / 60.0;
    _currentTime01 = (minutes / 1440.0).clamp(0.0, 1.0);
  }

  /// Check if it's currently nighttime (when lights should be visible)
  bool get _isNightTime {
    // Night: 21:00 (9 PM) to 06:00 (6 AM)
    // Dusk: 19:00 (7 PM) to 21:00 (9 PM) - gradual fade in
    // Dawn: 06:00 (6 AM) to 08:00 (8 AM) - gradual fade out
    const double T_19 = 19.0 / 24.0;  // Dusk starts at 7:00 PM
    const double T_21 = 21.0 / 24.0;  // Night starts at 9:00 PM
    const double T_06 = 6.0 / 24.0;   // Dawn starts at 6:00 AM
    const double T_08 = 8.0 / 24.0;   // Day starts at 8:00 AM
    
    final t = _currentTime01;
    final night = (t >= T_21) || (t < T_06);
    final dusk = (t >= T_19 && t < T_21);
    final dawn = (t >= T_06 && t < T_08);
    
    return night || dusk || dawn;
  }

  /// Get the current light intensity multiplier based on time of day
  double get _timeBasedIntensity {
    if (!_isNightTime) return 0.0; // No lights during day
    
    const double T_19 = 19.0 / 24.0;
    const double T_21 = 21.0 / 24.0;
    const double T_06 = 6.0 / 24.0;
    const double T_08 = 8.0 / 24.0;
    
    final t = _currentTime01;
    
    if (t >= T_21 || t < T_06) {
      return 1.0; // Full intensity at night
    } else if (t >= T_19 && t < T_21) {
      // Dusk transition: fade in from 0 to 1
      final dusk01 = (t - T_19) / (T_21 - T_19);
      return dusk01;
    } else if (t >= T_06 && t < T_08) {
      // Dawn transition: fade out from 1 to 0
      final dawn01 = (t - T_06) / (T_08 - T_06);
      return 1.0 - dawn01;
    }
    
    return 0.0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // Only show lights during night/dusk/dawn
    final timeMultiplier = _timeBasedIntensity;
    if (timeMultiplier <= 0.001) return;

    // Query relationship bonfires in the world and render additive radial lights
    final world = gameRef.world;
    final bonfires = world.children.whereType<RelationshipBonfire>();

    for (final rb in bonfires) {
      final intensity = rb.lightIntensity; // 0..1
      if (intensity <= 0.001) continue;

      // Convert bonfire world position to viewport (screen) coordinates
      final worldPos = rb.lightWorldPosition;
      final viewfinder = gameRef.camera.viewfinder;
      final zoom = viewfinder.zoom;
      final cameraCenter = viewfinder.position;
      final screenSize = gameRef.camera.viewport.size;
      final screenCenter = Vector2(screenSize.x / 2, screenSize.y / 2);
      final worldDelta = worldPos - cameraCenter;
      final screenPos = screenCenter + worldDelta * zoom;

      // Choose a significantly larger radius scaled by intensity
      final baseRadius = tileSize * 12.0; // ~12 tiles base radius
      final radius = baseRadius * (1.2 + 1.8 * intensity);
      
      // Apply time-based intensity multiplier
      final adjustedIntensity = intensity * timeMultiplier;

      // Build a warm radial gradient for the light
      final rect = Rect.fromCircle(center: Offset(screenPos.x, screenPos.y), radius: radius);
      final gradient = RadialGradient(
        colors: <Color>[
          // Hot core
          const Color(0xFFFFF6CC).withOpacity(1.00 * adjustedIntensity),
          const Color(0xFFFFD27A).withOpacity(0.85 * adjustedIntensity),
          const Color(0xFFFF9B3D).withOpacity(0.60 * adjustedIntensity),
          const Color(0xFFFF6B1A).withOpacity(0.30 * adjustedIntensity),
          // Fade to transparent at edges
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      );

      final paint = Paint()
        ..shader = gradient.createShader(rect)
        ..blendMode = BlendMode.plus; // Additive lighting

      canvas.drawCircle(Offset(screenPos.x, screenPos.y), radius, paint);
    }
  }

  @override
  void onRemove() {
    _timeUpdateTimer?.stop();
    super.onRemove();
  }
}


