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
    float a = body * inside * clamp(0.35 + heat * 0.75, 0.0, 1.0) * flicker * smoothstep(0.0, 0.03, level);
    return half4(c * half(a), half(a));
}

// MARK: - Dusk backdrop
//
// The sky behind a score page's hero: a glow in the page's colour at the horizon, two ridges of
// hills in silhouette (far ones lighter, near ones darker), faint stars when `stars` > 0, all fading
// to nothing toward the bottom so the page's own colour takes over. The ridges drift a hair with
// `time`, so the scene is alive but never busy.

[[ stitchable ]]
half4 noopBackdrop(float2 position, half4 color, float2 size, float time, half4 sky, half4 ridge, float stars) {
    float2 uv = position / size;
    // Sky: the page colour, brightest at the horizon line.
    float horizon = 0.58;
    float glow = exp(-pow((uv.y - horizon) / 0.30, 2.0));
    // Dark at the top of the sky, lit toward the horizon, as at dusk.
    half3 c = sky.rgb * half((0.05 + 0.40 * glow) * (0.45 + 0.55 * smoothstep(0.0, horizon, uv.y)));
    // Stars in the upper sky.
    if (stars > 0.0) {
        // One possible star per 7-point cell, round, at a random spot in the cell.
        float2 g = floor(position / 7.0);
        float h = hash21(g);
        float2 at = (g + 0.2 + 0.6 * float2(hash21(g + 3.1), hash21(g + 5.7))) * 7.0;
        float dot = smoothstep(1.1, 0.2, length(position - at));
        float tw = 0.55 + 0.45 * sin(time * (0.8 + 2.0 * hash21(g + 7.0)) + h * 40.0);
        float star = step(0.93, h) * dot * tw * smoothstep(horizon, 0.05, uv.y) * stars * 0.8;
        c += half3(star);
    }
    // Far ridge, then near ridge.
    float far = horizon - 0.06 - 0.10 * fbm(float2(uv.x * 2.4 + time * 0.004, 1.7));
    float near = horizon + 0.04 - 0.14 * fbm(float2(uv.x * 1.6 - time * 0.006 + 9.0, 4.2));
    float inFar = smoothstep(far - 0.003, far + 0.003, uv.y);
    float inNear = smoothstep(near - 0.003, near + 0.003, uv.y);
    c = mix(c, ridge.rgb * 0.55h, half(inFar * 0.85));
    c = mix(c, ridge.rgb * 0.22h, half(inNear));
    // Fade out toward the bottom of the frame.
    float fade = 1.0 - smoothstep(0.62, 1.0, uv.y);
    return half4(c * half(fade), half(fade));
}

// MARK: - Bloom
//
// Recovery as a flower opening: `petals` soft petals around the centre, each as long as `level`
// lets it be, layered twice (the inner layer smaller and turned half a petal) and breathing very
// slowly. Light is brightest at each petal's spine and fades to its edge.

[[ stitchable ]]
half4 noopBloom(float2 position, half4 color, float2 size, float time, float level, half4 tint, half4 deep) {
    float2 p = (position - size * 0.5) / (min(size.x, size.y) * 0.5);
    float r = length(p);
    float a = atan2(p.y, p.x);
    float breathe = 1.0 + 0.025 * sin(time * 0.9);
    float petals = 9.0;
    half4 out = half4(0);
    for (int layer = 0; layer < 2; layer++) {
        float turn = float(layer) * (M_PI_F / petals) + time * (layer == 0 ? 0.02 : -0.03);
        float reach = (0.28 + 0.66 * level) * (layer == 0 ? 1.0 : 0.68) * breathe;
        float shape = pow(abs(cos((a + turn) * petals * 0.5)), 0.65);
        float edge = reach * (0.55 + 0.45 * shape);
        float inside = smoothstep(edge + 0.012, edge - 0.012, r);
        float spine = pow(shape, 6.0) * (1.0 - r / max(edge, 0.001));
        half3 c = mix(deep.rgb, tint.rgb, half(clamp(0.25 + 0.75 * (r / max(edge, 0.001)) * 0.6 + spine * 0.6, 0.0, 1.0)));
        float alpha = inside * (layer == 0 ? 0.78 : 0.92);
        out = half4(mix(out.rgb, c, half(alpha)), max(out.a, half(alpha)));
    }
    // A soft core.
    float core = smoothstep(0.16, 0.0, r);
    out.rgb = mix(out.rgb, tint.rgb * 1.2h, half(core * 0.6));
    out.a = max(out.a, half(core * 0.6));
    return half4(out.rgb * out.a, out.a);
}

// MARK: - Scene
//
// The Bevel-style family's page backdrops: a painted landscape per page, drawn rather than shipped
// as artwork, so each is resolution-free and moves a little (stars, aurora, mist). Layers go back
// to front and take on the sky's colour with distance; the whole scene fades into the page below.
// kind: 0 Sleep (night cliffs and pines), 1 Recovery (aurora over meadow hills), 2 Strain (desert
// at dusk), 3 Trends (a lake at dawn), 4 You (rose hills at dusk).

static float fbm3(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 3; i++) { v += a * noise(p); p = p * 2.07 + 13.7; a *= 0.5; }
    return v;
}

/// Sharp-crested noise for rock: peaks where plain noise crosses its middle.
static float ridged(float2 p) {
    float v = 0.0, a = 0.55;
    for (int i = 0; i < 4; i++) {
        float n = 1.0 - abs(noise(p) * 2.0 - 1.0);
        v += a * n * n;
        p = p * 2.13 + 7.3;
        a *= 0.5;
    }
    return v;
}

static float sdCapsule(float2 p, float2 a, float2 b, float r) {
    float2 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

static float starField(float2 position, float time, float cell, float density) {
    float2 g = floor(position / cell);
    float h = hash21(g);
    float2 at = (g + 0.2 + 0.6 * float2(hash21(g + 3.1), hash21(g + 5.7))) * cell;
    float size = 0.5 + 0.9 * hash21(g + 9.3);
    float dot = smoothstep(size + 0.6, size * 0.3, length(position - at));
    float tw = 0.6 + 0.4 * sin(time * (0.6 + 1.8 * hash21(g + 7.0)) + h * 40.0);
    return step(1.0 - density, h) * dot * tw;
}

[[ stitchable ]]
half4 noopScene(float2 position, half4 color, float2 size, float time, float kind) {
    float2 uv = position / size;
    float x = uv.x, y = uv.y;
    int k = int(kind + 0.5);
    float drift = time * 0.004;

    // Palette: sky top, middle, horizon; the horizon's glow; far, middle and near land.
    float3 top, mid, low, glow, farC, midC, nearC;
    float horizon = 0.62;
    if (k == 0) {
        top = float3(0.03, 0.04, 0.12); mid = float3(0.10, 0.12, 0.33); low = float3(0.25, 0.27, 0.55);
        glow = float3(0.35, 0.38, 0.75);
        farC = float3(0.20, 0.21, 0.42); midC = float3(0.12, 0.12, 0.27); nearC = float3(0.05, 0.05, 0.12);
    } else if (k == 1) {
        top = float3(0.09, 0.08, 0.20); mid = float3(0.22, 0.18, 0.38); low = float3(0.55, 0.40, 0.52);
        glow = float3(0.80, 0.55, 0.55);
        farC = float3(0.30, 0.30, 0.42); midC = float3(0.16, 0.24, 0.22); nearC = float3(0.08, 0.14, 0.10);
    } else if (k == 2) {
        top = float3(0.14, 0.12, 0.26); mid = float3(0.33, 0.22, 0.40); low = float3(0.78, 0.47, 0.42);
        glow = float3(1.00, 0.62, 0.40);
        farC = float3(0.30, 0.25, 0.42); midC = float3(0.19, 0.15, 0.28); nearC = float3(0.08, 0.06, 0.12);
    } else if (k == 3) {
        top = float3(0.04, 0.10, 0.15); mid = float3(0.10, 0.25, 0.30); low = float3(0.36, 0.55, 0.52);
        glow = float3(0.70, 0.85, 0.70);
        farC = float3(0.18, 0.32, 0.35); midC = float3(0.10, 0.20, 0.22); nearC = float3(0.04, 0.09, 0.10);
        horizon = 0.57;
    } else {
        top = float3(0.12, 0.06, 0.12); mid = float3(0.30, 0.15, 0.25); low = float3(0.72, 0.42, 0.48);
        glow = float3(0.95, 0.62, 0.62);
        farC = float3(0.34, 0.22, 0.32); midC = float3(0.20, 0.12, 0.20); nearC = float3(0.09, 0.05, 0.09);
    }

    // Sky: dark overhead, lit toward the horizon, with a broad glow on it.
    float3 c = mix(top, mid, smoothstep(0.0, 0.32, y));
    c = mix(c, low, smoothstep(0.26, horizon, y));
    c += glow * 0.32 * exp(-pow((y - horizon) / 0.10, 2.0));

    // A light in the sky: the moon for Sleep, the low sun elsewhere.
    float2 lightAt = k == 0 ? float2(0.80, 0.27) : float2(k == 2 ? 0.32 : 0.62, horizon - 0.03);
    float2 d = (uv - lightAt) * float2(1.0, size.y / size.x);
    float r = length(d);
    if (k == 0) {
        c += float3(0.85, 0.88, 1.0) * smoothstep(0.022, 0.018, r);
        c += float3(0.45, 0.50, 0.85) * 0.35 * exp(-r * 9.0);
    } else {
        c += glow * 0.45 * exp(-r * 6.0);
    }

    // Stars: dense on the night, a few at dusk, none at dawn.
    float starDensity = k == 0 ? 0.10 : (k == 3 ? 0.0 : 0.035);
    if (starDensity > 0.0) {
        c += float3(starField(position, time, 6.0, starDensity)) * smoothstep(horizon - 0.05, 0.02, y) * 0.85;
    }

    // Aurora for Recovery: curtains hung in the upper sky, their lower hem brightest.
    if (k == 1) {
        float hem = 0.26 + 0.16 * fbm3(float2(x * 2.2 + time * 0.015, 2.0)) + 0.045 * sin(x * 6.5 + time * 0.2);
        float rays = fbm3(float2(x * 16.0 + hem * 6.0 + time * 0.06, y * 0.7));
        float rise = smoothstep(hem - 0.24, hem - 0.015, y) * smoothstep(hem + 0.035, hem - 0.01, y);
        float a = rise * (0.25 + 1.6 * rays * rays);
        float3 auroraC = mix(float3(0.25, 1.0, 0.60), float3(0.55, 0.40, 0.95), clamp((hem - y) / 0.26, 0.0, 1.0));
        c += auroraC * a * 0.55;
    }

    // Land, back to front. Each layer's top edge; nearer layers are darker and less hazy.
    float farEdge, midEdge, nearEdge;
    if (k == 0) {
        // A valley between granite walls: high at the sides, falling to the middle.
        float walls = pow(abs(x - 0.5) * 2.0, 1.6);
        farEdge = horizon - 0.04 - 0.10 * ridged(float2(x * 3.0 + 1.3, 0.5)) - 0.06 * walls;
        midEdge = horizon + 0.02 - 0.09 * ridged(float2(x * 2.2 + 4.1, 1.5)) - 0.20 * walls;
        nearEdge = horizon + 0.13 - 0.04 * fbm3(float2(x * 4.0 + 8.0, 2.5)) - 0.10 * walls;
    } else if (k == 2) {
        farEdge = horizon - 0.03 - 0.12 * ridged(float2(x * 2.6 + 2.0, 0.7));
        float m = fbm3(float2(x * 2.4 + 6.0, 1.1));
        // Mesas: flat tops with steep, slightly eroded sides.
        midEdge = horizon + 0.05 - 0.09 * smoothstep(0.44, 0.47, m + 0.02 * noise(float2(x * 40.0, 2.0)))
                  - 0.012 * fbm3(float2(x * 12.0, 4.0));
        nearEdge = horizon + 0.16 - 0.025 * fbm3(float2(x * 3.0 + 3.0, 3.3));
    } else {
        // Rolling hills.
        farEdge = horizon - 0.02 - 0.07 * fbm3(float2(x * 2.0 + 1.0 + drift, 0.3));
        midEdge = horizon + 0.04 - 0.07 * fbm3(float2(x * 1.6 + 5.0, 1.3));
        nearEdge = horizon + 0.12 - 0.08 * fbm3(float2(x * 1.3 + 9.0, 2.3));
    }
    // A fine broken edge, so ridgelines read as trees and rock rather than a cut line.
    float rough = (noise(float2(x * 160.0, 1.0)) - 0.5) * 0.004;
    float hazeC = 0.0;

    // Trends: a still lake under the horizon, mirroring the sky with slow ripples.
    if (k == 3 && y > horizon && y < midEdge + 0.10) {
        float my = 2.0 * horizon - y;
        float3 sky = mix(mid, low, smoothstep(0.26, horizon, my)) + glow * 0.30 * exp(-pow((my - horizon) / 0.10, 2.0));
        float ripple = sin(y * 900.0 + noise(float2(x * 30.0, y * 200.0)) * 6.0 + time * 0.8);
        c = sky * 0.75 + float3(0.04) * ripple * smoothstep(horizon, horizon + 0.08, y);
    }

    float inFar = smoothstep(farEdge - 0.002, farEdge + 0.002, y + rough);
    float3 farLand = mix(farC, low, 0.35);
    c = mix(c, farLand, inFar);
    // Mist pooled at the foot of the far layer.
    float mist = fbm3(float2(x * 3.0 + time * 0.012, y * 9.0)) * exp(-pow((y - (farEdge + 0.05)) / 0.035, 2.0));
    c = mix(c, low, clamp(mist * 0.55, 0.0, 1.0));

    if (k != 3) {
        float inMid = smoothstep(midEdge - 0.002, midEdge + 0.002, y + rough);
        float3 midLand = mix(midC, low, 0.12 + 0.20 * smoothstep(midEdge + 0.15, midEdge, y));
        c = mix(c, midLand, inMid);
        float mist2 = fbm3(float2(x * 4.0 - time * 0.01, y * 10.0)) * exp(-pow((y - (midEdge + 0.04)) / 0.03, 2.0));
        c = mix(c, low * 0.8, clamp(mist2 * 0.35, 0.0, 1.0));
    }

    float inNear = smoothstep(nearEdge - 0.002, nearEdge + 0.002, y + rough * 1.5);
    float3 nearLand = nearC * (0.85 + 0.3 * fbm3(float2(x * 8.0, y * 12.0)));
    // The sky's light catching the near crest.
    nearLand += low * 0.22 * exp(-max(0.0, y - nearEdge) / 0.006);
    c = mix(c, nearLand, inNear);

    // Things on the near layer.
    if (k == 0) {
        // Pines along the near ridge.
        float w = 0.032;
        float cellX = floor(x / w);
        for (int i = -1; i <= 1; i++) {
            float cx = (cellX + float(i) + 0.5 + 0.3 * (hash21(float2(cellX + float(i), 1.0)) - 0.5)) * w;
            if (hash21(float2(cellX + float(i), 2.0)) < 0.35) continue;
            float walls = pow(abs(cx - 0.5) * 2.0, 1.6);
            float base = horizon + 0.13 - 0.04 * fbm3(float2(cx * 4.0 + 8.0, 2.5)) - 0.10 * walls + 0.01;
            float h = 0.05 + 0.07 * hash21(float2(cellX + float(i), 3.0));
            float t = (y - (base - h)) / h;
            float tier = 0.75 + 0.25 * fract(t * 4.0);
            float halfW = 0.016 * t * tier * (h / 0.09);
            float tree = step(0.0, t) * step(t, 1.0) * smoothstep(halfW + 0.0015, halfW - 0.0015, abs(x - cx));
            c = mix(c, nearC * 0.6, tree);
        }
    } else if (k == 1 || k == 4) {
        // Wildflowers in the near meadow, smaller with distance.
        float depth = clamp((y - nearEdge) / 0.25, 0.0, 1.0);
        float cell = mix(5.0, 9.0, depth);
        float2 g = floor(position / cell);
        float h = hash21(g + 11.0);
        float2 at = (g + 0.5 + 0.35 * float2(hash21(g + 1.3) - 0.5, hash21(g + 2.9) - 0.5)) * cell;
        at.x += sin(time * 0.8 + h * 20.0) * 0.4;
        float petal = smoothstep(cell * 0.18, cell * 0.06, length(position - at));
        float3 flowerC = h > 0.97 ? float3(1.0, 0.75, 0.35) : (h > 0.94 ? float3(0.95, 0.92, 0.85) : float3(0.75, 0.55, 0.95));
        c = mix(c, flowerC * (0.45 + 0.45 * depth), petal * step(0.92, h) * inNear * smoothstep(0.0, 0.03, y - nearEdge));
    } else if (k == 2) {
        // Desert trees in silhouette: a trunk with raised arms, two near and one far.
        float aspect = size.y / size.x;
        float2 p = float2(x, y * aspect);
        float tree = 1e3;
        float2 roots[3] = { float2(0.84, nearEdge + 0.02), float2(0.95, nearEdge + 0.05), float2(0.12, nearEdge + 0.01) };
        float scales[3] = { 1.0, 0.75, 0.45 };
        for (int i = 0; i < 3; i++) {
            float s = scales[i];
            float2 b = float2(roots[i].x, roots[i].y * aspect);
            float2 fork = b - float2(0.0, 0.17 * s);
            tree = min(tree, sdCapsule(p, b, fork, 0.008 * s));
            tree = min(tree, sdCapsule(p, fork, fork + float2(-0.05, -0.07) * s, 0.006 * s));
            tree = min(tree, sdCapsule(p, fork, fork + float2(0.045, -0.09) * s, 0.006 * s));
            tree = min(tree, sdCapsule(p, fork + float2(0.02, -0.04) * s, fork + float2(0.07, -0.03) * s, 0.005 * s));
            // Spiky tufts at the tips.
            float2 tips[3] = { fork + float2(-0.05, -0.07) * s, fork + float2(0.045, -0.09) * s, fork + float2(0.07, -0.03) * s };
            for (int j = 0; j < 3; j++) {
                float2 q = p - tips[j];
                float ang = atan2(q.y, q.x);
                float spikes = 0.022 * s * (0.6 + 0.4 * abs(sin(ang * 9.0)));
                tree = min(tree, length(q) - spikes);
            }
        }
        c = mix(c, nearC * 0.55, smoothstep(0.0015, -0.0015, tree));
    }

    // Paint grain, and a soft fall-off into the page below.
    c += (hash21(position * 0.73) - 0.5) * 0.025;
    c *= 1.0 - 0.25 * pow(abs(x - 0.5) * 2.0, 2.5);
    float fade = 1.0 - smoothstep(0.76, 1.0, y);
    return half4(half3(c * fade), half(fade));
}
