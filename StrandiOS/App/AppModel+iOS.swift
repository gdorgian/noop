#if os(iOS)
import Foundation

extension AppModel {
    /// Execute any actions queued by App Intents while the app was suspended (mark moment, buzz).
    /// Call when the app becomes active.
    func drainPendingIntents() {
        for item in PendingIntents.drain() {
            switch item.action {
            case .markMoment: markMoment(at: item.date ?? Date())
            // #921: the "Buzz Strap" Siri shortcut logged its write but a WHOOP 4.0 never vibrated.
            // The one-shot routine sends the confirmed pattern + RUN_ALARM sequence, acked, so a
            // busy just-foregrounded BLE link can't silently drop it.
            case .buzz:       buzzStrapOnce()
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
}
#endif
