import XCTest
@testable import Strand

final class SleepResultChangeTests: XCTestCase {
    func testResultChangeOracle() {
        var tracker = SleepResultChangeTracker()
        func sample(_ scope: String = "strap:source:night", _ onset: Int = 1000,
                    _ wake: Int = 30000, _ asleep: Double = 420, _ edited: Bool = false) -> SleepResultSnapshot {
            SleepResultSnapshot(scope: scope, onset: onset, wake: wake, asleepMinutes: asleep, edited: edited)
        }
        var actual: [Bool] = []
        func observe(_ snapshot: SleepResultSnapshot?, _ ready: Bool = true) {
            actual.append(tracker.observe(snapshot, ready: ready))
        }
        observe(sample()) // First display.
        observe(sample()) // Unrelated pass, same displayed result.
        observe(sample("strap:source:night", 1060, 30060, 421)) // One-minute shift.
        observe(sample("strap:source:night", 1299, 30299, 424.99)) // Below threshold.
        observe(sample("strap:source:night", 1300)) // Cumulative onset threshold.
        observe(sample("strap:source:night", 1300)) // Same result does not re-announce.
        observe(sample("strap:source:night", 1300, 30300), false) // In-progress write.
        observe(sample("strap:source:night", 1300, 30300)) // Completed wake change.
        observe(sample("strap:source:night", 1300, 30300, 425)) // Total asleep.
        observe(sample("strap:source:night", 1300, 30300, 420)) // Decrease also matters.
        observe(sample("other-night")) // Navigation/new night.
        observe(sample("other-strap")) // Device/source change.
        observe(sample("other-strap", 2000, 31000, 430, true)) // Manual edit.
        observe(sample("other-strap", 3000, 32000, 440, true))
        observe(nil) // No visible night resets baseline.
        observe(sample())
        XCTAssertEqual(actual, [false, false, false, false, true, false, false, true,
                                true, true, false, false, false, false, false, false])
    }
}
