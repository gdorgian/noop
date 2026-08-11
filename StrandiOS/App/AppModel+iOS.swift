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
            case .exportHealth:
                Task { [repo] in
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
