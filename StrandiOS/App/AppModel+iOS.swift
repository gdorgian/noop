#if os(iOS)
import Foundation

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
}
#endif
