#if os(iOS)
import BackgroundTasks
import Foundation
import UserNotifications
import WidgetKit
import WhoopStore

extension Notification.Name {
    static let noopDeleteAllLocalData = Notification.Name("noop.deleteAllLocalData")
}

/// The HTML's destructive account action, implemented as an iOS-only local wipe. Noop has no server
/// account: "account" here means the complete local identity and record owned by this installation.
@MainActor
enum NoopLocalReset {
    static func perform(model: AppModel) async -> Bool {
        guard let store = await model.repo.storeHandle() else { return false }

        // Stop anything capable of writing fresh state while the record is being removed.
        SveaProactiveBackgroundTask.updateSchedule(enabled: false)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: SemanticMemoryBackgroundTask.identifier)
        HealthWritebackBackgroundScheduler.cancel()
        model.coach.stop()
        model.coach.disconnect()
        model.ble.forgetDevice(nil)

        let registry = model.deviceRegistry
        let paired = registry?.devices ?? []
        let pairedIDs = Set(paired.map(\.id))

        // Clear every known data namespace, including sources that do not appear as paired hardware.
        var sourceIDs = pairedIDs
        sourceIDs.formUnion(pairedIDs.map { $0 + "-noop" })
        sourceIDs.formUnion([
            model.deviceId,
            model.deviceId + "-noop",
            model.appleDeviceId,
            XiaomiImporter.deviceId,
            MoodStore.moodDeviceId,
            CycleTrackingStore.sourceId,
            HydrationStore.sourceId,
            Repository.journalDeviceId,
            WhoopStore.labBookSourceId,
            "lifting",
            "activity-file"
        ])

        var databaseWipeSucceeded = true
        for sourceID in sourceIDs.sorted() {
            do {
                try await store.deleteAllData(deviceId: sourceID)
            } catch {
                databaseWipeSucceeded = false
            }
        }
        guard databaseWipeSucceeded else {
            // Do not claim a completed deletion or hide the record behind onboarding after a database
            // failure. The user can retry while the remaining state is still inspectable.
            await model.repo.refresh()
            return false
        }

        // Remove registry rows only after their recordings are gone. `forget` repeats the now-empty
        // device delete defensively, then removes the actual pairing row.
        if let registry {
            for device in paired {
                OuraKeyStore.clear(deviceId: device.id)
                await registry.forget(device.id, store: store)
            }
        }

        model.activeWorkout = nil
        model.lastWorkout = nil
        model.moments = []
        model.sleepMarks = []
        await model.repo.refresh()

        // Empty every in-memory singleton as well as its backing store, so completing onboarding again
        // in the same process cannot resurrect stale entries.
        CaffeineLogStore.shared.replaceImported([])
        CaffeineLogStore.shared.clearAll()
        CoachMemory.shared.clearAll()
        CoachPlanStore.shared.clearAll()
        CoachGoalStore.shared.goals = []
        GoalActionStore.shared.clearAll()
        GoalContributionStore.shared.clearAll()
        UpdateStore.shared.clearAll()
        CoachIdentityStore.shared.applyPreset(.default)

        for conversation in model.coach.conversations {
            model.coach.deleteConversation(conversation.id)
        }
        model.coach.clearKey()
        CoachConversationStore.clear()
        CoachTranscriptStore.clear()
        await CoachSemanticMemory.shared.deleteIndex()

        #if OURA_CLOUD_IMPORT
        OuraTokenStore.clear()
        #endif

        let notifications = UNUserNotificationCenter.current()
        notifications.removeAllPendingNotificationRequests()
        notifications.removeAllDeliveredNotifications()

        // UserDefaults holds profile, UI, behavior, onboarding and per-feature settings. Removing the
        // app domain is the only honest "all settings" operation; write the onboarding gate back as
        // false so the live @AppStorage observer transitions immediately without a relaunch.
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        if let sharedDefaults = UserDefaults(suiteName: WidgetSnapshot.suiteName) {
            sharedDefaults.removePersistentDomain(forName: WidgetSnapshot.suiteName)
        }
        WidgetCenter.shared.reloadAllTimelines()
        UserDefaults.standard.set(false, forKey: "noop.onboarded")
        UserDefaults.standard.synchronize()
        return true
    }
}
#endif
