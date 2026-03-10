#include <metal_stdlib>
using namespace metal;

// Hash function for pseudo-random noise
float hash(float2 p) {
    float3 p3 = fract(float3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Value noise with smooth interpolation
float valueNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Fractal Brownian Motion for layered paper texture
float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * valueNoise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

[[ stitchable ]]
half4 paperGrain(float2 position, half4 color, float2 size, float intensity) {
    // Fine grain at high frequency
    float fineGrain = valueNoise(position * 3.0);

    // Medium fiber texture
    float fiber = fbm(position * 0.8);

    // Combine layers
    float noise = mix(fiber, fineGrain, 0.4);

    // Center around 0 and scale by intensity
    float offset = (noise - 0.5) * intensity;

    return half4(
        color.r + half(offset),
        color.g + half(offset * 0.95),
        color.b + half(offset * 0.85),
        color.a
    );
}
