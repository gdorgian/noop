import Foundation
import WhoopProtocol

/// Pure, testable mapping from a single standard-BLE Heart-Rate reading (0x2A37) onto the
/// datastore's `Streams` shape, so an isolated generic-strap source (`StandardHRSource` in the
/// app target) can persist its samples through the SAME `StreamStore.insert` path the WHOOP
/// pipeline uses — without duplicating the row-construction logic in the app target where it
/// can't be unit-tested.
///
/// A chest strap (Polar / Wahoo / Coospo / Garmin HRM / Amazfit Helio broadcast) only ever
/// reports HR and (optionally) R-R intervals over 0x2A37; every other stream (spo2, skin temp,
/// resp, gravity, steps, ppgHr, events, battery) is left empty.
public enum StandardHRMapping {
    /// Map already-decoded millisecond intervals while retaining the transport label chosen by the
    /// caller. Generic chest straps leave `source` nil; WHOOP's Collector passes `.whoopStandardBLE`
    /// so those live rows remain distinguishable from the historical replay of the same beats.
    public static func rrSamples(_ rr: [Int], at ts: Int,
                                 source: RRSourceChannel? = nil) -> [RRInterval] {
        rr.map { RRInterval(ts: ts, rrMs: $0, srcChannel: source) }
    }

    /// Build a `Streams` carrying one HR sample and zero-or-more R-R intervals, all stamped at the
    /// same wall-clock `ts` (unix seconds). Pure → unit-testable.
    public static func samples(fromHR hr: Int, rr: [Int], at ts: Int) -> Streams {
        Streams(
            hr: [HRSample(ts: ts, bpm: hr)],
            rr: rrSamples(rr, at: ts)
        )
    }
}
