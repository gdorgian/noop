import XCTest
@testable import Strand

/// A hand-set sleep need replaces the estimate; anything else falls back to it.
final class SleepNeedPrefsTests: XCTestCase {

    private func defaults(_ minutes: Int?) -> UserDefaults {
        let suite = "SleepNeedPrefsTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        if let minutes { d.set(minutes, forKey: SleepNeedPrefs.key) }
        return d
    }

    func testUnsetUsesTheEstimate() {
        XCTAssertEqual(SleepNeedPrefs.resolve(estimatedMinutes: 480, defaults(nil)), 480)
    }

    /// The reported case: a wearer who can only fit 6.5 h stops accruing debt against 8 h.
    func testHandSetNeedReplacesTheEstimate() {
        XCTAssertEqual(SleepNeedPrefs.resolve(estimatedMinutes: 480, defaults(390)), 390)
    }

    /// 0 is "use the estimate", the value the picker's reset writes.
    func testZeroMeansTheEstimate() {
        XCTAssertNil(SleepNeedPrefs.userMinutes(defaults(0)))
    }

    /// A corrupt stored value must never become a zero or absurd need.
    func testOutOfRangeIsIgnored() {
        XCTAssertNil(SleepNeedPrefs.userMinutes(defaults(30)))
        XCTAssertNil(SleepNeedPrefs.userMinutes(defaults(2_000)))
    }

    func testChoicesRunSixToNineHoursInHalfHours() {
        XCTAssertEqual(SleepNeedPrefs.choices.first, 360)
        XCTAssertEqual(SleepNeedPrefs.choices.last, 540)
        XCTAssertEqual(SleepNeedPrefs.choices.count, 7)
    }
}
