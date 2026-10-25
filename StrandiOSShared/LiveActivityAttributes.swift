#if os(iOS)
import Foundation
import ActivityKit

/// Live Activity attributes for an active live-HR / workout session. Shared between the app (which
/// starts/updates the activity) and the widget extension (which renders it on the Lock Screen and in
/// the Dynamic Island).
public struct NOOPActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var bpm: Int?
        public var recovery: Int?
        public var bonded: Bool
        // Effort / strain on NOOP's 0–100 axis (#446) — one more stat in the Dynamic Island expanded
        // region. OPTIONAL with a nil default so an activity started by an older build still decodes.
        public var effort: Int?
        /// The sample time is carried with the value, never inferred from the activity update time.
        /// Optional so an activity created by an older build decodes safely and shows no unaged figure.
        public var sampledAt: Date?
        public var lastBPM: Int?
        public var lastSampledAt: Date?
        public var zoneNumber: Int?
        public var ceilingBPM: Int?
        /// The recorded session this banner is following, when one is running. Optional so a banner
        /// started by an older build still decodes, and shows no controls.
        public var workout: Workout?

        public init(bpm: Int?, recovery: Int?, bonded: Bool, effort: Int? = nil,
                    sampledAt: Date? = nil, lastBPM: Int? = nil,
                    lastSampledAt: Date? = nil, zoneNumber: Int? = nil,
                    ceilingBPM: Int? = nil, workout: Workout? = nil) {
            self.bpm = bpm
            self.recovery = recovery
            self.bonded = bonded
            self.effort = effort
            self.sampledAt = sampledAt
            self.lastBPM = lastBPM
            self.lastSampledAt = lastSampledAt
            self.zoneNumber = zoneNumber
            self.ceilingBPM = ceilingBPM
            self.workout = workout
        }
    }

    /// A recorded cardio session, as the banner needs it: its name, its clock, and whether it is paused.
    public struct Workout: Codable, Hashable {
        public var sport: String
        /// SF Symbol for the sport.
        public var symbol: String
        /// The session's start shifted by every paused stretch, so a system timer counting up from it
        /// reads the active time without a push each second.
        public var clockStart: Date
        /// Whole seconds of active time when paused; nil while the clock runs.
        public var pausedElapsed: Int?
        /// A time goal, in seconds of active time. The banner fills toward it on its own, from `clockStart`.
        /// Every goal field is optional, so a banner started by an older build still decodes.
        public var goalSeconds: Int?
        /// A distance goal's progress, 0…1, pushed as the distance grows (in steps of a hundredth).
        public var goalFraction: Double?
        /// "of 30:00" / "2.4 of 5 km", worded app-side: the extension ships no string catalog.
        public var goalLabel: String?
        public var goalReached: Bool?

        public init(sport: String, symbol: String, clockStart: Date, pausedElapsed: Int?,
                    goalSeconds: Int? = nil, goalFraction: Double? = nil, goalLabel: String? = nil,
                    goalReached: Bool? = nil) {
            self.sport = sport
            self.symbol = symbol
            self.clockStart = clockStart
            self.pausedElapsed = pausedElapsed
            self.goalSeconds = goalSeconds
            self.goalFraction = goalFraction
            self.goalLabel = goalLabel
            self.goalReached = goalReached
        }

        public var hasGoal: Bool { goalSeconds != nil || goalFraction != nil }

        public var isPaused: Bool { pausedElapsed != nil }
    }

    /// Static title shown for the session.
    public var title: String

    public init(title: String = "Live HR") {
        self.title = title
    }
}
#endif
