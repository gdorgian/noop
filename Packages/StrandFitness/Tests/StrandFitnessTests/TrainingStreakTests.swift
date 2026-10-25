import XCTest
@testable import StrandFitness

final class TrainingStreakTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        c.firstWeekday = 2   // Monday
        return c
    }()

    /// 2026-10-21 is a Wednesday.
    private func day(_ d: Int, _ month: Int = 10) -> Date {
        cal.date(from: DateComponents(year: 2026, month: month, day: d, hour: 12))!
    }

    func testAWeekInProgressKeepsTheStreakAtRisk() {
        let r = TrainingStreak.reading(sessionDates: [day(13), day(6), day(29, 9)], now: day(21), calendar: cal)
        XCTAssertEqual(r.weeks, 3)
        XCTAssertFalse(r.thisWeekDone)
        XCTAssertTrue(r.atRisk)
        XCTAssertEqual(r.daysLeft, 5, "Wednesday to the end of Sunday")
    }

    func testThisWeeksWorkoutCountsAndTwoInOneWeekCountOnce() {
        let r = TrainingStreak.reading(sessionDates: [day(19), day(20), day(13)], now: day(21), calendar: cal)
        XCTAssertEqual(r.weeks, 2)
        XCTAssertTrue(r.thisWeekDone)
        XCTAssertEqual(r.thisWeekCount, 2)
        XCTAssertFalse(r.atRisk)
    }

    func testAMissedWeekEndsTheStreakButNotTheBest() {
        let dates = [day(15, 9), day(22, 9), day(29, 9), day(6), day(20)]   // week of 13 Oct missed
        let r = TrainingStreak.reading(sessionDates: dates, now: day(21), calendar: cal)
        XCTAssertEqual(r.weeks, 1)
        XCTAssertEqual(r.best, 4)
    }

    func testNoWorkoutsIsNoStreak() {
        let r = TrainingStreak.reading(sessionDates: [], now: day(21), calendar: cal)
        XCTAssertEqual(r.weeks, 0)
        XCTAssertFalse(r.atRisk)
    }

    func testAFutureSessionDoesNotCount() {
        let r = TrainingStreak.reading(sessionDates: [day(23)], now: day(21), calendar: cal)
        XCTAssertEqual(r.weeks, 0)
        XCTAssertFalse(r.thisWeekDone)
    }
}
