import Foundation

/// Personal-baseline banding for the Health Monitor's vital tiles.
///
/// In-range is judged against the user's OWN trailing baseline (the Winsorized EWMA
/// the rest of `Baselines` builds) once that baseline is trusted — `Baselines.minNightsTrust`
/// (14) valid nights and not stale. Until then, and again whenever a wear gap makes the
/// baseline stale, the fixed population range is the fallback.
///
/// `MetricCfg`'s physiological bounds stay an absolute outer guard either way. They are
/// deliberately NOT used as the in-range band: doing so would resurrect the exact false
/// positive this fixes — a perfectly normal personal HRV of 35 ms reading permanently
/// out-of-range against the 40–120 population band. The bounds only catch values that are
/// implausible for any human (e.g. an HRV of 300 ms), which no personal spread should excuse.
///
/// APPROXIMATE — informational, not a diagnosis.
public enum VitalBands {

    public enum Band: String, Equatable, Sendable { case inRange, outOfRange, noData }

    /// How the band was judged — drives the tile's caption wording.
    public enum Basis: String, Equatable, Sendable { case personal, population }

    public struct Result: Equatable, Sendable {
        public let band: Band
        public let basis: Basis
        /// Valid nights backing the personal baseline (0 when none).
        public let nights: Int
        public init(band: Band, basis: Basis, nights: Int) {
            self.band = band
            self.basis = basis
            self.nights = nights
        }
    }

    /// |z| at or below this is in-range vs the personal baseline — about 95% of the user's
    /// own normal nights. `Baselines.deviation`'s own `inNormalRange` (|z| <= 1) would flag
    /// roughly a third of normal nights, which is far too noisy for a passive at-a-glance tile.
    public static let sigmaK: Double = 2.0

    /// Band a single vital `value`.
    ///
    /// - Parameters:
    ///   - value: today's value, or nil for no data.
    ///   - history: nightly values oldest→newest EXCLUDING the displayed day. A nil entry is
    ///     a missing night; use `calendarSeries` first to pad real wear gaps so staleness sees them.
    ///   - populationRange: the fixed typical-adult range used as the cold-start / stale fallback.
    ///   - cfg: nil disables the personal path entirely (SpO2 stays population-only — there is
    ///     no SpO2 `MetricCfg` and an absolute floor is meaningful regardless of personal history).
    public static func band(value: Double?,
                            history: [Double?],
                            populationRange: ClosedRange<Double>,
                            cfg: MetricCfg?) -> Result {
        guard let value else { return Result(band: .noData, basis: .population, nights: 0) }
        guard let cfg else {
            return Result(band: populationRange.contains(value) ? .inRange : .outOfRange,
                          basis: .population, nights: 0)
        }
        let state = Baselines.foldHistory(history, cfg: cfg)
        // Absolute-plausibility outer guard: a value outside the physiological bounds is
        // out-of-range no matter how wide the personal spread happens to be.
        guard cfg.minVal <= value && value <= cfg.maxVal else {
            return Result(band: .outOfRange, basis: .population, nights: state.nValid)
        }
        if state.trusted {   // >= 14 valid nights and not stale
            let z = Baselines.deviation(value, state: state).z
            return Result(band: abs(z) <= sigmaK ? .inRange : .outOfRange,
                          basis: .personal, nights: state.nValid)
        }
        return Result(band: populationRange.contains(value) ? .inRange : .outOfRange,
                      basis: .population, nights: state.nValid)
    }

    // MARK: - Skin temp (mixed semantics: absolute °C from CSV import vs ±°C on-device deviation)

    /// A skin-temp value >= 20 °C is read as an ABSOLUTE skin temperature; smaller magnitudes
    /// are read as a ±°C deviation. The WHOOP CSV export stores absolute °C in its skin-temp
    /// column while NOOP's on-device pipeline stores a deviation from the personal baseline, so
    /// a merged series is bimodal. The displayed value picks which kind its history keeps.
    /// Heuristic but physically safe: no real wrist skin temp is below 20 °C, and no real
    /// nightly deviation reaches ±20 °C.
    public static func isAbsoluteSkinTemp(_ v: Double) -> Bool { v >= 20.0 }

    /// Keep only history entries of the SAME kind (absolute vs deviation) as the displayed
    /// `value`; entries of the other kind become nil (missing nights) so the baseline that
    /// `band` folds isn't computed across two incompatible scales.
    public static func skinTempHistory(matching value: Double, in history: [Double?]) -> [Double?] {
        let absolute = isAbsoluteSkinTemp(value)
        return history.map { v in
            guard let v else { return nil }
            return isAbsoluteSkinTemp(v) == absolute ? v : nil
        }
    }

    /// Deviation-semantics config for on-device skin-temp rows: ±°C around the personal mean,
    /// guarded to a physically sane ±8 °C. (The standard `skin_temp` config in `Baselines`
    /// is the ABSOLUTE-°C one, used for CSV-imported rows.)
    public static let skinTempDeviationCfg = MetricCfg(
        minVal: -8.0, maxVal: 8.0, floorSpread: 0.3, halfLifeB: 14.0, halfLifeS: 21.0)

    // MARK: - Calendar padding

    /// Calendar-align (day, value) rows keyed "yyyy-MM-dd" into a nightly series with nil for
    /// every absent day, so the baseline's staleness logic actually sees wear gaps. Stored rows
    /// simply skip days the strap wasn't worn; without padding, a user returning after two months
    /// would be banded against an ancient still-"trusted" baseline. Malformed day keys are dropped.
    /// Pure: fixed UTC math over the day keys only (no device clock).
    public static func calendarSeries(_ rows: [(day: String, value: Double?)]) -> [Double?] {
        // Plain day numbers instead of a DateFormatter: the same answer, without parsing every key
        // twice and formatting one string per calendar day of the whole history (that cost ~76 ms on
        // the main thread at launch, profiled on device 25 Oct 2026).
        var first = Int.max, last = Int.min
        // Last write wins for a duplicated day key, matching the dictionary the Kotlin port builds.
        // Only a canonical "yyyy-MM-dd" key can be looked up again, as the formatter's output was.
        var byDay: [Int: Double?] = [:]
        for r in rows {
            guard let (n, canonical) = dayNumber(r.day) else { continue }
            first = min(first, n); last = max(last, n)
            if canonical { byDay[n] = r.value }
        }
        guard first <= last else { return [] }
        return (first...last).map { byDay[$0] ?? nil }
    }

    /// Days since 1970-01-01 (UTC, proleptic Gregorian) for a "yyyy-MM-dd" key, and whether it is in
    /// that exact zero-padded form; nil for anything a strict POSIX formatter would not parse.
    static func dayNumber(_ key: String) -> (Int, Bool)? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              parts[1].count <= 2, parts[2].count <= 2, (1...12).contains(m) else { return nil }
        let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
        let monthDays = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][m - 1]
        guard (1...monthDays).contains(d) else { return nil }
        // Howard Hinnant's days_from_civil.
        let yy = m <= 2 ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let canonical = key.count == 10 && parts[0].count == 4 && parts[1].count == 2 && parts[2].count == 2
        return (era * 146_097 + doe - 719_468, canonical)
    }
}
