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

        public init(bpm: Int?, recovery: Int?, bonded: Bool, effort: Int? = nil,
                    sampledAt: Date? = nil, lastBPM: Int? = nil,
                    lastSampledAt: Date? = nil, zoneNumber: Int? = nil,
                    ceilingBPM: Int? = nil) {
            self.bpm = bpm
            self.recovery = recovery
            self.bonded = bonded
            self.effort = effort
            self.sampledAt = sampledAt
            self.lastBPM = lastBPM
            self.lastSampledAt = lastSampledAt
            self.zoneNumber = zoneNumber
            self.ceilingBPM = ceilingBPM
        }
    }

    /// Static title shown for the session.
    public var title: String

    public init(title: String = "Live HR") {
        self.title = title
    }
}
#endif
