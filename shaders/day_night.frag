#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>

// Day/Night color grading overlay driven by local time-of-day
// Inputs:
//  - resolution (0,1): component size in pixels
//  - u_time01 (2):     time of day in [0,1], where 0 = 00:00, 0.5 = 12:00
//  - u_strength (3):   maximum darkness strength at midnight in [0,1]

uniform vec2  resolution;
uniform float u_time01;
uniform float u_strength;

layout(location = 0) out vec4 fragColor;

// Smooth darkness curve: 0 at noon, 1 at midnight
float darkness_curve(float t) {
    // Distance from noon
    float d = abs(t - 0.5) * 2.0;     // 0 at noon, 1 at midnight
    // Ease both ends for gentle dawn/dusk transitions
    return smoothstep(0.0, 1.0, d);
}

// Optional warm dusk/dawn tint amount
float dusk_dawn_amount(float t) {
    // Two windows around ~6:00 and ~18:00
    float dawn  = smoothstep(0.00, 0.08, t) * (1.0 - smoothstep(0.12, 0.20, t));
    float dusk  = smoothstep(0.80, 0.88, t) * (1.0 - smoothstep(0.92, 1.00, t));
    return max(dawn, dusk);
}

void main() {
    vec2 uv = FlutterFragCoord().xy / max(resolution, vec2(1.0));

    // Base darkness factor using hard night window:
    //  - Night: 21:00–06:00 -> full strength (moved from 20:00 to 21:00)
    //  - Dusk fade: 19:00–21:00 -> ease from day to full night
    //  - Dawn fade: 06:00–08:00 -> ease from full night to day
    //  - Day: 08:00–19:00 -> none
    float t = fract(u_time01); // ensure [0,1)
    const float T_19 = 19.0/24.0;  // Dusk starts at 7:00 PM
    const float T_21 = 21.0/24.0;  // Night starts at 9:00 PM
    const float T_06 = 6.0/24.0;   // Dawn starts at 6:00 AM
    const float T_08 = 8.0/24.0;   // Day starts at 8:00 AM

    float dark = 0.0;
    bool night = (t >= T_21) || (t < T_06);
    if (night) {
        dark = u_strength;
    } else if (t >= T_19 && t < T_21) {
        // Dusk transition: 7:00 PM to 9:00 PM
        float dusk01 = clamp((t - T_19) / (T_21 - T_19), 0.0, 1.0);
        float ease = smoothstep(0.0, 1.0, dusk01);
        dark = ease * u_strength;
    } else if (t >= T_06 && t < T_08) {
        // Dawn transition: 6:00 AM to 8:00 AM
        float dawn01 = clamp((t - T_06) / (T_08 - T_06), 0.0, 1.0);
        float ease = smoothstep(0.0, 1.0, 1.0 - dawn01);
        dark = ease * u_strength;
    } else {
        dark = 0.0;
    }

    // Night bluish tint for multiply (reduce R/G more than B)
    vec3 nightTint = vec3(0.20, 0.35, 1.00);
    // Day is neutral white (multiply = identity)
    vec3 dayTint = vec3(1.0);
    vec3 tint = mix(dayTint, nightTint, dark);

    // Optional warm tint during dawn fade (06:00–08:00) and dusk fade (19:00–21:00)
    float warmBlend = 0.0;
    if (t >= T_06 && t < T_08) {
        // Dawn warm tint: strongest near 06:00
        float dawn01 = clamp((t - T_06) / (T_08 - T_06), 0.0, 1.0);
        warmBlend = smoothstep(0.0, 1.0, 1.0 - dawn01);
    } else if (t >= T_19 && t < T_21) {
        // Dusk warm tint: strongest near 21:00
        float dusk01 = clamp((t - T_19) / (T_21 - T_19), 0.0, 1.0);
        warmBlend = smoothstep(0.0, 1.0, dusk01);
    }
    vec3 warmTint = vec3(1.00, 0.80, 0.60);
    float warmStrength = u_strength; // comparable to night intensity
    tint = mix(tint, warmTint, warmBlend * warmStrength);

    // Increase blue bias deeper at night (reduced during dusk/dawn)
    float blueBoost = dark * 0.20 * (1.0 - warmBlend);
    tint = mix(tint, vec3(0.0, 0.0, 1.0), blueBoost);

    // Lightweight vignette for night only
    float vignette = 1.0;
    if (dark > 0.001) {
        vec2 p = uv - 0.5;
        float r = length(p);
        float vig = smoothstep(0.85, 0.35, r); // 1 center -> 0 edges
        vignette = mix(1.0, 0.92 + 0.08*vig, dark);
    }

    vec3 color = tint * vignette;
    color = clamp(color, 0.0, 1.0);

    // Premultiplied alpha; we output a solid color and rely on Multiply blending in Dart
    fragColor = vec4(color, 1.0);
}


