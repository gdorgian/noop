import Foundation
import XCTest
@testable import Strand

final class HistoryDateWindowTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Athens")!
        return c
    }
    private func day(_ key: String) -> Date {
        HistoryDateWindow.date(dayKey: key, timeZone: calendar.timeZone)!
    }

    func testThirtyDaysIsInclusiveAndExcludesTheNextMidnight() throws {
        let window = try XCTUnwrap(HistoryDateWindow(endingOn: day("2026-10-22"), dayCount: 30,
                                                     firstDay: day("2026-01-01"), calendar: calendar))
        XCTAssertEqual(window.start, day("2026-09-23"))
        XCTAssertTrue(window.contains(day("2026-10-22").addingTimeInterval(3600)))
        XCTAssertFalse(window.contains(day("2026-10-23")))
        XCTAssertFalse(window.contains(day("2026-09-22")))
    }

    func testCalendarDaysCrossSpringDSTWithoutDroppingADay() throws {
        let window = try XCTUnwrap(HistoryDateWindow(endingOn: day("2026-03-30"), dayCount: 3,
                                                     firstDay: day("2026-01-01"), calendar: calendar))
        XCTAssertEqual(window.start, day("2026-03-28"))
        XCTAssertEqual(window.endExclusive.timeIntervalSince(window.start), 71 * 3600)
        XCTAssertEqual(window.indices(in: [day("2026-03-27"), day("2026-03-28"), nil,
                                           day("2026-03-29"), day("2026-03-30"), day("2026-03-31")]), [1, 3, 4])
    }

    func testAllHistoryEndsAtTheChosenHistoricalDay() throws {
        let window = try XCTUnwrap(HistoryDateWindow(endingOn: day("2026-05-01"), dayCount: nil,
                                                     firstDay: day("2026-01-01"), calendar: calendar))
        XCTAssertEqual(window.start, day("2026-01-01"))
        XCTAssertFalse(window.contains(day("2026-05-02")))
    }

    func testInvalidDaysAndWindowsAreNotReplacedWithToday() {
        XCTAssertNil(HistoryDateWindow.date(dayKey: "2026-02-30"))
        XCTAssertNil(HistoryDateWindow.date(dayKey: "not-a-day"))
        XCTAssertNil(HistoryDateWindow.date(dayKey: "2026-2-03"))
        XCTAssertNil(HistoryDateWindow(endingOn: day("2026-01-01"), dayCount: 0,
                                       firstDay: day("2026-01-01"), calendar: calendar))
    }

    func testSelectionSnapsToRecordedPointsAcrossAGap() {
        let chart = DatedChartSeries(dates: [day("2026-10-01"), day("2026-10-02"), day("2026-10-03")],
                                     values: [60, nil, 58])
        XCTAssertEqual(chart.nearestPoint(to: 0.45)?.value, 60)
        XCTAssertEqual(chart.nearestPoint(to: 0.55)?.value, 58)
        XCTAssertNil(chart.nearestPoint(to: .nan))
        XCTAssertEqual(chart.average, 59)
        XCTAssertNil(DatedChartSeries(samples: []).average)
    }
    func testWeeklyOverviewUsesDailyValuesAndPreservesMissingWeeks() {
        let chart = DatedChartSeries(dates: [day("2026-10-05"), day("2026-10-06"), day("2026-10-19"), day("2026-10-23")],
                                     values: [60, 58, 56, 100])
        let weekly = chart.weeklyAverages(startingOn: [day("2026-10-05"), day("2026-10-12"), day("2026-10-19")],
                                          through: day("2026-10-22"), calendar: calendar)
        XCTAssertEqual(weekly, [59, nil, 56])
    }

    func testWeekBoundaryUsesCalendarDaysAcrossDST() {
        let chart = DatedChartSeries(dates: [day("2026-03-23"), day("2026-03-29"), day("2026-03-30")],
                                     values: [10, 20, 30])
        XCTAssertEqual(chart.weeklyAverages(startingOn: [day("2026-03-23"), day("2026-03-30")],
                                            through: day("2026-03-30"), calendar: calendar), [15, 30])
    }

}
