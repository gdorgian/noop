import XCTest
import CoreGraphics
@testable import StrandDesign

/// Pins the Aura charts' geometry. The views that draw these live in the app target, which no default CI
/// job compiles (CLAUDE.md §"The trap") — so an inverted axis or an off-by-one hit test would ship green.
/// Everything a reader could not eyeball from the drawing code is asserted here.
final class AuraChartMathTests: XCTestCase {

    // MARK: Bars

    func testFractionClampsRatherThanOverflowingItsContainer() {
        // A bar past its ceiling would draw outside the card, which is how one freak night breaks a chart.
        XCTAssertEqual(AuraChartMath.fraction(4.2, ceiling: 8.4), 0.5, accuracy: 0.0001)
        XCTAssertEqual(AuraChartMath.fraction(99, ceiling: 8.4), 1.0, accuracy: 0.0001)
        XCTAssertEqual(AuraChartMath.fraction(-3, ceiling: 8.4), 0.0, accuracy: 0.0001)
    }

    func testFractionSurvivesADegenerateCeiling() {
        XCTAssertEqual(AuraChartMath.fraction(5, ceiling: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(AuraChartMath.fraction(.nan, ceiling: 8.4), 0, accuracy: 0.0001)
        XCTAssertEqual(AuraChartMath.fraction(.infinity, ceiling: 8.4), 0, accuracy: 0.0001)
    }

    func testMinimumBarHeightKeepsAClearDayVisible() {
        // Rest debt of zero must still read as a tick on the axis, not vanish into a gap.
        XCTAssertEqual(AuraChartMath.barHeight(0, ceiling: 2.6, height: 72, minimum: 4), 4, accuracy: 0.001)
        XCTAssertEqual(AuraChartMath.barHeight(2.6, ceiling: 2.6, height: 72, minimum: 4), 72, accuracy: 0.001)
    }

    // MARK: Trend line

    func testPointsSpanTheFullWidthAndInvertY() {
        // SwiftUI's y grows downward, so the HIGHEST value must produce the SMALLEST y.
        let size = CGSize(width: 300, height: 100)
        let points = AuraChartMath.points([30, 61, 92], in: size, window: 30...92)
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points[0].x, 0, accuracy: 0.001)
        XCTAssertEqual(points[2].x, 300, accuracy: 0.001)
        XCTAssertEqual(points[0].y, 100, accuracy: 0.001, "the window's floor should sit on the baseline")
        XCTAssertEqual(points[2].y, 0, accuracy: 0.001, "the window's ceiling should sit at the top")
        XCTAssertLessThan(points[2].y, points[0].y)
    }

    func testPointsClampOutOfWindowValues() {
        let size = CGSize(width: 100, height: 50)
        let points = AuraChartMath.points([5, 500], in: size, window: 30...92)
        XCTAssertEqual(points[0].y, 50, accuracy: 0.001)
        XCTAssertEqual(points[1].y, 0, accuracy: 0.001)
    }

    func testSinglePointCentresRatherThanDividingByZero() {
        let points = AuraChartMath.points([60], in: CGSize(width: 200, height: 100), window: 30...92)
        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].x, 100, accuracy: 0.001)
        XCTAssertTrue(points[0].y.isFinite)
    }

    func testEmptySeriesProducesNoPoints() {
        XCTAssertTrue(AuraChartMath.points([], in: CGSize(width: 200, height: 100), window: 30...92).isEmpty)
    }

    // MARK: Hit testing

    func testNearestIndexSnapsToTheClosestPoint() {
        // 5 points across 400pt → one every 100pt.
        XCTAssertEqual(AuraChartMath.nearestIndex(toX: 0, count: 5, width: 400), 0)
        XCTAssertEqual(AuraChartMath.nearestIndex(toX: 149, count: 5, width: 400), 1)
        XCTAssertEqual(AuraChartMath.nearestIndex(toX: 151, count: 5, width: 400), 2)
        XCTAssertEqual(AuraChartMath.nearestIndex(toX: 400, count: 5, width: 400), 4)
    }

    func testNearestIndexClampsATapPastEitherEdge() {
        // A drag that leaves the plot must resolve to an end point, never to an out-of-range index.
        XCTAssertEqual(AuraChartMath.nearestIndex(toX: -900, count: 5, width: 400), 0)
        XCTAssertEqual(AuraChartMath.nearestIndex(toX: 9_000, count: 5, width: 400), 4)
    }

    func testNearestIndexHandlesDegenerateInput() {
        XCTAssertNil(AuraChartMath.nearestIndex(toX: 10, count: 0, width: 400))
        XCTAssertNil(AuraChartMath.nearestIndex(toX: 10, count: 5, width: 0))
        XCTAssertEqual(AuraChartMath.nearestIndex(toX: 10, count: 1, width: 400), 0)
    }

    // MARK: Tooltip

    func testTooltipFlipsBelowForHighPointsOnly() {
        // A high point (small y) would push the bubble over the card's header, so it flips under.
        XCTAssertTrue(AuraChartMath.tooltipGoesBelow(pointY: 10, plotHeight: 132))
        XCTAssertFalse(AuraChartMath.tooltipGoesBelow(pointY: 120, plotHeight: 132))
    }

    func testTooltipXStaysInsideTheCard() {
        XCTAssertEqual(AuraChartMath.tooltipX(pointX: 0, plotWidth: 300), 0.1, accuracy: 0.0001)
        XCTAssertEqual(AuraChartMath.tooltipX(pointX: 300, plotWidth: 300), 0.9, accuracy: 0.0001)
        XCTAssertEqual(AuraChartMath.tooltipX(pointX: 150, plotWidth: 300), 0.5, accuracy: 0.0001)
        XCTAssertEqual(AuraChartMath.tooltipX(pointX: 10, plotWidth: 0), 0.5, accuracy: 0.0001)
    }

    // MARK: Dot columns

    func testDotOpacityRampsWithColumnHeightAndStaysVisible() {
        XCTAssertEqual(AuraChartMath.dotOpacity(count: 0, ceiling: 6), 0.38, accuracy: 0.0001)
        XCTAssertEqual(AuraChartMath.dotOpacity(count: 6, ceiling: 6), 1.0, accuracy: 0.0001)
        XCTAssertEqual(AuraChartMath.dotOpacity(count: 99, ceiling: 6), 1.0, accuracy: 0.0001,
                       "a column past the ceiling must not exceed full opacity")
        XCTAssertGreaterThan(AuraChartMath.dotOpacity(count: 4, ceiling: 6),
                             AuraChartMath.dotOpacity(count: 2, ceiling: 6))
    }

    // MARK: Battery

    func testBatterySweepCoversTheFullCircle() {
        XCTAssertEqual(AuraChartMath.batterySweep(fraction: 0), 0, accuracy: 0.001)
        XCTAssertEqual(AuraChartMath.batterySweep(fraction: 0.62), 223.2, accuracy: 0.001)
        XCTAssertEqual(AuraChartMath.batterySweep(fraction: 1), 360, accuracy: 0.001)
    }

    func testBatterySweepClampsBadInput() {
        // The sweep is divided by 360 to place a gradient stop; a value outside 0…1 would put that stop
        // outside the gradient and render the ring undefined.
        XCTAssertEqual(AuraChartMath.batterySweep(fraction: 4), 360, accuracy: 0.001)
        XCTAssertEqual(AuraChartMath.batterySweep(fraction: -1), 0, accuracy: 0.001)
        XCTAssertEqual(AuraChartMath.batterySweep(fraction: .nan), 0, accuracy: 0.001)
    }

    // MARK: Range bar

    func testRangePositionClampsIntoTheTrack() {
        XCTAssertEqual(AuraChartMath.rangePosition(74), 74, accuracy: 0.001)
        XCTAssertEqual(AuraChartMath.rangePosition(-20), 0, accuracy: 0.001)
        XCTAssertEqual(AuraChartMath.rangePosition(180), 100, accuracy: 0.001)
        XCTAssertEqual(AuraChartMath.rangePosition(.nan), 50, accuracy: 0.001,
                       "an unusable position should sit mid-range, not at an extreme that reads as a verdict")
    }
}
