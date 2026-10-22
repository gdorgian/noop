import XCTest
@testable import StrandAnalytics

/// Synthetic sessions shaped like the ones the old detector missed, and the daily-life elevations it
/// must keep ignoring. Every series is 1 Hz with small deterministic jitter, resting 62, max 190.
final class ActivityBoutDetectorTests: XCTestCase {
    let rest = 62.0, maxHR = 190.0
    let t0 = 1_790_000_000

    /// Builds 1 Hz samples from (seconds, bpm) segments, with ±3 bpm jitter.
    func series(_ parts: [(Int, Double)], start: Int? = nil) -> [(ts: Int, bpm: Int)] {
        var out: [(ts: Int, bpm: Int)] = []
        var t = start ?? t0
        for (dur, bpm) in parts {
            for k in 0..<dur {
                out.append((t, Int((bpm + Double((t * 7 + k) % 7) - 3).rounded())))
                t += 1
            }
        }
        return out
    }

    func motion(_ hr: [(ts: Int, bpm: Int)], level: Double) -> [(ts: Int, intensity: Double)] {
        hr.map { ($0.ts, level) }
    }

    func detect(_ hr: [(ts: Int, bpm: Int)], motion m: [(ts: Int, intensity: Double)] = [],
                sleep: [ActivityBoutDetector.Span] = []) -> [ActivityBoutDetector.Bout] {
        ActivityBoutDetector.detect(hr: hr, restingBpm: rest, maxBpm: maxHR, motion: m, sleep: sleep)
    }

    // MARK: Sessions it must find

    func testLiftingWithRestsBetweenSetsIsOneStrengthSession() {
        // Ten sets: 60 s at 135, then 150 s of recovery at 88 — the rest would end the old detector's bout.
        var parts: [(Int, Double)] = [(600, 66)]
        for _ in 0..<10 { parts += [(60, 135), (150, 88)] }
        parts.append((600, 68))
        let hr = series(parts)
        let bouts = detect(hr, motion: motion(hr, level: 0.08))
        XCTAssertEqual(bouts.count, 1)
        XCTAssertGreaterThanOrEqual(bouts[0].durationMin, 30)
        XCTAssertEqual(bouts[0].sport, .strength)
        // The old confirmation detector misses it entirely.
        XCTAssertTrue(AutoWorkoutDetector.detect(hr: hr, restingBpm: 62).isEmpty)
    }

    func testSwimmingWithWallRestsIsOneSession() {
        var parts: [(Int, Double)] = [(300, 70)]
        for _ in 0..<12 { parts += [(150, 128), (40, 104)] }
        parts.append((300, 72))
        let hr = series(parts)
        let bouts = detect(hr, motion: motion(hr, level: 0.2))
        XCTAssertEqual(bouts.count, 1)
        XCTAssertGreaterThanOrEqual(bouts[0].durationMin, 36)
    }

    func testIntervalsAreOneSession() {
        var parts: [(Int, Double)] = [(300, 68), (300, 120)]
        for _ in 0..<5 { parts += [(240, 165), (180, 112)] }
        parts.append((300, 75))
        let hr = series(parts)
        let bouts = detect(hr)
        XCTAssertEqual(bouts.count, 1, "hard intervals qualify even with no motion recorded")
        XCTAssertGreaterThan(bouts[0].trimp, 20)
    }

    func testSteadyRunIsOneGenericBout() {
        // Naming a run is the classifier's job; the detector finds it and does not call it strength.
        let hr = series([(300, 70), (1800, 152), (300, 90)])
        let bouts = detect(hr, motion: motion(hr, level: 0.3))
        XCTAssertEqual(bouts.count, 1)
        XCTAssertEqual(bouts[0].sport, .activity)
    }

    func testBriskWalkIsFound() {
        let hr = series([(300, 72), (2100, 104), (300, 75)])
        XCTAssertEqual(detect(hr, motion: motion(hr, level: 0.12)).count, 1)
    }

    // MARK: Things it must ignore

    func testStressOrCoffeeWithoutMovementIsIgnored() {
        // Forty minutes sitting at 92 bpm: elevated, long, and not exercise.
        let hr = series([(600, 70), (2400, 92), (600, 72)])
        XCTAssertTrue(detect(hr, motion: motion(hr, level: 0.01)).isEmpty)
        XCTAssertTrue(detect(hr).isEmpty)
    }

    func testShortHardEffortIsNotAnActivity() {
        // Six minutes of stairs at 140.
        let hr = series([(600, 70), (360, 140), (600, 75)])
        XCTAssertTrue(detect(hr, motion: motion(hr, level: 0.3)).isEmpty)
    }

    func testRecordingGapIsNotExercise() {
        // Two 7-minute efforts with twenty minutes of nothing between them.
        let a = series([(420, 140)])
        let b = series([(420, 140)], start: t0 + 420 + 1200)
        XCTAssertTrue(detect(a + b).isEmpty)
    }

    func testNothingDuringSleep() {
        let hr = series([(2400, 130)])
        let sleep = [ActivityBoutDetector.Span(startSec: t0 - 3600, endSec: t0 + 600)]
        XCTAssertTrue(detect(hr, sleep: sleep).isEmpty)
    }

    func testAlreadyLoggedWorkoutIsNotDetectedAgain() {
        let hr = series([(300, 70), (1800, 150), (300, 80)])
        let logged = [ActivityBoutDetector.Span(startSec: t0 + 400, endSec: t0 + 2000)]
        XCTAssertTrue(ActivityBoutDetector.detect(hr: hr, restingBpm: rest, maxBpm: maxHR, exclude: logged).isEmpty)
    }

    func testBoundsAreTrimmedToTheEffort() {
        let hr = series([(900, 66), (1500, 150), (900, 70)])
        let b = detect(hr)[0]
        XCTAssertEqual(Double(b.startSec - t0), 900, accuracy: 60)
        XCTAssertEqual(Double(b.endSec - (t0 + 2400)), 0, accuracy: 120)
    }

    func testFitterWearerEasySessionStillCounts() {
        // Resting 45: an easy 40-minute spin at 105 is 0.41 of reserve — work, though only +60 over rest
        // would be needed by the old rule and a less fit wearer would sit higher.
        let hr = series([(300, 50), (2400, 105), (300, 52)])
        let bouts = ActivityBoutDetector.detect(hr: hr, restingBpm: 45, maxBpm: 190)
        XCTAssertEqual(bouts.count, 1)
    }

    func testCyclesCountsSetsAndRests() {
        let x: [Double] = [0.1, 0.4, 0.2, 0.15, 0.42, 0.2, 0.18, 0.41, 0.19, 0.2, 0.44, 0.2]
        XCTAssertGreaterThanOrEqual(ActivityBoutDetector.cycles(x), 3)
        XCTAssertEqual(ActivityBoutDetector.cycles(Array(repeating: 0.4, count: 12)), 0)
    }
}
