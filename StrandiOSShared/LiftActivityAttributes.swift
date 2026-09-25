#if os(iOS)
import Foundation
import ActivityKit

/// Live Activity attributes for a running Lift Log session — the minimised session bar, on the Lock
/// Screen and in the Dynamic Island.
///
/// Deliberately a SEPARATE activity type from `NOOPActivityAttributes` (live HR). They answer
/// different questions and have different lifetimes: the HR activity lives as long as the strap is
/// streaming, this one as long as a gym session is open. While a session is running this one is the
/// useful surface — it carries the heart rate too — so the app suppresses the HR activity rather
/// than stacking two banners on the Lock Screen.
///
/// TIME IS CARRIED AS DATES, NOT AS A FORMATTED STRING. The widget renders them with
/// `Text(timerInterval:)`, which ticks on its own without the app pushing anything. Pushing a new
/// content state every second to animate a clock would burn the Live Activity update budget and
/// still look worse.
public struct LiftActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Amber rest vs green working — the same colour language as the sheet and the bar.
        public var isResting: Bool
        /// A paused session remains visible but neither clock advances.
        public var isPaused: Bool
        /// The rest target has elapsed and the next set is ready to start.
        public var isReady: Bool
        /// The exercise being worked, or rested from.
        public var exercise: String
        /// "Set 2" / "Resting after set 2" — resolved app-side so the wording matches the bar.
        public var status: String
        /// "8 x 30 kg", already unit-converted, because the unit preference lives in the app.
        /// Nil when neither reps nor weight is known.
        public var detail: String?
        /// "3 of 19 sets done", localized APP-SIDE. The widget extension ships no string catalog, so
        /// every word it renders has to arrive already translated — the same reason `status` and
        /// `detail` are strings rather than numbers.
        public var progress: String
        public var setsDone: Int
        public var setsPlanned: Int
        /// When the current stage began — the widget counts UP from here while working.
        public var stageStartedAt: Date
        /// When the running rest is due to end; the widget counts DOWN to it. Nil while working.
        public var restEndsAt: Date?
        /// The frozen set/rest clock while paused. Nil while the widget can render a live timer.
        public var heldClockSeconds: Int?

        public init(isResting: Bool, isPaused: Bool, isReady: Bool,
                    exercise: String, status: String, detail: String?, progress: String,
                    setsDone: Int, setsPlanned: Int, stageStartedAt: Date,
                    restEndsAt: Date?, heldClockSeconds: Int?) {
            self.isResting = isResting
            self.isPaused = isPaused
            self.isReady = isReady
            self.exercise = exercise
            self.status = status
            self.detail = detail
            self.progress = progress
            self.setsDone = setsDone
            self.setsPlanned = setsPlanned
            self.stageStartedAt = stageStartedAt
            self.restEndsAt = restEndsAt
            self.heldClockSeconds = heldClockSeconds
        }
    }

    /// The program's name, fixed for the life of the session.
    public var programName: String

    public init(programName: String) {
        self.programName = programName
    }
}
#endif
