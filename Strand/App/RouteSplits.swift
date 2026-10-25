import Foundation

/// Kilometre splits from a recorded route's timed points: how long each whole kilometre took, and the
/// part-kilometre at the end. Pure, so it is tested without a route on a phone.
///
/// The points carry wall-clock times, and a paused session leaves a gap in them with no movement across
/// it. A gap longer than `pauseGapSec` covering less than `pauseGapMeters` is taken as that pause and not
/// counted — otherwise a coffee stop would read as the slowest kilometre of the run.
enum RouteSplits {
    struct Split: Equatable {
        /// 1-based kilometre.
        let index: Int
        /// The distance this split covers: 1000 m, or less for the last one.
        let meters: Double
        let seconds: Double

        /// Seconds per kilometre.
        var pace: Double { meters > 0 ? seconds / (meters / 1000) : 0 }
    }

    static let pauseGapSec = 20.0
    static let pauseGapMeters = 20.0

    static func splits(_ points: [WorkoutRoutePoint], every unit: Double = 1000) -> [Split] {
        guard points.count >= 2, unit > 0 else { return [] }
        var out: [Split] = []
        var covered = 0.0          // metres into the current split
        var elapsed = 0.0          // active seconds into the current split
        for i in 1..<points.count {
            let a = points[i - 1], b = points[i]
            var leg = RouteMath.haversineMeters(.init(a.lat, a.lon), .init(b.lat, b.lon))
            var dt = Double(b.tMs - a.tMs) / 1000
            guard dt > 0, leg.isFinite else { continue }
            if dt > pauseGapSec && leg < pauseGapMeters { continue }
            // A leg can finish a split part-way: share its time in proportion to the distance.
            while covered + leg >= unit {
                let need = unit - covered
                let share = dt * need / leg
                out.append(Split(index: out.count + 1, meters: unit, seconds: elapsed + share))
                leg -= need; dt -= share
                covered = 0; elapsed = 0
            }
            covered += leg
            elapsed += dt
        }
        // The part-kilometre at the end, when it is long enough to say something.
        if covered >= 100 {
            out.append(Split(index: out.count + 1, meters: covered, seconds: elapsed))
        }
        return out
    }
}
