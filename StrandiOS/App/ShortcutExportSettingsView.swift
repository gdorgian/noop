#if os(iOS)
import SwiftUI
import StrandDesign

/// #155 — the opt-in surface for the Apple-Health-free export. Sideloaded installs (free 7-day
/// signing) can't carry the HealthKit entitlement, so HealthKitBridge never runs for them; this
/// toggle instead has NOOP rewrite Documents/noop_sync.txt on every background transition, and the
/// user's Siri Shortcut reads the file and logs the rows into Apple Health. Default OFF.
struct ShortcutExportSettingsView: View {
    @AppStorage(ShortcutHealthExport.enabledKey) private var enabled = false
    @EnvironmentObject private var model: AppModel
    @State private var rebuilding = false
    @State private var rebuiltMessage: String?

    var body: some View {
        ScreenScaffold(title: "Shortcuts Export",
                       subtitle: "Strap data into Apple Health without HealthKit, for sideloaded installs.") {
            exportCard
            if enabled { rebuildCard }
        }
    }

    /// Recovery surface. The watermark only moves when a Shortcut confirms it logged the rows, but a span
    /// can still be stranded behind it — an export confirmed while the Shortcut was mis-wired, or history
    /// consumed by a build that advanced the watermark on write. The rows are never deleted from the
    /// store, only skipped by the export, so re-offering the last 7 days is always available.
    private var rebuildCard: some View {
        StrandCard(padding: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Re-export the last 7 days")
                    .font(StrandFont.headline)
                    .foregroundStyle(StrandPalette.textPrimary)
                Text("Rewinds the export so the files offer everything from the past week again. Use this if the files went empty before your Shortcut ever read them, or after you rebuild the Shortcut. Anything already in Apple Health will be logged a second time.")
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    rebuild()
                } label: {
                    Text(rebuilding ? "Rebuilding…" : "Re-export last 7 days")
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.accent)
                }
                .disabled(rebuilding)
                if let rebuiltMessage {
                    Text(rebuiltMessage)
                        .font(StrandFont.caption)
                        .foregroundStyle(StrandPalette.textSecondary)
                }
            }
        }
    }

    private func rebuild() {
        rebuilding = true
        rebuiltMessage = nil
        Task {
            ShortcutHealthExport.resetWatermark()
            ShortcutSessionExport.resetWatermarks()
            let windows = await ShortcutHealthExport.writeNow(repo: model.repo)
            let sessions = await ShortcutSessionExport.writeNow(repo: model.repo)
            var parts: [String] = []
            if case let .written(lines) = windows { parts.append("\(lines) windows") }
            if case let .written(sleepLines, workoutLines) = sessions {
                if sleepLines > 0 { parts.append("\(sleepLines) sleep rows") }
                if workoutLines > 0 { parts.append("\(workoutLines) workouts") }
            }
            rebuiltMessage = parts.isEmpty
                ? "Nothing in the last 7 days to export yet."
                : "Wrote " + parts.joined(separator: ", ") + ". Run your Shortcut now."
            rebuilding = false
        }
    }

    private var exportCard: some View {
        StrandCard(padding: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up.on.square.fill")
                        .foregroundStyle(StrandPalette.accent)
                        .accessibilityHidden(true)
                    Text("Shortcuts file export")
                        .font(StrandFont.headline)
                        .foregroundStyle(StrandPalette.textPrimary)
                }
                Toggle(isOn: $enabled) {
                    Text("Export for Shortcuts (Apple Health)")
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textPrimary)
                }
                .toggleStyle(.switch)
                .tint(StrandPalette.accent)
                Text("When this is on, NOOP rewrites a plain-text file (On My iPhone › NOOP › noop_sync.txt) each time you leave the app: one line per 15 minutes of heart rate, HRV and steps, read straight from your strap. Pair it with the Siri Shortcut that reads the file and logs everything into Apple Health (no HealthKit entitlement needed), so it works on sideloaded installs. The setup guide and the pre-built Shortcut live in the project wiki on GitHub.")
                    .font(StrandFont.caption)
                    .foregroundStyle(StrandPalette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
#endif
