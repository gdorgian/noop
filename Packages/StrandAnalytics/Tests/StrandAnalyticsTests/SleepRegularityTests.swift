import XCTest
@testable import StrandAnalytics

/// The property that matters: SRI measures WHEN you sleep, not how long. Every test here is built so
/// the duration proxy it replaces would answer differently.
final class SleepRegularityTests: XCTestCase {

    /// A UTC midnight to build clean days on.
    private let epochDay = 1_754_006_400   // 2026-08-01 00:00:00 UTC

    /// `nights` sessions, each starting `startHour` into its day and lasting `hours`.
    private func nights(_ count: Int, startHour: Double, hours: Double) -> [(start: Int, end: Int)] {
        (0..<count).map { day in
            let start = epochDay + day * 86_400 + Int(startHour * 3_600)
            return (start: start, end: start + Int(hours * 3_600))
        }
    }

    // MARK: The case the duration proxy cannot see

    func testAPerfectlyRepeatingScheduleScoresAtTheTop() {
        let sri = SleepRegularity.index(sessions: nights(14, startHour: 23, hours: 7.5))
        XCTAssertNotNil(sri)
        XCTAssertGreaterThan(sri ?? 0, 95, "an identical schedule every night is maximally regular")
    }

    /// The headline case. Identical durations every night, so `1 − CV` reports perfect regularity —
    /// but half the nights start five hours later, which is what regularity actually means.
    func testShiftedWeekendsScoreLowerEvenWithIdenticalDurations() {
        var mixed: [(start: Int, end: Int)] = []
        for day in 0..<14 {
            let startHour: Double = (day % 7 >= 5) ? 4 : 23   // two "weekend" nights in seven
            let start = epochDay + day * 86_400 + Int(startHour * 3_600)
            mixed.append((start: start, end: start + Int(7.5 * 3_600)))
        }

        let durations = Array(repeating: 7.5, count: 14)
        let proxy = VitalityEngine.sleepConsistency(nightlyHours: durations)
        XCTAssertEqual(proxy ?? 0, 1.0, accuracy: 1e-9,
                       "the duration proxy sees perfect regularity here — that is the flaw")

        let regular = SleepRegularity.index(sessions: nights(14, startHour: 23, hours: 7.5)) ?? 0
        let shifted = SleepRegularity.index(sessions: mixed) ?? 0
        XCTAssertLessThan(shifted, regular,
                          "a five-hour weekend shift must read as less regular than a fixed schedule")
    }

    /// And the converse: varying duration while keeping the same bedtime is only mildly irregular,
    /// where the duration proxy would punish it hard.
    func testVaryingDurationAtAFixedBedtimeStaysFairlyRegular() {
        var varied: [(start: Int, end: Int)] = []
        for day in 0..<14 {
            let start = epochDay + day * 86_400 + 23 * 3_600
            let hours = day.isMultiple(of: 2) ? 6.0 : 9.0
            varied.append((start: start, end: start + Int(hours * 3_600)))
        }
        XCTAssertGreaterThan(SleepRegularity.index(sessions: varied) ?? 0, 70)
    }

    // MARK: Gates

    func testTooFewDaysProducesNoIndexRatherThanAGuess() {
        XCTAssertNil(SleepRegularity.index(sessions: nights(3, startHour: 23, hours: 7.5)))
        XCTAssertNil(SleepRegularity.index(sessions: []))
    }

    func testAZeroLengthSessionIsIgnored() {
        var sessions = nights(14, startHour: 23, hours: 7.5)
        sessions.append((start: epochDay, end: epochDay))
        XCTAssertNotNil(SleepRegularity.index(sessions: sessions))
    }

    /// A split night must count as one stretch of sleep, not two — otherwise the union is wrong and
    /// so is every comparison downstream.
    func testOverlappingSessionsAreUnionedNotDoubleCounted() {
        var split = nights(14, startHour: 23, hours: 7.5)
        // Add a fragment that overlaps night 3 entirely.
        let third = split[3]
        split.append((start: third.start + 1_800, end: third.end - 1_800))
        let withFragment = SleepRegularity.index(sessions: split) ?? 0
        let without = SleepRegularity.index(sessions: nights(14, startHour: 23, hours: 7.5)) ?? 0
        XCTAssertEqual(withFragment, without, accuracy: 0.5,
                       "a contained fragment adds no new asleep minutes and must not move the index")
    }

    // MARK: Scale

    func testConsistencyIsTheZeroToOneScaleVitalityExpects() {
        let sessions = nights(14, startHour: 23, hours: 7.5)
        let index = SleepRegularity.index(sessions: sessions) ?? 0
        let consistency = SleepRegularity.consistency(sessions: sessions) ?? 0
        XCTAssertEqual(consistency, index / 100, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(consistency, 1)
        XCTAssertGreaterThanOrEqual(consistency, 0)
    }

    /// An anti-correlated rhythm clamps at 0 rather than going negative — there is nothing below
    /// "maximally irregular" worth distinguishing on a 0…1 input.
    func testAnAntiCorrelatedRhythmClampsToZero() {
        var flipping: [(start: Int, end: Int)] = []
        for day in 0..<14 where day.isMultiple(of: 2) {
            // Sleep the whole of every other day, awake through the ones between.
            let start = epochDay + day * 86_400
            flipping.append((start: start, end: start + 86_400))
        }
        let index = SleepRegularity.index(sessions: flipping) ?? 0
        XCTAssertLessThan(index, 0, "alternating whole days is anti-correlated at 24 h")
        XCTAssertEqual(SleepRegularity.consistency(sessions: flipping) ?? -1, 0)
    }
}
