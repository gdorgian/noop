import Foundation

/// Where the aerobic work went, over the app's five zones (Resting, Easy, Steady, Hard, All out).
/// Resting is not training, so the shares are of the other four:
///
///   low aerobic  — Easy and Steady, the base most endurance fitness is built on,
///   high aerobic — Hard, threshold and tempo work,
///   anaerobic    — All out, short efforts above threshold.
public enum CardioFocus {
    public enum Band: String, Sendable, CaseIterable {
        case lowAerobic, highAerobic, anaerobic

        public var title: String {
            switch self {
            case .lowAerobic: "Low aerobic"
            case .highAerobic: "High aerobic"
            case .anaerobic: "Anaerobic"
            }
        }
    }

    public struct Breakdown: Equatable, Sendable {
        /// Fractions of training time, summing to 1 when there was any.
        public let shares: [Band: Double]
        public let trainingSeconds: Double

        public var dominant: Band? {
            trainingSeconds > 0 ? Band.allCases.max { (shares[$0] ?? 0) < (shares[$1] ?? 0) } : nil
        }
    }

    /// - Parameter z: time in each of the five zones, lowest first.
    public static func breakdown(secondsInZones z: [Double]) -> Breakdown {
        let low = z[safe: 1] + z[safe: 2], high = z[safe: 3], ana = z[safe: 4]
        let total = low + high + ana
        guard total > 0 else { return Breakdown(shares: [:], trainingSeconds: 0) }
        return Breakdown(shares: [.lowAerobic: low / total, .highAerobic: high / total, .anaerobic: ana / total],
                         trainingSeconds: total)
    }
}

/// Running totals for a period beside the same-length period before it, aligned day by day — the two
/// lines on the Active Duration and Active Energy cards.
public enum PeriodTotals {
    public struct Series: Equatable, Sendable {
        /// Cumulative value at the end of each day of the current period.
        public let current: [Double]
        /// Cumulative value at the end of each day of the previous period.
        public let previous: [Double]
        public init(current: [Double], previous: [Double]) {
            self.current = current
            self.previous = previous
        }

        public var total: Double { current.last ?? 0 }
        public var previousTotal: Double { previous.last ?? 0 }
    }

    /// - Parameters:
    ///   - values: amounts with their dates (seconds, kilocalories, sets, kilograms…).
    ///   - days: period length, ending with the day containing `asOf`.
    public static func cumulative(_ values: [(date: Date, value: Double)], days: Int, asOf: Date,
                                  calendar: Calendar = .current) -> Series {
        let today = calendar.startOfDay(for: asOf)
        func run(endingAt end: Date) -> [Double] {
            var byDay = [Double](repeating: 0, count: days)
            for v in values {
                let d = calendar.startOfDay(for: v.date)
                guard let offset = calendar.dateComponents([.day], from: d, to: end).day,
                      offset >= 0, offset < days else { continue }
                byDay[days - 1 - offset] += v.value
            }
            var acc = 0.0
            return byDay.map { acc += $0; return acc }
        }
        let prevEnd = calendar.date(byAdding: .day, value: -days, to: today) ?? today
        return Series(current: run(endingAt: today), previous: run(endingAt: prevEnd))
    }
}

/// Strength totals for the Strength cards.
public enum StrengthTotals {
    /// Weight moved by one set: weight × reps, with the lifter's body mass added for bodyweight
    /// movements (a pull-up moves the whole body). A set with no reps moves nothing countable.
    public static func volumeKg(_ s: FitnessStrengthSet, bodyMassKg: Double?) -> Double {
        guard let reps = s.reps, reps > 0 else { return 0 }
        let w = (s.weightKg ?? 0) + (s.includesBodyweight ? (bodyMassKg ?? 0) : 0)
        return w * Double(reps)
    }

    /// Working sets per muscle group, counting a set once for its primary muscle and half for each
    /// secondary, as `MuscularLoad` weights them.
    public static func setsPerGroup(_ sets: [FitnessStrengthSet]) -> [FitnessMuscleGroup: Double] {
        var out: [FitnessMuscleGroup: Double] = [:]
        for s in sets {
            if let p = s.primaryMuscleId, let g = FitnessMuscleGroup.forMuscleId(p) { out[g, default: 0] += 1 }
            for m in s.secondaryMuscleIds where m != s.primaryMuscleId {
                if let g = FitnessMuscleGroup.forMuscleId(m) { out[g, default: 0] += MuscularLoad.secondaryWeight }
            }
        }
        return out
    }
}

extension Array where Element == Double {
    subscript(safe i: Int) -> Double { indices.contains(i) ? self[i] : 0 }
}
