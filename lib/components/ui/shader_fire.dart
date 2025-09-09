import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:lovenest_valley/shaders/fire_shader.dart';

class ShaderFire extends StatefulWidget {
  final double intensity;
  final double size;
  final Offset center;

  const ShaderFire({
    super.key,
    required this.intensity,
    required this.size,
    required this.center,
  });

  @override
  State<ShaderFire> createState() => _ShaderFireState();
}

class _ShaderFireState extends State<ShaderFire> with TickerProviderStateMixin {
  late AnimationController _animationController;
  double _time = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _animationController.addListener(() {
      setState(() {
        _time += 0.016; // 60 FPS
      });
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ShaderFirePainter(
        intensity: widget.intensity,
        time: _time,
        size: widget.size,
        center: widget.center,
      ),
      size: Size(widget.size * 2, widget.size * 2),
    );
  }
}

class ShaderFirePainter extends CustomPainter {
  final double intensity;
  final double time;
  final double size;
  final Offset center;

  ShaderFirePainter({
    required this.intensity,
    required this.time,
    required this.size,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Implement GLSL-like fire effect using Flutter's Canvas API
    // This simulates the shader logic without requiring actual GLSL compilation
    
    final paint = Paint();
    
    // Create fire effect using the shader logic principles
    for (int i = 0; i < 100; i++) {
      final random = math.Random(i);
      final x = center.dx + (random.nextDouble() - 0.5) * size * 2;
      final y = center.dy - random.nextDouble() * size * 2;
      
      // Calculate distance from center (like in shader)
      final distance = (Offset(x, y) - center).distance;
      final flameIntensity = intensity * (1.0 - distance / size);
      
      if (flameIntensity > 0.1) {
        // Simulate shader noise and flame shape
        final noise1 = _simulateNoise(x * 0.1, y * 0.1 + time * 0.8, i);
        final noise2 = _simulateNoise(x * 0.2, y * 0.2 + time * 0.8 + 10, i);
        final flameShape = (1.0 - (y - center.dy) / size) * noise1 * noise2;
        
        if (flameShape > 0.1) {
          // Color gradient like in shader
          final heightRatio = (center.dy - y) / size;
          Color fireColor;
          
          if (heightRatio > 0.7) {
            fireColor = const Color(0xFFFFE54C); // Bright yellow-white
          } else if (heightRatio > 0.4) {
            fireColor = const Color(0xFFFF8000); // Orange
          } else {
            fireColor = const Color(0xFFCC3300); // Red
          }
          
          // Apply flickering like in shader
          final flicker = 0.7 + 0.3 * math.sin(time * 10) * math.sin(time * 3);
          final alpha = flameShape * intensity * flicker;
          
          paint.color = fireColor.withOpacity(alpha);
          
          // Add movement like in shader
          final movementX = math.sin(time * 2 + i) * 2;
          final movementY = math.sin(time * 1.5 + i * 0.5) * 1;
          
          final particleSize = (random.nextDouble() * 0.5 + 0.5) * flameIntensity * 8;
          
          canvas.drawCircle(
            Offset(x + movementX, y + movementY),
            particleSize,
            paint,
          );
        }
      }
    }
    
    // Add glow effect like in shader
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.orange.withOpacity(intensity * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size * 2));
    
    canvas.drawCircle(center, size * 2, glowPaint);
  }

  // Simulate GLSL noise function
  double _simulateNoise(double x, double y, int seed) {
    final random = math.Random(seed);
    return random.nextDouble() * 0.5 + 0.5;
  }

  @override
  bool shouldRepaint(ShaderFirePainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
           oldDelegate.time != time ||
           oldDelegate.size != size ||
           oldDelegate.center != center;
  }
}

// Fallback custom painter for when shaders aren't available
class FirePainter extends CustomPainter {
  final double intensity;
  final double time;
  final double size;
  final Offset center;

  FirePainter({
    required this.intensity,
    required this.time,
    required this.size,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Create fire effect using gradients and noise
    for (int i = 0; i < 50; i++) {
      final random = math.Random(i);
      final x = center.dx + (random.nextDouble() - 0.5) * size * 2;
      final y = center.dy - random.nextDouble() * size * 2;
      
      // Calculate flame properties based on position and time
      final distance = (Offset(x, y) - center).distance;
      final flameIntensity = intensity * (1.0 - distance / size);
      
      if (flameIntensity > 0.1) {
        // Create flame particle
        final particleSize = (random.nextDouble() * 0.5 + 0.5) * flameIntensity * 10;
        
        // Color based on height and intensity
        final heightRatio = (center.dy - y) / size;
        Color flameColor;
        
        if (heightRatio > 0.8) {
          flameColor = Colors.blue.withOpacity(flameIntensity * 0.3);
        } else if (heightRatio > 0.5) {
          flameColor = Colors.yellow.withOpacity(flameIntensity * 0.7);
        } else {
          flameColor = Colors.orange.withOpacity(flameIntensity * 0.9);
        }
        
        final paint = Paint()..color = flameColor;
        
        // Add some movement based on time
        final movementX = math.sin(time * 2 + i) * 2;
        final movementY = math.sin(time * 1.5 + i * 0.5) * 1;
        
        canvas.drawCircle(
          Offset(x + movementX, y + movementY),
          particleSize,
          paint,
        );
      }
    }
    
    // Add glow effect
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.orange.withOpacity(intensity * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size * 2));
    
    canvas.drawCircle(center, size * 2, glowPaint);
  }

  @override
  bool shouldRepaint(FirePainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
           oldDelegate.time != time ||
           oldDelegate.size != size ||
           oldDelegate.center != center;
  }
} 
