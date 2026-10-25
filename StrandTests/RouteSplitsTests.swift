import XCTest
@testable import Strand

final class RouteSplitsTests: XCTestCase {
    /// A straight line north at a steady speed: 0.009° of latitude is about 1 km.
    private func line(kmPerStep: Double, steps: Int, secondsPerStep: Int64, start: Int64 = 1_000_000) -> [WorkoutRoutePoint] {
        (0...steps).map { i in
            WorkoutRoutePoint(lat: 0.00899322 * kmPerStep * Double(i), lon: 0, accuracyM: 5,
                              tMs: start + Int64(i) * secondsPerStep * 1000)
        }
    }

    func testSteadyRunSplitsEvenlyWithAPartKilometreAtTheEnd() {
        // 2.5 km at 5:00 /km, a point every 100 m.
        let s = RouteSplits.splits(line(kmPerStep: 0.1, steps: 25, secondsPerStep: 30))
        XCTAssertEqual(s.count, 3)
        XCTAssertEqual(s[0].seconds, 300, accuracy: 2)
        XCTAssertEqual(s[1].seconds, 300, accuracy: 2)
        XCTAssertEqual(s[2].meters, 500, accuracy: 5)
        XCTAssertEqual(s[2].pace, 300, accuracy: 3)
    }

    func testAPauseIsNotCountedAsSlowRunning() {
        var points = line(kmPerStep: 0.1, steps: 10, secondsPerStep: 30)
        // Paused for ten minutes at 500 m: the first fix after resuming is where the runner stood.
        var resumed = points[5]
        resumed.tMs += 600_000
        for i in 6..<points.count { points[i].tMs += 600_000 }
        points.insert(resumed, at: 6)
        let s = RouteSplits.splits(points)
        XCTAssertEqual(s.first?.seconds ?? 0, 300, accuracy: 2)
    }

    func testTooLittleRouteSaysNothing() {
        XCTAssertTrue(RouteSplits.splits(line(kmPerStep: 0.01, steps: 5, secondsPerStep: 3)).isEmpty)
        XCTAssertTrue(RouteSplits.splits([]).isEmpty)
    }
}
