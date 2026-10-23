import XCTest
import WhoopProtocol
@testable import StrandAnalytics

/// A late sleeper: asleep 03:00–10:00 local, awake and sitting at a steady 76 bpm after.
final class DaytimeStressSleepTests: XCTestCase {
    private let day = 1_790_000_000 - (1_790_000_000 % 86_400)   // a UTC midnight; tz offset 0

    private func samples() -> [HRSample] {
        stride(from: day + 3 * 3600, to: day + 16 * 3600, by: 5).map { ts in
            let asleep = ts < day + 10 * 3600
            let hour = (ts - day) / 3600
            return HRSample(ts: ts, bpm: asleep ? 56 + (ts / 60) % 3 : 72 + [0, 3, 6, 2, 5, 1][hour % 6] + (ts / 60) % 3)
        }
    }

    func testSleepingHoursDoNotSetTheCalmReference() {
        let hr = samples()
        let clockOnly = DaytimeStress.analyze(hr: hr, rr: [], tzOffsetSeconds: 0)
        let aware = DaytimeStress.analyze(hr: hr, rr: [], tzOffsetSeconds: 0,
                                          asleep: [(day + 3 * 3600)...(day + 10 * 3600)])
        func awakeLevels(_ r: DaytimeStress.Result) -> [Double] {
            r.hours.filter { $0.startTs >= day + 10 * 3600 }.compactMap(\.level)
        }
        func high(_ xs: [Double]) -> Int { xs.filter { $0 >= DaytimeStress.highBandFloor }.count }
        // Judged against 06:00–10:00 sleep, every hour of a sitting afternoon reads high…
        XCTAssertEqual(high(awakeLevels(clockOnly)), awakeLevels(clockOnly).count)
        // …judged against the waking hours alone, fewer do, and the afternoon reads lower overall.
        XCTAssertLessThan(high(awakeLevels(aware)), high(awakeLevels(clockOnly)))
        func mean(_ xs: [Double]) -> Double { xs.reduce(0, +) / Double(max(xs.count, 1)) }
        XCTAssertLessThan(mean(awakeLevels(aware)), mean(awakeLevels(clockOnly)) - 0.5)
    }

    func testSleepingHoursAreStillScoredAndDrawn() {
        let aware = DaytimeStress.analyze(hr: samples(), rr: [], tzOffsetSeconds: 0,
                                          asleep: [(day + 3 * 3600)...(day + 10 * 3600)])
        let night = aware.hours.filter { $0.startTs >= day + 3 * 3600 && $0.startTs < day + 10 * 3600 }
        XCTAssertEqual(night.count, 7, "03:00–10:00 is scored, including the hours before 06:00")
        XCTAssertTrue(night.allSatisfy { ($0.level ?? 3) < 1 }, "sleep reads low: \(night.map { $0.level ?? -1 })")
    }

    func testNoisyWakingHRVDoesNotMakeSleepHigh() {
        // Waking R-R read through movement often shows MORE variability than sleep. Against that
        // reference every quiet sleeping hour scored as high; against the night's own, it reads low.
        let rr: [RRInterval] = stride(from: day + 3 * 3600, to: day + 16 * 3600, by: 2).enumerated().map { i, ts in
            let asleep = ts < day + 10 * 3600
            let swing = asleep ? 20 : 70
            return RRInterval(ts: ts, rrMs: (asleep ? 1050 : 800) + (i % 2 == 0 ? swing : -swing) / 2)
        }
        let aware = DaytimeStress.analyze(hr: samples(), rr: rr, tzOffsetSeconds: 0,
                                          asleep: [(day + 3 * 3600)...(day + 10 * 3600)])
        let night = aware.hours.filter { $0.startTs < day + 10 * 3600 }
        XCTAssertEqual(night.count, 7)
        XCTAssertTrue(night.allSatisfy { ($0.level ?? 3) < 1 }, "sleep reads low: \(night.map { $0.level ?? -1 })")
    }

    func testNoSleepWindowIsUnchanged() {
        let hr = samples()
        XCTAssertEqual(DaytimeStress.analyze(hr: hr, rr: [], tzOffsetSeconds: 0),
                       DaytimeStress.analyze(hr: hr, rr: [], tzOffsetSeconds: 0, asleep: []))
    }
}
