import CoreHaptics
import SwiftUI

// MARK: - Surface wave
//
// Dropping a section, or saving a page, moves the page itself like water taking a drop. Nothing is
// drawn: the section that landed squashes and rebounds, and a wave runs out from its edges through
// the sections around it, each nudged away and springing back as the wave reaches it, the nearest
// first and hardest, the farthest last and faintest. The phone feels the drop, then the rings.

extension Notification.Name {
    /// Posted once, as first-run onboarding dissolves into the app: the page in view answers with a
    /// wave from its middle, as it does when a section lands.
    static let noopWelcomeWave = Notification.Name("noop.welcomeWave")
}

struct NoopSurfaceWave: Equatable {
    /// Where the drop landed, in the page's own coordinates; a zero-height rect for a point.
    var origin: CGRect
    /// Seconds to wait before the wave starts, so a dropped section settles into its place first.
    var delay: TimeInterval = 0
    /// The section that landed, which squashes rather than moving away.
    var source: String?

    static let duration: TimeInterval = 2.0
    /// Points a second the wave front travels, and how far the nearest section is pushed.
    private static let speed: Double = 900
    private static let push: Double = 18

    /// Where a section is `elapsed` seconds after the wave was sent.
    func motion(of id: String, frame: CGRect?, elapsed: TimeInterval) -> (dy: CGFloat, scale: CGFloat) {
        let t = elapsed - delay
        guard t > 0, t < Self.duration else { return (0, 1) }
        if id == source {
            return (0, 1 - 0.05 * sin(12 * t) * exp(-3.8 * t))
        }
        guard let frame else { return (0, 1) }
        let gap = Double(max(0, max(frame.minY - origin.maxY, origin.minY - frame.maxY)))
        let arrived = t - gap / Self.speed
        guard arrived > 0 else { return (0, 1) }
        let swing = sin(11 * arrived) * exp(-3.4 * arrived) / (1 + gap / 700)
        let away: Double = frame.midY >= origin.midY ? 1 : -1
        return (CGFloat(away * Self.push * swing), CGFloat(1 + 0.02 * swing))
    }
}

/// Noop's haptic language: one engine, one pattern per action, designed as a set. Each pattern has
/// a shape the hand can tell apart: a lift rises then catches, a pass is a crisp detent, a landing is
/// a soft thud whose aftershocks follow the wave through the page, a save is a drop into water with
/// ripples spreading and thinning, a removal is a small pop, an addition settles in.
@MainActor
enum NoopHaptics {
    enum Kind { case enterEdit, lift, pass, land, save, remove, add, cancel, edge, tick, grab, settle, anticipate, welcome }

    private static var engine: CHHapticEngine?
    private static var players: [Kind: CHHapticPatternPlayer] = [:]

    /// Starts the engine ahead of a burst of feedback (entering edit mode), so the first one is on time.
    static func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        if engine == nil {
            guard let made = try? CHHapticEngine() else { return }
            made.isAutoShutdownEnabled = true
            made.playsHapticsOnly = true
            made.resetHandler = { [weak made] in
                try? made?.start()
                Task { @MainActor in players = [:] }
            }
            made.stoppedHandler = { _ in Task { @MainActor in players = [:] } }
            engine = made
        }
        try? engine?.start()
    }

    static func play(_ kind: Kind) {
        guard !UIAccessibility.isReduceMotionEnabled || kind == .tick || kind == .pass else {
            // Reduce Motion keeps feedback, plainer.
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
            return
        }
        prepare()
        guard let engine else {
            UIImpactFeedbackGenerator(style: kind == .pass || kind == .tick ? .light : .medium).impactOccurred()
            return
        }
        do {
            let player = try players[kind] ?? engine.makePlayer(with: pattern(kind))
            players[kind] = player
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            players[kind] = nil
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private static func tap(_ t: TimeInterval, _ i: Float, _ s: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticTransient, parameters: [
            .init(parameterID: .hapticIntensity, value: i), .init(parameterID: .hapticSharpness, value: s)
        ], relativeTime: t)
    }

    private static func hum(_ t: TimeInterval, _ d: TimeInterval, _ i: Float, _ s: Float) -> CHHapticEvent {
        CHHapticEvent(eventType: .hapticContinuous, parameters: [
            .init(parameterID: .hapticIntensity, value: i), .init(parameterID: .hapticSharpness, value: s)
        ], relativeTime: t, duration: d)
    }

    private static func curve(_ id: CHHapticDynamicParameter.ID, at t: TimeInterval, _ points: [(TimeInterval, Float)]) -> CHHapticParameterCurve {
        CHHapticParameterCurve(parameterID: id, controlPoints: points.map { .init(relativeTime: $0.0, value: $0.1) }, relativeTime: t)
    }

    private static func pattern(_ kind: Kind) throws -> CHHapticPattern {
        switch kind {
        case .enterEdit:
            // Two light knocks: the page unlatching.
            return try CHHapticPattern(events: [tap(0, 0.42, 0.55), tap(0.075, 0.6, 0.7)], parameters: [])
        case .lift:
            // A short swell that rises, then catches as the section leaves the surface.
            return try CHHapticPattern(events: [hum(0, 0.11, 0.6, 0.25), tap(0.11, 0.75, 0.65)],
                                       parameterCurves: [curve(.hapticIntensityControl, at: 0, [(0, 0.25), (0.11, 1)])])
        case .pass:
            // A crisp detent each time the carried section takes a new place.
            return try CHHapticPattern(events: [tap(0, 0.5, 0.9)], parameters: [])
        case .tick:
            return try CHHapticPattern(events: [tap(0, 0.38, 0.8)], parameters: [])
        case .grab:
            // A chart taking hold under the finger: a soft swell that firms into a catch.
            return try CHHapticPattern(events: [hum(0, 0.06, 0.35, 0.3), tap(0.06, 0.55, 0.6)],
                                       parameterCurves: [curve(.hapticIntensityControl, at: 0, [(0, 0.3), (0.06, 1)])])
        case .settle:
            // A zoomed chart easing home: one low, rounded knock.
            return try CHHapticPattern(events: [tap(0, 0.5, 0.25), tap(0.07, 0.18, 0.3)], parameters: [])
        case .anticipate:
            // Squeezing the way in, like a hand gripper at its limit: once the orb has come to the
            // centre, a strained rumble that tightens over the squeeze (OnboardingFinaleScene), with a
            // fine, uneven tremble of light taps that comes faster and firmer, then one soft settle as
            // ENTER appears.
            var tremble: [CHHapticEvent] = []
            var t: TimeInterval = 1.0, step = 0.13
            while t < 3.3 {
                let strain = Float((t - 0.9) / 2.4)
                tremble.append(tap(t, 0.15 + 0.35 * strain, 0.85))
                // Uneven, like a shaking grip: alternate long and short gaps, both shrinking.
                step = max(0.035, step * 0.93)
                t += step * (tremble.count % 2 == 0 ? 1.3 : 0.7)
            }
            return try CHHapticPattern(events:
                [hum(0.9, 2.4, 0.7, 0.55)] + tremble + [tap(3.3, 0.5, 0.3)],
                parameterCurves: [
                    curve(.hapticIntensityControl, at: 0, [(0.9, 0.1), (3.3, 1)]),
                    curve(.hapticSharpnessControl, at: 0, [(0.9, -0.3), (3.3, 0.3)])
                ])
        case .welcome:
            // ENTER pressed, the grip let go: one big boom as everything bursts toward you, then sparks
            // crackling away as the pieces fly past.
            let sparks: [(TimeInterval, Float)] = [(0.1, 0.6), (0.17, 0.52), (0.25, 0.45), (0.33, 0.38),
                                                   (0.42, 0.31), (0.52, 0.25), (0.63, 0.19), (0.75, 0.14)]
            return try CHHapticPattern(events:
                [tap(0, 1, 0.65), hum(0, 0.35, 1, 0.45)]
                + sparks.map { tap($0.0, $0.1, 0.9) },
                parameterCurves: [
                    curve(.hapticIntensityControl, at: 0, [(0, 1), (0.35, 0.6), (0.8, 0.4)])
                ])
        case .edge:
            // The page starting to carry along: a soft, low push.
            return try CHHapticPattern(events: [hum(0, 0.14, 0.45, 0.1)],
                                       parameterCurves: [curve(.hapticIntensityControl, at: 0, [(0, 1), (0.14, 0)])])
        case .land:
            // A soft thud, then two aftershocks as the wave reaches the sections around it.
            return try CHHapticPattern(events: [
                tap(0, 0.95, 0.22), hum(0.005, 0.12, 0.55, 0.05),
                tap(0.12, 0.34, 0.35), tap(0.22, 0.18, 0.35)
            ], parameterCurves: [curve(.hapticIntensityControl, at: 0.005, [(0, 1), (0.12, 0)])])
        case .save:
            // A drop into water: the plop, a low swell beneath it, then ripples that spread further
            // apart and thinner as they go.
            let ripples: [(TimeInterval, Float, Float)] = [(0.13, 0.55, 0.45), (0.27, 0.4, 0.4), (0.44, 0.28, 0.35),
                                                          (0.64, 0.18, 0.3), (0.88, 0.1, 0.25)]
            return try CHHapticPattern(events: [tap(0, 1, 0.55), hum(0.01, 0.4, 0.65, 0.04)]
                                       + ripples.map { tap($0.0, $0.1, $0.2) },
                                       parameterCurves: [curve(.hapticIntensityControl, at: 0.01, [(0, 1), (0.1, 0.55), (0.4, 0)])])
        case .remove:
            // A small pop: sharp, then a lighter echo.
            return try CHHapticPattern(events: [tap(0, 0.72, 0.95), tap(0.045, 0.28, 0.6)], parameters: [])
        case .add:
            // Settling in: a brief rise that lands.
            return try CHHapticPattern(events: [hum(0, 0.09, 0.45, 0.3), tap(0.09, 0.65, 0.45)],
                                       parameterCurves: [curve(.hapticIntensityControl, at: 0, [(0, 0.2), (0.09, 1)])])
        case .cancel:
            return try CHHapticPattern(events: [tap(0, 0.45, 0.2)], parameters: [])
        }
    }
}
