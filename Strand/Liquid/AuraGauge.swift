import SwiftUI
import StrandDesign

// MARK: - AuraGauge — the "body state" hero
//
// A tick ring around a breathing orb, ported from the Aura · dark direction in the Noop design project.
//
// The idea it carries, and the reason it is not just another ring: the headline is a STATE, not a score.
// A number in a ring invites arithmetic — "is 62 good?" — which is the question a wearer is least equipped
// to answer, because the scale is arbitrary and personal. The orb answers "how is my body right now" as a
// colour and a word, and demotes the digits to a chip. The ticks still carry the magnitude for anyone who
// wants it, but they read as a gauge sweep rather than a percentage.
//
// Geometry is the design's, verbatim: 41 ticks over a 250° span starting at -125°, every fifth tick major
// (15pt vs 9pt), the lit run ramping 0.32 → 1.0 opacity toward the marker so the sweep has direction, and
// a triangular marker sitting just inside the ring at the current value.
struct AuraGauge: View {

    /// 0...1 — where the sweep stops. nil renders the unlit ring (no data yet), never a zeroed one, so a
    /// cold start reads as "nothing measured" rather than "your body is at rock bottom".
    let fraction: Double?
    let tint: Color
    /// Breathing is the whole point of the orb, but it is also the one thing on this screen that animates
    /// forever. Off for Reduce Motion, and off until data lands so the first paint is still.
    var animated: Bool = true

    private static let tickCount = 41
    private static let span: Double = 250
    private static let start: Double = -125
    private static let ringDiameter: CGFloat = 270
    private static let tickRadius: CGFloat = 124
    private static let markerRadius: CGFloat = 113
    private static let orbDiameter: CGFloat = 134
    private static let glowDiameter: CGFloat = 214

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private var breathes: Bool { animated && !reduceMotion }
    private var frac: Double { min(max(fraction ?? 0, 0), 1) }
    /// Index of the last lit tick. -1 when there is no reading, which lights none of them.
    private var activeIdx: Int {
        fraction == nil ? -1 : Int((frac * Double(Self.tickCount - 1)).rounded())
    }

    var body: some View {
        ZStack {
            ForEach(0..<Self.tickCount, id: \.self) { tick($0) }
            if fraction != nil { marker }

            // Glow and orb breathe on the SAME 6s cycle but different amplitudes (1.11 vs 1.055), which is
            // what stops it reading as a single pulsing blob — the halo leads and the core follows.
            Circle()
                .fill(tint.opacity(0.22))
                .frame(width: Self.glowDiameter, height: Self.glowDiameter)
                .blur(radius: 26)
                .scaleEffect(breathing ? 1.11 : 1.0)
                .opacity(breathing ? 1.0 : 0.72)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [tint.opacity(0.95), tint.opacity(0.55), tint.opacity(0.22)],
                        center: .init(x: 0.38, y: 0.32),
                        startRadius: 2,
                        endRadius: Self.orbDiameter * 0.72
                    )
                )
                .overlay(
                    // The slow sheen sweeping the orb. `.overlay` blend rather than a second animated
                    // layer: it costs one composite instead of a second 24s clock.
                    Circle().stroke(Color.white.opacity(0.16), lineWidth: 0.5)
                )
                .frame(width: Self.orbDiameter, height: Self.orbDiameter)
                .shadow(color: tint.opacity(0.45), radius: 24)
                .scaleEffect(breathing ? 1.055 : 1.0)
        }
        .frame(width: Self.ringDiameter, height: Self.ringDiameter)
        .animation(breathes ? .easeInOut(duration: 3).repeatForever(autoreverses: true) : nil,
                   value: breathing)
        .onAppear { if breathes { breathing = true } }
        .onChangeCompat(of: animated) { on in breathing = on && !reduceMotion }
        .accessibilityHidden(true)   // the caller states the score and its word
    }

    private func tick(_ i: Int) -> some View {
        let angle = Self.start + (Double(i) / Double(Self.tickCount - 1)) * Self.span
        let major = i % 5 == 0
        let lit = i <= activeIdx
        // Ramp the lit run toward the marker so the sweep reads as filling INTO the current value rather
        // than as a uniform bar. Guarded against activeIdx == 0 (a near-zero score lights one tick).
        let ramp = activeIdx > 0 ? 0.32 + 0.68 * (Double(i) / Double(activeIdx)) : 1.0
        return RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(lit ? tint.opacity(ramp) : Color.white.opacity(0.13))
            .frame(width: 2, height: major ? 15 : 9)
            .offset(y: -Self.tickRadius)
            .rotationEffect(.degrees(angle))
    }

    private var marker: some View {
        Triangle()
            .fill(StrandPalette.textPrimary)
            .frame(width: 12, height: 9)
            .shadow(color: .black.opacity(0.5), radius: 6)
            .offset(y: -Self.markerRadius)
            .rotationEffect(.degrees(Self.start + frac * Self.span))
    }
}

/// The gauge marker. A three-point path rather than an SF Symbol so it scales cleanly at 9pt and carries
/// no font metrics — the design's `border-*` triangle has no symbol equivalent.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
