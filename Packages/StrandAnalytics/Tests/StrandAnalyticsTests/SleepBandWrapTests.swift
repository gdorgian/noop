import XCTest
@testable import StrandAnalytics

/// Pins `SleepStager.hourInBand`, the shared local-hour band test behind the daytime false-sleep guard
/// (#90) and the cold-start overnight band (#547).
///
/// The band is really "the hours the wearer is normally AWAKE". For a day-worker that is a contiguous
/// 11:00–20:00 and the old `hour >= start && hour < end` was correct. For a night-shift wearer those
/// hours straddle midnight, and the old form evaluates to ALWAYS FALSE — which does not move the guard,
/// it silently removes it, letting any long sedentary stretch through as sleep. These tests pin both
/// branches so a future retune of the constants cannot reintroduce that.
final class SleepBandWrapTests: XCTestCase {

    // MARK: - Non-wrapping band (the shipped default, 11:00–20:00)

    func testNonWrappingBandIncludesItsInterior() {
        for hour in 11...19 {
            XCTAssertTrue(SleepStager.hourInBand(hour, start: 11, end: 20), "hour \(hour)")
        }
    }

    // Start inclusive, end exclusive — the same half-open contract the constants document.
    func testNonWrappingBandBoundsAreHalfOpen() {
        XCTAssertTrue(SleepStager.hourInBand(11, start: 11, end: 20))
        XCTAssertFalse(SleepStager.hourInBand(20, start: 11, end: 20))
    }

    func testNonWrappingBandExcludesOutside() {
        for hour in [0, 5, 10, 20, 21, 23] {
            XCTAssertFalse(SleepStager.hourInBand(hour, start: 11, end: 20), "hour \(hour)")
        }
    }

    // MARK: - Wrapping band (a night-shift wearer awake 19:00 → 12:00)

    func testWrappingBandCoversBothSidesOfMidnight() {
        for hour in [19, 20, 23, 0, 1, 8, 11] {
            XCTAssertTrue(SleepStager.hourInBand(hour, start: 19, end: 12), "hour \(hour)")
        }
    }

    // The complement is the wearer's SLEEP window — the hours the stricter bar must NOT apply to.
    func testWrappingBandExcludesTheSleepWindow() {
        for hour in 12...18 {
            XCTAssertFalse(SleepStager.hourInBand(hour, start: 19, end: 12), "hour \(hour)")
        }
    }

    func testWrappingBandBoundsAreHalfOpen() {
        XCTAssertTrue(SleepStager.hourInBand(19, start: 19, end: 12))
        XCTAssertFalse(SleepStager.hourInBand(12, start: 19, end: 12))
    }

    // The regression this helper exists to prevent: under the OLD non-wrapping-only comparison a
    // wrapping band matched nothing at all, so every hour of the day fell outside the guard.
    func testWrappingBandIsNotVacuous() {
        let matched = (0..<24).filter { SleepStager.hourInBand($0, start: 19, end: 12) }
        XCTAssertEqual(matched.count, 17)
        XCTAssertFalse(matched.isEmpty, "a wrapping band must not degenerate to always-false")
    }

    // A degenerate start == end band is treated as empty by the non-wrapping branch, not as all-day.
    func testEmptyBandMatchesNothing() {
        for hour in 0..<24 {
            XCTAssertFalse(SleepStager.hourInBand(hour, start: 9, end: 9), "hour \(hour)")
        }
    }

    // MARK: - The two call sites agree

    // The detector's onset window is the complement of the daytime band; the selector's cold-start band
    // is the same predicate. They must stay reconciled (#547) whatever the constants are set to.
    func testDetectorAndSelectorUseTheSameBandPredicate() {
        let utcNoonJan1 = 43_200  // 12:00 UTC on 1970-01-01
        for hourOffset in 0..<24 {
            let ts = utcNoonJan1 + hourOffset * 3_600
            let detectorSaysOvernight = SleepStager.isOvernightOnset(ts, tzOffsetSeconds: 0)
            let hour = ((ts % 86_400) + 86_400) % 86_400 / 3_600
            XCTAssertEqual(detectorSaysOvernight,
                           !SleepStager.hourInBand(hour,
                                                   start: SleepStager.daytimeBandStartHour,
                                                   end: SleepStager.daytimeBandEndHour),
                           "hour \(hour)")
        }
    }
}
