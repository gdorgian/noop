import Foundation
import WhoopProtocol

// WhoopStrain.swift — the wearer's Day Strain computed by WHOOP's own recipe, verified against
// WHOOP iOS 5.65.1 (the decompiled strain pipeline: StrainAccumulator / raw-strain sum / scale
// lookup, plus WHOOP's two bundled lookup tables), implemented independently here.
//
// This is a deliberate accuracy port, not the independent Edwards/Banister scorer —
// `StrainScorer` stays the fallback and the clean-room method. The two data files this needs
// (`strain_raw_scale_lookup.json` raw→0–21 and `recovery_to_strain.json` target per recovery %)
// are WHOOP's own tables and are shipped ONLY inside a local, git-ignored build
// (Config/, the same pattern as BundleIdSecrets.xcconfig): public builds fall back to
// `StrainScorer` and to `CoupledView`'s fixed target bands, and Diagnostics says which
// method produced a day's score.
//
// Recipe constants and lookup behavior are based on the owner's WHOOP iOS 5.65.1 assembly review.
// The duration/smoothing handoff and leading-low-reading gate remain unconfirmed; the existing
// minute coverage and bucket gate below are retained pending that evidence.
//   1. Bucket the day's HR samples into 60-second wall-clock buckets; each bucket's heart
//      rate is the 25th-percentile (numpy-style linear interpolation) of its samples.
//   2. Reserve: HRR′ = (hr − restingHR) / ((maxHR + 3.0) − restingHR), clamped [0, 1].
//      The +3.0 is WHOOP's own bump on max heart rate, not a typo.
//   3. Under 30 % of reserve the minute contributes nothing (gate at the normalized
//      value, i.e. below `reserveFloor` the minute is written as 0).
//   4. S-curve weight: w = 16.0 / (1 + exp((1 − HRR′) / 0.15)) — sigmoid from 0 at 0 to
//      8.0 at a full reserve, amplitude 16 and steepness 0.15 as WHOOP ships them.
//   5. Raw day score: Σ (w · coverage) / 691 200, with no extra HRR′ multiplier.
//      Coverage currently credits each retained minute bucket with 60 s. WHOOP's per-reading
//      duration cap is known, but its handoff from minute smoothing has not been verified.
//   6. Scale: 0–21 Day Strain is WHOOP's `strain_raw_scale_lookup` row lookup
//      (nearest raw node, midpoint ties to the upper row, 21 beyond the last row).
//
// Callers: `AnalyticsEngine` runs this for the DAY metric when tables are installed and
// maps the 0–21 result onto the 0–100 Effort axis with `StrainScorer.effortValue(fromWhoopStrain:)`.
// Everything else (workout bouts, Training Load, feasibility) keeps `StrainScorer`.

public enum WhoopStrain {

    // MARK: - WHOOP's constants (read from the WHOOP iOS 5.65.1 binary data section)

    /// Bump on max heart rate inside the reserve denominator.
    public static let hrMaxBump: Double = 3.0
    /// Minutes below this share of reserve contribute exactly zero.
    public static let reserveFloor: Double = 0.3
    /// S-curve amplitude (numerator) and steepness (exp denominator).
    public static let curveAmplitude: Double = 16.0
    public static let curveSteepness: Double = 0.15
    /// Bucket length for each minute's heart-rate percentile.
    public static let bucketSeconds: Int = 60
    /// Percentile on the 0–100 axis expected by `StrainScorer.percentile`.
    public static let bucketPercentile: Double = 25.0
    /// WHOOP's raw-score divisor (86 400 s/day × 8 = the full-reserve day at amplitude 8).
    public static let rawDivisor: Double = 691_200.0
    /// A bucket whose samples never reach this many bpm is a misread and is skipped
    /// (WHOOP's 30 bpm bucket gate).
    public static let bucketHrFloorBpm: Double = 30.0

    // MARK: - Exact tables (git-ignored local build only)

    /// One row of WHOOP's raw→strain scale (`strain_raw_scale_lookup.json`).
    public struct ScaleRow: Equatable, Sendable {
        public let raw: Double
        public let strain: Double
        public init(raw: Double, strain: Double) { self.raw = raw; self.strain = strain }
    }

    /// One row of WHOOP's recovery→strain-target table (`recovery_to_strain.json`).
    public struct TargetRow: Equatable, Sendable {
        public let recovery: Int
        /// WHOOP's fields: the target strain and its day band.
        public let lower: Double
        public let target: Double
        public let upper: Double
        public init(recovery: Int, lower: Double, target: Double, upper: Double) {
            self.recovery = recovery; self.lower = lower; self.target = target; self.upper = upper
        }
    }

    /// Both bundled WHOOP tables, when the local build carries them.
    public struct Tables: Equatable, Sendable {
        /// Raw → 0–21, sorted ascending by raw. Required for the strain recipe.
        public let scale: [ScaleRow]
        /// Target per recovery percent (0…100), sorted by recovery. Optional; the
        /// strain scale alone still ports item 1.
        public let targets: [TargetRow]?
        public init(scale: [ScaleRow], targets: [TargetRow]?) {
            self.scale = scale; self.targets = targets
        }

        /// Parse the two WHOOP IPA files verbatim: a `[[raw, strain], …]` array and a
        /// `[{"recovery":…, "lower_rec_strain":…, "rec_strain":…, "upper_rec_strain":…}]` array.
        /// Parse failures are reported through the thrown error, callers decide silently.
        public static func parse(scaleData: Data, targetsData: Data?) throws -> Tables {
            let scaleJSON = try JSONSerialization.jsonObject(with: scaleData) as? [[Double]]
            guard let scaleRaw = scaleJSON, scaleRaw.count >= 2,
                  scaleRaw.allSatisfy({ $0.count == 2 }) else { throw WhoopStrainError.tableShape }
            let scale = scaleRaw.map { ScaleRow(raw: $0[0], strain: $0[1]) }
            var targets: [TargetRow]? = nil
            if let targetsData {
                struct Row: Decodable {
                    let recovery: Int
                    let lower_rec_strain: Double
                    let rec_strain: Double
                    let upper_rec_strain: Double
                }
                targets = try JSONDecoder().decode([Row].self, from: targetsData).map {
                    TargetRow(recovery: $0.recovery, lower: $0.lower_rec_strain,
                              target: $0.rec_strain, upper: $0.upper_rec_strain)
                }
            }
            return Tables(scale: scale, targets: targets)
        }

        /// Load both resources by WHOOP's own file names (so a local copy is the untouched IPA file)
        /// from `bundle`. Returns nil when absent — public builds have neither bundled.
        public static func load(from bundle: Bundle) -> Tables? {
            guard let scaleURL = bundle.url(forResource: "strain_raw_scale_lookup", withExtension: "json"),
                  let scaleData = try? Data(contentsOf: scaleURL) else { return nil }
            let targetsData = bundle.url(forResource: "recovery_to_strain", withExtension: "json")
                .flatMap { try? Data(contentsOf: $0) }
            return try? Tables.parse(scaleData: scaleData, targetsData: targetsData)
        }

        /// WHOOP's versioned table for tests: read by path (the exact fixture test runs the
        /// rows against WHOOP's files without needing the app bundle).
        public static func load(scaleAt scaleURL: URL, targetsAt: URL?) throws -> Tables {
            let scaleData = try Data(contentsOf: scaleURL)
            let targetsData = targetsAt.flatMap { try? Data(contentsOf: $0) }
            return try Tables.parse(scaleData: scaleData, targetsData: targetsData)
        }
    }

    enum WhoopStrainError: Error { case tableShape }

    // MARK: - Installed tables

    /// The running app's exact tables, installed once at launch (AppModel / StrandiOSApp read
    /// Bundle.main). nil ⇒ every WHOOP-path caller falls back to its prior method.
    public nonisolated(unsafe) static var tables: Tables?

    public static var exactTablesInstalled: Bool { tables != nil }

    // MARK: - Item 1: Day Strain by WHOOP's recipe

    /// One minute-bucket: its percentile heart rate and the seconds of the day it covers.
    /// Internal; surfaced for tests and diagnostics rather than callers.
    struct MinuteBucket: Equatable {
        let hr: Double
        let coverage: Double
    }

    /// Split samples into `bucketSeconds` wall-clock buckets and take the 25th-percentile
    /// heart rate per bucket. Buckets whose samples never reach `bucketHrFloorBpm` are skipped.
    /// Whether WHOOP also drops leading low readings before this percentile is unconfirmed.
    ///
    /// Coverage currently credits each retained bucket with its full minute. This is an
    /// unresolved approximation: WHOOP caps individual reading durations at 3 s, but the
    /// connection between that scorer and its minute smoothing is not yet verified.
    static func minuteBuckets(_ hr: [HRSample]) -> [MinuteBucket] {
        guard !hr.isEmpty else { return [] }
        var byBucket: [Int: [Int]] = [:]                       // bucket start epoch → bpm list
        for sample in hr { byBucket[(sample.ts - sample.ts % bucketSeconds), default: []].append(sample.bpm) }
        var covered = [Int: Double]()                          // bucket start → seconds with HR
        for (bucket, bpms) in byBucket { covered[bucket] = Double(bpms.count) }
        let asc = byBucket.map { $0 }.sorted { $0.key < $1.key }
        var result: [MinuteBucket] = []
        result.reserveCapacity(asc.count)
        for index in asc.indices {
            let (start, bpms) = asc[index]
            let maxBpm = bpms.max() ?? 0
            if Double(maxBpm) < bucketHrFloorBpm { continue }   // WHOOP's 30 bpm bucket gate
            let sorted = bpms.map(Double.init).sorted()
            let hr = StrainScorer.percentile(sorted, bucketPercentile)
            // Preserve the existing minute-coverage interpretation pending verification of
            // the smoothing→per-reading-duration handoff; sparse readings may be overcredited.
            let toNext = index + 1 < asc.count ? Double(asc[index + 1].key - start) : Double(bucketSeconds)
            let span = min(max(toNext, covered[start] ?? 0), Double(bucketSeconds))
            result.append(MinuteBucket(hr: hr, coverage: span))
        }
        return result
    }

    /// One minute's reserve share (clamped [0,1]) and zero below WHOOP's floor.
    static func reserve(_ hr: Double, restingHR: Double, hrMax: Double) -> Double {
        let share = (hr - restingHR) / ((hrMax + hrMaxBump) - restingHR)
        let clamped = min(max(share, 0), 1)
        return clamped <= reserveFloor ? 0 : clamped   // at or under 30 % counts nothing
    }

    /// WHOOP's S-curve weight at `reserve` share: 16 / (1 + exp((1 − share) / 0.15)).
    static func curveWeight(_ share: Double) -> Double {
        curveAmplitude / (1.0 + Foundation.exp((1.0 - share) / curveSteepness))
    }

    /// Raw day score: Σ (weight · coverage) / 691 200. See the unresolved coverage note above.
    public static func rawStrain(_ hr: [HRSample], restingHR: Double, hrMax: Double) -> Double {
        accumulatedRawStrain(minuteBuckets(hr), restingHR: restingHR, hrMax: hrMax)
    }

    private static func accumulatedRawStrain(_ buckets: [MinuteBucket], restingHR: Double, hrMax: Double) -> Double {
        guard hrMax + hrMaxBump > restingHR else { return 0 }
        var total = 0.0
        for bucket in buckets {
            let share = reserve(bucket.hr, restingHR: restingHR, hrMax: hrMax)
            if share <= 0 { continue }
            total += curveWeight(share) * bucket.coverage
        }
        return total / rawDivisor
    }

    /// Select the nearest raw node; exact midpoint ties select the upper row.
    /// Values below the first row select it; values at or beyond the last row read 21.
    public static func scaleLookup(raw: Double, table: [ScaleRow]) -> Double {
        guard let first = table.first else { return 0 }
        if raw <= first.raw { return first.strain }
        for pair in zip(table, table.dropFirst()) {
            if raw < pair.1.raw {
                let midpoint = (pair.0.raw + pair.1.raw) / 2
                return raw >= midpoint ? pair.1.strain : pair.0.strain
            }
        }
        return 21.0
    }

    /// The day's 0–21 Day Strain by the current recipe. Returns nil when no bucket survives,
    /// the calibration is invalid, or tables are absent. Missing data remains unscored.
    public static func dayStrain21(_ hr: [HRSample], restingHR: Double, hrMax: Double,
                                   tables: Tables? = WhoopStrain.tables) -> Double? {
        guard let tables, !tables.scale.isEmpty, !hr.isEmpty, hrMax > restingHR else { return nil }
        let buckets = minuteBuckets(hr)
        guard !buckets.isEmpty else { return nil }
        let raw = accumulatedRawStrain(buckets, restingHR: restingHR, hrMax: hrMax)
        return scaleLookup(raw: raw, table: tables.scale)
    }

    // MARK: - Item 2: strain target per recovery percent (WHOOP's recovery curve)

    /// WHOOP's own target finding for `recovery` percent: (target, band lower…upper),
    /// linear interpolation between rows (recovery is 0…100; out-of-range clamps).
    /// nil when the target table is not installed.
    public static func targetStrain21(recovery: Double,
                                      tables: Tables? = WhoopStrain.tables) -> (target: Double, band: ClosedRange<Double>)? {
        guard let rows = tables?.targets, let first = rows.first, let last = rows.last else { return nil }
        let clamped = min(max(recovery, Double(first.recovery)), Double(last.recovery))
        for pair in zip(rows, rows.dropFirst()) {
            if clamped <= Double(pair.1.recovery) {
                let width = Double(pair.1.recovery - pair.0.recovery)
                if width <= 0 { return (pair.0.target, pair.0.lower...pair.0.upper) }
                let frac = (clamped - Double(pair.0.recovery)) / width
                let target = pair.0.target + frac * (pair.1.target - pair.0.target)
                let lower = pair.0.lower + frac * (pair.1.lower - pair.0.lower)
                let upper = pair.0.upper + frac * (pair.1.upper - pair.0.upper)
                return (target, lower...upper)
            }
        }
        return (last.target, last.lower...last.upper)
    }
}
