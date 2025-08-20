#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>

uniform float u_resolution_x;  // slot 0
uniform float u_resolution_y;  // slot 1
uniform float u_time;          // slot 2
uniform float u_speed;         // slot 3

layout(location = 0) out vec4 fragColor;

void main() {
    vec2 resolution = vec2(u_resolution_x, u_resolution_y);
    vec2 uv = FlutterFragCoord().xy / resolution;
    vec2 pos = uv * 2.0 - 1.0; // -1 to 1 space

    // Ellipse parameters for raindrop shape
    float radiusX = 0.12;
    float radiusY = 0.85;

    // Ellipse formula with more robust calculation
    float ellipse = (pos.x * pos.x) / (radiusX * radiusX) + (pos.y * pos.y) / (radiusY * radiusY);

    // Soft alpha edges with smoothstep
    float alpha = smoothstep(1.0, 0.95, ellipse);

    // Vertical gradient for highlight (top brighter)
    float highlight = smoothstep(-1.0, 0.0, pos.y);

    // Base blue color with white highlight on top
    vec3 baseColor = vec3(0.5, 0.7, 0.9);
    vec3 highlightColor = vec3(1.0, 1.0, 1.0);

    vec3 color = mix(baseColor, highlightColor, highlight);

    // Make it more transparent and watery with device-safe calculation
    float timeFactor = sin(u_time * 5.0);
    alpha *= 0.4 + 0.6 * abs(timeFactor);

    // Ensure alpha is within valid range
    alpha = clamp(alpha, 0.0, 1.0);
    
    // Ensure color is within valid range
    color = clamp(color, 0.0, 1.0);

    fragColor = vec4(color, alpha);
}