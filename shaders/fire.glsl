#version 460 core

precision highp float;

uniform vec2 uResolution;
uniform float uTime;
uniform float uIntensity;
uniform vec2 uCenter;
uniform float uSize;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / uResolution.xy;
    vec2 center = uCenter / uResolution.xy;
    
    // Calculate distance from center
    vec2 delta = uv - center;
    float dist = length(delta);
    
    // Simple fire shape
    float fireShape = smoothstep(uSize, 0.0, dist);
    
    // Simple color gradient
    vec3 fireColor = vec3(1.0, 0.5, 0.0); // Orange
    
    // Add some animation
    float flicker = 0.8 + 0.2 * sin(uTime * 10.0);
    fireColor *= flicker * uIntensity;
    
    // Final alpha
    float alpha = fireShape * uIntensity;
    
    fragColor = vec4(fireColor, alpha);
} 