#if os(iOS)
import BackgroundTasks
import Foundation

/// Best-effort background Svea turns. This task is scheduled only after the wearer explicitly enables
/// proactive briefs; provider traffic remains impossible at the default value.
enum SveaProactiveBackgroundTask {
    static let enabledKey = "noop.svea.backgroundProactiveEnabled"

    static var identifier: String {
        (Bundle.main.bundleIdentifier ?? "com.noopapp.noop") + ".sveaproactive"
    }

    @MainActor private static weak var coach: AICoachEngine?

    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(processingTask)
        }
    }

    @MainActor
    static func attach(coach: AICoachEngine) {
        self.coach = coach
        updateSchedule(enabled: UserDefaults.standard.bool(forKey: enabledKey))
    }

    static func updateSchedule(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: identifier)
        guard enabled,
              UserDefaults.standard.bool(forKey: "ai.dataConsent"),
              !SveaDataGrants.load().allowed.isEmpty else { return }

        let request = BGProcessingTaskRequest(identifier: identifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date().addingTimeInterval(4 * 3_600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGProcessingTask) {
        let work = Task { @MainActor in
            guard UserDefaults.standard.bool(forKey: enabledKey),
                  let coach,
                  CoachFeaturePrefs.isEnabled,
                  coach.dataConsent,
                  !SveaDataGrants.load().allowed.isEmpty,
                  coach.proactiveLevel != .off else {
                task.setTaskCompleted(success: true)
                updateSchedule(enabled: UserDefaults.standard.bool(forKey: enabledKey))
                return
            }

            // At most one generated turn per lease. Each method also has its own logical-day/repeat guard.
            var spoke = await coach.startBriefIfNeeded()
            if !spoke { spoke = await coach.runProactiveNudgeIfNeeded() }
            if !spoke { spoke = await coach.runGoalReviewIfNeeded() }
            if !spoke { spoke = await coach.runWeeklyReviewIfNeeded() }
            task.setTaskCompleted(success: spoke || !Task.isCancelled)
            updateSchedule(enabled: true)
        }
        task.expirationHandler = { work.cancel() }
    }
}
#endif
