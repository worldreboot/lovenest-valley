#version 460 core
precision highp float;
#include <flutter/runtime_effect.glsl>

// ─── Uniforms supplied by Flame ────────────────────────────────────
uniform vec2  resolution;   // slot 0,1   –  component size   (px)
uniform float u_time;       // slot 2     –  seconds since spawn
uniform float u_speed;      // slot 3     –  current vertical speed (+y = down)

// ─── Constants you can tweak ───────────────────────────────────────
const int   SHAPE_OCTAVES   = 5;
const int   TEXTURE_OCTAVES = 6;
const float STRETCH_STRENGTH = 0.45;   // tail length
const float MAX_SPEED_TAIL   = 600.0;  // speed (px/s) that maxes the tail

// ─── Noise helpers ─────────────────────────────────────────────────
float random(vec2 st){
    return fract(sin(dot(st.xy,vec2(12.9898,78.233)))*43758.5453123);
}

float noise(vec2 st){
    vec2 i = floor(st);
    vec2 f = fract(st);
    float a = random(i);
    float b = random(i+vec2(1.,0.));
    float c = random(i+vec2(0.,1.));
    float d = random(i+vec2(1.,1.));
    vec2 u = f*f*(3.-2.*f);
    return mix(a,b,u.x)+(c-a)*u.y*(1.-u.x)+(d-b)*u.y*u.x;
}

// Ridged noise for more turbulent patterns
float ridgedNoise(vec2 st) {
    return 1.0 - abs(noise(st) * 2.0 - 1.0);
}

// Domain warping for more complex patterns
vec2 domainWarp(vec2 p, float strength) {
    vec2 q = vec2(
        noise(p + vec2(0.0, 0.0)),
        noise(p + vec2(5.2, 1.3))
    );
    return p + strength * q;
}

float fbmShape(vec2 st,float persistence,float lacunarity){
    float total=0.,freq=1.,amp=1.,maxV=0.;
    for(int i=0;i<SHAPE_OCTAVES;i++){
        total+=noise(st*freq)*amp;
        maxV+=amp;
        amp*=persistence;
        freq*=lacunarity;
    }
    return maxV>0.?total/maxV:0.;
}

float fbmTexture(vec2 st,float persistence,float lacunarity){
    float total=0.,freq=1.,amp=1.,maxV=0.;
    for(int i=0;i<TEXTURE_OCTAVES;i++){
        // Mix regular and ridged noise for more interesting texture
        float n = (i < 3) ? noise(st*freq) : ridgedNoise(st*freq);
        total+=n*amp;
        maxV+=amp;
        amp*=persistence;
        freq*=lacunarity;
    }
    return maxV>0.?total/maxV:0.;
}

// ─── Fragment entry point ──────────────────────────────────────────
layout(location = 0) out vec4 fragColor;

void main(){
    // Normalised ‑1‥+1 space (origin at centre)
    vec2 uv  = FlutterFragCoord().xy / resolution;
    vec2 pos = (uv - 0.5) * 2.0;

    // ── Enhanced gravity stretch with non-linear falloff ──────────
    float speedNorm = clamp(u_speed / MAX_SPEED_TAIL, 0.0, 1.0);
    // More dramatic stretching with exponential curve
    float stretchCurve = pow(smoothstep(0.0, -1.0, pos.y), 1.5);
    float stretch = 1.0 - STRETCH_STRENGTH * speedNorm * stretchCurve;
    // Add slight horizontal pinching during stretch
    float horizontalSqueeze = 1.0 + 0.1 * speedNorm * stretchCurve;
    vec2 gpos = vec2(pos.x * horizontalSqueeze, pos.y * stretch);

    // Distance from centre BEFORE distortion (for fall‑off)
    float undistorted_dist = length(gpos);

    // ── Enhanced parameters ───────────────────────────────────────
    float time_scale        = 0.8;
    float displacement_scale= 0.4;  // Increased for more dramatic distortion
    float texture_scale     = 0.8;  // Increased texture variation
    float persistence       = 0.6;  // Slightly higher for more detail
    float lacunarity        = 2.1;

    // Enhanced radial fall‑off with more control
    float noise_falloff = 1.0 - smoothstep(0.4, 1.0, undistorted_dist);
    float strong_falloff = 1.0 - smoothstep(0.3, 0.8, undistorted_dist);

    // ── Domain warping for more complex distortion ────────────────
    vec2 warped_pos = domainWarp(gpos * 2.0 + vec2(u_time * 0.2, u_time * 0.1), 0.3);
    
    // ── Multi-layer shape distortion ──────────────────────────────
    // Large-scale distortion (primary shape)
    vec2 primary_off = vec2(
        fbmShape(warped_pos*1.2 + vec2(u_time*time_scale*0.3,0.), persistence, lacunarity) - 0.5,
        fbmShape(warped_pos*1.2 + vec2(0., u_time*time_scale*0.4), persistence, lacunarity) - 0.5
    );
    
    // Fine-scale turbulence
    vec2 turbulence_off = vec2(
        ridgedNoise(gpos*4.0 + vec2(u_time*time_scale*0.8, 0.)) - 0.5,
        ridgedNoise(gpos*4.0 + vec2(0., u_time*time_scale*1.2)) - 0.5
    ) * 0.3;

    vec2 distortion = (primary_off * noise_falloff + turbulence_off * strong_falloff) * displacement_scale;
    vec2 dpos = gpos + distortion;
    float dist = length(dpos);

    // ── Enhanced flicker with multiple frequencies ────────────────
    float baseRadius = 0.35;
    
    // Multiple flicker layers for more realistic behavior
    float globalFlick = 0.04 * sin(u_time * 6.0) + 0.02 * sin(u_time * 11.3);
    float localFlick = noise(gpos*4.0 + u_time*time_scale*2.0);
    float microFlick = noise(gpos*8.0 + u_time*time_scale*4.0) * 0.5;
    
    // Intensity-based flicker (hotter = more stable)
    float heat_stability = 1.0 - smoothstep(0.2, 0.6, undistorted_dist);
    float flicker = globalFlick + 
                   0.08 * (localFlick - 0.5) * noise_falloff +
                   0.04 * (microFlick - 0.5) * strong_falloff * (1.0 - heat_stability);
                   
    float radius = baseRadius + flicker;

    // ── Enhanced mask with soft inner core ────────────────────────
    float edgeSoftness = 0.12;
    float mask = smoothstep(radius + edgeSoftness * 0.5,
                           radius - edgeSoftness * 0.5,
                           dist);
    
    // Add inner glow for core brightness
    float core_glow = smoothstep(0.25, 0.05, dist) * 0.3;

    // ── Enhanced texture with multiple layers ─────────────────────
    // Primary texture (flowing upward)
    vec2 tex_coord1 = warped_pos * 3.0 + vec2(u_time * time_scale * 0.3, -u_time * time_scale * 0.9);
    float texNoise1 = fbmTexture(tex_coord1, persistence, lacunarity);
    
    // Secondary texture (faster, smaller scale)
    vec2 tex_coord2 = gpos * 6.0 + vec2(u_time * time_scale * 0.8, -u_time * time_scale * 1.4);
    float texNoise2 = noise(tex_coord2) * 0.6;
    
    // Combine textures with falloff
    float combined_tex = mix(texNoise1, texNoise1 * texNoise2, strong_falloff);
    float texIntensity = 1.0 + (combined_tex - 0.5) * texture_scale * noise_falloff;

    // ── Enhanced color gradient with more realistic fire colors ───
    vec3 core = vec3(1.0, 0.95, 0.7);   // Slightly cooler core
    vec3 hot  = vec3(1.0, 0.7, 0.1);    // Hot orange
    vec3 mid  = vec3(1.0, 0.4, 0.05);   // Deep orange
    vec3 cool = vec3(0.8, 0.15, 0.0);   // Cooler red
    vec3 rim  = vec3(0.3, 0.05, 0.0);   // Dark rim
    
    float t = clamp(dist / max(radius, 0.01), 0.0, 1.0);
    
    // Multi-step gradient for more realistic color transition
    vec3 col = mix(core, hot, smoothstep(0.0, 0.25, t));
    col = mix(col, mid, smoothstep(0.25, 0.5, t));
    col = mix(col, cool, smoothstep(0.5, 0.75, t));
    col = mix(col, rim, smoothstep(0.75, 1.0, t));
    
    // Apply texture modulation
    col *= texIntensity;
    
    // Enhanced hot spots with better blending
    float hot_spot_strength = smoothstep(1.2, 1.6, texIntensity) * strong_falloff;
    col = mix(col, vec3(1.0, 1.0, 0.85), hot_spot_strength * 0.6);
    
    // Add inner glow to core
    col = mix(col, vec3(1.0, 0.98, 0.8), core_glow);
    
    // Slight desaturation at edges for realism
    float edge_desat = 1.0 - smoothstep(0.7, 1.0, t) * 0.2;
    col *= edge_desat;
    
    col = clamp(col, 0.0, 1.0);

    // ── Enhanced alpha with edge transparency ─────────────────────
    float final_alpha = mask;
    
    // Reduce alpha at very edges for softer blending
    float edge_fade = 1.0 - smoothstep(0.85, 1.0, t) * 0.3;
    final_alpha *= edge_fade;

    // ── Premultiplied alpha output ────────────────────────────────
    fragColor = vec4(col * final_alpha, final_alpha);
}