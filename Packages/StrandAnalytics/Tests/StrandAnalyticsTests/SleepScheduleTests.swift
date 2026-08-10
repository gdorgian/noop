import XCTest
@testable import StrandAnalytics

/// Pins `SleepSchedule` — the wearer's awake window, from which the detector's daytime band (#90) and
/// the selector's cold-start overnight band (#547) are both derived.
///
/// Two properties matter most here. First, the default must reproduce the four constants these replaced
/// EXACTLY, so a host that never sets a schedule is byte-identical to upstream. Second, the overnight
/// band must be the complement of the awake band *structurally* — that reconciliation used to be
/// maintained by hand across two files and had already drifted once.
final class SleepScheduleTests: XCTestCase {

    /// A wearer who works nights: awake 19:00 → 10:00 (wrapping), asleep 10:00 → 19:00.
    private let nightShift = SleepSchedule(awakeStartHour: 19, awakeEndHour: 10)

    override func tearDown() {
        SleepSchedule.current = .dayWorker   // never leak a schedule into another test
        super.tearDown()
    }

    // MARK: - The default is upstream, exactly

    func testDefaultReproducesTheOriginalConstants() {
        SleepSchedule.current = .dayWorker
        XCTAssertEqual(SleepStager.daytimeBandStartHour, 11)
        XCTAssertEqual(SleepStager.daytimeBandEndHour, 20)
        XCTAssertEqual(SleepStageTotals.overnightStartHour, 20)
        XCTAssertEqual(SleepStageTotals.overnightEndHour, 11)
    }

    func testCurrentDefaultsToDayWorkerWithoutAnyHostSetup() {
        XCTAssertEqual(SleepSchedule.current, .dayWorker)
    }

    // Upstream's documented cold-start anchor is 03:30 local.
    func testDefaultColdStartAnchorIsUnchanged() {
        SleepSchedule.current = .dayWorker
        XCTAssertEqual(SleepStageTotals.coldStartAnchorSec, 3 * 3_600 + 1_800)
    }

    // MARK: - A night-shift schedule inverts both bands together

    func testNightShiftScheduleInvertsTheBands() {
        SleepSchedule.current = nightShift
        XCTAssertEqual(SleepStager.daytimeBandStartHour, 19)
        XCTAssertEqual(SleepStager.daytimeBandEndHour, 10)
        XCTAssertEqual(SleepStageTotals.overnightStartHour, 10)
        XCTAssertEqual(SleepStageTotals.overnightEndHour, 19)
    }

    // The wearer's real sleep centres (~14:00–17:00) must NOT attract the strict daytime bar.
    func testNightShiftSleepCentresAreNotTreatedAsDaytime() {
        SleepSchedule.current = nightShift
        for hour in 12...18 {
            XCTAssertFalse(SleepStager.hourInBand(hour,
                                                  start: SleepStager.daytimeBandStartHour,
                                                  end: SleepStager.daytimeBandEndHour),
                           "hour \(hour) should sit in the sleep window")
        }
    }

    // …and their genuinely awake hours must still get it, or the guard is doing nothing.
    func testNightShiftAwakeHoursKeepTheStricterBar() {
        SleepSchedule.current = nightShift
        for hour in [19, 22, 0, 3, 9] {
            XCTAssertTrue(SleepStager.hourInBand(hour,
                                                 start: SleepStager.daytimeBandStartHour,
                                                 end: SleepStager.daytimeBandEndHour),
                          "hour \(hour) should sit in the awake band")
        }
    }

    // Their habitual midsleep stand-in moves to 14:30, where upstream's 03:30 would have penalised
    // every night they ever record.
    func testNightShiftColdStartAnchorMovesToTheirMidsleep() {
        SleepSchedule.current = nightShift
        XCTAssertEqual(SleepStageTotals.coldStartAnchorSec, 14 * 3_600 + 1_800)
    }

    // MARK: - The complement is structural

    // For ANY valid schedule the overnight band must be the exact complement of the awake band. This is
    // the invariant the two hand-maintained constant pairs kept breaking.
    func testOvernightBandIsAlwaysTheComplementOfTheAwakeBand() {
        for start in 0...23 {
            for end in 0...23 where start != end {
                SleepSchedule.current = SleepSchedule(awakeStartHour: start, awakeEndHour: end)
                XCTAssertEqual(SleepStageTotals.overnightStartHour, SleepStager.daytimeBandEndHour)
                XCTAssertEqual(SleepStageTotals.overnightEndHour, SleepStager.daytimeBandStartHour)
                // Every hour is in exactly one of the two bands.
                for hour in 0..<24 {
                    let awake = SleepStager.hourInBand(hour,
                                                       start: SleepStager.daytimeBandStartHour,
                                                       end: SleepStager.daytimeBandEndHour)
                    let asleep = SleepStager.hourInBand(hour,
                                                        start: SleepStageTotals.overnightStartHour,
                                                        end: SleepStageTotals.overnightEndHour)
                    XCTAssertNotEqual(awake, asleep,
                                      "hour \(hour) in schedule \(start)→\(end) is in both or neither band")
                }
            }
        }
    }

    // MARK: - Invalid input falls back rather than degenerating

    // A degenerate or out-of-range band would make the predicate always-false, which does not shift the
    // guard — it removes it. Fall back to the shipped schedule instead.
    func testInvalidSchedulesFallBackToDayWorker() {
        for bad in [(-1, 20), (11, 24), (99, 3), (11, 11), (0, 0)] {
            let s = SleepSchedule(awakeStartHour: bad.0, awakeEndHour: bad.1)
            XCTAssertEqual(s, .dayWorker, "schedule \(bad) should have fallen back")
        }
    }

    func testValidEdgeHoursAreAccepted() {
        XCTAssertEqual(SleepSchedule(awakeStartHour: 0, awakeEndHour: 23).awakeStartHour, 0)
        XCTAssertEqual(SleepSchedule(awakeStartHour: 23, awakeEndHour: 0).awakeEndHour, 0)
    }
}
