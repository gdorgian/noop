import XCTest
import StrandAnalytics
@testable import Strand

/// Pins the host-side seam that installs the wearer's awake window into the pure analytics package.
///
/// The precedence matters more than it looks: the schedule drives the daytime false-sleep guard (#90),
/// so a resolution bug does not produce a visible error — it silently stages the wearer's real sleep
/// under the wrong bar, or their sofa under the right one.
final class SleepSchedulePrefsTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        suiteName = "SleepSchedulePrefsTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        SleepSchedule.current = .dayWorker   // never leak a schedule into another test
    }

    func testUnsetDefaultsResolveToTheFallback() {
        XCTAssertEqual(SleepSchedulePrefs.resolve(defaults), SleepSchedulePrefs.fallback)
    }

    func testStoredHoursWin() {
        defaults.set(7, forKey: SleepSchedulePrefs.awakeStartKey)
        defaults.set(23, forKey: SleepSchedulePrefs.awakeEndKey)
        let resolved = SleepSchedulePrefs.resolve(defaults)
        XCTAssertEqual(resolved.awakeStartHour, 7)
        XCTAssertEqual(resolved.awakeEndHour, 23)
    }

    // `integer(forKey:)` returns 0 for a missing key, so it cannot tell "unset" from a stored 0 — and 0
    // is a legitimate hour. Resolution must use `object(forKey:)`, which this pins.
    func testStoredZeroHourIsHonouredNotTreatedAsUnset() {
        defaults.set(0, forKey: SleepSchedulePrefs.awakeStartKey)
        defaults.set(9, forKey: SleepSchedulePrefs.awakeEndKey)
        let resolved = SleepSchedulePrefs.resolve(defaults)
        XCTAssertEqual(resolved.awakeStartHour, 0)
        XCTAssertEqual(resolved.awakeEndHour, 9)
        XCTAssertNotEqual(resolved, SleepSchedulePrefs.fallback)
    }

    // Half-written defaults (one key set, the other not) must not build a half-schedule.
    func testPartiallyStoredScheduleFallsBack() {
        defaults.set(19, forKey: SleepSchedulePrefs.awakeStartKey)
        XCTAssertEqual(SleepSchedulePrefs.resolve(defaults), SleepSchedulePrefs.fallback)
    }

    // A corrupt stored value must not produce a degenerate band that matches nothing.
    func testCorruptStoredHoursFallBackToDayWorker() {
        defaults.set(99, forKey: SleepSchedulePrefs.awakeStartKey)
        defaults.set(-4, forKey: SleepSchedulePrefs.awakeEndKey)
        XCTAssertEqual(SleepSchedulePrefs.resolve(defaults), .dayWorker)
    }

    func testApplyInstallsTheResolvedSchedule() {
        defaults.set(21, forKey: SleepSchedulePrefs.awakeStartKey)
        defaults.set(8, forKey: SleepSchedulePrefs.awakeEndKey)
        SleepSchedulePrefs.apply(defaults)
        XCTAssertEqual(SleepStager.daytimeBandStartHour, 21)
        XCTAssertEqual(SleepStager.daytimeBandEndHour, 8)
        // …and the overnight band follows structurally.
        XCTAssertEqual(SleepStageTotals.overnightStartHour, 8)
        XCTAssertEqual(SleepStageTotals.overnightEndHour, 21)
    }

    func testStorePersistsAndInstallsImmediately() {
        SleepSchedulePrefs.store(SleepSchedule(awakeStartHour: 18, awakeEndHour: 11), in: defaults)
        XCTAssertEqual(defaults.object(forKey: SleepSchedulePrefs.awakeStartKey) as? Int, 18)
        XCTAssertEqual(defaults.object(forKey: SleepSchedulePrefs.awakeEndKey) as? Int, 11)
        XCTAssertEqual(SleepStager.daytimeBandStartHour, 18)   // no relaunch needed
    }

    // This build ships a night-shift wearer's window: awake 22:00 → 10:00, so their sleep window is
    // 10:00 → 22:00. It must clear the LATEST plausible wake (21:00), not just the sleep centres — a
    // first pass closed it at 19:00 and a real 19:15 wake landed in the awake band, which truncated the
    // detected wake back to ~18:00. The band predicate itself is pinned in the package's own suite.
    func testForkFallbackPutsTheWearersSleepOutsideTheStrictBand() {
        SleepSchedule.current = SleepSchedulePrefs.fallback
        XCTAssertEqual(SleepStager.daytimeBandStartHour, 22)
        XCTAssertEqual(SleepStager.daytimeBandEndHour, 10)
        XCTAssertEqual(SleepStageTotals.overnightStartHour, 10)   // sleep window opens
        XCTAssertEqual(SleepStageTotals.overnightEndHour, 22)     // …and closes
    }
}
