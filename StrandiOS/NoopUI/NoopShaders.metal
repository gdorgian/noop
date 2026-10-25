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

// MARK: - Flow rings
//
// Three concentric rings (outermost first) as continuous bands. Each fills clockwise from the top to
// its `fills` value, shaded from `from` to `to` colour along its length, with a rounded head and a
// soft band of light travelling along the filled part toward the head. `reveal` grows every fill
// from zero with a slight overshoot handled by the caller.

static float arcMask(float angle01, float fill, float distToRing, float halfWidth, float radius) {
    // Body of the arc.
    float body = step(angle01, fill) * smoothstep(halfWidth + 0.75, halfWidth - 0.75, distToRing);
    return body;
}

[[ stitchable ]]
half4 noopFlowRings(float2 position, half4 color, float2 size, float time,
                    float fill0, float fill1, float fill2,
                    half4 from0, half4 to0, half4 from1, half4 to1, half4 from2, half4 to2) {
    float2 c = size * 0.5;
    float2 p = position - c;
    float r = length(p);
    float R = min(size.x, size.y) * 0.5;
    float halfWidth = R * 0.075;
    float radii[3] = { R - halfWidth - 2.0, R - halfWidth * 3.0 - 8.0, R - halfWidth * 5.0 - 14.0 };
    float fills[3] = { fill0, fill1, fill2 };
    half4 froms[3] = { from0, from1, from2 };
    half4 tos[3] = { to0, to1, to2 };

    // Angle from the top, clockwise, 0…1.
    float a = atan2(p.x, -p.y);
    float a01 = a < 0.0 ? a / (2.0 * M_PI_F) + 1.0 : a / (2.0 * M_PI_F);

    half4 out = half4(0);
    for (int i = 0; i < 3; i++) {
        float d = abs(r - radii[i]);
        // Track.
        float track = smoothstep(halfWidth + 0.75, halfWidth - 0.75, d);
        out = mix(out, half4(1, 1, 1, 1) * 0.06h, half(track) * (1.0h - out.a));
        float f = clamp(fills[i], 0.0, 1.0);
        if (f <= 0.001) { continue; }
        // Rounded ends: distance to the start and head cap centres.
        float headA = f * 2.0 * M_PI_F;
        float2 head = float2(sin(headA), -cos(headA)) * radii[i];
        float2 start = float2(0.0, -radii[i]);
        float capH = smoothstep(halfWidth + 0.75, halfWidth - 0.75, length(p - head));
        float capS = smoothstep(halfWidth + 0.75, halfWidth - 0.75, length(p - start));
        float body = arcMask(a01, f, d, halfWidth, radii[i]);
        float m = max(body, max(capH, capS));
        if (m <= 0.0) { continue; }
        float along = clamp(a01 / f, 0.0, 1.0);
        if (capS > body && a01 > 0.5) { along = 0.0; }
        half4 col = mix(froms[i], tos[i], half(along));
        // Light travelling toward the head, once every few seconds, slower on inner rings.
        float pulse = fract(time * (0.22 - 0.04 * float(i)) + float(i) * 0.31);
        float glow = exp(-pow((along - pulse) * 9.0, 2.0)) * 0.35;
        // A little shading across the band so it reads as a rounded tube.
        float across = (r - radii[i]) / halfWidth;
        float tube = 1.0 - 0.18 * across * across;
        col.rgb = col.rgb * half(tube) + half(glow);
        out = mix(out, half4(col.rgb, 1.0h), half(m));
    }
    return out;
}

// MARK: - Layered liquid
//
// Sleep as sediment in a glass: four layers from the bottom (deep, REM, light, awake), each as thick
// as its share of the night, filled to `level`. The top surface tilts and sloshes like `noopLiquid`;
// the boundaries between layers move far less, as a denser liquid would. `b1…b3` are the cumulative
// fractions of the fill at which each layer ends.

[[ stitchable ]]
half4 noopLayeredLiquid(float2 position, half4 color, float2 size, float time, float level,
                        float tilt, float slosh, float b1, float b2, float b3,
                        half4 c0, half4 c1, half4 c2, half4 c3) {
    float2 uv = position / size;
    float x = uv.x - 0.5;
    float wave = slosh * (0.03 * sin(x * 9.0 + time * 3.0) + 0.015 * sin(x * 17.0 - time * 4.1))
               + 0.004 * sin(x * 6.0 + time * 1.2);
    float surface = 1.0 - level + tilt * x + wave;
    float d = uv.y - surface;
    if (d < -0.012) { return half4(0); }

    // Height above the floor as a fraction of the fill, with damped boundary motion.
    float inner = tilt * x * 0.85 + wave * 0.25;
    float h = (1.0 - uv.y + inner) / max(level, 0.001);
    half4 c = h < b1 ? c0 : (h < b2 ? c1 : (h < b3 ? c2 : c3));
    // A soft seam where two layers meet.
    float seam = min(min(abs(h - b1), abs(h - b2)), abs(h - b3)) * level * size.y;
    c.rgb = mix(c.rgb, c.rgb * 1.25h, half(exp(-seam * seam / 6.0) * 0.6));
    // Darker toward the floor, lit along the surface.
    c.rgb *= half(0.72 + 0.28 * clamp(h, 0.0, 1.0));
    float men = smoothstep(-0.012, 0.0, d) * (1.0 - smoothstep(0.0, 0.018, d));
    c.rgb += half3(0.7, 0.8, 1.0) * half(men * 0.8);
    float alpha = smoothstep(-0.012, 0.004, d);
    return half4(c.rgb * half(alpha), half(alpha));
}

// MARK: - Heat
//
// Strain as heat inside a disc: tongues of light rise from the bottom as high as `level` (0…1),
// licking upward on noise, cool amber at the crown and white-hot at the base where the day's effort
// is densest. Outside the disc nothing is drawn.

[[ stitchable ]]
half4 noopHeat(float2 position, half4 color, float2 size, float time, float level) {
    float2 uv = position / size;
    float2 p = uv * 2.0 - 1.0;
    float r = length(p);
    float inside = smoothstep(1.0, 0.97, r);
    if (inside <= 0.0) { return half4(0); }

    float y = 1.0 - uv.y;                         // 0 at the bottom of the disc
    float n = fbm(float2(uv.x * 3.0, y * 2.2 - time * 0.55));
    float n2 = fbm(float2(uv.x * 6.5 + 7.0, y * 4.0 - time * 0.9));
    float crown = level * (0.92 + 0.22 * (n - 0.5)) + 0.05 * (n2 - 0.5);
    float body = smoothstep(crown + 0.06, crown - 0.05, y);
    float heat = clamp(1.0 - y / max(crown, 0.05), 0.0, 1.0);

    half3 ember = half3(0.95, 0.36, 0.12);
    half3 flame = half3(1.00, 0.66, 0.24);
    half3 hot   = half3(1.00, 0.93, 0.78);
    half3 c = heat < 0.55 ? mix(ember, flame, half(heat / 0.55)) : mix(flame, hot, half((heat - 0.55) / 0.45));
    float flicker = 0.8 + 0.35 * n2;
    float a = body * inside * clamp(0.35 + heat * 0.75, 0.0, 1.0) * flicker;
    return half4(c * half(a), half(a));
}
