import Foundation
import XCTest
@testable import Strand

final class DatedChartSeriesTests: XCTestCase {
    private func day(_ n: Double) -> Date { Date(timeIntervalSince1970: n * 86_400) }

    func testMissingWeeksKeepTheirPositionsAndBreakTheLine() {
        let chart = DatedChartSeries(dates: (0..<5).map { day(Double($0)) }, values: [60, nil, 58, 57, nil])
        XCTAssertEqual(chart.segments.map(\.count), [1, 2])
        XCTAssertEqual(chart.points.map(\.x), [0, 0.5, 0.75])
        XCTAssertEqual(chart.values, [60, 58, 57])
    }

    func testIrregularLabDrawsUseElapsedTimeNotRecordIndex() {
        let chart = DatedChartSeries(dates: [day(0), day(10), day(100)], values: [40, 45, 42])
        XCTAssertEqual(chart.points[1].x, 0.1, accuracy: 0.000001)
        XCTAssertEqual(chart.points.map(\.date), [day(0), day(10), day(100)])
    }

    func testIncompatibleUnitsBreakHistoryInsteadOfSharingAnAxis() {
        let chart = DatedChartSeries(observations: [
            .init(date: day(0), value: 90, unit: "mg/dL"),
            .init(date: day(10), value: 5, unit: "mmol/L"),
            .init(date: day(100), value: 95, unit: " mg/dL ")
        ], unit: "mg/dL")
        XCTAssertEqual(chart.values, [90, 95])
        XCTAssertEqual(chart.segments.map(\.count), [1, 1])
        XCTAssertEqual(chart.points.map(\.x), [0, 1])
    }

    func testMissingAndNonFiniteReadingsAreNotZero() {
        let chart = DatedChartSeries(dates: (0..<5).map { day(Double($0)) }, values: [0, .nan, nil, .infinity, -0.2])
        XCTAssertEqual(chart.values, [0, -0.2])
        XCTAssertEqual(chart.segments.map(\.count), [1, 1])
        XCTAssertEqual(chart.points.map(\.x), [0, 1])
    }

    func testSingleReadingIsAPointAndEmptyHistoryHasNoGeometry() {
        XCTAssertEqual(DatedChartSeries(samples: []).segments, [])
        let one = DatedChartSeries(dates: [day(10)], values: [42])
        XCTAssertEqual(one.segments.map(\.count), [1])
        XCTAssertEqual(one.points.first?.x, 1)
    }

    func testDateOrderAndUnmatchedValuesCannotCompressTheWindow() {
        let chart = DatedChartSeries(dates: [day(20), day(0), day(10)], values: [62, 60])
        XCTAssertEqual(chart.samples.map(\.date), [day(0), day(10), day(20)])
        XCTAssertEqual(chart.segments.map(\.count), [1, 1])
        XCTAssertEqual(chart.points.map(\.value), [60, 62])
        XCTAssertEqual(chart.points.map(\.x), [0, 1])
        XCTAssertEqual(DatedChartSeries(dates: [], values: [99]).values, [])
    }

    func testCaseSensitiveUnitPrefixesAreNotSilentlyConverted() {
        let chart = DatedChartSeries(observations: [
            .init(date: day(0), value: 2, unit: "mIU/L"),
            .init(date: day(1), value: 2, unit: "MIU/L")
        ], unit: "mIU/L")
        XCTAssertEqual(chart.values, [2])
        XCTAssertEqual(chart.points.count, 1)
        XCTAssertEqual(chart.points.first?.date, day(0))
    }

    func testUnknownUnitsAreNotAssumedEquivalent() {
        let chart = DatedChartSeries(observations: [.init(date: day(0), value: 5, unit: "")], unit: " ")
        XCTAssertTrue(chart.values.isEmpty)
        XCTAssertNil(DatedChartSeries.unitKey("\n "))
    }
}
