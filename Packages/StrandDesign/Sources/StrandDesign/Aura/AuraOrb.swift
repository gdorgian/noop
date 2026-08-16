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

    /// - Parameters:
    ///   - state: the body state to render — drives colour, glow and the marker's position together.
    ///   - poseStill: pass `NoopMotionState.shared.poseStill(reduceMotion)` from the hosting view. The
    ///     host must read `\.accessibilityReduceMotion` itself; the environment is the only place SwiftUI
    ///     publishes it, and reading it imperatively here would not invalidate on a settings change.
    public init(state: AuraBodyState, poseStill: Bool) {
        self.state = state
        self.poseStill = poseStill
    }

    /// Drives the breath. Starts at rest so a posed-still render is the resting frame.
    @State private var breathing = false

    private static let orbSize: CGFloat = 134
    private static let glowSize: CGFloat = 214
    /// How far the orb swells at the top of a breath. Small — this should be felt, not watched.
    private static let breathScale: CGFloat = 1.055
    /// The halo swells further and fades as it goes, so the bloom reads as expanding rather than pumping.
    private static let glowScale: CGFloat = 1.11

    public var body: some View {
        ZStack {
            tickRing
            glow
            orb
            sheen
        }
        .frame(width: AuraGaugeMath.ringSize, height: AuraGaugeMath.ringSize)
        // The orb is decorative; the state it encodes is announced by the label beneath it, so
        // duplicating it here would make VoiceOver read the same verdict twice.
        .accessibilityHidden(true)
        .onAppear {
            guard !poseStill else { return }
            withAnimation(.easeInOut(duration: AuraPalette.breathDuration).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .onChangeCompat(of: poseStill) { still in
            if still {
                // Settle to the resting frame in one breath rather than snapping mid-swell.
                withAnimation(.easeInOut(duration: 0.3)) { breathing = false }
            } else {
                withAnimation(.easeInOut(duration: AuraPalette.breathDuration).repeatForever(autoreverses: true)) {
                    breathing = true
                }
            }
        }
    }

    // MARK: Ring

    private var tickRing: some View {
        let active = AuraGaugeMath.activeIndex(fraction: state.gaugeFraction)
        return ZStack {
            ForEach(0..<AuraGaugeMath.tickCount, id: \.self) { i in
                tick(at: i, activeIndex: active)
            }
            marker
        }
        // The lit arc grows to its new length when the state changes, rather than cutting.
        .animation(NoopMotion.value, value: state)
    }

    private func tick(at index: Int, activeIndex: Int) -> some View {
        let isLit = index <= activeIndex
        let length = AuraGaugeMath.isMajor(tick: index) ? AuraGaugeMath.majorTickLength : AuraGaugeMath.minorTickLength
        return Capsule(style: .continuous)
            .fill(isLit ? state.accent : AuraPalette.track)
            .frame(width: AuraGaugeMath.tickWidth, height: length)
            .opacity(AuraGaugeMath.opacity(forTick: index, activeIndex: activeIndex))
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
            .rotationEffect(.degrees(AuraGaugeMath.markerAngle(fraction: state.gaugeFraction)))
    }

    // MARK: Orb

    private var glow: some View {
        Circle()
            .fill(
                // The halo is the orb's own light, so it wears the body temperature — NOT the fixed
                // chrome accent, which would leave a blue glow around a clay sphere.
                RadialGradient(
                    stops: [
                        .init(color: state.orbTint.opacity(state.glowOpacity), location: 0),
                        .init(color: state.orbTint.opacity(0), location: 0.68),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: Self.glowSize / 2
                )
            )
            .frame(width: Self.glowSize, height: Self.glowSize)
            .scaleEffect(breathing ? Self.glowScale : 1)
            .opacity(breathing ? 0.42 : 0.72)
            .blur(radius: 6)
    }

    private var orb: some View {
        let shadow = state.orbShadow
        return Circle()
            .fill(
                RadialGradient(
                    stops: state.orbStops,
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
            .scaleEffect(breathing ? Self.breathScale : 1)
    }

    /// A soft specular arc drifting around the orb, so a still sphere still has life in it.
    private var sheen: some View {
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
            .rotationEffect(.degrees(breathing ? 360 : 0))
            .animation(
                poseStill ? nil : .linear(duration: AuraPalette.sheenDuration).repeatForever(autoreverses: false),
                value: breathing
            )
            .scaleEffect(breathing ? Self.breathScale : 1)
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
