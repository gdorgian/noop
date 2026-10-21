#if os(iOS)
import SwiftUI
import StrandAnalytics
import StrandDesign
import WhoopStore

/// The utilities that left Settings → Later on 21 October 2026. Each one is an Aura page over an engine
/// the app already ships; none of them invents a figure. Drawn in Act 5's grammar (back header, Outfit
/// title, hairline cards) because design had listed them there without drawing them.
struct NoopUtilityScreens: View {
    @ObservedObject var navigation: NoopNavigation

    var body: some View {
        switch navigation.route {
        case .howItWorks: NoopHowItWorksPage(navigation: navigation)
        case .limitations: NoopStrapLimitsPage(navigation: navigation)
        case .siri: NoopSiriPage(navigation: navigation)
        case .shortcutExport: NoopShortcutExportPage(navigation: navigation)
        case .storage: NoopStoragePage(navigation: navigation)
        case .digest: NoopDigestPage(navigation: navigation)
        case .fused: NoopFusedPage(navigation: navigation)
        default: NoopHowItWorksPage(navigation: navigation)
        }
    }
}

// MARK: - Shared page grammar

private struct NoopUtilityPage<Content: View>: View {
    let back: String
    let title: String
    let lead: String
    @ObservedObject var navigation: NoopNavigation
    @ViewBuilder var content: Content

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                NoopBackHeader(label: back) { navigation.back(or: .settings) }
                    .padding(.horizontal, -2)
                    .padding(.bottom, -10)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(NoopHTMLFont.outfit(25)).tracking(-0.6)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(lead)
                        .font(NoopHTMLFont.sans(13.5)).tracking(-0.15)
                        .foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.bottom, 5)
                content
            }
        }
    }
}

private struct NoopUtilityCard<Content: View>: View {
    var label: String? = nil
    var trailing: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        NoopHTMLCard(radius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                if label != nil || trailing != nil {
                    HStack {
                        if let label { NoopSectionLabel(label) }
                        Spacer()
                        if let trailing {
                            Text(trailing).font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint)
                        }
                    }
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct NoopUtilityRow: View {
    let title: String
    var detail: String? = nil
    var value: String? = nil
    var valueTint: Color = NoopHTMLColor.ink

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                if let detail {
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                        .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            if let value {
                Text(value).font(NoopHTMLFont.outfit(16)).monospacedDigit().foregroundStyle(valueTint)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct NoopUtilityNote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint)
            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 2)
    }
}

private struct NoopUtilityButton: View {
    let title: String
    var busy = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(busy ? "Working…" : title)
                .font(NoopHTMLFont.sans(14, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity).frame(height: 50)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.11), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(busy)
    }
}

private func noopDivider() -> some View { Divider().overlay(NoopHTMLColor.border) }

// MARK: - How Noop works

private struct NoopHowItWorksPage: View {
    @ObservedObject var navigation: NoopNavigation

    private let sections: [(String, String, String)] = [
        ("Sleep", "Your main sleep is the longest real block, and once Noop has learned your usual hours, the one nearest them. Everything else that day is a nap. Stages come from movement and the beat-to-beat rhythm of your heart.",
         "duration · efficiency · stages"),
        ("Rest", "How long you slept against what you need, how efficient the night was, and how much of it was deep and REM. It needs about four nights to learn you, and sharpens over the first couple of weeks.",
         "your own baseline"),
        ("Effort", "Time in your heart-rate zones, each zone weighted so harder ones count for more (Edwards TRIMP), summed into one figure for the day. Settings offers Banister, which credits short hard efforts more.",
         "heart-rate zones"),
        ("Recovery", "Resting heart rate, sleep and night-to-night consistency, weighed against your own baseline, with heart-rate variability (rMSSD) leading wherever the strap gives a clean reading.",
         "against your baseline"),
        ("Fitness age", "An estimated VO₂max from the HUNT fitness model — resting heart rate, age and activity — read against population norms.",
         "a model, stated as one"),
    ]

    var body: some View {
        NoopUtilityPage(back: "Settings", title: "How Noop works",
                        lead: "Every number here is computed on this phone from your strap. Each follows a published method, named so you can read up on it, and none claims to reproduce another company’s score.",
                        navigation: navigation) {
            ForEach(sections, id: \.0) { section in
                NoopUtilityCard(label: section.0, trailing: section.2) {
                    Text(section.1)
                        .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                }
            }
            NoopUtilityCard(label: "Where a number comes from") {
                Text("A badge says whether a figure was scored on this phone, or imported from WHOOP or Apple Health. When Noop cannot compute something honestly it shows a dash and says what is missing, rather than a number it had to make up.")
                    .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Strap limitations

private struct NoopStrapLimitsPage: View {
    @ObservedObject var navigation: NoopNavigation

    private enum Reach { case full, partial, none }
    private let rows: [(String, Reach, Reach)] = [
        ("Live heart rate", .full, .full), ("Variability (rMSSD)", .full, .full),
        ("Sleep stages", .full, .full), ("Recovery and Effort", .full, .full),
        ("Breathing rate", .partial, .partial), ("Stress", .full, .full),
        ("Workout detection", .full, .full), ("Skin temperature", .partial, .full),
        ("Steps", .partial, .full), ("Blood oxygen", .none, .none),
        ("ECG", .none, .partial), ("Blood pressure", .none, .none),
    ]

    var body: some View {
        NoopUtilityPage(back: "Settings", title: "Strap limitations",
                        lead: "What each band can actually read. Noop never fills a gap with an estimate it cannot stand behind.",
                        navigation: navigation) {
            NoopUtilityCard {
                HStack {
                    Text("").frame(maxWidth: .infinity, alignment: .leading)
                    Text("4.0").frame(width: 62)
                    Text("5.0 / MG").frame(width: 70)
                }
                .font(NoopHTMLFont.sans(10.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.faint)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    if index > 0 { noopDivider() }
                    HStack {
                        Text(row.0).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        mark(row.1).frame(width: 62)
                        mark(row.2).frame(width: 70)
                    }
                    .padding(.vertical, 2)
                }
            }
            NoopUtilityCard(label: "Reading the marks") {
                legend(.full, "read live off the strap")
                legend(.partial, "an on-device estimate, or experimental on that firmware")
                legend(.none, "not from the strap — blood oxygen can come in from a WHOOP or Apple Health import")
            }
        }
    }

    private func mark(_ reach: Reach) -> some View {
        Text(reach == .full ? "yes" : reach == .partial ? "partly" : "no")
            .font(NoopHTMLFont.sans(11, weight: .semibold))
            .foregroundStyle(reach == .full ? NoopHTMLColor.green : reach == .partial ? NoopHTMLColor.warm : NoopHTMLColor.faint)
    }

    private func legend(_ reach: Reach, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            mark(reach).frame(width: 44, alignment: .leading)
            Text(text).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Siri and Shortcuts

private struct NoopSiriPage: View {
    @ObservedObject var navigation: NoopNavigation

    private let actions: [(String, String)] = [
        ("Sync Strap", "“Sync my Noop Aura strap” — pulls what the band has buffered"),
        ("Buzz Strap", "“Buzz my Noop Aura strap” — one buzz, to find it or to test it"),
        ("Mark a Moment", "“Mark a moment in Noop Aura” — a timestamp you can find later"),
        ("Ask Svea", "“Ask Noop Aura how I’m doing” — opens the conversation with your question"),
        ("Recovery Status", "says this morning’s recovery out loud"),
        ("Refresh Health Export", "rewrites the Shortcuts export files, for the HealthKit-free path"),
        ("Export Workout Route", "hands a recorded route to another app"),
    ]

    var body: some View {
        NoopUtilityPage(back: "Settings", title: "Siri and Shortcuts",
                        lead: "These are already on your phone — there is nothing to set up. Say them to Siri, find them in Spotlight, or build them into a Shortcut, a Back Tap or an automation.",
                        navigation: navigation) {
            NoopUtilityCard(label: "Ready-made actions") {
                ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                    if index > 0 { noopDivider() }
                    NoopUtilityRow(title: action.0, detail: action.1)
                }
            }
            NoopUtilityButton(title: "Open the Shortcuts app") {
                if let url = URL(string: "shortcuts://") { UIApplication.shared.open(url) }
            }
            NoopUtilityNote(text: "A Shortcut runs on this phone. Asking Svea sends only your question and the grants you allowed to the provider you set up; every other action stays here.")
        }
    }
}

// MARK: - Shortcuts export

private struct NoopShortcutExportPage: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var model: AppModel
    @AppStorage(ShortcutHealthExport.enabledKey) private var enabled = false
    @State private var rebuilding = false
    @State private var message: String?

    var body: some View {
        NoopUtilityPage(back: "Settings", title: "Shortcuts export",
                        lead: "The way into Apple Health for a sideloaded build that cannot hold the Health permission. Noop writes plain files; a Shortcut of yours reads them into Health.",
                        navigation: navigation) {
            NoopUtilityCard {
                Toggle(isOn: $enabled) {
                    NoopUtilityRow(title: "Write the export files",
                                   detail: "On My iPhone › Noop Aura › noop_sync.txt, rewritten each time you leave the app")
                }
                .tint(NoopHTMLColor.blue)
            }
            if enabled {
                NoopUtilityCard(label: "When the files went empty") {
                    Text("Rewinds the export so the files offer the past seven days again — for when your Shortcut never read them, or you changed it.")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    NoopUtilityButton(title: "Re-export the last 7 days", busy: rebuilding) { rebuild() }
                    if let message {
                        Text(message).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.green)
                    }
                }
            }
            NoopUtilityNote(text: "Shortcuts cannot write sleep stages, only asleep, awake and in bed. A build signed with the Health permission writes stages directly and does not need this.")
        }
    }

    private func rebuild() {
        rebuilding = true
        message = nil
        Task {
            ShortcutHealthExport.resetWatermark()
            ShortcutSessionExport.resetWatermarks()
            let windows = await ShortcutHealthExport.writeNow(repo: model.repo)
            let sessions = await ShortcutSessionExport.writeNow(repo: model.repo)
            var parts: [String] = []
            if case let .written(lines) = windows { parts.append("\(lines) heart-rate windows") }
            if case let .written(sleepLines, workoutLines) = sessions {
                if sleepLines > 0 { parts.append("\(sleepLines) sleep rows") }
                if workoutLines > 0 { parts.append("\(workoutLines) workouts") }
            }
            message = parts.isEmpty ? "Nothing in the last seven days to export yet."
                : "Wrote " + parts.joined(separator: ", ") + ". Run your Shortcut now."
            rebuilding = false
        }
    }
}

// MARK: - Storage

private struct NoopStoragePage: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var model: AppModel
    @State private var report: AppModel.StorageReport?
    @State private var cleaning = false
    @State private var cleaned: String?

    var body: some View {
        NoopUtilityPage(back: "Settings", title: "Storage",
                        lead: "What Noop is keeping on this phone. Your record is the database; the rest is working space that can go.",
                        navigation: navigation) {
            NoopUtilityCard(label: "On this phone") {
                NoopUtilityRow(title: "Your record", detail: "every night, session and reading, in one database",
                               value: format(report?.db))
                noopDivider()
                NoopUtilityRow(title: "Files handed to Noop", detail: "copies iOS made when you shared or picked a file",
                               value: report.map { format($0.inbox) })
                noopDivider()
                NoopUtilityRow(title: "Import working files", detail: "left over from unpacking an export",
                               value: report.map { format($0.importTemp) })
            }
            if let report, report.inbox + report.importTemp > 0 {
                NoopUtilityButton(title: "Clear \(format(report.inbox + report.importTemp)) of working files", busy: cleaning) {
                    clean()
                }
            }
            if let cleaned {
                Text(cleaned).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.green).padding(.horizontal, 2)
            }
            NoopUtilityNote(text: "Clearing never touches your record. Deleting the record itself lives under Data and permissions, behind its own confirmation.")
        }
        .task { report = await model.storageReport() }
    }

    private func format(_ bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func clean() {
        cleaning = true
        Task {
            let before = (report?.inbox ?? 0) + (report?.importTemp ?? 0)
            let after = await model.cleanUpStorage()
            report = after
            let freed = max(0, before - (after.inbox + after.importTemp))
            cleaned = "Cleared \(format(freed))."
            cleaning = false
        }
    }
}

// MARK: - Weekly digest

private struct NoopDigestPage: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var repo: Repository

    var body: some View {
        // Recovery is left out on purpose: Aura never presents morning recovery as Charge, and the
        // engine files it under that name. The focal points that lean on it go with it.
        let digest = WeeklyDigestSource.digest(from: repo.days, anchorDay: Repository.localDayKey(Date()))
        let metrics = digest.metrics.filter { $0.metric != .charge && $0.thisWeek.n > 0 }
        let focal = digest.focalPoints.filter { !$0.localizedCaseInsensitiveContains("charge") }
        return NoopUtilityPage(back: "Settings", title: "Weekly digest",
                               lead: "This week against last, in your own numbers. Written from what was measured; a day without a reading is left out, not counted as zero.",
                               navigation: navigation) {
            NoopUtilityCard(label: "This week", trailing: "\(digest.daysWithData) of 7 days measured") {
                if metrics.isEmpty {
                    Text("Nothing measured this week yet.")
                        .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                } else {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { index, m in
                        if index > 0 { noopDivider() }
                        NoopUtilityRow(title: m.metric.label,
                                       detail: change(m),
                                       value: value(m.thisWeek.mean, m.metric))
                    }
                }
            }
            if !focal.isEmpty {
                NoopUtilityCard(label: "Worth noticing") {
                    ForEach(focal, id: \.self) { line in
                        Text(line).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            NoopUtilityNote(text: "A comparison on fewer than three days a side is marked rough. These are readings, not a diagnosis.")
        }
    }

    private func value(_ v: Double, _ metric: WeeklyMetric) -> String {
        switch metric {
        case .rhr: "\(Int(v.rounded())) bpm"
        case .hrv: "\(Int(v.rounded())) ms"
        default: "\(Int(v.rounded()))"
        }
    }

    private func change(_ m: WeeklyMetricSummary) -> String {
        guard m.weekOverWeek.previous.n > 0 else { return "no last week to compare with" }
        let d = m.wowDelta
        let size = abs(d) < 0.5 ? "about the same as" : (d > 0 ? "up \(Int(abs(d).rounded())) on" : "down \(Int(abs(d).rounded())) on")
        return size + " last week" + (m.isRoughComparison ? " · rough" : "")
    }
}

// MARK: - Your data, fused

private struct NoopFusedPage: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var repo: Repository
    @State private var record: FusedRecord?

    var body: some View {
        NoopUtilityPage(back: "Settings", title: "Your data, fused",
                        lead: "Every source that spoke about today, merged onto one record, with the one Noop believed named for each reading.",
                        navigation: navigation) {
            if let record, !record.rows.isEmpty {
                NoopUtilityCard(label: "Today", trailing: "\(record.contributingSourceCount) source\(record.contributingSourceCount == 1 ? "" : "s")") {
                    ForEach(Array(record.rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { noopDivider() }
                        NoopUtilityRow(title: row.label,
                                       detail: detail(row.point),
                                       value: formatted(row.point))
                    }
                }
            } else {
                NoopUtilityCard {
                    Text(record == nil ? "Reading today’s sources…" : "No source has reported anything for today yet.")
                        .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                }
            }
            NoopUtilityNote(text: "When two sources disagree Noop keeps the one it trusts more for that reading — the strap over a phone estimate — and says so here. Nothing is averaged into a number neither source measured.")
        }
        .task(id: repo.refreshSeq) { record = await model.buildTodayFusedRecord() }
    }

    private func source(_ s: FusionSource) -> String {
        s == .noopComputed ? "Noop" : s.displayName
    }

    private func detail(_ p: FusedMetricPoint) -> String {
        let others = p.contributors.filter { $0.source != p.winningSource }.map { source($0.source) }
        let agreement: String = {
            switch p.agreement {
            case .single: return ""
            case .agree: return " · the others agree"
            case .minorDelta: return " · the others are close"
            case .conflict: return " · the others disagree"
            }
        }()
        return "from \(source(p.winningSource))" + (others.isEmpty ? "" : ", also \(others.joined(separator: ", "))") + agreement
    }

    /// Each reading in its own unit, as the rest of Aura states it.
    private func formatted(_ p: FusedMetricPoint) -> String {
        let v = p.value
        switch p.metric {
        case "rhr": return "\(Int(v.rounded())) bpm"
        case "hrv": return "\(Int(v.rounded())) ms"
        case "sleep_total_min":
            let m = Int(v.rounded())
            return "\(m / 60)h \(String(format: "%02d", m % 60))m"
        case "steps": return Int(v.rounded()).formatted()
        case "skin_temp": return String(format: "%+.1f °C", v)
        case "spo2": return String(format: "%.0f%%", v)
        default: return v.rounded() == v ? "\(Int(v))" : String(format: "%.1f", v)
        }
    }
}
#endif
