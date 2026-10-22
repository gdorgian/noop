import XCTest
import WhoopProtocol
@testable import StrandAnalytics

final class InBedWakeTests: XCTestCase {

    /// One minute of the synthetic night: pulse, whether the wrist moves, and the stage the stager gave it.
    struct Minute { var bpm: Int?; var moving: Bool; var stage: String }

    let t0 = 1_760_000_000 / 60 * 60

    /// 23:00–07:30 style night: asleep at 52 with REM bumps, every minute staged light (the stager's miss).
    func night(minutes: Int = 510, edit: (Int) -> Minute? = { _ in nil }) -> [Minute] {
        (0..<minutes).map { m in
            if let e = edit(m) { return e }
            let rem = (m % 90) >= 70          // twenty minutes of REM each cycle
            return Minute(bpm: rem ? 57 : 52, moving: m % 47 == 0, stage: rem ? "rem" : "light")
        }
    }

    func streams(_ ms: [Minute]) -> (hr: [HRSample], grav: [GravitySample], stages: [StageSegment]) {
        var hr: [HRSample] = [], grav: [GravitySample] = [], stages: [StageSegment] = []
        var angle = 0.0
        for (m, x) in ms.enumerated() {
            let base = t0 + m * 60
            if let b = x.bpm { for s in stride(from: 0, to: 60, by: 1) { hr.append(.init(ts: base + s, bpm: b)) } }
            for s in stride(from: 0, to: 60, by: 5) {
                if x.moving { angle += 0.05 }
                grav.append(.init(ts: base + s, x: sin(angle), y: cos(angle), z: 0.1))
            }
            if let last = stages.last, last.stage == x.stage, last.end == base {
                stages[stages.count - 1].end = base + 60
            } else {
                stages.append(.init(start: base, end: base + 60, stage: x.stage))
            }
        }
        return (hr, grav, stages)
    }

    func edges(_ ms: [Minute], band: [(ts: Int, state: Int)] = []) -> InBedWake.Edges {
        let s = streams(ms)
        return InBedWake.measure(s.stages, start: t0, end: t0 + ms.count * 60, hr: s.hr, grav: s.grav,
                                 bandSleepState: band)
    }

    func testLyingAwakeAfterWakingIsNotSleep() {
        // Woke at minute 450 and stayed in bed an hour, on the phone: pulse up, small movements.
        let ms = night { m in m >= 450 ? Minute(bpm: 63 + m % 3, moving: m % 4 != 0, stage: "light") : nil }
        let e = edges(ms)
        XCTAssertEqual(e.afterWakeMin, 60, accuracy: 3)
        XCTAssertEqual(e.latencyMin, 0)
    }

    func testRefineRelabelsTheTailAsWake() {
        let ms = night { m in m >= 450 ? Minute(bpm: 64, moving: true, stage: "light") : nil }
        let s = streams(ms)
        let out = InBedWake.refine(s.stages, start: t0, end: t0 + 510 * 60, hr: s.hr, grav: s.grav)
        let wake = out.filter { $0.stage == "wake" }.reduce(0) { $0 + $1.end - $1.start } / 60
        XCTAssertEqual(wake, 60, accuracy: 3)
        XCTAssertEqual(out.first?.start, t0)
        XCTAssertEqual(out.last?.end, t0 + 510 * 60)
        // Tiles the night with no gaps.
        for (a, b) in zip(out, out.dropFirst()) { XCTAssertEqual(a.end, b.start) }
    }

    func testReadingBeforeSleepIsLatency() {
        let ms = night { m in m < 25 ? Minute(bpm: 66, moving: m % 3 != 0, stage: "light") : nil }
        XCTAssertEqual(edges(ms).latencyMin, 25, accuracy: 3)
    }

    func testMorningREMStaysSleep() {
        // Raised but still pulse in the last half hour: REM, not waking.
        let ms = night { m in m >= 480 ? Minute(bpm: 59, moving: false, stage: "rem") : nil }
        XCTAssertEqual(edges(ms), InBedWake.Edges(latencyMin: 0, afterWakeMin: 0))
    }

    func testTurnOverAtTheEndStaysSleep() {
        // A minute of movement at a sleeping pulse is a turn-over.
        let ms = night { m in m >= 505 ? Minute(bpm: 53, moving: true, stage: "light") : nil }
        XCTAssertEqual(edges(ms).afterWakeMin, 0)
    }

    func testStrapWakeStateCountsWithAStillWrist() {
        // Awake and perfectly still, pulse only slightly up; the strap's own state says awake.
        let ms = night { m in m >= 470 ? Minute(bpm: 55, moving: false, stage: "light") : nil }
        let band = (470..<510).map { (ts: t0 + $0 * 60 + 30, state: 0) }
        XCTAssertEqual(edges(ms, band: band).afterWakeMin, 40, accuracy: 3)
        XCTAssertEqual(edges(ms).afterWakeMin, 0)   // without it, still and barely raised stays sleep
    }

    func testNoHeartRateLeavesTheNightAlone() {
        let ms = night { _ in Minute(bpm: nil, moving: false, stage: "light") }
        XCTAssertEqual(edges(ms), InBedWake.Edges(latencyMin: 0, afterWakeMin: 0))
    }

    func testAlwaysLeavesAnHourOfSleep() {
        // A short night that looks awake almost throughout keeps its sleep.
        let ms = night(minutes: 150) { m in m >= 40 ? Minute(bpm: 66, moving: true, stage: "light") : nil }
        let e = edges(ms)
        XCTAssertLessThanOrEqual(150 - e.latencyMin - e.afterWakeMin, 150)
        let s = streams(ms)
        let out = InBedWake.refine(s.stages, start: t0, end: t0 + 150 * 60, hr: s.hr, grav: s.grav)
        let asleep = out.filter { $0.stage != "wake" }.reduce(0) { $0 + $1.end - $1.start } / 60
        XCTAssertGreaterThanOrEqual(asleep, 40)
    }

    func testTracksDifferentAwakeDurations() {
        for awake in [15, 30, 45, 75, 100] {
            let ms = night { m in m >= 510 - awake ? Minute(bpm: 62, moving: m % 2 == 0, stage: "light") : nil }
            XCTAssertEqual(Double(edges(ms).afterWakeMin), Double(awake), accuracy: 3, "awake \(awake)")
        }
    }
}
