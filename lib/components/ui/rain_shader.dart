import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class RainShader extends StatefulWidget {
  final double intensity;
  final Widget child;

  const RainShader({
    super.key,
    required this.intensity,
    required this.child,
  });

  @override
  State<RainShader> createState() => _RainShaderState();
}

class _RainShaderState extends State<RainShader> with TickerProviderStateMixin {
  late AnimationController _animationController;
  double _time = 0.0;
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  bool _isShaderLoaded = false;
  bool _useFallback = false; // Force fallback on problematic devices

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
    
    _animationController.addListener(() {
      setState(() {
        _time += 0.016; // 60 FPS
      });
    });
    
    _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/rain.frag');
      _shader = _program!.fragmentShader();
      debugPrint('Rain shader loaded successfully');
      
      // Test shader on first render to detect device issues
      _testShaderCompatibility();
      
      setState(() {
        _isShaderLoaded = true;
      });
    } catch (e) {
      debugPrint('Failed to load rain shader: $e');
      setState(() {
        _isShaderLoaded = false;
        _useFallback = true;
      });
    }
  }

  void _testShaderCompatibility() {
    // Force fallback on certain devices that have shader issues
    // You can add device-specific checks here
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          // For now, let's try the shader first
          _useFallback = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.intensity > 0.0)
          Positioned.fill(
            child: CustomPaint(
              painter: (_isShaderLoaded && !_useFallback)
                ? RainShaderPainter(
                    shader: _shader!,
                    time: _time,
                    intensity: widget.intensity,
                  )
                : FallbackRainPainter(
                    intensity: widget.intensity,
                    time: _time,
                  ),
            ),
          ),
      ],
    );
  }
}

class RainShaderPainter extends CustomPainter {
  final ui.FragmentShader shader;
  final double time;
  final double intensity;

  RainShaderPainter({
    required this.shader,
    required this.time,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    try {
      debugPrint('Setting rain shader uniforms: width=${size.width}, height=${size.height}, time=$time, intensity=$intensity');
      
      // Set shader uniforms (must match the shader's uniform order)
      shader.setFloat(0, size.width);   // u_resolution_x
      shader.setFloat(1, size.height);  // u_resolution_y
      shader.setFloat(2, time);         // u_time
      shader.setFloat(3, intensity);    // u_speed

      final paint = Paint()..shader = shader;
      
      // Try different blend modes for device compatibility
      paint.blendMode = BlendMode.srcOver; // Changed from screen to srcOver
      
      canvas.drawRect(Offset.zero & size, paint);
    } catch (e) {
      debugPrint('Rain shader render error: $e');
      // Fallback to Canvas rendering if shader fails
      _renderFallback(canvas, size);
    }
  }

  void _renderFallback(Canvas canvas, Size size) {
    // Create multiple layers of raindrops for better effect
    for (int layer = 0; layer < 3; layer++) {
      final layerIntensity = intensity * (1.0 - layer * 0.2);
      final layerSpeed = 1.0 + layer * 0.3;
      
      for (int i = 0; i < 30; i++) {
        final random = math.Random(i + layer * 100);
        
        // Raindrop position with wind effect
        final x = random.nextDouble() * size.width;
        final y = (time * 150 * layerSpeed + random.nextDouble() * size.height) % (size.height + 50);
        
        // Raindrop size and opacity
        final dropSize = (random.nextDouble() * 1.5 + 0.5) * layerIntensity;
        final opacity = (random.nextDouble() * 0.4 + 0.6) * layerIntensity;
        
        final paint = Paint()
          ..color = const Color(0xFF87CEEB).withOpacity(opacity * 0.4)
          ..strokeWidth = dropSize;
        
        // Draw raindrop as a small line
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + dropSize * 8),
          paint,
        );
      }
    }
    
    // Add atmospheric fog effect
    final fogPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFB0C4DE).withOpacity(intensity * 0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Offset.zero & size, fogPaint);
  }

  @override
  bool shouldRepaint(RainShaderPainter oldDelegate) {
    return oldDelegate.time != time ||
           oldDelegate.intensity != intensity;
  }
}

// Fallback rain effect using Flutter Canvas API
class FallbackRainPainter extends CustomPainter {
  final double intensity;
  final double time;

  FallbackRainPainter({
    required this.intensity,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF87CEEB).withOpacity(intensity * 0.3)
      ..style = PaintingStyle.fill;

    // Create simple raindrops
    for (int i = 0; i < 50; i++) {
      final random = math.Random(i);
      
      // Raindrop position
      final x = random.nextDouble() * size.width;
      final y = (time * 200 + random.nextDouble() * size.height) % (size.height + 50);
      
      // Raindrop size and opacity
      final dropSize = (random.nextDouble() * 2 + 1) * intensity;
      final opacity = (random.nextDouble() * 0.5 + 0.5) * intensity;
      
      paint.color = const Color(0xFF87CEEB).withOpacity(opacity * 0.3);
      
      // Draw raindrop as a small line
      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + dropSize * 10),
        paint..strokeWidth = dropSize,
      );
    }
    
    // Add atmospheric fog effect
    final fogPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFB0C4DE).withOpacity(intensity * 0.1),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Offset.zero & size, fogPaint);
  }

  @override
  bool shouldRepaint(FallbackRainPainter oldDelegate) {
    return oldDelegate.time != time ||
           oldDelegate.intensity != intensity;
  }
} 