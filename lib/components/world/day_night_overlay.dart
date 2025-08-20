import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Full-screen shader overlay that color-grades the world based on local time.
///
/// Timing (based on local device time):
/// - Night mode: 9:00 PM (21:00) to 6:00 AM (06:00) - Full darkness
/// - Dusk transition: 7:00 PM (19:00) to 9:00 PM (21:00) - Gradual fade from day to night
/// - Dawn transition: 6:00 AM (06:00) to 8:00 AM (08:00) - Gradual fade from night to day
/// - Day mode: 8:00 AM (08:00) to 7:00 PM (19:00) - No darkness effect
///
/// The fragment shader expects:
/// 0: resolution.x, 1: resolution.y, 2: u_time01 (0..1), 3: u_strength (0..1)
class DayNightOverlay extends PositionComponent {
  DayNightOverlay({
    super.position,
    super.size,
    this.maxNightStrength = 0.65,
    this.debugForceNight = false,
    this.debugForcedTime01,
  })  : assert(maxNightStrength >= 0.0 && maxNightStrength <= 1.0),
        super(priority: 100000);

  final double maxNightStrength;
  final bool debugForceNight;
  final double? debugForcedTime01; // if set, overrides time of day 0..1

  late final ui.FragmentProgram _program;
  ui.FragmentShader? _shader;
  bool _loaded = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/day_night.frag');
      _shader = _program.fragmentShader();
      _loaded = true;
    } catch (e) {
      debugPrint('[DayNightOverlay] Failed to load shader: $e');
    }
  }

  // Compute local time as 0..1 fraction where 0 = 00:00, 0.5 = noon
  double _localTime01() {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute + now.second / 60.0;
    return (minutes / 1440.0).clamp(0.0, 1.0);
  }

  @override
  void render(Canvas canvas) {
    if (!_loaded || _shader == null) {
      // Fallback: draw nothing (daytime)
      return;
    }

    try {
      final time01 = debugForcedTime01 ?? (debugForceNight ? 0.0 : _localTime01());
      _shader!.setFloat(0, size.x);
      _shader!.setFloat(1, size.y);
      _shader!.setFloat(2, time01);
      _shader!.setFloat(3, maxNightStrength);

      final paint = Paint()
        ..shader = _shader!
        ..blendMode = BlendMode.multiply; // color grading

      canvas.drawRect(size.toRect(), paint);
    } catch (e) {
      debugPrint('[DayNightOverlay] Render error: $e');
    }
  }

  @override
  void onGameResize(Vector2 gameSize) {
    super.onGameResize(gameSize);
    size = gameSize;
  }
}


