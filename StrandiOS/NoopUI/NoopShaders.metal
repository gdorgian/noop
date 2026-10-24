#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Noop Aura's GPU effects. Each is driven by the wearer's own numbers: nothing here is decoration
// for its own sake.

// MARK: - Noise

static float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float noise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash21(i), hash21(i + float2(1, 0)), u.x),
               mix(hash21(i + float2(0, 1)), hash21(i + float2(1, 1)), u.x), u.y);
}

static float fbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * noise(p); p = p * 2.03 + 17.1; a *= 0.5; }
    return v;
}

/// A value from `heights` (count `n`) at fraction `x`, linearly between samples.
static float sampleHeights(float x, device const float *heights, int n) {
    float f = clamp(x, 0.0, 1.0) * float(n - 1);
    int i = int(floor(f));
    int j = min(i + 1, n - 1);
    return mix(heights[i], heights[j], f - float(i));
}

// MARK: - Aurora
//
// Curtains of light rising from the bottom edge. At each x the curtain reaches as high as
// `heights` says (the night's depth of sleep at that moment); its folds are domain-warped noise
// flowing slowly sideways, its colour runs green at the base to violet at the crown, and `reveal`
// sweeps it in from the left.

[[ stitchable ]]
half4 noopAurora(float2 position, half4 color, float2 size, float time, float reveal,
                 device const float *heights, int count) {
    float2 uv = position / size;
    float x = uv.x, y = 1.0 - uv.y;
    float h = sampleHeights(x, heights, count) * 0.64;

    // Folds: noise in x, stretched tall, drifting.
    float2 q = float2(x * 3.2 + time * 0.035, y * 0.6);
    float warp = fbm(q + float2(time * 0.05, 0.0));
    float folds = fbm(float2(x * 9.0 + warp * 2.4 + time * 0.08, y * 1.2 - time * 0.02));
    float rays = pow(folds, 2.2) * 2.4;

    // The curtain's crown wavers with the folds; light fades up to it and a little past.
    float crown = h * (0.88 + 0.24 * warp);
    float body = smoothstep(crown + 0.08, crown - 0.04, y) * smoothstep(0.0, 0.06, y);
    float intensity = body * (0.25 + rays) * smoothstep(0.0, crown + 0.001, y + 0.15);

    float t = clamp(y / max(crown, 0.05), 0.0, 1.0);
    half3 base = half3(0.18, 0.95, 0.62);
    half3 mid = half3(0.30, 0.85, 1.00);
    half3 top = half3(0.70, 0.52, 1.00);
    half3 c = t < 0.55 ? mix(base, mid, half(t / 0.55)) : mix(mid, top, half((t - 0.55) / 0.45));

    float sweep = smoothstep(reveal * 1.1 - 0.1, reveal * 1.1, x);
    float a = clamp(intensity * 0.72, 0.0, 0.85) * (1.0 - sweep);
    return half4(c * half(a), half(a));
}

// MARK: - Liquid
//
// A vessel filled to `level` (0 empty … 1 full). The surface tilts with the phone (`tilt`, the
// surface's slope) and carries two travelling waves whose height is `slosh`, which the caller
// raises when the phone moves and lets decay. Below the surface the liquid darkens with depth; a
// thin bright meniscus runs along the surface; `split` (0…1 of the fill) marks where the lower
// layer ends.

[[ stitchable ]]
half4 noopLiquid(float2 position, half4 color, float2 size, float time, float level,
                 float tilt, float slosh, float split, half4 lower, half4 upper) {
    float2 uv = position / size;
    float x = uv.x - 0.5;
    float wave = slosh * (0.035 * sin(x * 9.0 + time * 3.1) + 0.018 * sin(x * 19.0 - time * 4.3))
               + 0.006 * sin(x * 7.0 + time * 1.3);
    float surface = 1.0 - level + tilt * x + wave;
    float d = uv.y - surface;
    if (d < -0.012) { return half4(0); }

    float boundary = 1.0 - level * split + tilt * x * 0.6 + wave * 0.4;
    half4 c = uv.y > boundary ? lower : upper;
    // Darker with depth.
    float depth = clamp((uv.y - surface) / max(level, 0.05), 0.0, 1.0);
    c.rgb *= half(1.0 - 0.38 * depth);
    // Meniscus: a bright line at the surface, soft above it.
    float men = smoothstep(-0.012, 0.0, d) * (1.0 - smoothstep(0.0, 0.02, d));
    c.rgb += half3(0.55, 0.85, 1.0) * half(men * 0.9);
    float alpha = smoothstep(-0.012, 0.004, d);
    return half4(c.rgb * half(alpha), c.a * half(alpha));
}

// MARK: - Touch ripple
//
// A single ring travelling out from where the finger last touched, bending what is beneath it;
// `age` is seconds since the touch.

[[ stitchable ]]
half4 noopTouchRipple(float2 position, SwiftUI::Layer layer, float2 origin, float age, float strength) {
    float2 d = position - origin;
    float dist = length(d);
    float front = age * 520.0;
    float band = exp(-pow((dist - front) / 26.0, 2.0));
    float fade = exp(-age * 2.4) * strength;
    float2 dir = dist > 0.001 ? d / dist : float2(0);
    float offset = sin((dist - front) * 0.22) * 7.0 * band * fade;
    half4 c = layer.sample(position - dir * offset);
    c.rgb += half(0.10 * band * fade) * c.a;
    return c;
}
