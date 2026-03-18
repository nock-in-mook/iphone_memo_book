#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// シンプルなランダムノイズ
[[ stitchable ]]
half4 randomNoise(float2 position, half4 color, float seed) {
    float value = fract(sin(dot(position + seed, float2(12.9898, 78.233))) * 43758.5453);
    return half4(value, value, value, color.a);
}

// パラメータ付きノイズ（強度・周波数を制御）
[[ stitchable ]]
half4 paramNoise(float2 position, half4 color, float intensity, float frequency) {
    float value = fract(cos(dot(position * frequency, float2(12.9898, 78.233))) * 43758.5453);
    half r = color.r * mix(half(1.0), half(value), half(intensity));
    half g = color.g * mix(half(1.0), half(value), half(intensity));
    half b = color.b * mix(half(1.0), half(value), half(intensity));
    return half4(r, g, b, color.a);
}

// 滑らかなノイズ（Perlin風、補間あり）
float hash(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
}

float smoothNoise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f); // smoothstep

    float a = hash(i + float2(0.0, 0.0));
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

[[ stitchable ]]
half4 perlinNoise(float2 position, half4 color, float scale, float intensity) {
    float n = smoothNoise(position * scale);
    half v = half(n * intensity);
    return half4(color.r + v, color.g + v, color.b + v, color.a);
}

// バンプ（凹凸）ノイズ — 白ハイライト + 黒シャドウで立体感
[[ stitchable ]]
half4 bumpNoise(float2 position, half4 color, float scale, float intensity) {
    float n1 = smoothNoise(position * scale);
    float n2 = smoothNoise((position + float2(1.0, 1.0)) * scale);
    // 差分で凹凸方向を決定
    float bump = (n1 - n2) * intensity;
    return half4(color.r + half(bump), color.g + half(bump), color.b + half(bump), color.a);
}

// フロストガラス — 多層ノイズ
[[ stitchable ]]
half4 frostGlass(float2 position, half4 color, float roughness) {
    float n1 = smoothNoise(position * 0.05) * 0.5;
    float n2 = smoothNoise(position * 0.1) * 0.25;
    float n3 = smoothNoise(position * 0.2) * 0.125;
    float combined = (n1 + n2 + n3) * roughness;
    return half4(color.r + half(combined), color.g + half(combined), color.b + half(combined), color.a);
}
