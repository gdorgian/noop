import SwiftUI

// MARK: - AuraOrb — the hero gauge
//
// A 1:1 transcription of the design's hero: a 41-tick sweep over 250°, a triangular marker, a blurred
// glow, and a breathing orb. Geometry is the design's verbatim (see `darkVals()` in Noop.dc.html):
//
//     const N = 41, SPAN = 250, START = -125;
//     tick i  → angle START + (i / (N-1)) * SPAN, height 15 when i % 5 == 0 else 9,
//               translateY(-124), lit when i <= activeIdx,
//               opacity lit ? 0.32 + 0.68 * (i / activeIdx) : 1
//     marker  → angle START + frac * SPAN, translateY(-113)
//     glow    → 214pt, blur 6, breatheSoft 6s (scale 1 → 1.11, opacity .72 → 1)
//     orb     → 134pt, breathe 6s (scale 1 → 1.055)
struct AuraOrb: View {

    /// 0...1. nil renders the ring unlit — a cold start reads as "nothing measured", never as a body
    /// at rock bottom, which is what a zeroed gauge would assert.
    let fraction: Double?
    let accent: Color
    /// Held still until data lands, and for Reduce Motion. This is the only thing on the screen that
    /// animates indefinitely, so it is also the only thing that has to justify itself.
    var animated: Bool = true

    private static let tickCount = 41
    private static let span: Double = 250
    private static let start: Double = -125
    private static let ring: CGFloat = 270
    private static let tickRadius: CGFloat = 124
    private static let markerRadius: CGFloat = 113
    private static let glowSize: CGFloat = 214
    private static let orbSize: CGFloat = 134

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private var breathes: Bool { animated && !reduceMotion }
    private var frac: Double { min(max(fraction ?? 0, 0), 1) }
    private var activeIdx: Int {
        fraction == nil ? -1 : Int((frac * Double(Self.tickCount - 1)).rounded())
    }

    var body: some View {
        ZStack {
            ForEach(0..<Self.tickCount, id: \.self) { tick($0) }
            if fraction != nil { marker }

            // Glow and orb share the 6s cycle at different amplitudes (1.11 vs 1.055) so the halo leads
            // and the core follows — one amplitude for both reads as a single pulsing blob.
            Circle()
                .fill(RadialGradient(colors: [accent.opacity(0.44), accent.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: Self.glowSize * 0.34))
                .frame(width: Self.glowSize, height: Self.glowSize)
                .blur(radius: 6)
                .scaleEffect(breathing ? 1.11 : 1.0)
                .opacity(breathing ? 1.0 : 0.72)

            Circle()
                .fill(RadialGradient(colors: [accent.opacity(0.98), accent, accent.opacity(0.42)],
                                     center: .init(x: 0.38, y: 0.32),
                                     startRadius: 2, endRadius: Self.orbSize * 0.78))
                .frame(width: Self.orbSize, height: Self.orbSize)
                // The design's `box-shadow: 0 18px 52px <accent .55>` — the orb sits above the page and
                // spills onto it, which is most of why it reads as a light source rather than a disc.
                .shadow(color: accent.opacity(0.55), radius: 26, y: 18)
                .scaleEffect(breathing ? 1.055 : 1.0)

            // The slow conic sheen (`drift 24s linear`, mix-blend overlay). Stops are explicit and BOTH
            // ends are fully clear: an evenly-spread three-colour angular gradient wraps from its last
            // stop straight back to its first, and any opacity difference across that join renders as a
            // hard radial seam across the orb. Blurred as well, because a conic ramp on a 134pt circle
            // bands visibly without it.
            Circle()
                .fill(AngularGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0.00),
                        .init(color: .white.opacity(0.34), location: 0.29),
                        .init(color: .white.opacity(0), location: 0.58),
                        .init(color: .white.opacity(0), location: 1.00),
                    ],
                    center: .center, angle: .degrees(200)))
                .frame(width: Self.orbSize, height: Self.orbSize)
                .blur(radius: 8)
                .blendMode(.overlay)
                .scaleEffect(breathing ? 1.055 : 1.0)
        }
        .frame(width: Self.ring, height: Self.ring)
        .animation(breathes ? .easeInOut(duration: 3).repeatForever(autoreverses: true) : nil,
                   value: breathing)
        .onAppear { if breathes { breathing = true } }
        .accessibilityHidden(true)
    }

    private func tick(_ i: Int) -> some View {
        let angle = Self.start + (Double(i) / Double(Self.tickCount - 1)) * Self.span
        let lit = i <= activeIdx
        // Ramp toward the marker so the sweep reads as filling INTO the value rather than as a uniform
        // bar. Guarded for activeIdx == 0, where a near-zero charge lights exactly one tick.
        let ramp = activeIdx > 0 ? 0.32 + 0.68 * (Double(i) / Double(activeIdx)) : 1.0
        return RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(lit ? accent.opacity(ramp) : Color.white.opacity(0.13))
            .frame(width: 2, height: i % 5 == 0 ? 15 : 9)
            .offset(y: -Self.tickRadius)
            .rotationEffect(.degrees(angle))
    }

    private var marker: some View {
        AuraMarker()
            .fill(Aura.ink)
            .frame(width: 12, height: 9)
            .shadow(color: .black.opacity(0.5), radius: 6)
            .offset(y: -Self.markerRadius)
            .rotationEffect(.degrees(Self.start + frac * Self.span))
    }
}

/// The gauge marker — the design's CSS `border-*` triangle, which has no SF Symbol equivalent and would
/// carry font metrics if faked with one.
struct AuraMarker: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
