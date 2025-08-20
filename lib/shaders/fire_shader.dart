import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class FireShader {
  static String getFragmentShaderSource() => _fragmentShaderSource;
  static String getVertexShaderSource() => _vertexShaderSource;

  static const String _vertexShaderSource = '''
    #version 300 es
    
    in vec2 aPosition;
    out vec2 vUv;

    void main() {
        gl_Position = vec4(aPosition, 0.0, 1.0);
        vUv = aPosition * 0.5 + 0.5;
    }
  ''';

  static const String _fragmentShaderSource = '''
    #version 300 es
    
    precision highp float;
    
    in vec2 vUv;
    uniform vec2 uResolution;
    uniform float uTime;
    uniform float uIntensity;
    
    layout(location = 0) out vec4 outColor;
    
    // Enhanced noise functions for more realistic patterns
    float hash21(vec2 p) {
        p = fract(p * vec2(233.34, 851.73));
        p += dot(p, p + 23.45);
        return fract(p.x * p.y);
    }
    
    float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f); // Smooth interpolation
        
        float a = hash21(i);
        float b = hash21(i + vec2(1.0, 0.0));
        float c = hash21(i + vec2(0.0, 1.0));
        float d = hash21(i + vec2(1.0, 1.0));
        
        return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    }
    
    // Domain warping for more realistic fire turbulence
    vec2 warp(vec2 p, float time) {
        float warpStrength = 0.3;
        return p + warpStrength * vec2(
            noise(p * 2.0 + time * 0.5),
            noise(p * 2.0 + time * 0.3 + 100.0)
        );
    }
    
    // Multi-octave noise with better frequency distribution
    float fbm(vec2 p, int octaves) {
        float value = 0.0;
        float amplitude = 0.5;
        float frequency = 1.0;
        
        for (int i = 0; i < octaves; i++) {
            value += amplitude * noise(p * frequency);
            amplitude *= 0.5;
            frequency *= 2.0;
        }
        return value;
    }
    
    // Realistic fire shape with better physics simulation
    float fireShape(vec2 uv, float time) {
        // Create base flame shape - wider at bottom, tapered at top
        float baseShape = 1.0 - smoothstep(0.0, 1.0, uv.y);
        baseShape *= smoothstep(0.0, 0.1, uv.y); // Clean bottom edge
        
        // Horizontal tapering - flame gets narrower towards top
        float width = mix(0.6, 0.1, pow(uv.y, 0.7));
        baseShape *= smoothstep(width, width - 0.1, abs(uv.x - 0.5));
        
        // Apply domain warping for realistic turbulence
        vec2 warpedUV = warp(uv, time);
        
        // Multiple noise layers for complexity
        float turbulence1 = fbm(warpedUV * 4.0 + vec2(0.0, time * 2.0), 4);
        float turbulence2 = fbm(warpedUV * 8.0 + vec2(time * 0.5, time * 3.0), 3);
        float turbulence3 = fbm(warpedUV * 16.0 + vec2(time * 1.5, time * 4.0), 2);
        
        // Combine turbulence with different weights
        float combinedNoise = turbulence1 * 0.6 + turbulence2 * 0.3 + turbulence3 * 0.1;
        
        // Apply noise to flame shape
        float flame = baseShape * combinedNoise;
        
        // Add flickering at the edges for more realism
        float edgeFlicker = sin(time * 15.0 + uv.x * 10.0) * 0.1 + 
                           sin(time * 8.0 + uv.y * 12.0) * 0.05;
        flame += edgeFlicker * baseShape * 0.2;
        
        return clamp(flame, 0.0, 1.0);
    }
    
    // Realistic fire color palette with temperature simulation
    vec3 fireColor(float intensity, float height) {
        // Temperature-based colors (hotter = whiter/bluer, cooler = redder)
        vec3 coolRed = vec3(0.7, 0.1, 0.0);      // Deep red at base
        vec3 warmOrange = vec3(1.0, 0.4, 0.0);   // Orange mid-tones
        vec3 hotYellow = vec3(1.0, 0.9, 0.3);    // Yellow-white hot spots
        vec3 superHot = vec3(1.0, 1.0, 0.8);     // Nearly white core
        vec3 blueCore = vec3(0.8, 0.9, 1.0);     // Blue core for extreme heat
        
        // Color mixing based on intensity and height
        vec3 color = coolRed;
        
        // Blend towards orange
        color = mix(color, warmOrange, smoothstep(0.2, 0.5, intensity));
        
        // Blend towards yellow
        color = mix(color, hotYellow, smoothstep(0.4, 0.7, intensity));
        
        // Hot core areas
        color = mix(color, superHot, smoothstep(0.7, 0.9, intensity));
        
        // Extremely hot blue-white core (rare but realistic)
        color = mix(color, blueCore, smoothstep(0.9, 1.0, intensity) * smoothstep(0.8, 1.0, height));
        
        return color;
    }
    
    void main() {
        vec2 uv = vUv;
        
        // Center and scale UV coordinates
        uv = (uv - 0.5) * 2.0;
        uv.x *= uResolution.x / uResolution.y;
        
        // Shift to bottom-center origin for fire
        uv.y += 0.8;
        uv = uv * 0.5 + 0.5;
        
        // Calculate flame intensity
        float flame = fireShape(uv, uTime);
        
        // Enhanced flickering with multiple frequencies
        float flicker = 0.85 + 0.15 * (
            sin(uTime * 12.0) * 0.4 +
            sin(uTime * 6.0 + uv.x * 8.0) * 0.3 +
            sin(uTime * 18.0 + uv.y * 12.0) * 0.2 +
            noise(vec2(uTime * 4.0, uv.x * 6.0)) * 0.1
        );
        
        // Apply global intensity and flickering
        flame *= uIntensity * flicker;
        
        // Get fire color based on intensity and height
        vec3 color = fireColor(flame, uv.y);
        
        // Add subtle inner glow effect
        float glow = flame * 0.3;
        color += vec3(glow * 0.8, glow * 0.4, glow * 0.1);
        
        // Enhance contrast for more dramatic effect
        flame = smoothstep(0.1, 0.8, flame);
        
        // Add some smoke/heat distortion at the top
        if (uv.y > 0.7) {
            float smokeIntensity = smoothstep(0.7, 1.0, uv.y) * (1.0 - flame);
            vec3 smokeColor = vec3(0.2, 0.15, 0.1);
            color = mix(color, smokeColor, smokeIntensity * 0.3);
            flame = max(flame, smokeIntensity * 0.5);
        }
        
        // Final color with proper alpha
        outColor = vec4(color, flame);
    }
  ''';
}

// Enhanced fire painter that implements the realistic GLSL shader logic
class EnhancedFirePainter extends CustomPainter {
  final double intensity;
  final double time;
  final double size;
  final Offset center;

  EnhancedFirePainter({
    required this.intensity,
    required this.time,
    required this.size,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Implement the realistic GLSL shader logic using Flutter Canvas
    // This simulates the enhanced shader effects from the GLSL code
    
    final paint = Paint();
    
    // Create multiple flame layers for realistic depth
    for (int layer = 0; layer < 8; layer++) {
      final layerIntensity = intensity * (1.0 - layer * 0.1);
      final layerSize = size * (0.7 + layer * 0.15);
      
      // Enhanced flickering with multiple frequencies (like in GLSL)
      final flicker = 0.85 + 0.15 * (
        math.sin(time * 12.0) * 0.4 +
        math.sin(time * 6.0 + layer * 2.0) * 0.3 +
        math.sin(time * 18.0 + layer * 3.0) * 0.2 +
        _simulateNoise(time * 4.0, layer * 6.0) * 0.1
      );
      
      // Create realistic flame shape with turbulence
      for (int i = 0; i < 60; i++) {
        final random = math.Random(i + layer * 100);
        final x = center.dx + (random.nextDouble() - 0.5) * layerSize * 1.5;
        final y = center.dy - random.nextDouble() * layerSize * 2.5;
        
        // Calculate distance and flame shape (like GLSL fireShape)
        final distance = (Offset(x, y) - center).distance;
        final heightRatio = (center.dy - y) / layerSize;
        
        // Base flame shape - wider at bottom, tapered at top
        final baseShape = (1.0 - heightRatio).clamp(0.0, 1.0);
        final width = 0.6 - (heightRatio * 0.5); // Tapering width
        final horizontalShape = (1.0 - (x - center.dx).abs() / (layerSize * width)).clamp(0.0, 1.0);
        
        // Apply turbulence (like GLSL domain warping)
        final turbulence1 = _simulateNoise(x * 0.1, y * 0.1 + time * 0.8, i);
        final turbulence2 = _simulateNoise(x * 0.2, y * 0.2 + time * 0.6, i + 100);
        final turbulence3 = _simulateNoise(x * 0.4, y * 0.4 + time * 0.4, i + 200);
        
        final combinedNoise = turbulence1 * 0.6 + turbulence2 * 0.3 + turbulence3 * 0.1;
        final flameShape = baseShape * horizontalShape * combinedNoise;
        
        if (flameShape > 0.1) {
          // Realistic fire color palette (like GLSL fireColor)
          Color fireColor;
          if (heightRatio > 0.8) {
            fireColor = const Color(0xFFCCE5FF); // Blue core
          } else if (heightRatio > 0.6) {
            fireColor = const Color(0xFFFFF2CC); // Super hot white
          } else if (heightRatio > 0.4) {
            fireColor = const Color(0xFFFFE54C); // Hot yellow
          } else if (heightRatio > 0.2) {
            fireColor = const Color(0xFFFF8000); // Orange
          } else {
            fireColor = const Color(0xFFCC3300); // Red base
          }
          
          // Apply intensity and flickering
          final alpha = flameShape * layerIntensity * flicker;
          paint.color = fireColor.withOpacity(alpha);
          
          // Add movement and turbulence
          final movementX = math.sin(time * 2 + i + layer) * 3;
          final movementY = math.sin(time * 1.5 + i * 0.5 + layer) * 2;
          
          final particleSize = (random.nextDouble() * 0.6 + 0.4) * layerIntensity * 12;
          
          canvas.drawCircle(
            Offset(x + movementX, y + movementY),
            particleSize,
            paint,
          );
        }
      }
    }
    
    // Add enhanced glow effect
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.bottomCenter,
        radius: 1.5,
        colors: [
          const Color(0xFF0066FF).withOpacity(intensity * 0.2), // Blue core glow
          const Color(0xFFFFFFAA).withOpacity(intensity * 0.4), // White-yellow glow
          const Color(0xFFFF6600).withOpacity(intensity * 0.3), // Orange glow
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size * 3));
    
    canvas.drawCircle(center, size * 3, glowPaint);
    
    // Add smoke/heat distortion at the top
    if (intensity > 0.5) {
      final smokePaint = Paint()
        ..color = const Color(0xFF333333).withOpacity(intensity * 0.1);
      
      for (int i = 0; i < 20; i++) {
        final random = math.Random(i);
        final x = center.dx + (random.nextDouble() - 0.5) * size * 2;
        final y = center.dy - size * 2 - random.nextDouble() * size;
        
        canvas.drawCircle(
          Offset(x, y),
          random.nextDouble() * 8 + 4,
          smokePaint,
        );
      }
    }
  }

  // Enhanced noise simulation (like GLSL hash21 and noise functions)
  double _simulateNoise(double x, double y, [int seed = 0]) {
    final random = math.Random((x * 1000 + y * 1000 + seed).toInt());
    return random.nextDouble() * 0.5 + 0.5;
  }

  @override
  bool shouldRepaint(EnhancedFirePainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
           oldDelegate.time != time ||
           oldDelegate.size != size ||
           oldDelegate.center != center;
  }
}

// Keep the original FirePainter as fallback
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
    // Simple fallback rendering
    final paint = Paint()
      ..color = Colors.orange.withOpacity(intensity)
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(center, size, paint);
  }

  @override
  bool shouldRepaint(FirePainter oldDelegate) {
    return oldDelegate.intensity != intensity ||
           oldDelegate.time != time ||
           oldDelegate.size != size ||
           oldDelegate.center != center;
  }
}