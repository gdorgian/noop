#if os(iOS)
import Foundation
import UIKit

/// What the "Sync Strap" shortcut observed when it asked for a sync. Each case names only what was seen.
enum StrapSyncShortcutOutcome {
    /// `syncNow` ran and a sync session is now in progress.
    case started
    /// A sync was already running when the shortcut arrived, so nothing new was requested.
    case alreadyRunning
    /// The link was not ready within the wait (NOOP was launched in the background by the shortcut and is
    /// still connecting). The request is parked and the connect handshake runs it once the link can serve.
    case willSyncWhenConnected
    /// No app model at all, so there was nowhere to park the request.
    case strapNotReady
    /// The link was ready and `syncNow` ran, but no session started. The strap log says why.
    case notStarted
}

/// What the "Buzz Strap" shortcut observed. A buzz is only worth anything at the moment it was asked for,
/// so an unready link is reported, never parked for later.
enum StrapBuzzShortcutOutcome {
    case buzzed
    case strapNotReady
}

extension AppModel {
    /// Execute any actions queued by App Intents while the app was suspended (mark moment, buzz,
    /// ask coach, Shortcuts health export). Call when the app becomes active. The optional `router`
    /// lets the ask-coach intent navigate to the Coach tab after sending the question.
    func drainPendingIntents(router: NavRouter? = nil) {
        for item in PendingIntents.drain() {
            switch item.action {
            case .markMoment: markMoment(at: item.date ?? Date())
            // #921: the "Buzz Strap" Siri shortcut logged its write but a WHOOP 4.0 never vibrated.
            // The one-shot routine sends the confirmed pattern + RUN_ALARM sequence, acked, so a
            // busy just-foregrounded BLE link can't silently drop it.
            case .buzz:       buzzStrapOnce()
            // K9: "Ask Coach" via Siri — send the queued question to the Coach engine and navigate
            // to the Coach tab so the user sees the response. The question is consumed from a
            // dedicated key (one at a time).
            case .askCoach:
                if let question = PendingIntents.consumeCoachQuestion() {
                    router?.openCoach()
                    Task { @MainActor in
                        await coach.send(question)
                    }
                }
            // Both drop-file writers are gated on the same Shortcuts Export opt-in, so this is a no-op
            // until the wearer turns it on. Fire-and-forget: the Shortcut that raised this intent reads
            // the files on its next step, and a slow store read must not block the drain.
            // A refresh CONFIRMS the previous batch before writing the next one.
            //
            // "Refresh" is raised by a Shortcut that is about to read the files, so whatever it was
            // handed last time it has already logged. Acknowledging here means the Shortcut does not
            // have to delete the files to acknowledge them — and file deletion is the one step iOS
            // prompts for on EVERY run, which is what stops an automation being unattended.
            //
            // The trade-off is bounded and deliberate: if a run refreshes and then dies before logging,
            // that one batch is acknowledged without reaching Health. Settings → Shortcuts Export →
            // "Re-export the last 7 days" recovers it. Losing at most one batch to a crash beats
            // requiring a human tap on every single run.
            case .exportHealth:
                Task { [repo] in
                    ShortcutHealthExport.confirm()
                    ShortcutSessionExport.confirm()
                    await ShortcutHealthExport.writeIfEnabled(repo: repo)
                    await ShortcutSessionExport.writeIfEnabled(repo: repo)
                }
            // Promote pending → confirmed, THEN re-export: the rewrite is what actually empties the
            // files, and it must run after the watermarks have moved or it would re-emit the same span.
            case .confirmHealthExport:
                Task { [repo] in
                    ShortcutHealthExport.confirm()
                    ShortcutSessionExport.confirm()
                    await ShortcutHealthExport.writeIfEnabled(repo: repo)
                    await ShortcutSessionExport.writeIfEnabled(repo: repo)
                }
            }
        }
    }

    /// Background entry point for the "Sync Strap" shortcut. When iOS launches NOOP in the background to run
    /// the intent, the strap link is still coming up: NOOP auto-connects to the remembered strap on launch,
    /// but a connect + bond + handshake takes longer than an App Intent can wait, and `BLEManager.syncNow`
    /// declines until it has run (`LiveState.historyReady`). So: wait briefly for a link that is already up
    /// (the app-in-background case, where the reply can say the sync started), otherwise park the request
    /// with `armPendingManualSync` so the connect handshake runs it the moment the link can serve.
    static func startStrapSyncFromShortcut(waitSeconds: Int = 8) async -> StrapSyncShortcutOutcome {
        // The Dynamic Island readout goes up first, from here, because only a LiveActivityIntent may start
        // one from the background; the controller carries it through the sync from there.
        var islandStarted = false
        if let model = shared {
            SyncLiveActivityController.shared.startFromShortcut(live: model.live)
            islandStarted = true
        }
        for _ in 0..<waitSeconds {
            // A cold launch can hand the intent its first tick before the model exists; start the island
            // on the first tick that has one rather than never.
            if !islandStarted, let model = shared {
                SyncLiveActivityController.shared.startFromShortcut(live: model.live)
                islandStarted = true
            }
            if let model = shared, model.live.historyReady { break }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        guard let model = shared else {
            SyncLiveActivityController.shared.shortcutDidNotStart()
            return .strapNotReady
        }
        guard model.live.historyReady else {
            model.ble.armPendingManualSync()
            holdProcessAliveForPendingSync()
            return .willSyncWhenConnected
        }
        if model.live.backfilling { return .alreadyRunning }
        model.ble.syncNow()
        if model.live.backfilling { return .started }
        SyncLiveActivityController.shared.shortcutDidNotStart()
        return .notStarted
    }

    /// Background entry point for the "Buzz Strap" shortcut, so a Shortcuts automation (a message from someone,
    /// a VIP email, a meeting) can buzz the wrist without opening NOOP. Waits briefly for the link, then fires
    /// `pulses` single notification buzzes `gapMs` apart, or the full alarm-style one-shot when `alarm` is set.
    /// Each 5/MG notification buzz is a fixed-length motor pulse (see `buzzTimeNow`), so a pattern is a count of
    /// buzzes, not a length. Returns only after the last write so the background process stays alive for it.
    static func buzzFromShortcut(pulses: Int, alarm: Bool, gapMs: Int = 900, waitSeconds: Int = 6) async -> StrapBuzzShortcutOutcome {
        for _ in 0..<waitSeconds {
            if let model = shared, model.live.historyReady || model.live.backfilling { break }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
        guard let model = shared, model.live.historyReady || model.live.backfilling else { return .strapNotReady }
        if alarm {
            model.buzzStrapOnce()
            return .buzzed
        }
        for i in 0..<max(1, pulses) {
            if i > 0 { try? await Task.sleep(nanoseconds: UInt64(gapMs) * 1_000_000) }
            model.ble.send(.runHapticsPattern, payload: [2, 1, 0, 0, 0], writeType: .withResponse)
        }
        return .buzzed
    }

    /// Once the intent has replied, nothing keeps the background-launched process running, and iOS may suspend
    /// it before the strap has even answered the connect. Hold a background-time assertion until the link is
    /// ready (the parked request then fires on its own) or `maxSeconds` pass, whichever is first. Ended on every
    /// path, including the expiry handler, so the assertion never just runs out. Same idiom as the scene
    /// delegate's standard-HR flush. If the handshake needs longer than this, CoreBluetooth's own wakes on each
    /// BLE callback and state restoration take over; the parked request is persisted for exactly that case.
    private static func holdProcessAliveForPendingSync(maxSeconds: Int = 25) {
        let application = UIApplication.shared
        var taskID: UIBackgroundTaskIdentifier = .invalid
        taskID = application.beginBackgroundTask(withName: "sync-strap-shortcut-connect") {
            application.endBackgroundTask(taskID)
            taskID = .invalid
        }
        Task { @MainActor in
            for _ in 0..<maxSeconds {
                if taskID == .invalid { return }
                if let model = shared, model.live.historyReady || model.live.backfilling { break }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            if taskID != .invalid {
                application.endBackgroundTask(taskID)
                taskID = .invalid
            }
        }
    }
}
#endif
