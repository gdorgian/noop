import SwiftUI
import Charts
import StrandAnalytics
import WhoopStore

/// A logged or detected session, opened from Fitness (23 Oct 2026). What the strap saw — duration, heart
/// rate, effort, a heart-rate line over the zone bands and the time in each zone — and the activity it
/// was. A detected session asks first; every answer becomes a labelled session the personal model learns
/// from, so the choices are, over time, the wearer's own activities ranked by how much this looks like them.
struct NoopActivityConfirmSheet: View {
    let row: WorkoutRow
    /// Opened straight after the session was saved: the finish ring closes once around its icon.
    var justFinished = false
    var onDone: () -> Void = {}

    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var suggestions: [PersonalActivityModel.Suggestion] = []
    @State private var changing = false
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var working = false
    /// The wearer's own 1–10 read of the session, when one was given.
    @State private var feel: Double?
    @State private var rating = 6.0
    @State private var ratingOpen = false
    @State private var route: (points: [RouteMath.LatLng], meters: Double, splits: [RouteSplits.Split])?
    @State private var compare: (count: Int, lines: [NoopCompareCard.Line])?

    /// Common answers after the learned ones, so a first-ever detection still has one-tap choices.
    static let common = ["Strength", "Running", "Walking", "Cycling", "Swimming", "HIIT", "Yoga", "Dancing",
                         "Pilates", "Core training"]

    private var detected: Bool { WorkoutSource.classify(row.source) == .detected }
    /// Imported from Apple Health, a file or another app: shown, never changed here.
    private var imported: Bool {
        let kind = WorkoutSource.classify(row.source)
        return kind != .detected && kind != .manual
    }
    private var unnamed: Bool { row.sport.isEmpty || row.sport.lowercased() == "detected" }
    private var title: String { unnamed ? "Activity" : row.sport }

    private var choices: [String] {
        var out: [String] = []
        func add(_ s: String) { if !out.contains(where: { $0.caseInsensitiveCompare(s) == .orderedSame }) { out.append(s) } }
        suggestions.prefix(3).forEach { add($0.sport) }
        if !unnamed { add(row.sport) }
        Self.common.forEach(add)
        return Array(out.prefix(9))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                NoopSessionHero(symbol: NoopFitnessCardioLive.symbol(for: row.sport),
                                kind: detected ? "Detected activity" : kindLine, title: title, when: when,
                                source: detected ? "Noop Aura · detected from heart rate" : imported ? importedSource : "Noop Aura",
                                badge: detected ? "unconfirmed" : nil,
                                tint: accent, ink: isStrength ? NoopHTMLColor.voltInk : NoopHTMLColor.blueInk,
                                celebrate: justFinished, share: detected ? nil : shareContent)
                if detected || changing { picker } else if !imported { changeRow }
                NoopSessionHeading(title: "Workout details")
                if let strain = row.strain, strain > 0 {
                    let e = NoopSessionEffort.describe(strain)
                    NoopSessionRingRow(value: e.value, fraction: e.fraction, title: "Effort", line: e.line)
                }
                if !detected && !imported { feelRow }
                NoopSessionFigures(items: figures)
                if let compare, !compare.lines.isEmpty {
                    NoopCompareCard(sport: row.sport, count: compare.count, lines: compare.lines)
                        .transition(.opacity)
                }
                if let route {
                    NoopRouteCard(points: route.points, distanceM: route.meters).transition(.opacity)
                    if route.splits.count >= 2 { NoopSplitsCard(splits: route.splits).transition(.opacity) }
                }
                NoopSessionHeart(start: row.startTs, end: row.endTs, source: row.source)
                if imported {
                    Text("Imported, so it is changed where it came from. The heart rate and zones are the strap's for the same window.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    actions
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .task {
            suggestions = await repo.personalActivitySuggestions(start: row.startTs, end: row.endTs)
        }
        .task {
            guard let store = await repo.storeHandle() else { return }
            feel = (try? await store.workoutFeel(deviceId: repo.deviceId, startTs: row.startTs))?.rating
        }
        .task(id: "\(row.startTs)|\(row.sport)") { await loadExtras() }
        .sheet(isPresented: $ratingOpen) {
            NoopLiftEffortSheet(rating: $rating, cardio: true) {
                let value = rating.rounded()
                ratingOpen = false
                withAnimation(NoopMotion.swap) { feel = value }
                Task { await NoopCardioFeel.save(value, startTs: row.startTs, repo: repo) }
            }
            .noopSheet()
        }
        .confirmationDialog(detected ? "Delete this detected activity?" : "Delete this session?",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    await repo.deleteWorkout(row)
                    await finish()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text(detected ? "It will not be detected again." : "This removes it from your record.") }
        .sheet(isPresented: $editing) {
            NoopSessionEditSheet(row: row, choices: choices) { edited in
                Task {
                    await repo.saveManualWorkout(edited, replacing: row)
                    await model.intelligence.analyzeRecent()
                    await finish()
                }
            }
            .noopSheet()
        }
        .sensoryFeedback(.success, trigger: working)
    }

    private var picker: some View {
        NoopHTMLCard(radius: 20, padding: 16, tint: NoopHTMLColor.volt) {
            VStack(alignment: .leading, spacing: 12) {
                Text(detected ? "What was it?" : "Change activity")
                    .font(NoopHTMLFont.sans(NoopType.body, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Text(detected
                     ? "Tap what you did to confirm it. Each answer teaches Noop how your sessions look."
                     : suggestions.isEmpty
                     ? "Pick what you did. Each answer teaches Noop how your sessions look."
                     : "Ranked by how much this looks like your past sessions.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                    .fixedSize(horizontal: false, vertical: true)
                // The best guess as one tap: confirming it is the usual answer.
                if detected, let top = suggestions.first?.sport {
                    NoopActionButton(title: "Confirm \(top)", systemImage: "checkmark") { pick(top) }
                }
                NoopFlowLayout(spacing: 8) {
                    ForEach(choices, id: \.self) { item in chip(item) }
                }
            }
        }
        .disabled(working)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func chip(_ item: String) -> some View {
        let top = item.caseInsensitiveCompare(suggestions.first?.sport ?? "") == .orderedSame
        let current = !unnamed && item.caseInsensitiveCompare(row.sport) == .orderedSame
        let lit = detected ? top : current
        return NoopChip(title: item, systemImage: NoopFitnessCardioLive.symbol(for: item), isOn: lit) { pick(item) }
    }

    private var changeRow: some View {
        Button { withAnimation(NoopMotion.swap) { changing = true } } label: {
            HStack {
                Text("Activity").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                Spacer()
                Text("Change").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(accent)
            }
            .padding(.horizontal, 16).frame(minHeight: 48)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var feelRow: some View {
        Button {
            rating = feel ?? 6
            ratingOpen = true
        } label: {
            if let feel {
                let v = Int(feel)
                NoopSessionRingRow(value: "\(v)", fraction: feel / 10, title: "How it felt",
                                   line: "\(NoopLiftEffortSheet.cardioWord(v)) · your own read, out of 10",
                                   colors: [NoopHTMLColor.blueLight, feel < 4 ? NoopHTMLColor.blueLight : feel < 7 ? NoopHTMLColor.warm
                                            : feel < 9 ? NoopHTMLColor.amber : NoopHTMLColor.red], chevron: true)
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "gauge.with.dots.needle.67percent").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueLight)
                        .frame(width: 40, height: 40).background(NoopHTMLColor.blueLight.opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("How hard was it?").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                        Text("Rate it 1–10, beside what the strap measured").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                    }
                    Spacer(minLength: 0)
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                }
                .padding(14)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var shareContent: NoopShareContent {
        var figures: [(value: String, label: String)] = [(NoopFitnessHome.duration(row.durationS ?? Double(row.endTs - row.startTs)), "time")]
        if let d = row.distanceM, d > 100 { figures.append((NoopCardioGoalText.km(d), "km")) }
        if let hr = row.avgHr { figures.append(("\(hr)", "avg bpm")) }
        if let strain = row.strain, strain > 0 { figures.append((String(format: "%.1f", strain), "Effort")) }
        else if let kcal = row.energyKcal, kcal > 0 { figures.append(("\(Int(kcal.rounded()))", "kcal")) }
        return NoopShareContent(symbol: NoopFitnessCardioLive.symbol(for: row.sport), tint: accent,
                                ink: isStrength ? NoopHTMLColor.voltInk : NoopHTMLColor.blueInk,
                                kind: kindLine, title: title, when: when, figures: figures,
                                route: route?.points ?? [])
    }

    /// Weights are green across Fitness; cardio and every other sport are Aura blue.
    private var isStrength: Bool { kindLine == "Strength training" }
    private var accent: Color { isStrength ? NoopHTMLColor.volt : NoopHTMLColor.blueLight }

    private var kindLine: String {
        let t = row.sport.lowercased()
        if t.contains("strength") || t.contains("lift") || t.contains("weight") { return "Strength training" }
        if t.contains("run") || t.contains("walk") || t.contains("cycl") || t.contains("swim") || t.contains("row") { return "Cardio" }
        return "Activity"
    }

    private var figures: [NoopSessionFigures.Item] {
        var items: [NoopSessionFigures.Item] = [.init(label: "Duration", value: NoopFitnessHome.duration(row.durationS ?? Double(row.endTs - row.startTs)))]
        if let hr = row.avgHr { items.append(.init(label: "Avg HR", value: "\(hr)", unit: "bpm")) }
        if let hr = row.maxHr { items.append(.init(label: "Peak HR", value: "\(hr)", unit: "bpm")) }
        if let kcal = row.energyKcal, kcal > 0 { items.append(.init(label: "Energy", value: "\(Int(kcal.rounded()))", unit: "kcal")) }
        if let d = row.distanceM, d > 0 { items.append(.init(label: "Distance", value: String(format: "%.2f", d / 1000), unit: "km")) }
        return items
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button { editing = true } label: {
                Text("Edit time or activity").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .background(Color.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(NoopHTMLPressStyle())
            Button(role: .destructive) { confirmDelete = true } label: {
                Text(detected ? "Not an activity — delete" : "Delete session").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 46)
            }
            .foregroundStyle(NoopHTMLColor.red)
            .buttonStyle(NoopPlainHitStyle())
        }
    }

    private var importedSource: String {
        switch WorkoutSource.classify(row.source) {
        case .apple: "Apple Health"
        case .activityFile: "Activity file"
        case .lifting: "Imported lifting"
        case .whoop: "WHOOP import"
        default: "Imported"
        }
    }

    private var when: String {
        let start = Date(timeIntervalSince1970: TimeInterval(row.startTs))
        let end = Date(timeIntervalSince1970: TimeInterval(row.endTs))
        let day = Calendar.current.isDateInToday(start) ? "Today"
            : Calendar.current.isDateInYesterday(start) ? "Yesterday"
            : start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(day), \(AppClock.hourMinuteFormatter().string(from: start))–\(AppClock.hourMinuteFormatter().string(from: end))"
    }

    private func pick(_ sport: String) {
        guard !working else { return }
        if !detected, sport.caseInsensitiveCompare(row.sport) == .orderedSame {
            withAnimation(NoopMotion.swap) { changing = false }
            return
        }
        working = true
        Task {
            if detected {
                await repo.relabelDetected(row, sport: sport)
            } else {
                let renamed = WorkoutRow(startTs: row.startTs, endTs: row.endTs, sport: sport, source: row.source,
                                         durationS: row.durationS, energyKcal: row.energyKcal, avgHr: row.avgHr,
                                         maxHr: row.maxHr, strain: row.strain, distanceM: row.distanceM,
                                         zonesJSON: row.zonesJSON, notes: row.notes, steps: row.steps)
                await repo.saveManualWorkout(renamed, replacing: row)
            }
            await model.intelligence.analyzeRecent()
            await finish()
        }
    }

    /// The route and its splits, from the phone's own route store, and the last five sessions of this sport.
    @MainActor private func loadExtras() async {
        let key = RouteStore.key(startTs: row.startTs, sport: row.sport)
        if let stored = RouteStore.load(startTs: row.startTs, sport: row.sport) {
            let line = RouteMath.decode(stored.polyline)
            if line.count >= 2 {
                let points = RoutePointStore.load(for: key) ?? []
                withAnimation(NoopMotion.swap) {
                    route = (line, stored.distanceM, RouteSplits.splits(points))
                }
            }
        }
        guard !detected, !unnamed else { return }
        let recent = (await repo.workoutRows(days: 180))
            .filter { $0.sport.caseInsensitiveCompare(row.sport) == .orderedSame && $0.startTs < row.startTs }
            .sorted { $0.startTs > $1.startTs }
            .prefix(5)
        let lines = NoopCompareCard.lines(for: row, recent: Array(recent))
        withAnimation(NoopMotion.swap) { compare = (recent.count, lines) }
    }

    @MainActor private func finish() async {
        NoopFitnessModel.markChanged()
        await repo.refresh()
        onDone()
        dismiss()
    }
}

/// Noop's own editor for a session's activity and times. Heart rate, effort and energy are not typed in:
/// the strap's samples fill them for whatever window is saved.
struct NoopSessionEditSheet: View {
    let row: WorkoutRow
    let choices: [String]
    let onSave: (WorkoutRow) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var sport: String
    @State private var start: Date
    @State private var end: Date

    init(row: WorkoutRow, choices: [String], onSave: @escaping (WorkoutRow) -> Void) {
        self.row = row
        self.choices = choices
        self.onSave = onSave
        let named = !(row.sport.isEmpty || row.sport.lowercased() == "detected")
        _sport = State(initialValue: named ? row.sport : "")
        _start = State(initialValue: Date(timeIntervalSince1970: TimeInterval(row.startTs)))
        _end = State(initialValue: Date(timeIntervalSince1970: TimeInterval(row.endTs)))
    }

    private var timesChanged: Bool {
        Int(start.timeIntervalSince1970) != row.startTs || Int(end.timeIntervalSince1970) != row.endTs
    }

    /// The row to save, or nil while the input cannot make an honest one.
    private var draft: WorkoutRow? {
        guard let built = WorkoutSource.buildManualRowFromSpan(
            start: start, end: end, sport: sport,
            avgHr: timesChanged ? nil : row.avgHr, energyKcal: timesChanged ? nil : row.energyKcal,
            distanceM: row.distanceM) else { return nil }
        return built
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Edit session").font(NoopHTMLFont.sheetTitle).foregroundStyle(NoopHTMLColor.ink)

                VStack(alignment: .leading, spacing: 10) {
                    NoopSectionLabel("Activity")
                    TextField("What did you do?", text: $sport)
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .padding(.horizontal, 14).frame(minHeight: 48)
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    NoopFlowLayout(spacing: 8) {
                        ForEach(choices, id: \.self) { item in
                            let on = item.caseInsensitiveCompare(sport) == .orderedSame
                            NoopChip(title: item, isOn: on) { sport = item }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    timeRow("Started", $start)
                    Divider().overlay(NoopHTMLColor.border)
                    timeRow("Ended", $end)
                }
                .padding(.horizontal, 14)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack {
                    Text("Duration").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                    Spacer()
                    Text(end > start ? NoopFitnessHome.duration(end.timeIntervalSince(start)) : "—")
                        .font(NoopHTMLFont.outfit(NoopType.title3)).foregroundStyle(NoopHTMLColor.ink).monospacedDigit()
                }
                Text("Heart rate, effort and energy come from the strap for the window you save.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    guard let draft else { return }
                    onSave(draft)
                    dismiss()
                } label: {
                    Text("Save").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .foregroundStyle(NoopHTMLColor.voltInk)
                        .background(NoopHTMLColor.volt.opacity(draft == nil ? 0.35 : 1), in: Capsule())
                }
                .buttonStyle(NoopHTMLPressStyle())
                .disabled(draft == nil)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
    }

    private func timeRow(_ label: String, _ date: Binding<Date>) -> some View {
        HStack {
            Text(label).font(NoopHTMLFont.sans(NoopType.subhead)).foregroundStyle(NoopHTMLColor.ink)
            Spacer()
            DatePicker("", selection: date, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .tint(NoopHTMLColor.volt)
        }
        .frame(minHeight: 52)
    }
}

/// Saves the wearer's rating of a cardio session beside its workout row.
enum NoopCardioFeel {
    @MainActor static func save(_ rating: Double, startTs: Int, repo: Repository) async {
        guard let store = await repo.storeHandle() else { return }
        try? await store.upsertWorkoutFeel(.init(deviceId: repo.deviceId, startTs: startTs, rating: rating,
                                                 ts: Int(Date().timeIntervalSince1970)))
    }
}

/// What a finished cardio session opens on, the way a finished lift does: "How hard was that?" first,
/// then the session as it was saved. The workout is already saved when this appears; the rating rides beside it.
struct NoopCardioFinishSheet: View {
    let row: WorkoutRow
    @EnvironmentObject private var repo: Repository
    @State private var rating = 6.0
    @State private var rated = false

    var body: some View {
        ZStack {
            if rated {
                NoopActivityConfirmSheet(row: row, justFinished: true)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                NoopLiftEffortSheet(rating: $rating, cardio: true) {
                    let value = rating.rounded()
                    Task {
                        await NoopCardioFeel.save(value, startTs: row.startTs, repo: repo)
                        withAnimation(NoopMotion.swap) { rated = true }
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: rated)
    }
}
