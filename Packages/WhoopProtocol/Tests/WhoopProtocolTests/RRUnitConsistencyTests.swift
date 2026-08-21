import XCTest
@testable import WhoopProtocol

/// Why the v18 historical R-R is read as 1/1024-second ticks rather than milliseconds (#1008/#1118).
///
/// A WHOOP 5.0 emits the SAME beat train twice: live over the standard Bluetooth Heart Rate
/// Measurement characteristic (0x2A37), and again inside its own type-47 historical records. The
/// Bluetooth spec fixes the unit on the first one — RR-Interval is uint16 in 1/1024 s — and
/// `Strand/BLE/StandardHeartRate.swift` has always converted it. The historical field was read as
/// milliseconds, so one strap was reporting one quantity in two different units and nothing compared
/// them, because until R-R rows carried a transport label the two copies were indistinguishable.
///
/// Reading the v18 field as ticks makes the two transports agree. Reading it as milliseconds makes the
/// historical copy of a beat 2.4% longer than the live copy of that same beat — which reads as a
/// lower heart rate and a slightly inflated HRV, on exactly the records scoring prefers.
///
/// The conversion is VERSION-LOCAL to v18. WHOOP 4's v24 values are already milliseconds (their
/// unconverted values satisfy `60000/mean(R-R) ≈ HR`); v20/v21/v25/v26 carry no R-R at all.
final class RRUnitConsistencyTests: XCTestCase {

    /// The two units, on the beat the real v18 fixtures carry.
    func testTickReadingAgreesWithTheStandardBLEConversion() {
        // `StandardHeartRate` maps a raw 0x2A37 value to ms as `raw / 1024 * 1000`.
        func standardBLEms(_ raw: Int) -> Int { Int((Double(raw) / 1024.0 * 1000.0).rounded()) }
        // `Interpreter` maps a raw v18 value with the integer form of the same conversion.
        func v18ms(_ raw: Int) -> Int { (raw * 1_000 + 512) / 1_024 }

        for raw in [568, 578, 595, 602, 613, 800, 1_000] {
            XCTAssertEqual(v18ms(raw), standardBLEms(raw),
                           "the two transports must resolve the same raw value to the same ms")
        }
    }

    /// The physiological cross-check, on every REAL record the oracle holds. It does not settle the
    /// question, and this test exists to say so rather than to imply otherwise.
    ///
    /// An earlier version of this test claimed two multi-beat v18 records both favoured the tick reading.
    /// One of them was `whoop4_v24_real_worn` — a WHOOP 4 record, not a WHOOP 5 one — and its cited values
    /// `[568, 578]` did not exist anywhere: they were the fixture's real `[555, 564]` multiplied by 1.024.
    /// v24 is never converted, so its stored values ARE its raw values, and back-computing "raw ticks" from
    /// them fabricated a row that then agreed with the hypothesis it was cited to support. Upstream caught
    /// it (ryanbr/noop#1505). The lesson is the repo's own rule: a fixture cannot test units, because
    /// agreement is a property of whoever wrote it.
    ///
    /// What the real records actually say:
    ///
    ///   whoop5_v18_real_worn    hr=102  raw [602, 613]   as-ms 98.77 (−3.23)   as-ticks 101.14 (−0.86)
    ///   whoop5_v18_real_one_rr  hr=101  raw [595]        as-ms 100.84 (−0.16)  as-ticks 103.26 (+2.26)
    ///
    /// Mean |residual| is 1.70 bpm under milliseconds and 1.59 bpm under ticks. That is a tie, on two
    /// records totalling three beats, where the units question is worth 2.3 bpm and beat-to-beat scatter
    /// on a two-beat mean is larger than that.
    func testTheOracleCannotSettleTheUnitsQuestion() {
        // (heart_rate, RAW v18 values as they appear in the frame bytes).
        let realV18: [(hr: Double, raw: [Int])] = [
            (102, [602, 613]),
            (101, [595]),
        ]
        func residual(_ record: (hr: Double, raw: [Int]), asTicks: Bool) -> Double {
            var mean = Double(record.raw.reduce(0, +)) / Double(record.raw.count)
            if asTicks { mean = mean * 1_000.0 / 1_024.0 }
            return 60_000.0 / mean - record.hr
        }
        let msError = realV18.map { abs(residual($0, asTicks: false)) }.reduce(0, +) / 2
        let tickError = realV18.map { abs(residual($0, asTicks: true)) }.reduce(0, +) / 2

        // Neither reading is separated by this evidence. If a future capture makes one of them clearly
        // better, this assertion fails and the comment above has to be rewritten — which is the point.
        XCTAssertEqual(msError, tickError, accuracy: 0.5,
                       "two records, three beats: the oracle does not discriminate the units")
    }

    /// Why the physiological cross-check cannot answer this, demonstrated on a record whose units are
    /// not in question.
    ///
    /// `whoop4_v24_real_worn` is WHOOP 4 v24. We never convert it, and the decoder header's 88%
    /// agreement figure was measured with it read as milliseconds. If `60000/mean(R-R) ≈ heart_rate`
    /// could separate a 2.4% scale error, this record should read clearly better as milliseconds.
    ///
    /// It reads better as TICKS (residual +0.81 vs −1.76) — on a record that is milliseconds. The check
    /// is not measuring units at this sample size: the units question is worth 2.4–2.6 bpm on all three
    /// real records, and the residual scatter is the same size or larger.
    ///
    /// That also settles what the 88% figure can tell us, which is nothing either way. A systematic 2.4%
    /// bias moves each residual by less than the spread already present, so an 88% pass rate is
    /// consistent with both readings and recomputing it under the other one will not separate them.
    func testTheCrossCheckCannotDiscriminateUnitsAtTheseSampleSizes() {
        func residual(hr: Double, raw: [Int], asTicks: Bool) -> Double {
            var mean = Double(raw.reduce(0, +)) / Double(raw.count)
            if asTicks { mean = mean * 1_000.0 / 1_024.0 }
            return 60_000.0 / mean - hr
        }
        // A record we KNOW is milliseconds, "preferring" the tick reading.
        let asMilliseconds = residual(hr: 109, raw: [555, 564], asTicks: false)
        let asTicks = residual(hr: 109, raw: [555, 564], asTicks: true)
        XCTAssertLessThan(abs(asTicks), abs(asMilliseconds),
                          "a millisecond record reads 'better' as ticks — the check is not a units test")

        // And the effect being hunted is smaller than the check's own scatter, on every real record.
        for (hr, raw) in [(109.0, [555, 564]), (102.0, [602, 613]), (101.0, [595])] {
            _ = hr
            let mean = Double(raw.reduce(0, +)) / Double(raw.count)
            let separation = 60_000.0 / (mean * 1_000.0 / 1_024.0) - 60_000.0 / mean
            XCTAssertLessThan(separation, 3.0, "the units question is worth under 3 bpm here")
        }
    }

    /// The strongest evidence anyone has, and it is a single pair. Reported upstream from a #1451
    /// diagnostic: one stored second carrying two R-R rows, `-1s[872#0, 893#0]`, both at ord 0 — which
    /// per `RRInterval.ord`'s contract means two SEPARATE deliveries of the same beat, not two beats from
    /// one record's array. Their ratio is the conversion, to within a rounding step.
    ///
    /// n=1, and 21 ms is also an ordinary beat-to-beat difference. This is the shape of evidence that
    /// withdrew #194, so it is recorded here as a lead to confirm, not as a proof.
    func testTheObservedDuplicatePairMatchesTheConversion() {
        XCTAssertEqual(Double(893) * 1_000.0 / 1_024.0, 872, accuracy: 0.5)
    }
}
