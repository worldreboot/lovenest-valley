import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FireEffect extends PositionComponent {
  late final ui.FragmentProgram _program;
  late final ui.FragmentShader _shader;
  
  // Physics properties
  double fireIntensity = 1.0;
  double verticalSpeed = 0.0; // pixels per second (positive = downward)
  
  // Internal state
  double _time = 0.0;
  bool _isShaderLoaded = false;
  
  // Optional: wind effects
  double windStrength = 0.0;
  double windDirection = 0.0; // radians

  FireEffect({
    super.position, 
    super.size,
    this.fireIntensity = 1.0,
    this.verticalSpeed = 0.0,
  }) : super(priority: 2000); // High priority for fire/smoke effects to render on top

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      debugPrint('[FireEffect] Loading triple-A fire shader...');
      
      // Load the fragment program
      _program = await ui.FragmentProgram.fromAsset('shaders/fire.frag');
      _shader = _program.fragmentShader();
      _isShaderLoaded = true;
      
      debugPrint('[FireEffect] ✅ Triple-A shader loaded successfully!');
    } catch (e, st) {
      debugPrint('[FireEffect] ❌ Shader failed to load: $e');
      debugPrint('Stack trace: $st');
      _isShaderLoaded = false;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    
    // Optional: Add some natural movement variation
    // You can modify verticalSpeed here for dynamic effects
  }

  @override
  void render(Canvas canvas) {
    if (!_isShaderLoaded) {
      _renderFallback(canvas);
      return;
    }

    try {
      // Set shader uniforms (must match the shader's uniform order)
      _shader.setFloat(0, size.x);           // resolution.x
      _shader.setFloat(1, size.y);           // resolution.y  
      _shader.setFloat(2, _time);            // u_time
      _shader.setFloat(3, verticalSpeed);    // u_speed (NOT fireIntensity!)

      final paint = Paint()..shader = _shader;
      
      // Important: Use proper blending for fire effects
      paint.blendMode = BlendMode.plus; // Additive blending for realistic fire
      
      // Draw the fire effect
      canvas.drawRect(size.toRect(), paint);
      
    } catch (e) {
      debugPrint('[FireEffect] ❌ Render error: $e');
      _renderFallback(canvas);
    }
  }

  void _renderFallback(Canvas canvas) {
    // Enhanced fallback with gradient
    final rect = size.toRect();
    final gradient = RadialGradient(
      colors: [
        Colors.white.withOpacity(fireIntensity * 0.8),
        Colors.yellow.withOpacity(fireIntensity * 0.6),
        Colors.orange.withOpacity(fireIntensity * 0.4),
        Colors.red.withOpacity(fireIntensity * 0.2),
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.5, 0.8, 1.0],
    );
    
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.plus;
      
    canvas.drawOval(rect, paint);
  }

  // Control methods for dynamic fire behavior
  void setFireIntensity(double intensity) {
    fireIntensity = intensity.clamp(0.0, 3.0); // Allow higher values for HDR
  }
  
  void setVerticalSpeed(double speed) {
    verticalSpeed = speed; // Positive = moving down, negative = moving up
  }
  
  void setWindEffect(double strength, double direction) {
    windStrength = strength.clamp(0.0, 1.0);
    windDirection = direction;
    // You could pass these as additional uniforms if you modify the shader
  }
  
  // Preset configurations for different fire types
  void configureTorch() {
    fireIntensity = 1.0;
    verticalSpeed = -50.0; // Slight upward movement
  }
  
  void configureCandle() {
    fireIntensity = 0.7;
    verticalSpeed = -20.0; // Gentle upward movement
  }
  
  void configureBonfire() {
    fireIntensity = 1.5;
    verticalSpeed = -100.0; // Strong upward movement
  }
  
  void configureExplosion() {
    fireIntensity = 2.5;
    verticalSpeed = 200.0; // Rapid expansion
  }
}

// Optional: Enhanced fire system with multiple effects
class FireSystem extends Component {
  final List<FireEffect> _fires = [];
  
  void addFire(FireEffect fire) {
    _fires.add(fire);
    add(fire);
  }
  
  void removeFire(FireEffect fire) {
    _fires.remove(fire);
    remove(fire);
  }
  
  // Update all fires with environmental effects
  void applyGlobalWind(double windX, double windY) {
    for (final fire in _fires) {
      // You could modify each fire's speed based on wind
      fire.verticalSpeed += windY * 0.1;
    }
  }
  
  void applyGravity(double gravity) {
    for (final fire in _fires) {
      fire.verticalSpeed += gravity * 0.1;
    }
  }
}
