import CoreHaptics
import SwiftUI

// MARK: - Drop ripple
//
// Saving a page lands like a drop in a bowl of water: the surface dips under the drop and rebounds a
// few times, settling, while rings of light run out from where it fell and fade as they spread. The
// phone feels the drop and then each ring. Drawn with SwiftUI alone, so building the app needs no
// shader toolchain.

struct NoopDropRipple: ViewModifier {
    /// Each change sends one drop.
    var trigger: Int
    /// Where it lands, in the modified view's own coordinates.
    var origin: CGPoint

    static let duration: TimeInterval = 2.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, elapsed in
                view.modifier(NoopRippleFrame(origin: origin, elapsed: elapsed))
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(Self.duration, duration: Self.duration)
            }
        }
    }
}

private struct NoopRippleFrame: ViewModifier {
    var origin: CGPoint
    var elapsed: TimeInterval

    /// Rings leave the drop one after another and travel at this many points a second.
    private static let ringDelays: [Double] = [0, 0.12, 0.25, 0.4]
    private static let speed: Double = 620

    private var running: Bool { elapsed > 0 && elapsed < NoopDropRipple.duration }

    /// The surface's give: a dip, then smaller rebounds.
    private var give: Double { running ? -0.026 * sin(12 * elapsed) * exp(-2.8 * elapsed) : 0 }

    func body(content: Content) -> some View {
        content
            .visualEffect { view, proxy in
                view.scaleEffect(1 + give, anchor: UnitPoint(x: origin.x / max(1, proxy.size.width),
                                                             y: origin.y / max(1, proxy.size.height)))
            }
            .overlay {
                if running {
                    Canvas { context, size in
                        context.blendMode = .plusLighter
                        let reach = Double(max(size.width, UIScreen.main.bounds.height))
                        // The splash where it fell.
                        let splash = max(0, 1 - elapsed / 0.35)
                        if splash > 0 {
                            let r = 18 + 40 * (1 - splash)
                            context.fill(Path(ellipseIn: CGRect(x: origin.x - r, y: origin.y - r, width: 2 * r, height: 2 * r)),
                                         with: .radialGradient(Gradient(colors: [.white.opacity(0.4 * splash), .clear]),
                                                               center: origin, startRadius: 0, endRadius: r))
                        }
                        for (i, delay) in Self.ringDelays.enumerated() {
                            let t = elapsed - delay
                            guard t > 0 else { continue }
                            let radius = Self.speed * t * (1 - 0.18 * min(1, t))
                            let fade = exp(-1.7 * t) * max(0, 1 - radius / reach) * (1 - 0.18 * Double(i))
                            guard fade > 0.01 else { continue }
                            let ring = Path(ellipseIn: CGRect(x: origin.x - radius, y: origin.y - radius,
                                                              width: 2 * radius, height: 2 * radius))
                            var glow = context
                            glow.addFilter(.blur(radius: 6 + 10 * t))
                            glow.stroke(ring, with: .color(.white.opacity(0.55 * fade)), lineWidth: 12 + 16 * t)
                            context.stroke(ring, with: .color(.white.opacity(0.85 * fade)), lineWidth: 2)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

/// The drop, felt: one firm, slightly soft hit, a low swell under it, then softer taps as each ring
/// passes, fading with the picture.
enum NoopDropHaptic {
    @MainActor private static var engine: CHHapticEngine?

    @MainActor
    static func play() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            return
        }
        do {
            if engine == nil {
                let made = try CHHapticEngine()
                made.isAutoShutdownEnabled = true
                made.resetHandler = { [weak made] in try? made?.start() }
                engine = made
            }
            try engine?.start()
            try engine?.makePlayer(with: pattern()).start(atTime: CHHapticTimeImmediate)
        } catch {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private static func pattern() throws -> CHHapticPattern {
        func tap(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ], relativeTime: time)
        }
        let swell = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.08)
        ], relativeTime: 0.02, duration: 0.5)
        let fade = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: [
            .init(relativeTime: 0, value: 1), .init(relativeTime: 0.5, value: 0)
        ], relativeTime: 0.02)
        let rings = [(0.16, 0.42), (0.31, 0.30), (0.48, 0.21), (0.67, 0.14), (0.88, 0.09)]
        let events = [tap(0, 0.95, 0.45), swell] + rings.map { tap($0.0, Float($0.1), 0.25) }
        return try CHHapticPattern(events: events, parameterCurves: [fade])
    }
}
