#if os(iOS)
import SwiftUI
import StrandFitness
import StrandAnalytics
import WhoopStore

/// A month, or a year, in training: what was done, how it compares with the period before, the muscles
/// and exercises it went to, and every record it set — with a card to share.
///
/// Built from the same history the Fitness page reads (sessions of every kind, working sets) plus each
/// exercise's whole record, so a record counts when it was set (`LiftRecords.events`).
struct NoopFitnessReportScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @EnvironmentObject private var repo: Repository
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    @State private var year = false
    @State private var start: Date = NoopFitnessReport.monthStart(Date())
    @State private var records: [NoopFitnessReport.Record] = []
    @State private var shareImage: Image?

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }
    private var cal: Calendar { Calendar.current }
    private var period: DateInterval {
        cal.dateInterval(of: year ? .year : .month, for: start) ?? DateInterval(start: start, duration: 86_400 * 30)
    }
    private var previous: DateInterval {
        let back = cal.date(byAdding: year ? .year : .month, value: -1, to: period.start) ?? period.start
        return cal.dateInterval(of: year ? .year : .month, for: back) ?? period
    }

    var body: some View {
        NoopFitnessPage(navigation: navigation, title: year ? "Year in review" : "Month in review") {
            if let h = fitness.snapshot?.history {
                content(h)
            } else {
                Text("Reading your training…").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .onAppear {
            if let asked = navigation.fitnessReportStart { start = asked; navigation.fitnessReportStart = nil }
        }
        // Keyed on the history too: opened straight onto this page, the history arrives after it appears.
        .task(id: "\(period.start.timeIntervalSince1970)-\(repo.refreshSeq)-\(fitness.snapshot?.history.now.timeIntervalSince1970 ?? 0)") {
            await loadRecords()
        }
    }

    @ViewBuilder
    private func content(_ h: NoopFitnessHistory) -> some View {
        let now = NoopFitnessReport.summary(h, period)
        let before = NoopFitnessReport.summary(h, previous)
        VStack(alignment: .leading, spacing: 20) {
            NoopTabs(options: [("Month", false), ("Year", true)], selection: $year)
            HStack {
                step(.left) { start = cal.date(byAdding: year ? .year : .month, value: -1, to: period.start) ?? start }
                Text(title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    .frame(maxWidth: .infinity)
                step(.right, enabled: period.end <= Date()) {
                    start = cal.date(byAdding: year ? .year : .month, value: 1, to: period.start) ?? start
                }
            }
            if now.workouts == 0 {
                NoopExerciseEmpty(text: "No workouts in \(title). Pick another \(year ? "year" : "month") with the arrows.")
            } else {
                hero(now, before)
                days(h)
                muscles(h)
                exercises(h)
                recordsSection
                shareButton(now)
            }
        }
    }

    private var title: String {
        year ? period.start.formatted(.dateTime.year()) : period.start.formatted(.dateTime.month(.wide).year())
    }

    // MARK: Hero

    private func hero(_ s: NoopFitnessReport.Summary, _ b: NoopFitnessReport.Summary) -> some View {
        NoopFitnessReportCard(title: title, summary: s, previous: b, records: records.count, units: units)
    }

    // MARK: Training days

    @ViewBuilder
    private func days(_ h: NoopFitnessHistory) -> some View {
        let sessions = h.sessions.filter { period.contains($0.start) }
        VStack(alignment: .leading, spacing: 10) {
            NoopSectionLabel(year ? "Workouts by month" : "Training days")
            if year {
                let counts = (0..<12).map { m -> Int in
                    let monthStart = cal.date(byAdding: .month, value: m, to: period.start) ?? period.start
                    return sessions.filter { cal.isDate($0.start, equalTo: monthStart, toGranularity: .month) }.count
                }
                let top = max(1, counts.max() ?? 1)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<12, id: \.self) { m in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(NoopHTMLColor.volt.opacity(counts[m] == 0 ? 0.12 : 0.35 + 0.6 * Double(counts[m]) / Double(top)))
                                .frame(height: max(4, 90 * CGFloat(counts[m]) / CGFloat(top)))
                            Text(cal.veryShortMonthSymbols[(cal.component(.month, from: period.start) - 1 + m) % 12])
                                .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 112, alignment: .bottom)
                .padding(16)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                let trained = Set(sessions.map { cal.startOfDay(for: $0.start) })
                let count = cal.range(of: .day, in: .month, for: period.start)?.count ?? 30
                let lead = (cal.component(.weekday, from: period.start) - cal.firstWeekday + 7) % 7
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                    ForEach(0..<(lead + count), id: \.self) { i in
                        if i < lead {
                            Color.clear.frame(height: 30)
                        } else {
                            let day = cal.date(byAdding: .day, value: i - lead, to: period.start) ?? period.start
                            let on = trained.contains(day)
                            Text("\(i - lead + 1)")
                                .font(NoopHTMLFont.sans(NoopType.caption, weight: on ? .semibold : .regular))
                                .foregroundStyle(on ? NoopHTMLColor.voltInk : NoopHTMLColor.muted)
                                .frame(maxWidth: .infinity).frame(height: 30)
                                .background(on ? NoopHTMLColor.volt : Color.white.opacity(0.04), in: Circle())
                        }
                    }
                }
                .padding(14)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    // MARK: Muscles and exercises

    @ViewBuilder
    private func muscles(_ h: NoopFitnessHistory) -> some View {
        let sets = h.scoredSets.map(\.set).filter { period.contains($0.date) }
        let groups = StrengthTotals.setsPerGroup(sets).sorted { $0.value > $1.value }.prefix(6)
        if !groups.isEmpty {
            let top = groups.first?.value ?? 1
            VStack(alignment: .leading, spacing: 10) {
                NoopSectionLabel("Where the sets went")
                VStack(spacing: 10) {
                    ForEach(Array(groups), id: \.key) { group, n in
                        HStack(spacing: 10) {
                            Text(group.title).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                                .frame(width: 96, alignment: .leading)
                            GeometryReader { geo in
                                Capsule().fill(NoopHTMLColor.blush.opacity(0.85))
                                    .frame(width: max(6, geo.size.width * CGFloat(n / top)))
                            }
                            .frame(height: 10)
                            Text(n == n.rounded() ? "\(Int(n))" : String(format: "%.1f", n))
                                .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.copy).frame(width: 34, alignment: .trailing)
                        }
                    }
                }
                .padding(16)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func exercises(_ h: NoopFitnessHistory) -> some View {
        let sets = h.scoredSets.map(\.set).filter { period.contains($0.date) }
        let byName = Dictionary(grouping: sets, by: \.exerciseId).map { (name: $0.key, sets: $0.value) }
            .sorted { $0.sets.count > $1.sets.count }.prefix(5)
        if !byName.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                NoopSectionLabel("Most trained")
                VStack(spacing: 0) {
                    ForEach(Array(byName.enumerated()), id: \.element.name) { i, e in
                        let best = e.sets.max { ($0.weightKg ?? 0, $0.reps ?? 0) < ($1.weightKg ?? 0, $1.reps ?? 0) }
                        HStack {
                            Text("\(i + 1)").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.muted).frame(width: 22, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.name).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                Text("\(e.sets.count) sets · best \(NoopExerciseFormat.set(best?.weightKg, best?.reps, units))")
                                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        if i < byName.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 4)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    // MARK: Records

    @ViewBuilder
    private var recordsSection: some View {
        if !records.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                NoopSectionLabel("Records set")
                VStack(spacing: 8) {
                    ForEach(records.prefix(12)) { r in
                        HStack(spacing: 12) {
                            Image(systemName: NoopExerciseFormat.symbol(r.kind)).font(.system(size: 12, weight: .bold))
                                .foregroundStyle(NoopExerciseFormat.tint(r.kind))
                                .frame(width: 30, height: 30).background(NoopExerciseFormat.tint(r.kind).opacity(0.14), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.exercise).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                Text("\(NoopExerciseFormat.title(r.kind)) · \(NoopExerciseFormat.date(r.ts))")
                                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                            }
                            Spacer()
                            Text(r.value).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).monospacedDigit()
                                .foregroundStyle(NoopHTMLColor.ink)
                        }
                    }
                    if records.count > 12 {
                        Text("and \(records.count - 12) more").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
                    }
                }
                .padding(16)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    // MARK: Share

    private func shareButton(_ s: NoopFitnessReport.Summary) -> some View {
        let card = NoopFitnessReportCard(title: title, summary: s, previous: nil, records: records.count, units: units, forSharing: true)
            .frame(width: 390).background(NoopHTMLColor.canvas)
        return Group {
            if let shareImage {
                ShareLink(item: shareImage, preview: SharePreview("\(title) in training", image: shareImage)) {
                    shareLabel
                }
            } else {
                shareLabel.opacity(0.5)
            }
        }
        .task(id: "\(title)-\(s.workouts)-\(records.count)") {
            let renderer = ImageRenderer(content: card)
            renderer.scale = 3
            shareImage = renderer.uiImage.map(Image.init(uiImage:))
        }
    }

    private var shareLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up").font(.system(size: 14, weight: .semibold))
            Text("Share \(year ? "your year" : "your month")").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
        }
        .foregroundStyle(NoopHTMLColor.ink)
        .frame(maxWidth: .infinity).frame(minHeight: 52)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func step(_ d: NoopFixedChevron.Direction, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button { withAnimation(NoopMotion.swap) { action() } } label: {
            NoopFixedChevron(direction: d, color: enabled ? NoopHTMLColor.inkSoft : NoopHTMLColor.chevronDim)
                .frame(width: 44, height: 40)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
    }

    private func loadRecords() async {
        guard let store = await repo.storeHandle(), let h = fitness.snapshot?.history else { return }
        let names = Set(h.scoredSets.map(\.set).filter { period.contains($0.date) }.map(\.exerciseId))
        var out: [NoopFitnessReport.Record] = []
        let from = Int(period.start.timeIntervalSince1970), to = Int(period.end.timeIntervalSince1970)
        for name in names {
            let history = (try? await store.liftExerciseHistory(deviceId: repo.deviceId, exercise: name)) ?? []
            // One line per kind per exercise: the best of that kind in the period, not every step to it.
            var best: [LiftRecords.Kind: LiftRecords.Event] = [:]
            for e in LiftRecords.events(in: history, fromTs: from, toTs: to) { best[e.kind] = e }
            for (kind, e) in best {
                out.append(.init(exercise: name, kind: kind, ts: e.sessionStartTs, value: value(kind, e.set)))
            }
        }
        records = out.sorted { ($0.ts, $0.exercise) > ($1.ts, $1.exercise) }
    }

    private func value(_ kind: LiftRecords.Kind, _ s: LiftSetRow) -> String {
        switch kind {
        case .heaviestWeight: NoopExerciseFormat.kg(s.weightKg ?? 0, units)
        case .bestOneRepMax: NoopExerciseFormat.kg(LiftMetrics.estimatedOneRepMaxKg(weightKg: s.weightKg, reps: s.reps) ?? 0, units)
        case .mostReps: "\(s.reps ?? 0) reps"
        default: NoopExerciseFormat.set(s.weightKg, s.reps, units)
        }
    }
}

/// The period's headline numbers, and how they moved — on the page, and as the image that is shared.
struct NoopFitnessReportCard: View {
    let title: String
    let summary: NoopFitnessReport.Summary
    let previous: NoopFitnessReport.Summary?
    let records: Int
    let units: UnitSystem
    var forSharing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(forSharing ? "NOOP AURA · \(title.uppercased())" : "\(title.uppercased())")
                    .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.2).foregroundStyle(NoopHTMLColor.volt)
                Text("\(summary.workouts) \(summary.workouts == 1 ? "workout" : "workouts")")
                    .font(NoopHTMLFont.outfit(NoopType.title1, weight: .light)).foregroundStyle(NoopHTMLColor.ink)
                Text("\(summary.days) training \(summary.days == 1 ? "day" : "days") · \(NoopFitnessHome.duration(summary.seconds)) active")
                    .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                cell("\(summary.lifts)", "lifts", previous.map { summary.lifts - $0.lifts })
                cell("\(summary.sets)", "working sets", previous.map { summary.sets - $0.sets })
                cell(volume, "volume", nil)
                cell("\(summary.cardio)", "cardio", previous.map { summary.cardio - $0.cardio })
                cell("\(records)", records == 1 ? "record" : "records", nil)
                cell("\(summary.bestStreak)", "week streak", nil)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [NoopHTMLColor.volt.opacity(0.14), NoopHTMLColor.card], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(NoopHTMLColor.volt.opacity(0.22), lineWidth: 0.8))
        .padding(forSharing ? 18 : 0)
    }

    private var volume: String {
        let shown = LiftFormat.display(fromKilograms: summary.volumeKg, system: units)
        return shown >= 100_000 ? "\(LiftFormat.trim((shown / 1000 * 10).rounded() / 10))k" : Int(shown.rounded()).formatted(.number)
    }

    private func cell(_ value: String, _ label: String, _ delta: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(NoopHTMLFont.outfit(NoopType.title3)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                if let delta, delta != 0 {
                    Text("\(delta > 0 ? "+" : "−")\(abs(delta))").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                        .foregroundStyle(delta > 0 ? NoopHTMLColor.green : NoopHTMLColor.muted)
                }
            }
            Text(label == "volume" ? "\(LiftFormat.weightUnit(units)) volume" : label)
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum NoopFitnessReport {
    struct Summary: Equatable {
        var workouts = 0, lifts = 0, cardio = 0, days = 0, sets = 0
        var seconds: Double = 0
        var volumeKg: Double = 0
        var bestStreak = 0
    }

    struct Record: Identifiable, Equatable {
        let exercise: String
        let kind: LiftRecords.Kind
        let ts: Int
        let value: String
        var id: String { "\(exercise)-\(kind.rawValue)" }
    }

    static func monthStart(_ d: Date) -> Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: d)) ?? d
    }

    /// The period's figures, counted the way the Fitness page counts them: every session (short detected
    /// bouts excepted, as for the streak), working sets, and the weight logged.
    static func summary(_ h: NoopFitnessHistory, _ p: DateInterval) -> Summary {
        let cal = Calendar.current
        let sessions = h.sessions.filter { p.contains($0.start) && (!$0.detected || $0.kind == .strength || $0.durationS >= 20 * 60) }
        let sets = h.scoredSets.map(\.set).filter { p.contains($0.date) }
        var s = Summary()
        s.workouts = sessions.count
        s.lifts = sessions.filter { $0.kind == .strength }.count
        s.cardio = s.workouts - s.lifts
        s.days = Set(sessions.map { cal.startOfDay(for: $0.start) }).count
        s.seconds = sessions.reduce(0) { $0 + $1.durationS }
        s.sets = sets.count
        s.volumeKg = sets.reduce(0) { $0 + StrengthTotals.volumeKg($1, bodyMassKg: nil) }
        s.bestStreak = TrainingStreak.reading(sessionDates: sessions.map(\.start), now: min(p.end.addingTimeInterval(-1), Date())).best
        return s
    }
}
#endif
