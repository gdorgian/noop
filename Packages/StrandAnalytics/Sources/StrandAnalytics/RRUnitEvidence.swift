import Foundation

// MARK: - Settling the v18 R-R units question on real data
//
// The physiological cross-check (`60000/mean(R-R) ≈ heart_rate`) cannot answer whether the WHOOP 5 v18
// historical R-R field is in milliseconds or in 1/1024-second ticks. That is not an opinion: a WHOOP 4
// v24 record — a layout we never convert, and the one the decoder's 88% agreement figure was measured on
// — reads *better* under a tick conversion than under the milliseconds it actually is. The effect being
// hunted is worth 2.4–2.6 bpm on every real record we hold, and the residual scatter on a one- or
// two-beat mean is the same size or larger. A statistic cannot separate two hypotheses that sit inside
// its own noise floor, and recomputing the 88% under the other reading will not change that.
//
// There is a test that can, and it needs no new capture — only the transport labels the store now carries.
//
// ## The measurement
//
// A WHOOP 5 delivers the same beat twice: live over the standard Bluetooth Heart Rate Measurement
// characteristic (`0x2A37`), where the Bluetooth spec fixes the unit at 1/1024 s and NOOP has always
// converted, and again inside its own v18 historical record, which is read raw. If v18 were milliseconds,
// the two copies of one beat agree. If v18 is ticks, the historical copy is 1.024× the live one.
//
// So: find seconds carrying more than one durable R-R row, pair them up, and look at the distribution of
// their ratios. Two clusters are expected and they mean opposite things —
//
//   • ratio ≈ 1.024 → the same beat, seen twice, in two units. The units question is answered.
//   • ratio ≈ 1.00x → two genuinely different beats in the same second (ordinary beat-to-beat
//     variability), which says nothing about units.
//
// One pair proves nothing: 872 and 893 differ by 21 ms, and 21 ms is also a perfectly ordinary
// beat-to-beat step. What settles it is whether the ratios PILE UP at 1.024 rather than spreading around
// 1.0 the way sinus arrhythmia would. That is the shape of evidence #194 was withdrawn for lacking, and
// it is the shape this produces.

public enum RRUnitEvidence {

    /// The conversion under test: 1/1024-second ticks to milliseconds.
    public static let tickRatio = 1_024.0 / 1_000.0

    /// How close a ratio must sit to `tickRatio` to count as a units match. ±0.3% — tight enough that
    /// ordinary beat-to-beat variability does not wander into it, loose enough to absorb the integer
    /// rounding both transports apply.
    public static let matchTolerance = 0.003

    /// One second carrying two durable R-R rows.
    public struct Pair: Equatable, Sendable {
        public let ts: Int
        /// The value believed to be milliseconds already — the live 0x2A37 copy, converted at parse.
        public let liveMs: Int
        /// The value read raw out of the v18 historical record.
        public let historicalRaw: Int

        public init(ts: Int, liveMs: Int, historicalRaw: Int) {
            self.ts = ts
            self.liveMs = liveMs
            self.historicalRaw = historicalRaw
        }

        public var ratio: Double {
            liveMs > 0 ? Double(historicalRaw) / Double(liveMs) : 0
        }

        /// Whether this pair reads as one beat in two units rather than two different beats.
        public var matchesTickConversion: Bool {
            abs(ratio - RRUnitEvidence.tickRatio) <= RRUnitEvidence.matchTolerance
        }
    }

    /// What a run of pairs says.
    public struct Verdict: Equatable, Sendable {
        public let pairs: Int
        public let matchingTickConversion: Int
        /// Pairs whose two values are within rounding of each other.
        public let matchingIdentity: Int
        /// Pairs where the historical copy is 2.4% SHORT of the live one — what an over-conversion looks
        /// like once a converting build has banked rows.
        public let matchingOverConversion: Int
        public let medianRatio: Double

        public var fractionMatchingTicks: Double {
            pairs > 0 ? Double(matchingTickConversion) / Double(pairs) : 0
        }

        public init(pairs: Int, matchingTickConversion: Int, matchingIdentity: Int,
                    matchingOverConversion: Int = 0, medianRatio: Double) {
            self.pairs = pairs
            self.matchingTickConversion = matchingTickConversion
            self.matchingIdentity = matchingIdentity
            self.matchingOverConversion = matchingOverConversion
            self.medianRatio = medianRatio
        }

        /// A one-line read, written so it cannot overstate a thin sample.
        public var summary: String {
            guard pairs > 0 else {
                return "R-R units: no duplicate-transport pairs found — nothing to compare."
            }
            let percent = Int((fractionMatchingTicks * 100).rounded())
            let head = "R-R units: \(pairs) pair(s), median ratio \(String(format: "%.4f", medianRatio)); "
                + "\(matchingTickConversion) at 1.024 (\(percent)%), \(matchingIdentity) at 1.000, "
                + "\(matchingOverConversion) at 0.977"
            if pairs < minimumPairsForAVerdict {
                return head + " — too few pairs to conclude anything."
            }
            if fractionMatchingTicks >= 0.8 {
                return head + " — the historical copy is 1/1024-s ticks."
            }
            if Double(matchingIdentity) / Double(pairs) >= 0.8 {
                // On a database banked by a NON-converting build this means v18 was milliseconds all
                // along. On one banked by a converting build it means the conversion is correct and the
                // two transports now agree. Which build wrote the rows is the caller's to know.
                return head + " — the two transports agree."
            }
            if Double(matchingOverConversion) / Double(pairs) >= 0.8 {
                return head + " — the historical copy is 2.4% SHORT: the conversion is wrong, revert it."
            }
            return head + " — mixed; these are probably different beats, not two copies of one."
        }
    }

    /// Below this, say so rather than concluding. One pair is an anecdote; a handful of pairs that all
    /// land on 1.024 is not something beat-to-beat variability produces.
    public static let minimumPairsForAVerdict = 20

    /// Summarise a run of pairs.
    public static func verdict(for pairs: [Pair]) -> Verdict {
        let usable = pairs.filter { $0.liveMs > 0 && $0.historicalRaw > 0 }
        guard !usable.isEmpty else {
            return Verdict(pairs: 0, matchingTickConversion: 0, matchingIdentity: 0, medianRatio: 0)
        }
        let ratios = usable.map(\.ratio).sorted()
        let mid = ratios.count / 2
        let median = ratios.count % 2 == 1 ? ratios[mid] : (ratios[mid - 1] + ratios[mid]) / 2
        return Verdict(
            pairs: usable.count,
            matchingTickConversion: usable.filter(\.matchesTickConversion).count,
            matchingIdentity: usable.filter { abs($0.ratio - 1.0) <= matchTolerance }.count,
            matchingOverConversion: usable.filter { abs($0.ratio - 1.0 / tickRatio) <= matchTolerance }.count,
            medianRatio: median
        )
    }
}
