#if !os(watchOS)
import SwiftUI

// MARK: - Aura orb + tick gauge
//
// The home screen's whole read, in one control: a breathing orb for how the body FEELS, ringed by a tick
// arc with a marker for where that sits against the user's own range. No number appears on either — that
// is the direction's central bet, and the reason the arc is an arc (two ends, a position) rather than a
// closed ring (a progress circle, which reads as a percentage even unlabelled).
//
// Motion is never-settling, so it consults the one gate every looping animation in the app consults:
// `NoopMotionState.poseStill(_:)` — system Reduce Motion, Low Power Mode, or the in-app quiet-motion
// preference. Posed still, the orb renders at its resting size with no breath and no sheen, which is also
// what a screenshot test or a launch-time render gets.

public struct AuraOrb: View {
    private let state: AuraBodyState
    private let poseStill: Bool
    private let available: Bool
    private let fraction: Double
    private let wakeFraction: Double

    /// - Parameters:
    ///   - state: the body state to render — drives colour, glow and the marker's position together.
    ///   - poseStill: pass `NoopMotionState.shared.poseStill(reduceMotion)` from the hosting view. The
    ///     host must read `\.accessibilityReduceMotion` itself; the environment is the only place SwiftUI
    ///     publishes it, and reading it imperatively here would not invalidate on a settings change.
    public init(
        state: AuraBodyState,
        poseStill: Bool,
        available: Bool = true,
        fraction: Double? = nil,
        wakeFraction: Double? = nil
    ) {
        self.state = state
        self.poseStill = poseStill
        self.available = available
        let resolved = AuraGaugeMath.clampFraction(fraction ?? state.gaugeFraction)
        self.fraction = resolved
        self.wakeFraction = max(resolved, AuraGaugeMath.clampFraction(wakeFraction ?? resolved))
    }

    private static let orbSize: CGFloat = 176
    private static let glowSize: CGFloat = 268
    private static let haloRingSize: CGFloat = 224
    private static let cycleDuration: Double = 16

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: poseStill)) { context in
            let phase = poseStill ? 0.125 : cyclePhase(at: context.date)
            ZStack {
                tickRing
                glow(scale: glowScale(at: phase), opacity: glowOpacity(at: phase))
                haloRing(scale: ringScale(at: phase), opacity: ringOpacity(at: phase))
                orb(scale: orbScale(at: phase))
                sheen(scale: orbScale(at: phase), angle: sheenAngle(at: context.date))
            }
        }
        .frame(width: AuraGaugeMath.ringSize, height: AuraGaugeMath.ringSize)
        // The orb is decorative; the state it encodes is announced by the label beneath it, so
        // duplicating it here would make VoiceOver read the same verdict twice.
        .accessibilityHidden(true)
    }

    // MARK: Ring

    private var tickRing: some View {
        let active = available ? AuraGaugeMath.activeIndex(fraction: fraction) : -1
        let wake = available ? AuraGaugeMath.activeIndex(fraction: wakeFraction) : -1
        return ZStack {
            ForEach(0..<AuraGaugeMath.tickCount, id: \.self) { i in
                tick(at: i, activeIndex: active, wakeIndex: wake)
            }
            if available { marker }
        }
        // The lit arc grows to its new length when the state changes, rather than cutting.
        .animation(NoopMotion.gated(NoopMotion.value, reduced: poseStill), value: state)
    }

    private func tick(at index: Int, activeIndex: Int, wakeIndex: Int) -> some View {
        let isLit = index <= activeIndex
        let isGhost = index > activeIndex && index <= wakeIndex
        let length = AuraGaugeMath.isMajor(tick: index) ? AuraGaugeMath.majorTickLength : AuraGaugeMath.minorTickLength
        return Capsule(style: .continuous)
            .fill(isLit ? orbTint : (isGhost ? Color(hex: "#9FE2FB").opacity(0.28) : Color.white.opacity(0.13)))
            .frame(width: AuraGaugeMath.tickWidth, height: length)
            .opacity(isLit ? AuraGaugeMath.opacity(forTick: index, activeIndex: activeIndex) : 1)
            .padding(.top, AuraGaugeMath.topInset(radius: AuraGaugeMath.tickRadius, length: length))
            // Pinning the tick to the top edge of a ring-sized box and rotating THAT box is what makes
            // the rotation happen about the ring's centre. Rotating the tick itself would spin it in place.
            .frame(width: AuraGaugeMath.ringSize, height: AuraGaugeMath.ringSize, alignment: .top)
            .rotationEffect(.degrees(AuraGaugeMath.angle(forTick: index)))
    }

    private var marker: some View {
        AuraMarker()
            .fill(AuraPalette.textPrimary)
            .frame(width: 12, height: 9)
            .shadow(color: .black.opacity(0.5), radius: 3)
            .padding(.top, AuraGaugeMath.topInset(radius: AuraGaugeMath.markerRadius, length: 9))
            .frame(width: AuraGaugeMath.ringSize, height: AuraGaugeMath.ringSize, alignment: .top)
            .rotationEffect(.degrees(AuraGaugeMath.markerAngle(fraction: fraction)))
    }

    // MARK: Orb

    private func glow(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(
                // The halo is the orb's own light, so it wears the body temperature — NOT the fixed
                // chrome accent, which would leave a blue glow around a clay sphere.
                RadialGradient(
                    stops: [
                        .init(color: orbTint.opacity(available ? state.glowOpacity : 0.2), location: 0),
                        .init(color: orbTint.opacity(0), location: 0.68),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: Self.glowSize / 2
                )
            )
            .frame(width: Self.glowSize, height: Self.glowSize)
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: 6)
    }

    private func haloRing(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .strokeBorder(Color(hex: "#9FE2FB").opacity(0.5), lineWidth: 1)
            .frame(width: Self.haloRingSize, height: Self.haloRingSize)
            .scaleEffect(scale)
            .opacity(available ? opacity : opacity * 0.35)
    }

    private func orb(scale: CGFloat) -> some View {
        let shadow: (color: Color, radius: CGFloat, y: CGFloat) = available
            ? state.orbShadow
            : (Color.black.opacity(0.32), 14, 8)
        return Circle()
            .fill(
                RadialGradient(
                    stops: orbStops,
                    center: UnitPoint(x: 0.38, y: 0.32),
                    startRadius: 0,
                    // CSS sizes a `radial-gradient(circle at 38% 32%, …)` to the farthest corner, which for
                    // that centre lands at ≈0.92 of the diameter. Matching it keeps the outermost stop at
                    // the sphere's edge instead of banding inside it.
                    endRadius: Self.orbSize * 0.92
                )
            )
            .frame(width: Self.orbSize, height: Self.orbSize)
            .shadow(color: shadow.color, radius: shadow.radius, x: 0, y: shadow.y)
            .scaleEffect(scale)
    }

    private var orbTint: Color {
        available ? state.orbTint : AuraPalette.textDim
    }

    private var orbStops: [Gradient.Stop] {
        guard available else {
            return [
                .init(color: Color.white.opacity(0.16), location: 0),
                .init(color: AuraPalette.textDim.opacity(0.6), location: 0.48),
                .init(color: AuraPalette.canvas, location: 1),
            ]
        }
        return state.orbStops
    }

    /// A soft specular arc drifting around the orb, so a still sphere still has life in it.
    private func sheen(scale: CGFloat, angle: Double) -> some View {
        Circle()
            .fill(
                AngularGradient(
                    stops: [
                        .init(color: .white.opacity(0), location: 0),
                        .init(color: .white.opacity(0.4), location: 0.29),
                        .init(color: .white.opacity(0), location: 0.58),
                        .init(color: .white.opacity(0), location: 1),
                    ],
                    center: .center,
                    angle: .degrees(200)
                )
            )
            .frame(width: Self.orbSize, height: Self.orbSize)
            .blendMode(.overlay)
            .rotationEffect(.degrees(angle))
            .scaleEffect(scale)
    }

    private func cyclePhase(at date: Date) -> Double {
        let elapsed = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Self.cycleDuration)
        return max(0, elapsed / Self.cycleDuration)
    }

    /// CSS handoff keyframes: inhale 0–25%, hold 25–50%, exhale 50–75%, hold 75–100%.
    private func boxValue(at phase: Double, low: CGFloat, high: CGFloat) -> CGFloat {
        switch phase {
        case 0..<0.25:
            return low + (high - low) * CGFloat(phase / 0.25)
        case 0.25..<0.5:
            return high
        case 0.5..<0.75:
            return high - (high - low) * CGFloat((phase - 0.5) / 0.25)
        default:
            return low
        }
    }

    private func orbScale(at phase: Double) -> CGFloat { boxValue(at: phase, low: 0.82, high: 1.16) }
    private func glowScale(at phase: Double) -> CGFloat { boxValue(at: phase, low: 0.86, high: 1.24) }
    private func ringScale(at phase: Double) -> CGFloat { boxValue(at: phase, low: 0.80, high: 1.32) }

    private func glowOpacity(at phase: Double) -> Double {
        Double(boxValue(at: phase, low: 0.32, high: 0.80))
    }

    private func ringOpacity(at phase: Double) -> Double {
        Double(boxValue(at: phase, low: 0.55, high: 0.12))
    }

    private func sheenAngle(at date: Date) -> Double {
        guard !poseStill else { return 0 }
        return date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: AuraPalette.sheenDuration)
            / AuraPalette.sheenDuration * 360
    }
}

// MARK: - Marker

/// The gauge's position marker: a triangle whose apex points outward through the tick ring.
public struct AuraMarker: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#if DEBUG
#Preview("Aura orb") {
    VStack(spacing: 24) {
        ForEach(AuraBodyState.allCases) { state in
            HStack(spacing: 20) {
                AuraOrb(state: state, poseStill: true)
                    .scaleEffect(0.62)
                    .frame(width: 168, height: 168)
                VStack(alignment: .leading, spacing: 6) {
                    Text(state.label)
                        .font(.system(size: 26, weight: .light, design: .rounded))
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(state.coaching)
                        .font(.system(size: 13))
                        .foregroundStyle(AuraPalette.textSecondary)
                }
            }
        }
    }
    .padding(24)
    .frame(width: 420)
    .background(AuraPalette.canvas)
}
#endif
#endif
