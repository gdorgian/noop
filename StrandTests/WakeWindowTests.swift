import XCTest
import WhoopProtocol
@testable import Strand

/// WakeWindow — the smart wake window's pure decision policy (`Strand/System/WakeWindow.swift`).
///
/// The policy is NOOP's own, trial-tunable heuristic (deliberately NOT decompiled WHOOP constants),
/// so these tests pin the DECISION TABLE, not magic numbers: which pattern fires early, which waits
/// for the ramp, which stays silent, and every data-shortfall no-fire path. Timer/runtime wiring
/// (sweep, dedupe, haptic) is deliberately not covered here — it is app-runtime, not policy.
final class WakeWindowTests: XCTestCase {

    // Fixed reference time on a whole minute.
    private let wake = Date(timeIntervalSince1970: 1_800_000_600)      // wake, on a minute boundary
    private var windowMinutes = 30

    private var wakeEpoch: Int { Int(wake.timeIntervalSince1970) }

    /// A stable "deep-looking" recent window: flat bpm, no jitter, floor == recent floor. The old
    /// history runs at the same bpm so elevation is 0.
    private func deepSamples(nowEpoch: Int) -> [HRSample] {
        var out: [HRSample] = []
        for t in stride(from: nowEpoch - 3_600, to: nowEpoch, by: 10) {
            out.append(HRSample(ts: t, bpm: 55))   // flat and stable, well past any misread gate
        }
        return out
    }

    /// A "wakeable" recent window: the last 15 minutes sit visibly above the overnight floor.
    private func lightSamples(nowEpoch: Int) -> [HRSample] {
        var out: [HRSample] = []
        for t in stride(from: nowEpoch - 3_600, to: nowEpoch - 900, by: 10) {
            out.append(HRSample(ts: t, bpm: 55))
        }
        for t in stride(from: nowEpoch - 900, to: nowEpoch, by: 10) {
            out.append(HRSample(ts: t, bpm: 63))   // +8 over the floor: restless by elevation
        }
        return out
    }

    private func decide(_ samples: [HRSample], now: Date) -> WakeWindow.Decision {
        WakeWindow.evaluate(now: now, wake: wake, windowMinutes: windowMinutes, recent: samples)
    }

    // MARK: window bounds

    func testNoFireBeforeTheWindowOpens() {
        let now = wake.addingTimeInterval(-31 * 60)      // 31 min out, window is 30
        XCTAssertEqual(decide(deepSamples(nowEpoch: wakeEpoch - 1_860), now: now).fire, false)
        XCTAssertEqual(decide(deepSamples(nowEpoch: wakeEpoch - 1_860), now: now).reason, "before window")
    }

    func testNoFireInsideTheFirmwareHandover() {
        // Last minute belongs to the strap's firmware alarm — never double-hit.
        let now = wake.addingTimeInterval(-30)
        XCTAssertEqual(decide(lightSamples(nowEpoch: Int(now.timeIntervalSince1970)), now: now).reason,
                       "inside firmware handover")
    }

    func testWindowMinutesClampToThePolicyBounds() {
        // Broken defaults can't collapse the feature: windowMinutes 0 behaves as the 5-minute
        // minimum (3 min out is INSIDE it and ramp-fires, 10 min out is not), and 999 behaves
        // as the 90-minute maximum (45 min out is inside it).
        windowMinutes = 0
        let threeOut = wake.addingTimeInterval(-3 * 60)
        XCTAssertEqual(decide(deepSamples(nowEpoch: Int(threeOut.timeIntervalSince1970)), now: threeOut).fire, true,
                       "a 0-minute ask clamps to 5, so 3 min out is ramp fire")
        let tenOut = wake.addingTimeInterval(-10 * 60)
        XCTAssertEqual(decide(deepSamples(nowEpoch: Int(tenOut.timeIntervalSince1970)), now: tenOut).fire, false,
                       "…while 10 min out is before a clamped-5 window")
        windowMinutes = 999
        let mid = wake.addingTimeInterval(-45 * 60)
        XCTAssertEqual(decide(deepSamples(nowEpoch: Int(mid.timeIntervalSince1970)), now: mid).reason.hasPrefix("stable deep-looking pattern"),
                       true,
                       "45 min out is inside a window clamped to the 90-minute maximum, and 45 min is not the ramp")
    }

    // MARK: data shortfalls never buzz a guess

    func testNoFireWhenRecentDataIsTooSparse() {
        let now = wake.addingTimeInterval(-15 * 60)
        let lonely = [HRSample(ts: wakeEpoch - 1_800, bpm: 60),
                      HRSample(ts: wakeEpoch - 1_700, bpm: 60)]
        let decision = decide(lonely, now: now)
        XCTAssertEqual(decision.fire, false)
        XCTAssertEqual(decision.reason, "insufficient recent HR data")
    }

    func testNoFireWhenEmptyInput() {
        let now = wake.addingTimeInterval(-15 * 60)
        XCTAssertEqual(decide([], now: now).fire, false)
    }

    // MARK: the decision table

    func testUniformRecentFloorReadsStableNotRestless() {
        // Overnight floor == recent floor == everything flat: elevation 0, slope 0, sd 0 → deep,
        // but inside the window there is still no buzz until the ramp.
        let now = wake.addingTimeInterval(-20 * 60)     // inside a 30-min window, 10 min before ramp
        windowMinutes = 30
        let decision = decide(deepSamples(nowEpoch: Int(now.timeIntervalSince1970)), now: now)
        XCTAssertEqual(decision.fire, false, "stable flat HR mid-window holds off; ramp owns the end")
        XCTAssertTrue(decision.reason.hasPrefix("stable deep-looking pattern"))
    }

    func testElevatedRecentFloorFires() {
        // Recent floor +8 over the overnight floor → restless → gentle loop-1 buzz.
        let now = wake.addingTimeInterval(-20 * 60)
        windowMinutes = 30
        let decision = decide(lightSamples(nowEpoch: Int(now.timeIntervalSince1970)), now: now)
        XCTAssertEqual(decision.fire, true)
        XCTAssertEqual(decision.buzzLoops, 1)
        XCTAssertTrue(decision.reason.hasPrefix("wakeable HR pattern"))
    }

    func testRisingRecentSlopeFires() {
        // Flat levels can't test the slope rule cleanly (elevation triggers first), so build a
        // window whose recent floor is level with the overnight floor but drifts upward inside
        // the recent slice: slow +0.2 bpm/10min… too slow; +3 bpm over 15 min = +2/10min ≥ 1.5.
        let now = wake.addingTimeInterval(-20 * 60)
        windowMinutes = 30
        var out: [HRSample] = []
        for t in stride(from: Int(now.timeIntervalSince1970) - 3_600, to: Int(now.timeIntervalSince1970) - 900, by: 10) {
            out.append(HRSample(ts: t, bpm: 55))
        }
        // Recent slice climbs 55 → 58 over its first half, flat over its last: the trailing third
        // sits ~+2 over the leading third → slope rule, while the LOWERMOST recent bpm stays at
        // 55, so the floor elevation stays 0.
        let recentStart = Int(now.timeIntervalSince1970) - 900
        for (index, t) in stride(from: recentStart, to: Int(now.timeIntervalSince1970), by: 10).enumerated() {
            let bpm = 55 + min(3, index / 15)
            out.append(HRSample(ts: t, bpm: bpm))
        }
        let decision = decide(out, now: now)
        XCTAssertEqual(decision.fire, true, "a slow climb is the classic pre-wake pattern")
        XCTAssertEqual(decision.buzzLoops, 1)
    }

    func testRampFiresGentleEvenWhenStable() {
        // A stable deep pattern inside the last 10 minutes still gets its gentle pull-up.
        let now = wake.addingTimeInterval(-8 * 60)
        let decision = decide(deepSamples(nowEpoch: Int(now.timeIntervalSince1970)), now: now)
        XCTAssertEqual(decision.fire, true)
        XCTAssertEqual(decision.buzzLoops, 2)
        XCTAssertTrue(decision.reason.hasPrefix("ramp"))
    }

    func testLongWindowStillBoundedByRampAndHandover() {
        // A 90-minute window: 95 min out is "before window"; 60 min out is INSIDE it but 50 min
        // past the ramp (a stable pattern holds off); 5 min out is ramp fire; the hand-over
        // still wins at the end.
        windowMinutes = 90
        let out95 = wake.addingTimeInterval(-95 * 60)
        XCTAssertEqual(decide(lightSamples(nowEpoch: Int(out95.timeIntervalSince1970)), now: out95).reason, "before window")
        let out60 = wake.addingTimeInterval(-60 * 60)
        XCTAssertTrue(decide(deepSamples(nowEpoch: Int(out60.timeIntervalSince1970)), now: out60)
            .reason.hasPrefix("stable deep-looking pattern"),
            "inside a 90-min window but far from the ramp, a stable pattern holds off")
        XCTAssertEqual(decide(lightSamples(nowEpoch: Int(out60.timeIntervalSince1970)), now: out60).fire, true,
                       "inside the window a restless pattern still fires early")
        let in5 = wake.addingTimeInterval(-5 * 60)
        XCTAssertEqual(decide(deepSamples(nowEpoch: Int(in5.timeIntervalSince1970)), now: in5).buzzLoops, 2)
    }
}
