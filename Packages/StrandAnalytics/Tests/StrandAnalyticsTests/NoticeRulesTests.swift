import XCTest
@testable import StrandAnalytics

final class NoticeRulesTests: XCTestCase {

    /// Need is the median sleep before recovered mornings; eight hours until five such mornings exist.
    func testSleepNeed() {
        let few = [NoticeRules.Night(asleepMinutes: 450, charge: 80)]
        XCTAssertEqual(NoticeRules.sleepNeed(few), 480)
        let good = [440, 455, 470, 490, 500].map { NoticeRules.Night(asleepMinutes: Double($0), charge: 75) }
        let bad = [300, 320].map { NoticeRules.Night(asleepMinutes: Double($0), charge: 30) }
        XCTAssertEqual(NoticeRules.sleepNeed(good + bad), 470)
        let short = (0..<5).map { _ in NoticeRules.Night(asleepMinutes: 360, charge: 90) }
        XCTAssertEqual(NoticeRules.sleepNeed(short), 420, "held to seven hours at least")
    }

    /// A weekday with its own nights uses them; one without falls back to all nights.
    func testUsualWakePerWeekday() {
        var wakes = (0..<12).map { _ in NoticeRules.Wake(weekday: 2, minute: 7 * 60) }
        XCTAssertTrue(NoticeRules.usualWake(wakes).isEmpty)
        wakes += [.init(weekday: 7, minute: 9 * 60), .init(weekday: 7, minute: 9 * 60 + 30)]
        let usual = NoticeRules.usualWake(wakes)
        XCTAssertEqual(usual[2], 420)
        XCTAssertEqual(usual[7], 9 * 60 + 30)
        XCTAssertEqual(usual[4], 420)
    }

    /// Wake 07:00 with a 7 h 45 need: in bed 23:00, nudged 22:30.
    func testBedtime() {
        let t = NoticeRules.bedtime(wakeMinute: 420, need: 465)
        XCTAssertEqual(t.bedtime, 23 * 60)
        XCTAssertEqual(t.nudge, 22 * 60 + 30)
    }

    /// A best needs thirty prior days and a clear margin, in the right direction.
    func testPreviousBest() {
        let prior = Array(repeating: 55.0, count: 29) + [53]
        XCTAssertEqual(NoticeRules.previousBest(51, prior: prior, higherIsBetter: false, margin: 1), 53)
        XCTAssertNil(NoticeRules.previousBest(53, prior: prior, higherIsBetter: false, margin: 1))
        XCTAssertNil(NoticeRules.previousBest(40, prior: Array(prior.prefix(20)), higherIsBetter: false, margin: 1))
        XCTAssertEqual(NoticeRules.previousBest(90, prior: [70] + Array(repeating: 60, count: 29),
                                                higherIsBetter: true, margin: 2), 70)
    }

    func testWeekSkipsMissingDays() {
        let w = NoticeRules.week(asleep: [420, nil, 480], charge: [60, 70, nil], sessions: 3)
        XCTAssertEqual(w.asleepMinutes, 450)
        XCTAssertEqual(w.charge, 65)
        XCTAssertEqual(w.sessions, 3)
    }
}
