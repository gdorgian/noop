import Foundation

/// Presentation-only comparison of a fully loaded, displayed night. Five minutes is a
/// notification threshold, not an accuracy claim. Stage redistribution alone stays quiet.
/// Keep the baseline across smaller changes so cumulative drift can cross the threshold.
struct SleepResultSnapshot: Equatable {
    let scope: String
    let onset: Int
    let wake: Int
    let asleepMinutes: Double
    let edited: Bool
}

struct SleepResultChangeTracker {
    private var baseline: SleepResultSnapshot?

    mutating func observe(_ next: SleepResultSnapshot?, ready: Bool) -> Bool {
        guard ready else { return false }
        guard let next else { baseline = nil; return false }
        guard let previous = baseline, previous.scope == next.scope,
              !previous.edited, !next.edited else {
            baseline = next
            return false
        }
        let changed = abs(next.onset - previous.onset) >= 300
            || abs(next.wake - previous.wake) >= 300
            || abs(next.asleepMinutes - previous.asleepMinutes) >= 5
        if changed { baseline = next }
        return changed
    }
}
