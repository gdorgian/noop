import CoreHaptics
import SwiftUI

// MARK: - Surface wave
//
// Dropping a section, or saving a page, moves the page itself like water taking a drop. Nothing is
// drawn: the section that landed squashes and rebounds, and a wave runs out from its edges through
// the sections around it, each nudged away and springing back as the wave reaches it, the nearest
// first and hardest, the farthest last and faintest. The phone feels the drop, then the rings.

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

/// The drop, felt: one firm, slightly soft hit, a low swell under it, then softer taps as each ring
/// passes, fading with the picture.
enum NoopDropHaptic {
    @MainActor private static var engine: CHHapticEngine?

    /// `strength` scales every part of it: 1 for a save, less for a section set down.
    @MainActor
    static func play(strength: Float = 1) {
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
            try engine?.makePlayer(with: pattern(strength)).start(atTime: CHHapticTimeImmediate)
        } catch {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
    }

    private static func pattern(_ strength: Float) throws -> CHHapticPattern {
        func tap(_ time: TimeInterval, _ intensity: Float, _ sharpness: Float) -> CHHapticEvent {
            CHHapticEvent(eventType: .hapticTransient, parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity * strength),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
            ], relativeTime: time)
        }
        let swell = CHHapticEvent(eventType: .hapticContinuous, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.45 * strength),
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
