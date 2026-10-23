import Foundation

// MARK: - Pace of aging

/// How fast body age is moving against the calendar, from a series of dated body-age estimates.
///
/// Body age already carries chronological age inside it, so the least-squares slope of body age
/// against calendar years *is* the pace: 1.0 means one year of body age per year lived. The
/// estimate is only offered once its 95% interval is narrow enough to say something; a weekly
/// body age wobbles by a few tenths of a year, so ten weeks of it cannot pin a slope.
public enum AgingPace {
    public struct Result: Equatable, Sendable {
        /// Body-age years per calendar year.
        public let pace: Double
        /// Half-width of the 95% interval on `pace`.
        public let halfWidth: Double
        public let points: Int
        /// True when the interval is narrow enough to show the number.
        public let isDefensible: Bool

        /// Slower or faster than real time only when the whole interval is on one side of 1.
        public var direction: Direction {
            if pace + halfWidth < 1 { return .slower }
            if pace - halfWidth > 1 { return .faster }
            return .inStep
        }
    }

    public enum Direction: Equatable, Sendable { case slower, inStep, faster }

    /// Widest interval still worth showing as a number.
    public static let maxHalfWidth = 0.6
    public static let minPoints = 8

    public static func estimate(_ points: [(date: Date, age: Double)]) -> Result? {
        let finite = points.filter { $0.age.isFinite }
        guard finite.count >= minPoints, let t0 = finite.map(\.date).min() else { return nil }
        let year = 365.2425 * 86_400
        let xs = finite.map { $0.date.timeIntervalSince(t0) / year }
        let ys = finite.map(\.age)
        let n = Double(xs.count)
        let mx = xs.reduce(0, +) / n, my = ys.reduce(0, +) / n
        let sxx = xs.reduce(0) { $0 + ($1 - mx) * ($1 - mx) }
        guard sxx > 0 else { return nil }
        let sxy = zip(xs, ys).reduce(0) { $0 + ($1.0 - mx) * ($1.1 - my) }
        let slope = sxy / sxx
        let intercept = my - slope * mx
        let sse = zip(xs, ys).reduce(0) { acc, p in
            let r = p.1 - (intercept + slope * p.0)
            return acc + r * r
        }
        let se = (sse / (n - 2)).squareRoot() / sxx.squareRoot()
        let half = StudentT.critical95(df: xs.count - 2) * se
        return Result(pace: slope, halfWidth: half, points: xs.count, isDefensible: half <= maxHalfWidth)
    }
}

// MARK: - Window verdict

/// Answers "is it working?" for a Trends window: each signal's earlier half against its later
/// half, called a change only when it clears both the signal's own week-to-week noise (two
/// standard errors of the difference) and a floor below which no one would feel it.
public enum TrendVerdict {
    public struct Signal: Sendable {
        public let key: String
        public let weekly: [Double?]
        public let higherIsBetter: Bool
        /// Smallest change worth calling, in the signal's own unit.
        public let minimumChange: Double
        public init(key: String, weekly: [Double?], higherIsBetter: Bool, minimumChange: Double) {
            self.key = key; self.weekly = weekly; self.higherIsBetter = higherIsBetter
            self.minimumChange = minimumChange
        }
    }

    public enum Call: Equatable, Sendable { case improved, worse, steady, unknown }

    public struct Reading: Equatable, Sendable {
        public let key: String
        public let call: Call
        /// Later-half mean minus earlier-half mean; nil when `unknown`.
        public let change: Double?
    }

    public enum Headline: Equatable, Sendable {
        case tooEarly, working, slowly, mixed, steady, slipping
    }

    public struct Result: Equatable, Sendable {
        public let headline: Headline
        public let readings: [Reading]
    }

    /// Fewer recorded weeks than this per half, and a signal is left unknown.
    public static let minWeeksPerHalf = 3
    /// Windows shorter than this many weeks are always too early: slow signals cannot move in them.
    public static let minWindowWeeks = 12

    public static func evaluate(_ signals: [Signal], windowWeeks: Int) -> Result {
        let readings = signals.map(read)
        guard windowWeeks >= minWindowWeeks,
              readings.filter({ $0.call != .unknown }).count >= 2 else {
            return Result(headline: .tooEarly, readings: readings)
        }
        let up = readings.filter { $0.call == .improved }.count
        let down = readings.filter { $0.call == .worse }.count
        let headline: Headline
        switch (up, down) {
        case (0, 0): headline = .steady
        case (_, 0): headline = up >= 2 ? .working : .slowly
        case (0, _): headline = .slipping
        default: headline = down > up ? .slipping : .mixed
        }
        return Result(headline: headline, readings: readings)
    }

    static func read(_ s: Signal) -> Reading {
        let half = s.weekly.count / 2
        let early = s.weekly.prefix(half).compactMap { $0 }.filter(\.isFinite)
        let late = s.weekly.suffix(s.weekly.count - half).compactMap { $0 }.filter(\.isFinite)
        guard early.count >= minWeeksPerHalf, late.count >= minWeeksPerHalf else {
            return Reading(key: s.key, call: .unknown, change: nil)
        }
        let m1 = mean(early), m2 = mean(late)
        let se = (variance(early) / Double(early.count) + variance(late) / Double(late.count)).squareRoot()
        let diff = m2 - m1
        guard abs(diff) >= max(2 * se, s.minimumChange) else {
            return Reading(key: s.key, call: .steady, change: diff)
        }
        return Reading(key: s.key, call: (diff > 0) == s.higherIsBetter ? .improved : .worse, change: diff)
    }

    private static func mean(_ v: [Double]) -> Double { v.reduce(0, +) / Double(v.count) }
    private static func variance(_ v: [Double]) -> Double {
        let m = mean(v)
        return v.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(max(v.count - 1, 1))
    }
}

/// Two-sided 95% critical values of Student's t.
enum StudentT {
    static func critical95(df: Int) -> Double {
        let table: [Double] = [12.706, 4.303, 3.182, 2.776, 2.571, 2.447, 2.365, 2.306, 2.262, 2.228,
                               2.201, 2.179, 2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086,
                               2.080, 2.074, 2.069, 2.064, 2.060, 2.056, 2.052, 2.048, 2.045, 2.042]
        guard df >= 1 else { return .infinity }
        if df <= table.count { return table[df - 1] }
        return df <= 60 ? 2.000 : 1.960
    }
}
