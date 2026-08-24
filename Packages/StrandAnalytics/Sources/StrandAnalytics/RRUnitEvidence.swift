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
// characteristic (`0x2A37`), where the Bluetooth spec fixes the unit at 1/1024 s and NOOP converts at
// parse, and again inside its own v18 historical record. Depending on which build banked the history,
// the stored historical value may be raw or already converted. The diagnostic therefore recognises the
// tick, identity and over-conversion clusters and reports them without assuming the writer version.
//
// Receive timestamps are not the historical record's embedded timestamps, so exact-same-second pairing is
// not an instrument. Search the bounded integer lag range, keep every same-second beat in stable order, and
// look at the distribution of the resulting ratios. Three clusters are useful —
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

    /// One durable R-R value before it has been paired across transports. Callers provide same-second rows
    /// in emission/storage order; `lagSearch` preserves that order rather than sorting by R-R value.
    public struct TimedValue: Equatable, Sendable {
        public let ts: Int
        public let value: Int

        public init(ts: Int, value: Int) {
            self.ts = ts
            self.value = value
        }
    }

    /// Two transport rows paired at one candidate lag.
    public struct Pair: Equatable, Sendable {
        /// The live/receive timestamp. Retains the original `ts` API used by earlier diagnostics.
        public let ts: Int
        /// The historical record's embedded timestamp.
        public let historicalTs: Int
        /// The value believed to be milliseconds already — the live 0x2A37 copy, converted at parse.
        public let liveMs: Int
        /// The value stored from the v18 historical record (raw on old writers, converted on new writers).
        public let historicalRaw: Int

        public init(ts: Int, liveMs: Int, historicalRaw: Int) {
            self.ts = ts
            self.historicalTs = ts
            self.liveMs = liveMs
            self.historicalRaw = historicalRaw
        }

        public init(liveTs: Int, historicalTs: Int, liveMs: Int, historicalStored: Int) {
            self.ts = liveTs
            self.historicalTs = historicalTs
            self.liveMs = liveMs
            self.historicalRaw = historicalStored
        }

        public var ratio: Double {
            liveMs > 0 ? Double(historicalRaw) / Double(liveMs) : 0
        }

        /// Whether this pair reads as one beat in two units rather than two different beats.
        public var matchesTickConversion: Bool {
            abs(ratio - RRUnitEvidence.tickRatio) <= RRUnitEvidence.matchTolerance
        }

        public var matchesExactly: Bool { liveMs == historicalRaw }
    }

    /// What a run of pairs says.
    public struct Verdict: Equatable, Sendable {
        public enum Conclusion: String, Equatable, Sendable {
            case noPairs = "no-pairs"
            case insufficient
            case ticks
            case identity
            case overConverted = "over-converted"
            case mixed
        }

        public let pairs: Int
        public let matchingTickConversion: Int
        /// Pairs whose two values are within rounding of each other.
        public let matchingIdentity: Int
        /// Pairs where the historical copy is 2.4% SHORT of the live one — what an over-conversion looks
        /// like once a converting build has banked rows.
        public let matchingOverConversion: Int
        public let medianRatio: Double
        public let lowerQuartileRatio: Double
        public let upperQuartileRatio: Double
        public let minimumRatio: Double
        public let maximumRatio: Double
        public let exactValueMatches: Int

        public var fractionMatchingTicks: Double {
            pairs > 0 ? Double(matchingTickConversion) / Double(pairs) : 0
        }

        public var mismatches: Int { pairs - exactValueMatches }

        public var dominantClusterCount: Int {
            max(matchingTickConversion, matchingIdentity, matchingOverConversion)
        }

        public var dominantClusterFraction: Double {
            pairs > 0 ? Double(dominantClusterCount) / Double(pairs) : 0
        }

        public var conclusion: Conclusion {
            guard pairs > 0 else { return .noPairs }
            guard pairs >= RRUnitEvidence.minimumPairsForAVerdict else { return .insufficient }
            if fractionMatchingTicks >= 0.8 { return .ticks }
            if Double(matchingIdentity) / Double(pairs) >= 0.8 { return .identity }
            if Double(matchingOverConversion) / Double(pairs) >= 0.8 { return .overConverted }
            return .mixed
        }

        public init(pairs: Int, matchingTickConversion: Int, matchingIdentity: Int,
                    matchingOverConversion: Int = 0, medianRatio: Double,
                    lowerQuartileRatio: Double = 0, upperQuartileRatio: Double = 0,
                    minimumRatio: Double = 0, maximumRatio: Double = 0,
                    exactValueMatches: Int = 0) {
            self.pairs = pairs
            self.matchingTickConversion = matchingTickConversion
            self.matchingIdentity = matchingIdentity
            self.matchingOverConversion = matchingOverConversion
            self.medianRatio = medianRatio
            self.lowerQuartileRatio = lowerQuartileRatio
            self.upperQuartileRatio = upperQuartileRatio
            self.minimumRatio = minimumRatio
            self.maximumRatio = maximumRatio
            self.exactValueMatches = exactValueMatches
        }

        /// A one-line read, written so it cannot overstate a thin sample.
        public var summary: String {
            guard pairs > 0 else {
                return "R-R units: no duplicate-transport pairs found — nothing to compare."
            }
            let percent = Int((fractionMatchingTicks * 100).rounded())
            let head = "R-R units: \(pairs) pair(s), ratio q1/median/q3 "
                + "\(String(format: "%.4f", lowerQuartileRatio))/"
                + "\(String(format: "%.4f", medianRatio))/"
                + "\(String(format: "%.4f", upperQuartileRatio)); exact \(exactValueMatches), "
                + "mismatch \(mismatches); "
                + "\(matchingTickConversion) at 1.024 (\(percent)%), \(matchingIdentity) at 1.000, "
                + "\(matchingOverConversion) at 0.977"
            if conclusion == .insufficient {
                return head + " — too few pairs to conclude anything."
            }
            if conclusion == .ticks {
                return head + " — the historical copy is 1/1024-s ticks."
            }
            if conclusion == .identity {
                // On a database banked by a NON-converting build this means v18 was milliseconds all
                // along. On one banked by a converting build it means the conversion is correct and the
                // two transports now agree. Which build wrote the rows is the caller's to know.
                return head + " — the two transports agree."
            }
            if conclusion == .overConverted {
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
        func quantile(_ fraction: Double) -> Double {
            let position = fraction * Double(ratios.count - 1)
            let lower = Int(position.rounded(.down))
            let upper = Int(position.rounded(.up))
            guard lower != upper else { return ratios[lower] }
            let weight = position - Double(lower)
            return ratios[lower] * (1 - weight) + ratios[upper] * weight
        }
        return Verdict(
            pairs: usable.count,
            matchingTickConversion: usable.filter(\.matchesTickConversion).count,
            matchingIdentity: usable.filter { abs($0.ratio - 1.0) <= matchTolerance }.count,
            matchingOverConversion: usable.filter { abs($0.ratio - 1.0 / tickRatio) <= matchTolerance }.count,
            medianRatio: quantile(0.5),
            lowerQuartileRatio: quantile(0.25),
            upperQuartileRatio: quantile(0.75),
            minimumRatio: ratios[0],
            maximumRatio: ratios[ratios.count - 1],
            exactValueMatches: usable.filter(\.matchesExactly).count
        )
    }

    /// One candidate integer lag. Positive means the live receive timestamp is later than the historical
    /// embedded timestamp (`live.ts == historical.ts + lagSeconds`).
    public struct LagResult: Equatable, Sendable {
        public let lagSeconds: Int
        public let pairs: [Pair]
        public let liveSampleCount: Int
        public let historicalSampleCount: Int
        public let verdict: Verdict

        public init(lagSeconds: Int, pairs: [Pair], liveSampleCount: Int,
                    historicalSampleCount: Int) {
            self.lagSeconds = lagSeconds
            self.pairs = pairs
            self.liveSampleCount = liveSampleCount
            self.historicalSampleCount = historicalSampleCount
            self.verdict = RRUnitEvidence.verdict(for: pairs)
        }

        /// Fraction of the larger independently sampled transport that found an ordered partner at this
        /// lag. The raw denominator is retained on the result so the log cannot hide a small overlap.
        public var coverage: Double {
            let denominator = max(liveSampleCount, historicalSampleCount)
            return denominator > 0 ? Double(verdict.pairs) / Double(denominator) : 0
        }
    }

    public struct LagSearchResult: Equatable, Sendable {
        public let candidates: [LagResult]
        public let best: LagResult?

        public init(candidates: [LagResult], best: LagResult?) {
            self.candidates = candidates
            self.best = best
        }
    }

    /// Stable ordered matching across every integer lag in the requested range. A timestamp bucket pairs
    /// first-to-first, second-to-second, and so on; `min(count)` rows are emitted and excess rows remain
    /// visible through coverage rather than being collapsed with MIN/MAX or sorted by their physiological
    /// value. Input order breaks same-second ties deterministically.
    public static func lagSearch(live: [TimedValue], historical: [TimedValue],
                                 lags: ClosedRange<Int> = -5...5) -> LagSearchResult {
        func stablySorted(_ values: [TimedValue]) -> [TimedValue] {
            values.enumerated().sorted { left, right in
                if left.element.ts != right.element.ts { return left.element.ts < right.element.ts }
                return left.offset < right.offset
            }.map(\.element)
        }

        func buckets(_ values: [TimedValue], shiftingTsBy lag: Int = 0) -> [Int: [TimedValue]] {
            var result: [Int: [TimedValue]] = [:]
            for value in values {
                let (shifted, overflow) = value.ts.addingReportingOverflow(lag)
                guard !overflow else { continue }
                result[shifted, default: []].append(value)
            }
            return result
        }

        let orderedLive = stablySorted(live)
        let orderedHistorical = stablySorted(historical)
        let liveBuckets = buckets(orderedLive)
        var candidates: [LagResult] = []
        for lag in lags {
            let historicalBuckets = buckets(orderedHistorical, shiftingTsBy: lag)
            let sharedTimes = Set(liveBuckets.keys).intersection(historicalBuckets.keys).sorted()
            var pairs: [Pair] = []
            for alignedTs in sharedTimes {
                guard let liveRows = liveBuckets[alignedTs],
                      let historicalRows = historicalBuckets[alignedTs] else { continue }
                for (liveRow, historicalRow) in zip(liveRows, historicalRows) {
                    pairs.append(Pair(liveTs: liveRow.ts, historicalTs: historicalRow.ts,
                                      liveMs: liveRow.value, historicalStored: historicalRow.value))
                }
            }
            candidates.append(LagResult(lagSeconds: lag, pairs: pairs,
                                        liveSampleCount: orderedLive.count,
                                        historicalSampleCount: orderedHistorical.count))
        }

        func isBetter(_ candidate: LagResult, than incumbent: LagResult) -> Bool {
            let candidateVerdict = candidate.verdict
            let incumbentVerdict = incumbent.verdict
            if candidateVerdict.dominantClusterCount != incumbentVerdict.dominantClusterCount {
                return candidateVerdict.dominantClusterCount > incumbentVerdict.dominantClusterCount
            }
            if candidateVerdict.dominantClusterFraction != incumbentVerdict.dominantClusterFraction {
                return candidateVerdict.dominantClusterFraction > incumbentVerdict.dominantClusterFraction
            }
            if candidateVerdict.exactValueMatches != incumbentVerdict.exactValueMatches {
                return candidateVerdict.exactValueMatches > incumbentVerdict.exactValueMatches
            }
            if candidateVerdict.pairs != incumbentVerdict.pairs {
                return candidateVerdict.pairs > incumbentVerdict.pairs
            }
            if candidate.coverage != incumbent.coverage { return candidate.coverage > incumbent.coverage }
            if abs(candidate.lagSeconds) != abs(incumbent.lagSeconds) {
                return abs(candidate.lagSeconds) < abs(incumbent.lagSeconds)
            }
            return candidate.lagSeconds < incumbent.lagSeconds
        }

        var best: LagResult?
        for candidate in candidates where candidate.verdict.pairs > 0 {
            if best == nil || isBetter(candidate, than: best!) { best = candidate }
        }
        return LagSearchResult(candidates: candidates, best: best)
    }
}
