import Foundation

// PersonalActivityModel.swift — learns what YOUR sessions look like, one logged workout at a time.
//
// Every workout the wearer labels (logged by hand, confirmed from a suggestion, imported from Apple
// Health or recorded live) becomes one example: a small shape vector taken from the heart rate inside
// its window. A new unlabelled window is compared against those examples (distance-weighted nearest
// neighbours on standardised features) and the activities are ranked by how closely past sessions of
// each kind match it. Three weeks of logging teaches it how a swim, a lift or a dance class looks on
// this one body; with no history it says nothing rather than guess.
//
// HR shape only, deliberately. The ~1 Hz motion streams cannot tell sports apart reliably (see
// WorkoutTypeClassifier's header), and heart-rate shape relative to the wearer's own resting pulse is
// what actually differs between their activities: a lift is bursty, a swim or run is steady and high,
// a walk is steady and low. Time of day is included because people train at habitual times.
//
// Pure / headless: no I/O, no clock. All timestamps are unix SECONDS. NOT medical advice.

public enum PersonalActivityModel {
    /// One labelled session's shape. `sport` is the wearer's own label, compared case-insensitively.
    public struct Example: Codable, Equatable, Sendable {
        public let sport: String
        public let features: [Double]
        public init(sport: String, features: [Double]) {
            self.sport = sport
            self.features = features
        }
    }

    /// A ranked guess. `share` is this activity's part of the total neighbour weight (0–1).
    public struct Suggestion: Equatable, Sendable {
        public let sport: String
        public let share: Double
        public let examples: Int
    }

    /// Neighbours consulted per guess.
    public static let neighbours = 5
    /// Below this many labelled sessions in total the model stays silent.
    public static let minimumExamples = 3
    /// The top guess must hold at least this share and rest on two or more of its own sessions before
    /// anything is allowed to log it without asking.
    public static let confidentShare = 0.75
    public static let confidentExamples = 3

    /// The shape vector for one window, or nil when the window has too little heart rate to describe.
    /// Features: log duration, mean and peak above resting, spread, burstiness (mean absolute change
    /// between 30-second means, which separates sets-and-rest work from steady efforts), and the start
    /// hour on a circle so 23:00 sits next to 01:00.
    public static func features(hr: [(ts: Int, bpm: Int)], startSec: Int, endSec: Int,
                                restingBpm: Int?, utcOffsetSec: Int = 0) -> [Double]? {
        guard endSec > startSec else { return nil }
        let inside = hr.filter { $0.ts >= startSec && $0.ts <= endSec }.map { Double($0.bpm) }
        guard inside.count >= 30 else { return nil }
        let rest = Double(restingBpm ?? AutoWorkoutDetector.defaultRestingHR)
        let mean = inside.reduce(0, +) / Double(inside.count)
        let peak = inside.max() ?? mean
        let spread = (inside.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(inside.count)).squareRoot()

        // 30-second means, then the mean absolute step between consecutive ones.
        var buckets: [Int: (sum: Double, n: Double)] = [:]
        for s in hr where s.ts >= startSec && s.ts <= endSec {
            let k = (s.ts - startSec) / 30
            let b = buckets[k] ?? (0, 0)
            buckets[k] = (b.sum + Double(s.bpm), b.n + 1)
        }
        let series = buckets.keys.sorted().compactMap { k in buckets[k].map { $0.sum / $0.n } }
        let steps = zip(series, series.dropFirst()).map { abs($1 - $0) }
        let burst = steps.isEmpty ? 0 : steps.reduce(0, +) / Double(steps.count)

        let minutes = Double(endSec - startSec) / 60
        let localHour = Double(((startSec + utcOffsetSec) % 86_400 + 86_400) % 86_400) / 3600
        let angle = localHour / 24 * 2 * .pi
        return [log(max(1, minutes)), mean - rest, peak - rest, spread, burst, cos(angle), sin(angle)]
    }

    /// Ranked guesses for `features`, best first, or [] when there is not enough history.
    public static func suggest(_ features: [Double], from examples: [Example]) -> [Suggestion] {
        let usable = examples.filter { $0.features.count == features.count && !$0.sport.isEmpty }
        guard usable.count >= minimumExamples, !features.isEmpty else { return [] }

        // Standardise each feature by its spread across the examples, so bpm and log-minutes weigh the
        // same. A feature that never varies (one-activity history) gets a unit scale instead of /0.
        let dims = features.count
        var scale = [Double](repeating: 1, count: dims)
        for d in 0..<dims {
            let column = usable.map { $0.features[d] }
            let m = column.reduce(0, +) / Double(column.count)
            let sd = (column.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(column.count)).squareRoot()
            scale[d] = sd > 1e-6 ? sd : 1
        }
        func distance(_ a: [Double]) -> Double {
            (0..<dims).map { d in let x = (a[d] - features[d]) / scale[d]; return x * x }.reduce(0, +).squareRoot()
        }

        let nearest = usable.map { (example: $0, distance: distance($0.features)) }
            .sorted { $0.distance < $1.distance }
            .prefix(neighbours)
        var weight: [String: Double] = [:]
        var label: [String: String] = [:]
        for n in nearest {
            let key = n.example.sport.lowercased()
            weight[key, default: 0] += 1 / (n.distance + 0.25)
            label[key] = label[key] ?? n.example.sport
        }
        let total = weight.values.reduce(0, +)
        guard total > 0 else { return [] }
        let counts = Dictionary(grouping: usable, by: { $0.sport.lowercased() }).mapValues(\.count)
        return weight
            .map { Suggestion(sport: label[$0.key] ?? $0.key, share: $0.value / total, examples: counts[$0.key] ?? 0) }
            .sorted { $0.share != $1.share ? $0.share > $1.share : $0.sport < $1.sport }
    }

    /// True when the top guess is strong enough to log without asking.
    public static func isConfident(_ suggestions: [Suggestion]) -> Bool {
        guard let top = suggestions.first else { return false }
        return top.share >= confidentShare && top.examples >= confidentExamples
    }
}
