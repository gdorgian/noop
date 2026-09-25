#if os(iOS)
import StrandImport
import SwiftUI
import UniformTypeIdentifiers
import WhoopStore

// MARK: - plumbing/data · the two doors
//
// Import and backup are the same two formats read in opposite directions. The way in is ONE drop
// target, not twelve rows: the importer works out what it was handed from content and key shape, so
// the catalog of twelve is documentation and lives one tap down.
//
// Reading, what-was-written and the-wrong-file are explicit navigation states because Debug capture
// and restoration must be deterministic. They deliberately carry no back button: Stop, Done and
// Choose another file are the exits drawn by the HTML. Blush is the family hue; amber is spent only
// on the rejected file that needs something from the reader.
//
// Metrics below are the handoff's, read off the drawn frames rather than paraphrased: section labels
// sit ABOVE their card, trailing notes sit BELOW it, list cards are padded 4/16 with a hairline
// between rows, and the two figure heroes are Outfit 200.


// MARK: - Production adapter
//
// The screens below draw the handoff. In a Debug `--demo-seed` build they draw its fixture; everywhere
// else they read this adapter, which binds them to the importers, `DataBackup`, `CsvExport`,
// `FolderBackup` and the store. It never supplies a number the store, the file or the importer did not
// hand it: what is unknown renders as unknown.

@MainActor
final class NoopDataFlow: ObservableObject {
    static let shared = NoopDataFlow()

    struct Stored: Equatable {
        let days: Int
        let sleeps: Int
        let first: String?
        let last: String?
    }

    struct Reading: Equatable {
        let fileName: String
        let fileSize: Int?
        let startedAt: Date
    }

    struct Written: Equatable {
        let source: String
        let summary: ImportSummary
    }

    struct Refused: Equatable {
        let fileName: String
        let reason: String
    }

    enum Phase: Equatable {
        case idle
        case reading(Reading)
        case imported(Written)
        case rejected(Refused)
    }

    @Published private(set) var stored: Stored?
    @Published private(set) var storedUnavailable = false
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var backupBusy = false
    @Published var notice: (title: String, message: String)?

    var isReading: Bool { if case .reading = phase { return true }; return false }

    // MARK: Stored on this phone

    func loadStored(repo: Repository) async {
        guard let store = await repo.storeHandle() else {
            stored = nil
            storedUnavailable = true
            return
        }
        // Every namespace that the iOS import door can actually write. Counting only the active and
        // canonical WHOOP ids made Apple Health, Mi Band, Oura, Fitbit and Garmin disappear from this
        // card even though their rows were safely in the database.
        let ids = (
            repo.importedReadIds
                + repo.computedReadIds
                + [Repository.appleHealthSource, Repository.xiaomiBandSource]
                + Repository.wearableImportSources
        ).reduce(into: [String]()) { result, id in
            if !result.contains(id) { result.append(id) }
        }

        do {
            var days = Set<String>()
            // A "sleep" here is one stored sleep day. That lets Apple Health's daily sleep aggregate
            // and a wearable's matching session describe the same night without double-counting it.
            var sleeps = Set<String>()
            let sleepRowLimit = 100_001

            for id in ids {
                for metric in try await store.dailyMetrics(
                    deviceId: id,
                    from: "0000-01-01",
                    to: "9999-12-31"
                ) {
                    days.insert(metric.day)
                    if metric.totalSleepMin != nil { sleeps.insert(metric.day) }
                }

                let sessions = try await store.sleepSessions(
                    deviceId: id,
                    from: 0,
                    to: 4_102_444_800,
                    limit: sleepRowLimit
                )
                // Never present a truncated count as complete. Reaching this deliberately generous
                // bound is treated as unavailable until the store exposes an aggregate count query.
                guard sessions.count < sleepRowLimit else {
                    stored = nil
                    storedUnavailable = true
                    return
                }
                for session in sessions {
                    sleeps.insert(Repository.localDayKey(
                        Date(timeIntervalSince1970: TimeInterval(session.endTs))
                    ))
                }
            }

            let sorted = days.sorted()
            stored = Stored(days: days.count, sleeps: sleeps.count, first: sorted.first, last: sorted.last)
            storedUnavailable = false
        } catch {
            // A partial count is worse than an explicit unknown: it looks authoritative and can only
            // understate what the person has entrusted to the app.
            stored = nil
            storedUnavailable = true
        }
    }

    // MARK: The door in

    /// Pick one file and hand it to the importer that recognises it by content. The flow moves forward
    /// only: `reading`, then `imported` or `rejected`.
    func chooseAndImport(model: AppModel, navigation: NoopNavigation) {
        guard !isReading else { navigation.replace(with: .reading); return }
        Task {
            let types: [UTType] = [.zip, .xml, .json, .commaSeparatedText, .plainText, .data, .item]
            guard let picked = await DocumentPicker.importFile(types) else { return }
            await importFile(picked, model: model, navigation: navigation)
        }
    }

    func importFile(_ picked: URL, model: AppModel, navigation: NoopNavigation) async {
        guard !isReading else { return }
        let size = (try? picked.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        phase = .reading(Reading(fileName: picked.lastPathComponent, fileSize: size, startedAt: Date()))
        navigation.replace(with: .reading)
        let outcome = await Self.run(picked, model: model)
        phase = outcome
        await loadStored(repo: model.repo)
        // A reader who left the flow is not dragged back into it; the result waits for them.
        if navigation.route == .reading {
            switch outcome {
            case .imported: navigation.replace(with: .imported)
            case .rejected: navigation.replace(with: .rejected)
            case .idle, .reading: break
            }
        }
    }

    #if DEBUG
    private var debugImportConsumed = false

    /// Debug-only capture seam: `--act5-import <path>` runs the real importer on a file already in the
    /// app's sandbox, so the production flow can be exercised without driving the system picker.
    func runDebugImportIfRequested(model: AppModel, navigation: NoopNavigation) async {
        guard !debugImportConsumed,
              let flag = CommandLine.arguments.firstIndex(of: "--act5-import"),
              CommandLine.arguments.indices.contains(flag + 1) else { return }
        debugImportConsumed = true
        await importFile(URL(fileURLWithPath: CommandLine.arguments[flag + 1]), model: model, navigation: navigation)
    }
    #endif

    func finishFlow() {
        if !isReading { phase = .idle }
    }

    private static func run(_ picked: URL, model: AppModel) async -> Phase {
        let name = picked.lastPathComponent
        let scoped = picked.startAccessingSecurityScopedResource()
        defer { if scoped { picked.stopAccessingSecurityScopedResource() } }
        guard let store = await model.repo.storeHandle() else {
            return .rejected(Refused(fileName: name, reason: "The record on this phone could not be opened, so nothing was read. Try again after reopening Noop."))
        }
        do {
            let local = try await AppModel.materializeForImport(picked)
            defer { local.cleanup() }
            let kind: DataSourceKind?
            do {
                kind = try ImportCoordinator().detectKind(of: local.url)
            } catch ImportError.notAZipOrFolder {
                kind = nil   // no first-party marker: the wearable importer sniffs Oura, Fitbit or Garmin
            }
            let written: Written
            switch kind {
            case .whoopExport:
                let summary = try await WhoopImporter.importExport(url: local.url, into: store, deviceId: model.deviceId)
                written = Written(source: "WHOOP export", summary: summary)
            case .appleHealth:
                let summary = try await AppleHealthImport.importExport(url: local.url, into: store, deviceId: model.appleDeviceId)
                model.repo.appleHealthCache = nil
                model.repo.appleHealthLoadedSeq = -1
                written = Written(source: "Apple Health", summary: summary)
            case .xiaomiBand:
                let summary = try await XiaomiImporter.importExport(url: local.url, into: store)
                written = Written(source: "Mi Band", summary: summary)
            case .ouraImport, .fitbitImport, .garminImport, nil:
                let result = try await WearableImporter.importExport(url: local.url, into: store)
                written = Written(source: result.brand.displayName, summary: result.summary)
            }
            try? await store.checkpointWAL()
            await model.repo.refresh()
            return .imported(written)
        } catch let error as ImportError {
            return .rejected(Refused(fileName: name, reason: Self.reason(for: error)))
        } catch {
            // Third-party parser errors can include the app's sandbox path. The screen already names
            // the selected file; do not expose an internal path or an unreviewed system sentence.
            return .rejected(Refused(
                fileName: name,
                reason: "Noop could not finish reading this file, so nothing from it was written. Check that the export finished downloading, then choose it again."
            ))
        }
    }

    private static func reason(for error: ImportError) -> String {
        switch error {
        case .fileNotFound:
            return "The file was gone by the time Noop went to read it. Nothing was written."
        // The importer's own text carries a sandbox path; the reader gets the finding without it.
        case .notAZipOrFolder:
            return "Noop could not recognise this as an export it reads. It is not one of the files in the list below, so nothing in it could be attached to a date."
        case .missingEntry(let entry):
            return "This looks like an export, but it is missing \((entry as NSString).lastPathComponent), which Noop needs to read the rest."
        case .xmlParseFailed:
            return "The file looks like an Apple Health export, but it could not be parsed. It may have been cut short while it was copied."
        case .emptyExport:
            return "Noop recognised the file, but it carried nothing that could be written."
        }
    }

    // MARK: The door out

    func exportBackup(repo: Repository) {
        guard !backupBusy else { return }
        backupBusy = true
        Task {
            let result = await DataBackup.runExport(checkpoint: { await repo.checkpointForBackup() })
            backupBusy = false
            switch result {
            case .cancelled: return
            case .exported(let url):
                notice = ("Backup saved", "\(url.lastPathComponent) is ready to copy to your other phone.")
            case .imported:
                return
            // The file is valid and worth keeping — a restore just needs one confirmation. Said at
            // EXPORT time on purpose: the alternative is finding out during a restore, which is exactly
            // when the original is gone.
            case .exportedOversize(let url, _, _):
                notice = ("Backup saved, and it is a large one",
                          "\(url.lastPathComponent) is ready. Your record is big enough that restoring it will ask you to confirm once.")
            // Not an export outcome; answered so the reading stays exhaustive if the shared type grows.
            case .restoreTooLarge:
                return
            case .failure(let message):
                notice = ("The backup was not written", message)
            }
        }
    }

    func exportCSV(repo: Repository) {
        guard !backupBusy else { return }
        backupBusy = true
        Task {
            let result = await CsvExport.run(repo: repo)
            backupBusy = false
            switch result {
            case .cancelled: return
            case .exported(let url):
                notice = ("CSV saved", "\(url.lastPathComponent) reads back into Noop.")
            case .failure(let message):
                notice = ("The CSV was not written", message)
            }
        }
    }

    func restoreBackup() {
        guard !backupBusy, !isReading else { return }
        backupBusy = true
        Task {
            let result = await DataBackup.runImport()
            backupBusy = false
            switch result {
            case .cancelled, .exported, .exportedOversize: return
            case .imported:
                notice = ("Restored", "The backup replaced the record on this phone. Quit and reopen Noop for it to take effect.")
            // The size ceiling is a decompression guard against a hostile archive, and a backup the
            // wearer just picked out of their own files is a different threat model. Upstream offers to
            // go ahead anyway; Noop Aura has no designed confirmation for that yet, so this says plainly
            // what stopped rather than pretending the file was broken.
            case .restoreTooLarge(let name, _):
                notice = ("That backup is too large to restore",
                          "\(name) is bigger than the size Noop will unpack on its own. Nothing on this phone was changed.")
            case .failure(let message):
                notice = ("Nothing was restored", message)
            }
        }
    }
}

/// Formatting that only ever restates what it is given.
enum NoopDataFormat {
    static func count(_ value: Int) -> String {
        value.formatted(
            .number
                .grouping(.automatic)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
    }

    static func day(_ key: String) -> String? {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: key).map(date)
    }

    static func date(_ value: Date) -> String {
        let out = DateFormatter()
        out.calendar = Calendar(identifier: .gregorian)
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "d MMM yyyy"
        return out.string(from: value)
    }

    static func bytes(_ value: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .file)
    }

    static func age(sinceMs ms: Int, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(Date(timeIntervalSince1970: Double(ms) / 1000))
        let days = Int(seconds / 86_400)
        if days >= 2 { return "\(days) days ago" }
        if days == 1 { return "Yesterday" }
        let hours = Int(seconds / 3_600)
        if hours >= 1 { return hours == 1 ? "An hour ago" : "\(hours) hours ago" }
        return "Just now"
    }

    /// "Seven years, in" from the span the importer reported. No span, no claim about time.
    static func headline(_ summary: ImportSummary) -> String {
        guard let first = summary.earliest, let last = summary.latest, last >= first else {
            return "Written, undated"
        }
        let parts = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: first, to: last)
        let (n, unit): (Int, String) = {
            if let y = parts.year, y >= 1 { return (y, "year") }
            if let m = parts.month, m >= 1 { return (m, "month") }
            return (max(1, (parts.day ?? 0) + 1), "day")
        }()
        let words = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
                     "Eleven", "Twelve"]
        let lead = n < words.count ? words[n] : "\(n)"
        return "\(lead) \(unit)\(n == 1 ? "" : "s"), in"
    }

    /// The importers' own category keys, said in words.
    static func category(_ key: String) -> String {
        let known: [String: String] = [
            "days": "Days", "cycles": "Cycles", "sleeps": "Sleeps", "sleepSessions": "Sleeps",
            "workouts": "Workouts", "journal": "Journal entries", "journalEntries": "Journal entries",
            "HeartRate": "Heart rate", "SleepAnalysis": "Sleep analysis", "RestingHeartRate": "Resting heart rate",
            "HeartRateVariabilitySDNN": "Variability", "StepCount": "Steps"
        ]
        if let word = known[key] { return word }
        var spaced = ""
        for (index, char) in key.enumerated() {
            if index > 0, char.isUppercase { spaced += " " }
            spaced.append(index == 0 ? Character(char.uppercased()) : Character(char.lowercased()))
        }
        return spaced
    }
}

struct NoopDataScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var repo: Repository
    @ObservedObject private var flow = NoopDataFlow.shared
    @State private var connectedServices: Set<String> = ["Apple Health"]

    /// The handoff's fixture is drawn only in a Debug `--demo-seed` build. `--act5-live` keeps a seeded
    /// capture on the production binding, so the live states can be flipped at the same position.
    private var demo: Bool {
        #if DEBUG
        NoopContentPolicy.allowsPrototypeContent && !CommandLine.arguments.contains("--act5-live")
        #else
        false
        #endif
    }

    private static let blush = Color(hex: 0xE08A9B)
    private static let blushLight = Color(hex: 0xF6D3DA)
    private static let blushInk = Color(hex: 0x201013)
    /// rgb(139,149,143) — the handoff's sub-copy and section-label grey inside the phone.
    private static let dim = Color(hex: 0x8B958F)

    var body: some View {
        Group {
            switch navigation.route {
            case .importHistory: importScreen
            case .reading: reading
            case .imported: imported
            case .rejected: rejected
            case .backup: backupScreen
            default: dataHome
            }
        }
        .task(id: repo.refreshSeq) {
            if !demo { await flow.loadStored(repo: repo) }
        }
        #if DEBUG
        .task {
            if !demo { await flow.runDebugImportIfRequested(model: model, navigation: navigation) }
        }
        #endif
        .alert(flow.notice?.title ?? "", isPresented: Binding(
            get: { flow.notice != nil },
            set: { if !$0 { flow.notice = nil } }
        )) {
            Button("OK") { flow.notice = nil }
        } message: {
            Text(flow.notice?.message ?? "")
        }
    }

    // MARK: 1 · The door in, and 5 · the door out

    private var importScreen: some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 0) {
                NoopBackHeader(label: "Your data") { navigation.back(or: .data) }
                    .padding(.bottom, -8)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Bring your history in")
                        .font(NoopHTMLFont.outfit(23))
                        .tracking(-0.46)
                        .foregroundStyle(NoopHTMLColor.ink)
                        .padding(.horizontal, 2)

                    dropTarget
                        .padding(.top, 16)

                    section("Stored on this phone") {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 7) {
                                figure(storedDays, "days")
                                figure(storedSleeps, "sleeps")
                                Spacer(minLength: 0)
                            }
                            Text(storedSpan)
                                .font(NoopHTMLFont.sans(11.5))
                                .monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                        .padding(.vertical, 15)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 22).fill(NoopHTMLColor.card))
                        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
                    }
                    .padding(.top, 18)

                    section(
                        "What it can read",
                        note: "A renamed or re-zipped export still routes correctly — it is read by content, not by filename."
                    ) {
                        Button { navigation.show(.importCatalog) } label: {
                            rowsCard([
                                RowModel(title: "Wearable exports",
                                         note: "WHOOP, Apple Health, Oura, Fitbit, Garmin, Mi Band",
                                         trailing: .chevron, padding: 13),
                                RowModel(title: "Single files",
                                         note: "Workouts, nutrition, lab markers, lifting",
                                         trailing: .chevron, padding: 13)
                            ])
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                    .padding(.top, 18)

                    Text("Your scores stay yours. Noop recomputes Rest, Charge and Effort from the raw heart rate, variability and sleep it finds. A brand’s own score is kept for reference and never shown as one of yours — so your numbers here will not match your old app’s.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Self.dim)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 16)
                }
            }
        }
    }

    /// One drop target, drawn in the screen's own hue so it reads as the way in rather than as
    /// another card. Radius 28 and a full-weight border are the handoff's — this is the only
    /// panel on the surface that is not the standard 22/0.5 card.
    private var dropTarget: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Self.blush.opacity(0.13))
                    .overlay(Circle().strokeBorder(Self.blush.opacity(0.3), lineWidth: 0.5))
                NoopCanonicalGlyph(name: .download, size: 21, color: Self.blush)
            }
            .frame(width: 47, height: 47)

            Text("Hand it one file")
                .font(NoopHTMLFont.outfit(19))
                .tracking(-0.38)
                .foregroundStyle(NoopHTMLColor.ink)
                .padding(.top, 12)

            Text("A zip, a folder, or a single file. Noop reads it and works out what it is — you don’t pick a brand.")
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(NoopHTMLColor.copy)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 12.5 * 19)   // max-width: 19em
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)

            Button {
                if demo {
                    navigation.importStartedAt = Date()
                    navigation.replace(with: .reading)
                } else {
                    flow.chooseAndImport(model: model, navigation: navigation)
                }
            } label: {
                Text("Choose a file or folder")
                    .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                    .foregroundStyle(Self.blushInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Self.blush.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(NoopHTMLPressStyle())
            .padding(.top, 14)

            Text("Sharing to Noop from Files or Mail works too")
                .font(NoopHTMLFont.sans(11))
                .foregroundStyle(NoopHTMLColor.faint)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(RoundedRectangle(cornerRadius: 28).fill(Self.blush.opacity(0.05)))
        // The app's only dashed edge: the one place a dashed border means "put something here".
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(Self.blush.opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }

    private var storedDays: String {
        if demo { return "1,284" }
        return flow.stored.map { NoopDataFormat.count($0.days) } ?? "\u{2014}"
    }

    private var storedSleeps: String {
        if demo { return "1,190" }
        return flow.stored.map { NoopDataFormat.count($0.sleeps) } ?? "\u{2014}"
    }

    private var storedSpan: String {
        if demo { return "14 Feb 2023 \u{2014} today" }
        if flow.storedUnavailable { return "The record on this phone could not be opened" }
        guard let stored = flow.stored else { return "Counting what is stored\u{2026}" }
        guard let first = stored.first.flatMap(NoopDataFormat.day),
              let last = stored.last.flatMap(NoopDataFormat.day) else { return "Nothing stored yet" }
        return "\(first) \u{2014} \(last)"
    }

    private func figure(_ value: String, _ unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .font(NoopHTMLFont.outfit200(26))
                .tracking(-0.78)
                .monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink)
            Text(unit)
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(NoopHTMLColor.copy)
        }
    }

    // MARK: 5 · The door out

    private var backupContents: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        NoopSectionLabel("Last snapshot", color: Self.dim)
                        Text(snapshotAge)
                            .font(NoopHTMLFont.outfit(21, weight: .light))
                            .tracking(-0.42)
                            .foregroundStyle(NoopHTMLColor.ink)
                            .padding(.top, 4)
                        Text(snapshotPlace)
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .padding(.top, 5)
                    }
                    Spacer(minLength: 0)
                    // Blush, not amber: the schedule is being kept. Amber here is reserved for a
                    // snapshot that has actually been missed.
                    schedulePill
                }

                Divider().overlay(NoopHTMLColor.border).padding(.top, 12)

                HStack(spacing: 8) {
                    NoopCanonicalGlyph(name: .clock, size: 13, color: NoopHTMLColor.faint)
                    Text(snapshotNext)
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Self.dim)
                }
                .padding(.top, 10)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24).fill(NoopHTMLColor.card))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

            section("Take one now", noteView: AnyView(approximateNote)) {
                rowsCard([
                    RowModel(id: "noopbak", title: "Everything, exactly · .noopbak",
                             note: "The whole database, your settings, and which build wrote it. The phone-to-phone path.",
                             noteColor: Self.dim, noteSize: 11.5,
                             trailing: .glyph(.upload, Self.blush.opacity(0.8), 17), padding: 14),
                    RowModel(id: "csv", title: "A readable copy · WHOOP CSV",
                             note: "Four CSVs in a zip. Reads back into Noop, and into the Android build.",
                             noteColor: Self.dim, noteSize: 11.5,
                             trailing: .glyph(.upload, Self.blush.opacity(0.8), 17), padding: 14)
                ], onTap: demo ? nil : { id in
                    if id == "noopbak" { flow.exportBackup(repo: repo) } else { flow.exportCSV(repo: repo) }
                })
            }

            section(
                "On a new phone",
                note: "There is no account and no server, so this file is the only way your history reaches another phone. That is the whole reason this screen ships with Act 5.",
                noteColor: Self.dim
            ) {
                Button {
                    // The HTML's row opens the drop target. The content detector does not read a
                    // `.noopbak`, so the production row runs the one restore path that does.
                    if demo { navigation.enter(.importHistory, from: .data) } else { flow.restoreBackup() }
                } label: {
                    rowsCard([
                        RowModel(title: "Restore from a .noopbak",
                                 note: "Replaces everything on this phone. It will tell you which build wrote the file first.",
                                 noteColor: Self.dim, noteSize: 11.5,
                                 trailing: .chevron, padding: 14)
                    ])
                }
                .buttonStyle(NoopHTMLPressStyle())
            }

        }
    }

    private var backupScreen: some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 0) {
                NoopBackHeader(label: "Your data") { navigation.back(or: .data) }
                    .padding(.bottom, -8)
                Text("Backup and sync")
                    .font(NoopHTMLFont.outfit(23))
                    .tracking(-0.46)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .padding(.horizontal, 2)
                backupContents
                    .padding(.top, 18)
            }
        }
    }

    private var snapshotAge: String {
        if demo { return "2 days ago" }
        let last = FolderBackup.lastBackupMs
        return last > 0 ? NoopDataFormat.age(sinceMs: last) : "None yet"
    }

    private var snapshotPlace: String {
        if demo { return "iCloud Drive \u{00B7} 214 MB" }
        return FolderBackup.folderLabel() ?? "No backup folder chosen"
    }

    private var snapshotNext: String {
        if demo { return "Next on Sunday, keeping the last 8" }
        guard FolderBackup.autoEnabled, FolderBackup.hasFolder else {
            return "Automatic snapshots are off"
        }
        return "Next a day after the last, keeping the last \(FolderBackup.keepCount)"
    }

    private var scheduleWord: String {
        if demo { return "Weekly" }
        return FolderBackup.autoEnabled && FolderBackup.hasFolder ? "Daily" : "Manual"
    }

    private var schedulePill: some View {
        HStack(spacing: 6) {
            Circle().fill(Self.blush.opacity(0.75)).frame(width: 5, height: 5)
            Text(scheduleWord)
                .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                .tracking(0.63)
                .foregroundStyle(Self.blushLight)
        }
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(RoundedRectangle(cornerRadius: 10).fill(Self.blush.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Self.blush.opacity(0.3), lineWidth: 0.5))
    }

    /// The tag is named in the app's own voice, so it is set apart from the sentence around it.
    private var approximateNote: some View {
        (
            Text("In the CSV, anything Noop worked out itself is tagged ")
            + Text("noop (APPROXIMATE)").font(.system(size: 11, design: .monospaced)).foregroundColor(Self.dim)
            + Text(" and skipped on the way back in, and Apple Health rows are left out entirely so they cannot be mis-attributed to a strap.")
        )
        .font(NoopHTMLFont.sans(11.5))
        .foregroundStyle(NoopHTMLColor.faint)
        .lineSpacing(3.5)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: The other half of the screen's name
    //
    // The doors are new; these are not. They sit below the way out because a person comes here to
    // move their history far more often than to read what the strap records.

    private var dataHome: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                NoopBackHeader(label: "You") { navigation.back(or: .you) }
                    .padding(.horizontal, -2)
                    .padding(.bottom, -10)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Data and permissions")
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("What is collected, where it sits, and how to take it with you.")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4)
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("What the strap records")
                        VStack(alignment: .leading, spacing: 10) {
                            dataFact("Pulse, and the gap between beats", "Continuously while worn. This is where sleep stages, stress and recovery all come from.")
                            dataFact("Movement", "To tell sleep from lying still, and to auto-pause a session.")
                            dataFact("Skin temperature and blood oxygen", "Overnight, as deviations from your own normal rather than absolute figures.")
                            dataFact("What you log", "Coffee, drinks, meals, naps, intimacy. Only what you tap.")
                        }
                    }
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("Where it lives")
                        VStack(alignment: .leading, spacing: 11) {
                            dataPlace("On your phone", demo
                                ? "Everything raw: every beat, every night, the whole 221. It never has to leave to be useful."
                                : "Everything raw: every beat, every night. It never has to leave to be useful.", glyph: .watch)
                            dataPlace("On Noop’s servers", "Nothing. There is no account and no server — a restore comes from your own backup file.", glyph: .cloud)
                        }
                    }
                }

                VStack(spacing: 0) {
                    if demo {
                        dataConnection("Apple Health", "writes sleep, workouts and vitals")
                        Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
                        dataConnection("Strava", "would write sessions only")
                        Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
                        dataConnection("Google Fit", "not connected")
                    } else {
                        // Strava and Google Fit do not exist in this build, and the Apple Health
                        // switches live on their own screen; a toggle here would change nothing.
                        dataRoute("Apple Health", "What Noop writes and reads is set here", glyph: .heart) {
                            navigation.enter(.apple, from: .data)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

                VStack(spacing: 8) {
                    VStack(spacing: 0) {
                        dataRoute("Bring your history in", "One file, any brand — Noop works out what it is", glyph: .download) {
                            navigation.enter(.importHistory, from: .data)
                        }
                        Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
                        dataRoute("Backup and sync", backupRouteDetail, glyph: .upload) {
                            navigation.enter(.backup, from: .data)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

                    Button { navigation.show(.destructiveConfirmation("your account and data")) } label: {
                        HStack(spacing: 9) {
                            NoopCanonicalGlyph(name: .trash, size: 19, color: Color(hex: 0xF3A472))
                            Text("Delete my account and data")
                                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        }
                        .foregroundStyle(Color(hex: 0xF3A472))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(NoopHTMLColor.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(NoopHTMLColor.amber.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }

                Text("Nothing here is sold, and there is no advertising identifier in the app. Deleting takes effect immediately and the export is a plain file you can read yourself.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }
        }
    }

    private var backupRouteDetail: String {
        if demo { return "Last snapshot 2 days ago \u{00B7} iCloud Drive" }
        let last = FolderBackup.lastBackupMs
        guard last > 0 else { return "No snapshot yet" }
        let age = NoopDataFormat.age(sinceMs: last)
        let place = FolderBackup.folderLabel().map { " \u{00B7} \($0)" } ?? ""
        return "Last snapshot \(age.prefix(1).lowercased() + age.dropFirst())\(place)"
    }

    private func dataFact(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle().fill(NoopHTMLColor.blue).frame(width: 7, height: 7).padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.ink)
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
            }
        }
    }

    private func dataPlace(_ title: String, _ detail: String, glyph: NoopCanonicalGlyphName) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NoopCanonicalGlyph(name: glyph, size: 19, color: Self.blush).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.ink)
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
            }
        }
    }

    private func dataConnection(_ title: String, _ detail: String) -> some View {
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
            }
            Spacer(minLength: 8)
            NoopA5TintToggle(isOn: connectedServices.contains(title), tint: Self.blush) {
                if connectedServices.contains(title) { connectedServices.remove(title) }
                else { connectedServices.insert(title) }
            }
        }
        .frame(minHeight: 62)
    }

    private func dataRoute(_ title: String, _ detail: String, glyph: NoopCanonicalGlyphName, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                NoopCanonicalGlyph(name: glyph, size: 19, color: Self.blush).frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                }
                Spacer(minLength: 8)
                NoopChevron()
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    // MARK: 2 · Reading

    private var reading: some View {
        if demo { return AnyView(demoReading) }
        return AnyView(liveReading)
    }

    private var demoReading: some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 18) {
                NoopScreenHeader("Apple Health", eyebrow: "Reading")
                    .padding(.bottom, -18)

                VStack(alignment: .leading, spacing: 13) {
                    // The figure and the bar are one number, read twice.
                    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                        let fraction = Self.readFraction(from: navigation.importStartedAt, at: timeline.date)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(Int(fraction * 100))")
                                .font(NoopHTMLFont.outfit200(44))
                                .tracking(-1.76)
                                .monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("%")
                                .font(NoopHTMLFont.sans(15))
                                .foregroundStyle(NoopHTMLColor.copy)
                            Spacer(minLength: 8)
                            Text("export.xml · 2.4 GB")
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                    }
                    .frame(height: 44)

                    readingBar

                    Text("Streaming it a piece at a time and aggregating as it goes, so a file this size never has to fit in memory.")
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                section("Found so far") {
                    rowsCard([
                        RowModel(title: "Sleeps", trailing: .value("1,904", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Resting heart rate", trailing: .value("2,210 days", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Variability", trailing: .value("1,860 nights", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Workouts", trailing: .value("just started", NoopHTMLColor.faint), padding: 12)
                    ])
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button { navigation.replace(with: .importHistory) } label: {
                        Text("Stop")
                            .font(NoopHTMLFont.sans(13.5, weight: .medium))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(maxWidth: .infinity)
                            .frame(height: 47)
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Text("Stopping keeps what has been written already. Nothing here leaves the phone — there is no server to send it to.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var readingBar: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            let fraction = Self.readFraction(from: navigation.importStartedAt, at: timeline.date)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 6).fill(Self.blush).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 12)
        }
    }

    /// A read walks from the handoff's 41% toward done; the figure and the bar both read it.
    private static func readFraction(from started: Date?, at now: Date) -> Double {
        guard let started else { return 0.41 }
        return min(0.92, 0.41 + now.timeIntervalSince(started) / 60)
    }

    // The importers report nothing until they finish: no fraction, no running counts, no cancel. The
    // live read therefore draws the same frame with what is known — the file, its size, and an honest
    // "not yet" — rather than a percentage or counts it would have to make up.
    private var liveReading: some View {
        let current: NoopDataFlow.Reading? = { if case .reading(let r) = flow.phase { return r }; return nil }()
        return NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 18) {
                NoopScreenHeader(current.map { ($0.fileName as NSString).deletingPathExtension } ?? "No file", eyebrow: "Reading")
                    .lineLimit(1)
                    .padding(.bottom, -18)

                VStack(alignment: .leading, spacing: 13) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\u{2014}")
                            .font(NoopHTMLFont.outfit200(44))
                            .tracking(-1.76)
                            .foregroundStyle(NoopHTMLColor.ink)
                        Spacer(minLength: 8)
                        if let current {
                            Text(current.fileSize.map { "\(current.fileName) \u{00B7} \(NoopDataFormat.bytes($0))" } ?? current.fileName)
                                .font(.system(size: 11.5, design: .monospaced))
                                .foregroundStyle(NoopHTMLColor.faint)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .frame(height: 44)

                    liveReadingBar(running: current != nil)

                    Text(current == nil
                         ? "No read is running. Choose a file from the drop target to start one."
                         : "Reading it locally and writing only records the importer can identify. Nothing leaves this phone.")
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }

                section("Found so far") {
                    rowsCard([
                        RowModel(title: "Counts arrive when the read finishes", trailing: .value("\u{2014}", NoopHTMLColor.faint), padding: 12)
                    ])
                }

                VStack(alignment: .leading, spacing: 10) {
                    if current == nil {
                        Button { navigation.replace(with: .importHistory) } label: {
                            Text("Choose a file")
                                .font(NoopHTMLFont.sans(13.5, weight: .medium))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                                .frame(maxWidth: .infinity)
                                .frame(height: 47)
                                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                    Text("A read cannot be stopped once it has started. Nothing here leaves the phone \u{2014} there is no server to send it to.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// No fraction exists, so the fill does not claim one: a short segment travels the track while
    /// the importer is working, and the track sits empty when nothing is.
    private func liveReadingBar(running: Bool) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !running)) { timeline in
            GeometryReader { proxy in
                let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
                let segment = proxy.size.width * 0.28
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.06))
                    if running {
                        RoundedRectangle(cornerRadius: 6).fill(Self.blush)
                            .frame(width: segment)
                            .offset(x: (proxy.size.width + segment) * t - segment)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 12)
        }
    }

    // MARK: 3 · What was written

    private var imported: some View {
        if demo { return AnyView(demoImported) }
        if case .imported(let written) = flow.phase { return AnyView(liveImported(written)) }
        return AnyView(noResult(eyebrow: "Imported", title: "Nothing has been imported"))
    }

    private var demoImported: some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 18) {
                NoopScreenHeader("Seven years, in", eyebrow: "Imported · WHOOP 5.0 export")
                    .padding(.bottom, -18)

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("2,547")
                                .font(NoopHTMLFont.outfit200(44))
                                .tracking(-1.76)
                                .monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("days")
                                .font(NoopHTMLFont.sans(14))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        Text("12 Feb 2019 — 28 Aug 2026")
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(Self.dim)
                    }
                    Spacer(minLength: 8)
                    ZStack {
                        Circle().fill(Self.blush.opacity(0.13))
                            .overlay(Circle().strokeBorder(Self.blush.opacity(0.3), lineWidth: 0.5))
                        NoopCanonicalGlyph(name: .check, size: 16, color: Self.blush)
                    }
                    .frame(width: 35, height: 35)
                    .padding(.top, 10)
                }

                section(
                    "By category",
                    note: "Only what the export carried was written. What it did not carry stays blank rather than becoming a zero — a missing night and a bad night should never look alike."
                ) {
                    rowsCard([
                        RowModel(title: "Sleeps", note: "with stages",
                                 trailing: .value("2,491", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Cycles", note: "day boundaries and strain",
                                 trailing: .value("2,540", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Workouts",
                                 trailing: .value("1,208", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Resting heart rate",
                                 trailing: .value("2,547 days", NoopHTMLColor.ink), padding: 12),
                        RowModel(title: "Variability",
                                 trailing: .value("2,533 nights", NoopHTMLColor.ink), padding: 12),
                        // Unknown stays nil, not zero: the title dims and the value is a dash.
                        RowModel(title: "Skin temperature", titleColor: Self.dim, note: "not in a 5.0 export",
                                 trailing: .value("—", NoopHTMLColor.faint), padding: 12),
                        RowModel(title: "Blood oxygen", titleColor: Self.dim, note: "not in a 5.0 export",
                                 trailing: .value("—", NoopHTMLColor.faint), padding: 12)
                    ])
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button { navigation.reset(to: .data) } label: {
                        Text("Done")
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(Self.blushInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Self.blush.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Button { navigation.replace(with: .importHistory) } label: {
                        Text("Import something else")
                            .font(NoopHTMLFont.sans(13.5, weight: .medium))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(maxWidth: .infinity)
                            .frame(height: 47)
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    (
                        Text("Rest and Charge are being recomputed from what came in. Your first fourteen days will carry a ")
                        + Text("building").font(NoopHTMLFont.serif(14, italic: true))
                        + Text(" chip while the baselines catch up.")
                    )
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Self.dim)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: 4 · The wrong file — the one screen that earns amber

    private var rejected: some View {
        if demo { return AnyView(demoRejected) }
        if case .rejected(let refused) = flow.phase { return AnyView(liveRejected(refused)) }
        return AnyView(noResult(eyebrow: "Nothing was written", title: "No file has been refused"))
    }

    private var demoRejected: some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 18) {
                NoopScreenHeader("This one is the raw log", eyebrow: "Nothing was written")
                    .padding(.bottom, -18)

                // Amber is spent here and nowhere else on this surface: the file wants something
                // from the reader. The action below it stays blush, because it is not the alarm.
                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(NoopHTMLColor.warm.opacity(0.14))
                            NoopCanonicalGlyph(name: .file, size: 16, color: NoopHTMLColor.warm)
                        }
                        .frame(width: 30, height: 30)
                        Text("Oura/heartrate.csv")
                            .font(NoopHTMLFont.sans(12.5))
                            .foregroundStyle(NoopHTMLColor.warm)
                    }
                    Text("That is Oura’s raw heart-rate log — one row per reading, with no daily summary Noop can attach to a date. There is nothing wrong with the file; it is the wrong one of the set.")
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24).fill(NoopHTMLColor.warm.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(NoopHTMLColor.warm.opacity(0.26), lineWidth: 0.5))

                section(
                    "Two ways out",
                    note: "The JSON is the better of the two: one file, every category, and Noop can tell it from Fitbit’s and Garmin’s by its keys."
                ) {
                    rowsCard([
                        RowModel(title: "Export as JSON instead",
                                 note: "Oura app → Account → Export Data. One file, every category.",
                                 noteColor: Self.dim, noteSize: 11.5, trailing: .chevron, padding: 14),
                        RowModel(title: "Or hand it the daily CSVs",
                                 note: "sleep, readiness or activity — the summaries, not the logs.",
                                 noteColor: Self.dim, noteSize: 11.5, trailing: .chevron, padding: 14)
                    ])
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button { navigation.replace(with: .importHistory) } label: {
                        Text("Choose another file")
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(Self.blushInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Self.blush.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Text("Your 1,284 stored days are untouched. A rejected file changes nothing — it is read, judged and dropped.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Self.dim)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: 3 and 4, bound to the importer's result

    private func liveImported(_ written: NoopDataFlow.Written) -> some View {
        let summary = written.summary
        let dayCount = summary.countsByCategory["days"] ?? summary.countsByCategory["cycles"]
        let span: String? = {
            guard let first = summary.earliest, let last = summary.latest else { return nil }
            return "\(NoopDataFormat.date(first)) \u{2014} \(NoopDataFormat.date(last))"
        }()
        var rows = summary.countsByCategory
            .sorted { $0.key < $1.key }
            .map { RowModel(title: NoopDataFormat.category($0.key), trailing: .value(NoopDataFormat.count($0.value), NoopHTMLColor.ink), padding: 12) }
        if summary.skippedSpans > 0 {
            rows.append(RowModel(title: "Unreadable stretches", titleColor: Self.dim, note: "skipped, not guessed",
                                 trailing: .value(NoopDataFormat.count(summary.skippedSpans), NoopHTMLColor.faint), padding: 12))
        }
        if rows.isEmpty {
            rows = [RowModel(title: "Records", trailing: .value(NoopDataFormat.count(summary.recordCount), NoopHTMLColor.ink), padding: 12)]
        }
        return NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 18) {
                NoopScreenHeader(NoopDataFormat.headline(summary), eyebrow: "Imported \u{00B7} \(written.source)")
                    .padding(.bottom, -18)

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(NoopDataFormat.count(dayCount ?? summary.recordCount))
                                .font(NoopHTMLFont.outfit200(44))
                                .tracking(-1.76)
                                .monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text(dayCount == nil ? "records" : "days")
                                .font(NoopHTMLFont.sans(14))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        Text(span ?? "The file carried no dates")
                            .font(NoopHTMLFont.sans(12))
                            .monospacedDigit()
                            .foregroundStyle(Self.dim)
                    }
                    Spacer(minLength: 8)
                    ZStack {
                        Circle().fill(Self.blush.opacity(0.13))
                            .overlay(Circle().strokeBorder(Self.blush.opacity(0.3), lineWidth: 0.5))
                        NoopCanonicalGlyph(name: .check, size: 16, color: Self.blush)
                    }
                    .frame(width: 35, height: 35)
                    .padding(.top, 10)
                }

                section(
                    "By category",
                    note: "Only what the export carried was written. What it did not carry stays blank rather than becoming a zero — a missing night and a bad night should never look alike."
                ) {
                    rowsCard(rows)
                }

                resultActions
            }
        }
    }

    private var resultActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                flow.finishFlow()
                navigation.reset(to: .data)
            } label: {
                Text("Done")
                    .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                    .foregroundStyle(Self.blushInk)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(Self.blush.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(NoopHTMLPressStyle())

            Button {
                flow.finishFlow()
                navigation.replace(with: .importHistory)
            } label: {
                Text("Import something else")
                    .font(NoopHTMLFont.sans(13.5, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                    .frame(maxWidth: .infinity)
                    .frame(height: 47)
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
            }
            .buttonStyle(NoopHTMLPressStyle())

            Text("Only measures supported by what the file actually carried can be calculated. Missing inputs stay blank.")
            .font(NoopHTMLFont.sans(11.5))
            .foregroundStyle(Self.dim)
            .lineSpacing(3.5)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func liveRejected(_ refused: NoopDataFlow.Refused) -> some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 18) {
                NoopScreenHeader("This file could not be used", eyebrow: "Nothing was written")
                    .padding(.bottom, -18)

                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(NoopHTMLColor.warm.opacity(0.14))
                            NoopCanonicalGlyph(name: .file, size: 16, color: NoopHTMLColor.warm)
                        }
                        .frame(width: 30, height: 30)
                        Text(refused.fileName)
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundStyle(NoopHTMLColor.warm)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(refused.reason)
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 17)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 24).fill(NoopHTMLColor.warm.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(NoopHTMLColor.warm.opacity(0.26), lineWidth: 0.5))

                // The importers report why a file failed, not which file of a set to send instead, so
                // the specific fixes are not guessed. The reference list is what can honestly be offered.
                section("The way out") {
                    Button { navigation.show(.importCatalog) } label: {
                        rowsCard([
                            RowModel(title: "See what it can read",
                                     note: "Each app, and the export to ask it for.",
                                     noteColor: Self.dim, noteSize: 11.5, trailing: .chevron, padding: 14)
                        ])
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }

                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        flow.finishFlow()
                        navigation.replace(with: .importHistory)
                    } label: {
                        Text("Choose another file")
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(Self.blushInk)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Self.blush.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Text(untouchedLine)
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Self.dim)
                        .lineSpacing(3.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var untouchedLine: String {
        let lead = flow.stored.map { "Your \(NoopDataFormat.count($0.days)) stored days are untouched." } ?? "What is stored is untouched."
        return lead + " A rejected file changes nothing — it is read, judged and dropped."
    }

    /// A result route reached with no result behind it (a relaunch, or a direct route) says so.
    private func noResult(eyebrow: String, title: String) -> some View {
        NoopScreen(topInset: 56, horizontalInset: 18) {
            VStack(alignment: .leading, spacing: 18) {
                NoopScreenHeader(title, eyebrow: eyebrow)
                    .padding(.bottom, -18)
                Text("There is no finished read on this launch to show. Results are not kept once you leave them.")
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                resultActions
            }
        }
    }

    // MARK: The surface's vocabulary
    //
    // A section is a 10/600 label ABOVE its card and an optional note BELOW it — never inside.

    private func section<Content: View>(
        _ title: String,
        note: String? = nil,
        noteColor: Color = NoopHTMLColor.faint,
        noteView: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            NoopSectionLabel(title, color: Self.dim)
            content()
            if let noteView {
                noteView
            } else if let note {
                Text(note)
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(noteColor)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, -1)
            }
        }
    }

    private enum RowTrailing {
        case none
        case chevron
        case value(String, Color)
        case glyph(NoopCanonicalGlyphName, Color, CGFloat)
    }

    private struct RowModel {
        var id: String = ""
        var title: String
        var titleColor: Color = NoopHTMLColor.inkSoft
        var note: String = ""
        var noteColor: Color = NoopHTMLColor.faint
        var noteSize: CGFloat = 11
        var leading: NoopCanonicalGlyphName? = nil
        var trailing: RowTrailing = .none
        var padding: CGFloat = 12
    }

    /// The handoff's list card: padded 4/16, one hairline between rows and none after the last.
    private func rowsCard(_ rows: [RowModel], onTap: ((String) -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if let onTap {
                    Button { onTap(row.id) } label: { listRow(row).contentShape(Rectangle()) }
                        .buttonStyle(NoopHTMLPressStyle())
                        .disabled(flow.backupBusy)
                } else {
                    listRow(row)
                }
                if index < rows.count - 1 {
                    Rectangle()
                        .fill(NoopHTMLColor.border)
                        .frame(height: 0.5)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22).fill(NoopHTMLColor.card))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    @ViewBuilder
    private func listRow(_ row: RowModel) -> some View {
        HStack(alignment: row.note.isEmpty ? .firstTextBaseline : .center, spacing: 11) {
            if let leading = row.leading {
                NoopCanonicalGlyph(name: leading, size: 18, color: Self.blush)
                    .frame(width: 20)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(NoopHTMLFont.sans(13))
                    .foregroundStyle(row.titleColor)
                if !row.note.isEmpty {
                    Text(row.note)
                        .font(NoopHTMLFont.sans(row.noteSize))
                        .foregroundStyle(row.noteColor)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            switch row.trailing {
            case .none:
                EmptyView()
            case .chevron:
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
            case let .value(text, color):
                Text(text)
                    .font(NoopHTMLFont.sans(12.5, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(color)
            case let .glyph(name, color, size):
                NoopCanonicalGlyph(name: name, size: size, color: color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, row.padding)
    }
}

// MARK: - The twelve, one tap down

struct NoopImportCatalogSheet: View {
    @ObservedObject var navigation: NoopNavigation

    private static let groups: [(String, [(String, String)])] = [
        ("Wearables · six", [
            ("WHOOP", ".zip or folder — the four CSVs; 4.0, 5.0 and MG. Biomarker export too."),
            ("Apple Health", "export.zip, export.xml or a folder. Streamed and aggregated on-device."),
            ("Oura", "Account → Export Data JSON, or the per-category daily CSVs."),
            ("Fitbit", "Google Takeout → Fitbit → JSON."),
            ("Garmin", "Connect → Export Your Data, the GDPR .zip."),
            ("Xiaomi / Mi Band", "The Mi Fitness sandbox folder, a .zip of it, or the bare user_id.db.")
        ]),
        ("Files · six", [
            ("A single workout", "GPX, TCX or FIT."),
            ("Nutrition", "Daily CSV from Cronometer or MacroFactor."),
            ("Lab markers", "CSV."),
            ("A lab report", "As text."),
            ("Lifting", "A strength-training log."),
            ("The strap", "Live over Bluetooth — the one that is not a file.")
        ])
    ]

    var body: some View {
        NoopBottomSheet(title: "What it can read", dismiss: navigation.dismissOverlay, showsDone: true) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(Self.groups.enumerated()), id: \.offset) { _, group in
                    VStack(alignment: .leading, spacing: 11) {
                        NoopSectionLabel(group.0, color: Color(hex: 0x8B958F))
                        ForEach(Array(group.1.enumerated()), id: \.offset) { index, item in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.0)
                                    .font(NoopHTMLFont.sans(13))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                                Text(item.1)
                                    .font(NoopHTMLFont.sans(11.5))
                                    .foregroundStyle(Color(hex: 0x8B958F))
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if index < group.1.count - 1 {
                                Divider().overlay(NoopHTMLColor.border)
                            }
                        }
                    }
                }
                Text("Oura, Fitbit and Garmin share one importer and are told apart by JSON key shape. That is why the screen shows a summary and this list sits behind a chevron: it is documentation, not a control.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 8)
            }
        }
    }
}
#endif
