import Foundation
import XCTest
@testable import Strand

final class AuraHistoryPresentationTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Athens")!; return c
    }
    private func date(_ day: Int) -> Date { calendar.date(from: DateComponents(year: 2026, month: 3, day: day))! }
    func testVariabilityRequiresFourteenRecordedDaysAndDoesNotUseFutureData() {
        let series = DatedChartSeries(dates: (1...16).map(date), values: (1...16).map { Double($0) })
        let chart = AuraHistoryPresentation(series: series, calendar: calendar)
        XCTAssertEqual(chart.bands.first?.date, date(14))
        XCTAssertEqual(chart.bands.first?.count, 14)
        let expectedSD = sqrt(17.5)
        XCTAssertEqual(chart.bands.first!.low, 7.5 - expectedSD, accuracy: 0.00001)
        XCTAssertEqual(chart.bands.first!.high, 7.5 + expectedSD, accuracy: 0.00001)
    }
    func testBandSplitsAtMissingDayEvenWhenSurroundingWindowsHaveEnoughValues() {
        let dates = (1...20).map(date)
        let values: [Double?] = (1...20).map { $0 == 17 ? nil : Double($0) }
        let chart = AuraHistoryPresentation(series: .init(dates: dates, values: values), calendar: calendar)
        XCTAssertEqual(chart.bandSegments.count, 2)
        XCTAssertFalse(chart.bands.contains { $0.date == date(17) })
    }
    func testSparseMeasurementsDoNotAcquireAVariabilityBand() {
        let chart = AuraHistoryPresentation(series: .init(dates: [date(1), date(15)], values: [70, 71]), showVariability: false)
        XCTAssertTrue(chart.bands.isEmpty)
        XCTAssertEqual(chart.average, 70.5)
    }
    func testConstantZeroAndMissingSeriesHaveFiniteGeometry() {
        for values: [Double?] in [[0, 0], [nil, nil], [60, 60]] {
            let chart = AuraHistoryPresentation(series: .init(dates: [date(1), date(2)], values: values))
            XCTAssertTrue(chart.lower.isFinite); XCTAssertTrue(chart.upper.isFinite)
            XCTAssertGreaterThan(chart.upper, chart.lower)
            XCTAssertTrue(chart.fraction(0).isFinite)
        }
    }
    func testComparisonUsesEqualCalendarWindowsAcrossDSTAndReportsCounts() throws {
        let series = DatedChartSeries(dates: (25...31).map(date), values: [10, 20, nil, 40, 50, 60, 70])
        let comparison = try XCTUnwrap(AuraHistoryComparison(series: series, start: date(29), end: date(31), calendar: calendar))
        XCTAssertEqual(comparison.previous.start, date(26)); XCTAssertEqual(comparison.previous.end, date(28))
        XCTAssertEqual(comparison.previous.count, 2); XCTAssertEqual(comparison.current.count, 3)
        XCTAssertEqual(comparison.difference, 30)
    }
    func testMissingComparisonStaysMissingRatherThanZero() throws {
        let comparison = try XCTUnwrap(AuraHistoryComparison(series: .init(dates: [date(30)], values: [80]), start: date(29), end: date(31), calendar: calendar))
        XCTAssertNil(comparison.previous.average); XCTAssertNil(comparison.difference)
    }
    func testEstimateBandUsesEngineUncertaintyAndKeepsMissingWeeks() {
        let series = DatedChartSeries(dates: [date(1), date(8), date(15)], values: [40, nil, 42])
        let chart = AuraHistoryPresentation(series: series, estimateHalfWidth: 3)
        XCTAssertEqual(chart.bandKind, .estimateUncertainty)
        XCTAssertEqual(chart.bands.map(\.low), [37, 39])
        XCTAssertEqual(chart.bands.map(\.high), [43, 45])
        XCTAssertEqual(chart.bandSegments.count, 2)
    }
    func testVariabilityUsesPriorContextButOnlyThirtyCalendarDays() throws {
        let context = DatedChartSeries(dates: (1...31).map(date), values: (1...31).map { Double($0) })
        let visible = DatedChartSeries(dates: [date(31)], values: [31])
        let chart = AuraHistoryPresentation(series: visible, context: context, calendar: calendar)
        let band = try XCTUnwrap(chart.bands.first)
        XCTAssertEqual(chart.bandKind, .observedVariability)
        XCTAssertEqual(band.count, 30)
        XCTAssertEqual((band.low + band.high) / 2, 16.5, accuracy: 0.00001)
    }
    func testSparseOldContextDoesNotBecomeThirtyValidDayBand() {
        let dates = (1...14).map { calendar.date(byAdding: .day, value: -$0 * 4, to: date(31))! } + [date(31)]
        let context = DatedChartSeries(dates: dates, values: Array(repeating: 60, count: dates.count))
        let chart = AuraHistoryPresentation(series: .init(dates: [date(31)], values: [60]), context: context, calendar: calendar)
        XCTAssertTrue(chart.bands.isEmpty)
    }
    func testReferencesAndExtremeFiniteValuesStayInsideFiniteAxes() {
        let target = AuraHistoryPresentation(series: .init(dates: [date(1)], values: [6]), references: [8])
        XCTAssertGreaterThan(target.upper, 8)
        let extreme = AuraHistoryPresentation(series: .init(dates: [date(1), date(2)], values: [-1e308, 1e308]), showVariability: false)
        XCTAssertTrue(extreme.ticks.allSatisfy(\.isFinite))
        XCTAssertEqual(extreme.fraction(-1e308), 0)
        XCTAssertEqual(extreme.fraction(1e308), 1)
    }

}
