import Foundation

/// The figures the Sleep, Steps, Vitals, Weight, Workouts, Consistency and Goal widgets draw.
///
/// Published by the app beside `WidgetSnapshot`, under its own App Group key, so the widgets that
/// only need the glance never decode a week of sleep and a quarter of training to show one ring.
/// Every value is derived in the app by the same builder the matching screen uses (Rest, Today's
/// vitals, Body, Fitness, the goal journey); the widget only lays it out. A missing value means
/// unknown, never zero, and every panel is optional: a panel the app cannot defend is left out
/// and its widget says so in words.
public struct WidgetPanels: Codable, Equatable, Sendable {
    public var updated: Date
    public var sleep: Sleep?
    public var steps: Steps?
    public var vitals: Vitals?
    public var weight: Weight?
    public var training: Training?
    public var goal: Goal?

    public init(updated: Date, sleep: Sleep? = nil, steps: Steps? = nil, vitals: Vitals? = nil,
                weight: Weight? = nil, training: Training? = nil, goal: Goal? = nil) {
        self.updated = updated
        self.sleep = sleep
        self.steps = steps
        self.vitals = vitals
        self.weight = weight
        self.training = training
        self.goal = goal
    }

    // MARK: Sleep

    /// The newest recorded night, as the Rest screen reads it.
    public struct Sleep: Codable, Equatable, Sendable {
        public struct Run: Codable, Equatable, Sendable {
            /// 0 awake · 1 light · 2 REM · 3 deep.
            public var stage: Int
            /// Fractions of the recorded span.
            public var from: Double
            public var to: Double
            public init(stage: Int, from: Double, to: Double) {
                self.stage = stage
                self.from = from
                self.to = to
            }
        }

        /// The morning the night ended on.
        public var endedAt: Date
        public var asleepMin: Double
        public var deepMin: Double
        public var remMin: Double
        public var lightMin: Double
        public var awakeMin: Double
        /// "23:25 – 06:30" in the wearer's clock.
        public var window: String
        /// The per-wearer need the Rest ring closes at. Nil when none is known.
        public var needMin: Double?
        /// True while the need is still the population default (too few nights of your own).
        public var needCalibrating: Bool
        /// The night's stage runs, only when a real per-epoch timeline exists.
        public var runs: [Run]?
        /// Minutes asleep for the seven nights ending this morning, oldest first; nil = no night.
        public var week: [Double?]
        public var weekLetters: [String]

        public init(endedAt: Date, asleepMin: Double, deepMin: Double, remMin: Double, lightMin: Double,
                    awakeMin: Double, window: String, needMin: Double?, needCalibrating: Bool,
                    runs: [Run]?, week: [Double?], weekLetters: [String]) {
            self.endedAt = endedAt
            self.asleepMin = asleepMin
            self.deepMin = deepMin
            self.remMin = remMin
            self.lightMin = lightMin
            self.awakeMin = awakeMin
            self.window = window
            self.needMin = needMin
            self.needCalibrating = needCalibrating
            self.runs = runs
            self.week = week
            self.weekLetters = weekLetters
        }
    }

    // MARK: Steps

    public struct Steps: Codable, Equatable, Sendable {
        /// Today's count so far; nil when nothing has counted today.
        public var today: Int?
        /// Where today's count came from: "strap" or "health".
        public var source: String?
        /// Seven days ending today, oldest first; nil = nothing counted.
        public var week: [Int?]
        public var weekLetters: [String]
        /// The highest active daily step target among the wearer's goal actions, if one is set.
        public var goal: Int?

        public init(today: Int?, source: String?, week: [Int?], weekLetters: [String], goal: Int?) {
            self.today = today
            self.source = source
            self.week = week
            self.weekLetters = weekLetters
            self.goal = goal
        }

        /// Mean of the six finished days, the honest comparison for a day still in progress.
        public var priorAverage: Int? {
            let done = week.dropLast().compactMap { $0 }
            guard done.count >= 3 else { return nil }
            return Int((Double(done.reduce(0, +)) / Double(done.count)).rounded())
        }
    }

    // MARK: Vitals

    /// The night's vitals, each judged the way Today's Vitals screen judges it.
    public struct Vitals: Codable, Equatable, Sendable {
        public struct Item: Codable, Equatable, Sendable, Identifiable {
            /// rhr · hrv · resp · spo2 · skin
            public var id: String
            public var name: String
            public var short: String
            public var unit: String
            public var decimals: Int
            public var value: Double
            /// The zone the value was judged against.
            public var low: Double
            public var high: Double
            /// The drawn scale around the zone.
            public var scaleLow: Double
            public var scaleHigh: Double
            /// Your own baseline, only when the zone is personal.
            public var baseline: Double?
            public var outside: Bool

            public init(id: String, name: String, short: String, unit: String, decimals: Int, value: Double,
                        low: Double, high: Double, scaleLow: Double, scaleHigh: Double,
                        baseline: Double?, outside: Bool) {
                self.id = id
                self.name = name
                self.short = short
                self.unit = unit
                self.decimals = decimals
                self.value = value
                self.low = low
                self.high = high
                self.scaleLow = scaleLow
                self.scaleHigh = scaleHigh
                self.baseline = baseline
                self.outside = outside
            }

            public func fraction(_ x: Double) -> Double {
                let span = max(scaleHigh - scaleLow, 1e-6)
                return min(1, max(0, (x - scaleLow) / span))
            }
        }

        /// When the newest of these readings was taken.
        public var measuredAt: Date?
        public var items: [Item]

        public init(measuredAt: Date?, items: [Item]) {
            self.measuredAt = measuredAt
            self.items = items
        }

        public var outsideCount: Int { items.filter(\.outside).count }
    }

    // MARK: Weight

    public struct Weight: Codable, Equatable, Sendable {
        public struct Point: Codable, Equatable, Sendable {
            public var at: Date
            public var value: Double
            public init(at: Date, value: Double) {
                self.at = at
                self.value = value
            }
        }

        /// "kg" or "lb"; every value below is already in it.
        public var unit: String
        /// The latest weigh-in, exactly as measured.
        public var latest: Double
        public var latestAt: Date
        /// The smoothed centre the change is read from.
        public var trend: Double
        public var trendReliable: Bool
        /// Change in the trend over 30 days; nil when the history is shorter.
        public var change30: Double?
        /// Weigh-ins over the last 90 days and the trend through them, oldest first.
        public var readings: [Point]
        public var trendLine: [Point]

        public init(unit: String, latest: Double, latestAt: Date, trend: Double, trendReliable: Bool,
                    change30: Double?, readings: [Point], trendLine: [Point]) {
            self.unit = unit
            self.latest = latest
            self.latestAt = latestAt
            self.trend = trend
            self.trendReliable = trendReliable
            self.change30 = change30
            self.readings = readings
            self.trendLine = trendLine
        }
    }

    // MARK: Training (Workouts + Consistency)

    public struct Training: Codable, Equatable, Sendable {
        public struct Session: Codable, Equatable, Sendable {
            public var title: String
            public var strength: Bool
            /// SF Symbol for the sport.
            public var symbol: String
            public var start: Date
            public var minutes: Int
            public init(title: String, strength: Bool, symbol: String, start: Date, minutes: Int) {
                self.title = title
                self.strength = strength
                self.symbol = symbol
                self.start = start
                self.minutes = minutes
            }
        }

        /// The training week (Monday first): minutes trained per day, nil for days still to come.
        public var weekMinutes: [Int?]
        public var weekSessions: [Int]
        public var weekLetters: [String]
        public var todayIndex: Int
        public var last: Session?
        /// Twelve whole weeks of trained minutes, Monday-first columns, oldest first. nil = a day
        /// before any record or still to come, which is not a rest day.
        public var grid: [Int?]
        /// Days trained among the last 28.
        public var trained28: Int

        /// A sport or routine the Train widget starts in one tap.
        public struct Start: Codable, Equatable, Sendable {
            public var title: String
            public var symbol: String
            /// The sport's catalogue name, or the routine's id.
            public var key: String
            public var strength: Bool
            public init(title: String, symbol: String, key: String, strength: Bool) {
                self.title = title
                self.symbol = symbol
                self.key = key
                self.strength = strength
            }
        }

        // The Train widget. Optional, so a payload written before it existed still decodes.
        /// Recent sports, newest first, then routines: what one tap starts.
        public var starts: [Start]?
        public var streakWeeks: Int?
        public var weekStrengthMinutes: Int?
        public var weekCardioMinutes: Int?

        public init(weekMinutes: [Int?], weekSessions: [Int], weekLetters: [String], todayIndex: Int,
                    last: Session?, grid: [Int?], trained28: Int, starts: [Start]? = nil, streakWeeks: Int? = nil,
                    weekStrengthMinutes: Int? = nil, weekCardioMinutes: Int? = nil) {
            self.starts = starts
            self.streakWeeks = streakWeeks
            self.weekStrengthMinutes = weekStrengthMinutes
            self.weekCardioMinutes = weekCardioMinutes
            self.weekMinutes = weekMinutes
            self.weekSessions = weekSessions
            self.weekLetters = weekLetters
            self.todayIndex = todayIndex
            self.last = last
            self.grid = grid
            self.trained28 = trained28
        }

        public var weekCount: Int { weekSessions.reduce(0, +) }
        public var weekTotalMinutes: Int { weekMinutes.compactMap { $0 }.reduce(0, +) }
        public var hasAnyRecord: Bool { grid.contains { $0 != nil } }
    }

    // MARK: Goal

    /// The one active goal, as its journey reads it.
    public struct Goal: Codable, Equatable, Sendable {
        public struct Action: Codable, Equatable, Sendable {
            public var label: String
            public var done: Bool
            public init(label: String, done: Bool) {
                self.label = label
                self.done = done
            }
        }

        public var title: String
        public var kind: String
        /// SF Symbol for the goal kind.
        public var symbol: String
        /// Baseline-to-target progress, 0…1; nil when the goal has no measurement.
        public var progress: Double?
        /// The tracker's verdict ("On track", "Needs attention", …) and its rank, 0 worst.
        public var health: String
        public var healthRank: Int
        public var reason: String
        public var deadline: Date?
        /// "42.1 kg" style current reading and target, already formatted.
        public var current: String?
        public var target: String?
        public var nextMilestone: String?
        public var streakWeeks: Int
        /// Today's goal actions.
        public var today: [Action]
        /// True for a goal the tracker measures (distance, weight, sleep, sessions); false for one it holds
        /// in words only. Optional so a payload written before it existed still decodes.
        public var measured: Bool?

        public init(title: String, kind: String, symbol: String, progress: Double?, health: String,
                    healthRank: Int, reason: String, deadline: Date?, current: String?, target: String?,
                    nextMilestone: String?, streakWeeks: Int, today: [Action], measured: Bool? = nil) {
            self.title = title
            self.kind = kind
            self.symbol = symbol
            self.progress = progress
            self.health = health
            self.healthRank = healthRank
            self.reason = reason
            self.deadline = deadline
            self.current = current
            self.target = target
            self.nextMilestone = nextMilestone
            self.streakWeeks = streakWeeks
            self.today = today
            self.measured = measured
        }
    }

    // MARK: Store

    public static let storageKey = "noop.widget.panels.v1"

    /// Widget kinds that read this payload, reloaded together when it changes.
    public static let kinds = ["SleepWidget", "StepsWidget", "VitalsWidget", "WeightWidget",
                               "WorkoutsWidget", "TrainWidget", "ConsistencyWidget", "GoalWidget"]

    public static func load() -> WidgetPanels? {
        guard let defaults = UserDefaults(suiteName: WidgetSnapshot.suiteName),
              let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(WidgetPanels.self, from: data)
    }

    /// Writes only when something a widget draws changed; returns whether it wrote.
    @discardableResult
    public func saveIfChanged(previous: WidgetPanels?) -> Bool {
        var comparable = self
        comparable.updated = previous?.updated ?? updated
        guard comparable != previous,
              let defaults = UserDefaults(suiteName: WidgetSnapshot.suiteName),
              let data = try? JSONEncoder().encode(self) else { return false }
        defaults.set(data, forKey: Self.storageKey)
        return true
    }
}
