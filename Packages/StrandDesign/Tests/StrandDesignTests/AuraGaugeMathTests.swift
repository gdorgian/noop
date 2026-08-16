import XCTest
import SwiftUI
@testable import StrandDesign

/// Pins the Aura tick-gauge geometry. The gauge encodes body state as a POSITION on an arc rather than a
/// score, so its arithmetic is the only thing keeping the marker honest — and the views that draw it are
/// compiled by no default CI job (CLAUDE.md §"The trap"). These tests are therefore the coverage.
final class AuraGaugeMathTests: XCTestCase {

    // MARK: Arc

    func testArcIsSymmetricAboutVertical() {
        // An arc centred on straight-up is what lets the marker read as "left of centre / right of
        // centre" at a glance. If the ends stop being mirror images, that read silently breaks.
        XCTAssertEqual(AuraGaugeMath.angle(forTick: 0), -125, accuracy: 0.001)
        XCTAssertEqual(AuraGaugeMath.angle(forTick: AuraGaugeMath.tickCount - 1), 125, accuracy: 0.001)
        let middle = AuraGaugeMath.angle(forTick: (AuraGaugeMath.tickCount - 1) / 2)
        XCTAssertEqual(middle, 0, accuracy: 0.001)
    }

    func testTickCountIsOddSoAMiddleTickExists() {
        // The midpoint read above only exists if there is a tick exactly at the centre.
        XCTAssertEqual(AuraGaugeMath.tickCount % 2, 1)
    }

    func testTickAnglesAreEvenlySpacedAndMonotonic() {
        let step = AuraGaugeMath.sweep / Double(AuraGaugeMath.tickCount - 1)
        for i in 1..<AuraGaugeMath.tickCount {
            let delta = AuraGaugeMath.angle(forTick: i) - AuraGaugeMath.angle(forTick: i - 1)
            XCTAssertEqual(delta, step, accuracy: 0.001, "tick \(i) is unevenly spaced")
        }
    }

    func testOutOfRangeTickIndicesClampToTheArcEnds() {
        XCTAssertEqual(AuraGaugeMath.angle(forTick: -10), AuraGaugeMath.angle(forTick: 0), accuracy: 0.001)
        XCTAssertEqual(AuraGaugeMath.angle(forTick: 9_999),
                       AuraGaugeMath.angle(forTick: AuraGaugeMath.tickCount - 1), accuracy: 0.001)
    }

    // MARK: Marker

    func testMarkerSpansTheSameArcAsTheTicks() {
        XCTAssertEqual(AuraGaugeMath.markerAngle(fraction: 0), AuraGaugeMath.angle(forTick: 0), accuracy: 0.001)
        XCTAssertEqual(AuraGaugeMath.markerAngle(fraction: 1),
                       AuraGaugeMath.angle(forTick: AuraGaugeMath.tickCount - 1), accuracy: 0.001)
        XCTAssertEqual(AuraGaugeMath.markerAngle(fraction: 0.5), 0, accuracy: 0.001)
    }

    func testMarkerClampsRatherThanLeavingTheArc() {
        // A fraction outside 0…1 must park the marker at an end, never spin it into the open bottom
        // of the ring where it would read as a completely different state.
        XCTAssertEqual(AuraGaugeMath.markerAngle(fraction: -3), -125, accuracy: 0.001)
        XCTAssertEqual(AuraGaugeMath.markerAngle(fraction: 4), 125, accuracy: 0.001)
        XCTAssertEqual(AuraGaugeMath.markerAngle(fraction: .nan), -125, accuracy: 0.001)
        XCTAssertEqual(AuraGaugeMath.markerAngle(fraction: .infinity), -125, accuracy: 0.001)
    }

    // MARK: Lit arc

    func testActiveIndexTracksTheFraction() {
        XCTAssertEqual(AuraGaugeMath.activeIndex(fraction: 0), 0)
        XCTAssertEqual(AuraGaugeMath.activeIndex(fraction: 1), AuraGaugeMath.tickCount - 1)
        XCTAssertEqual(AuraGaugeMath.activeIndex(fraction: 0.5), 20)
    }

    func testActiveIndexStaysInBoundsForBadInput() {
        // This value indexes the tick loop, so an out-of-range result would be a crash, not a glitch.
        for fraction in [-1.0, 2.0, .nan, .infinity, -.infinity] as [Double] {
            let index = AuraGaugeMath.activeIndex(fraction: fraction)
            XCTAssertTrue((0..<AuraGaugeMath.tickCount).contains(index),
                          "fraction \(fraction) produced out-of-range index \(index)")
        }
    }

    func testLitTicksRampUpTowardTheMarker() {
        let active = AuraGaugeMath.activeIndex(fraction: 0.84)
        XCTAssertEqual(AuraGaugeMath.opacity(forTick: 0, activeIndex: active), 0.32, accuracy: 0.001)
        XCTAssertEqual(AuraGaugeMath.opacity(forTick: active, activeIndex: active), 1.0, accuracy: 0.001)
        // Strictly increasing across the lit run — the ramp is what gives the arc direction.
        for i in 1...active {
            XCTAssertGreaterThan(AuraGaugeMath.opacity(forTick: i, activeIndex: active),
                                 AuraGaugeMath.opacity(forTick: i - 1, activeIndex: active))
        }
    }

    func testUnlitTicksAreFullyOpaqueInTheirOwnColour() {
        // Unlit ticks are dimmed by their COLOUR, not by opacity; fading them too would make the
        // unlit arc disappear against the canvas.
        let active = AuraGaugeMath.activeIndex(fraction: 0.5)
        XCTAssertEqual(AuraGaugeMath.opacity(forTick: active + 1, activeIndex: active), 1.0, accuracy: 0.001)
        XCTAssertEqual(AuraGaugeMath.opacity(forTick: AuraGaugeMath.tickCount - 1, activeIndex: active),
                       1.0, accuracy: 0.001)
    }

    func testSingleLitTickDoesNotDivideByZero() {
        // fraction 0 lights exactly one tick; the ramp's denominator is that index.
        let active = AuraGaugeMath.activeIndex(fraction: 0)
        XCTAssertEqual(active, 0)
        let opacity = AuraGaugeMath.opacity(forTick: 0, activeIndex: active)
        XCTAssertTrue(opacity.isFinite)
        XCTAssertEqual(opacity, 1.0, accuracy: 0.001)
    }

    // MARK: Layout

    func testTopInsetPlacesATickAtItsIntendedRadius() {
        // The inset is what positions a tick before the ring is rotated; if it drifts, every tick
        // moves off the circle at once.
        let inset = AuraGaugeMath.topInset(radius: AuraGaugeMath.tickRadius, length: AuraGaugeMath.majorTickLength)
        let centreFromTop = inset + AuraGaugeMath.majorTickLength / 2
        XCTAssertEqual(AuraGaugeMath.ringSize / 2 - centreFromTop, AuraGaugeMath.tickRadius, accuracy: 0.001)
    }

    func testRingIsLargeEnoughToHoldItsTicks() {
        XCTAssertGreaterThanOrEqual(
            AuraGaugeMath.ringSize / 2,
            AuraGaugeMath.tickRadius + AuraGaugeMath.majorTickLength / 2
        )
    }

    func testMarkerSitsInsideTheTickRing() {
        // The marker points outward through the ticks; if it passed them it would read as a separate
        // element floating outside the gauge.
        XCTAssertLessThan(AuraGaugeMath.markerRadius, AuraGaugeMath.tickRadius)
    }

    // MARK: Body state

    func testEveryBodyStateSitsOnTheArc() {
        for state in AuraBodyState.allCases {
            XCTAssertTrue((0...1).contains(state.gaugeFraction), "\(state.rawValue) is off the arc")
        }
    }

    func testBodyStateFractionsDescendFromRestoredToDepleted() {
        // The temperature ramp only reads if the four states stay ordered.
        let fractions = AuraBodyState.allCases.map(\.gaugeFraction)
        XCTAssertEqual(fractions, fractions.sorted(by: >))
    }

    func testBodyStateRawValuesAreStable() {
        // Persisted / passed across the app, so these strings are a contract.
        XCTAssertEqual(AuraBodyState.allCases.map(\.rawValue),
                       ["restored", "ready", "strained", "depleted"])
    }

    func testEveryBodyStateSuppliesItsFullVoice() {
        // A state with an empty line would render a blank where the screen's only sentence should be.
        for state in AuraBodyState.allCases {
            XCTAssertFalse(state.label.isEmpty, "\(state.rawValue) has no label")
            XCTAssertFalse(state.coaching.isEmpty, "\(state.rawValue) has no coaching line")
            XCTAssertFalse(state.session.isEmpty, "\(state.rawValue) has no session")
            XCTAssertFalse(state.sessionRationale.isEmpty, "\(state.rawValue) has no rationale")
        }
    }

    func testOrbGradientIsAThreeStopRampPerState() {
        for state in AuraBodyState.allCases {
            let stops = state.orbStops
            XCTAssertEqual(stops.count, 3, "\(state.rawValue) orb ramp changed shape")
            XCTAssertEqual(stops.map(\.location), [0, 0.55, 1])
        }
    }
}
