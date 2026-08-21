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

    /// The physiological cross-check, on the v18 records that carry more than one interval. A single
    /// interval is an instantaneous beat and the record's `heart_rate` is an average, so n=1 records
    /// cannot separate the hypotheses — normal beat-to-beat variability exceeds the 2.4% difference.
    func testMultiBeatV18RecordsFavourTheTickReading() {
        // (heart_rate, raw v18 intervals) — from the real captures in `decoder_oracle.json`.
        let records: [(hr: Double, raw: [Int])] = [
            (102, [602, 613]),
            (109, [568, 578]),
        ]
        for record in records {
            let asMilliseconds = Double(record.raw.reduce(0, +)) / Double(record.raw.count)
            let asTicks = asMilliseconds * 1_000.0 / 1_024.0
            let errorAsMilliseconds = abs(60_000.0 / asMilliseconds - record.hr)
            let errorAsTicks = abs(60_000.0 / asTicks - record.hr)
            XCTAssertLessThan(errorAsTicks, errorAsMilliseconds,
                              "reading \(record.raw) as ticks should land closer to hr \(record.hr)")
            XCTAssertLessThan(errorAsTicks, 2.0, "and within 2 bpm of the record's own heart rate")
        }
    }
}
