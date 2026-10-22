#if os(iOS)
import SwiftUI
import Charts
import StrandFitness

// MARK: - Detail screen

/// Every Fitness card opens here. Each page shares one shape: the figure for the period, the figures
/// to switch between, a chart to drag across, the period controls, then what it means and the sessions
/// behind it.
struct NoopFitnessDetailScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel

    var body: some View {
        if let h = fitness.snapshot?.history {
            switch navigation.fitnessMetric {
            case .cardioLoad: NoopFitnessLoadPage(navigation: navigation, history: h, kind: .cardio)
            case .muscularLoad: NoopFitnessLoadPage(navigation: navigation, history: h, kind: .muscular)
            case .activeTime: NoopFitnessActivityPage(navigation: navigation, history: h, start: "time")
            case .activeEnergy: NoopFitnessActivityPage(navigation: navigation, history: h, start: "energy")
            case .sets: NoopFitnessStrengthPage(navigation: navigation, history: h, start: "sets")
            case .volume: NoopFitnessStrengthPage(navigation: navigation, history: h, start: "volume")
            case .vo2: NoopFitnessReadingPage(navigation: navigation, history: h, kind: .vo2)
            case .recovery: NoopFitnessReadingPage(navigation: navigation, history: h, kind: .recovery)
            case .focus: NoopFitnessFocusPage(navigation: navigation, history: h)
            case .zones: NoopFitnessZonesPage(navigation: navigation, history: h)
            }
        } else {
            NoopFitnessPage(navigation: navigation, title: navigation.fitnessMetric.title) { EmptyView() }
        }
    }

    static func focusColor(_ b: CardioFocus.Band) -> Color {
        switch b {
        case .lowAerobic: NoopHTMLColor.blueLight
        case .highAerobic: NoopHTMLColor.warm
        case .anaerobic: NoopHTMLColor.red
        }
    }
}

// MARK: - Formatting

enum NoopFitnessFormat {
    static func duration(_ s: Double) -> String { NoopFitnessHome.duration(s) }
    static func count(_ v: Double) -> String { Int(v.rounded()).formatted() }
    static func kcal(_ v: Double) -> String { "\(Int(v.rounded()).formatted()) kcal" }
    static func kg(_ v: Double) -> String {
        v >= 10_000 ? String(format: "%.1f t", v / 1000) : "\(Int(v.rounded()).formatted()) kg"
    }
    static func km(_ m: Double) -> String { m >= 100_000 ? String(format: "%.0f km", m / 1000) : String(format: "%.1f km", m / 1000) }
    static func bpm(_ v: Double) -> String { "\(Int(v.rounded())) bpm" }
    static func one(_ v: Double) -> String { String(format: "%.1f", v) }

    /// "+12% on the 30 days before (14h 2m)"
    static func comparison(_ now: Double?, _ before: Double?, window: NoopFitnessWindow,
                           format: (Double) -> String) -> String? {
        guard let before else { return nil }
        let span: String = switch window.range {
        case .week: "the 7 days before"
        case .month: "the 30 days before"
        case .quarter: "the 3 months before"
        case .year: "the year before"
        case .ytd: "the same span last year"
        }
        guard let now, before > 0 else { return "\(format(before)) in \(span)" }
        let pct = (now - before) / before * 100
        if abs(pct) < 0.5 { return "Level with \(span) · \(format(before))" }
        return String(format: "%@%.0f%% on %@ · %@", pct > 0 ? "+" : "−", abs(pct), span, format(before))
    }
}

// MARK: - A page built from measures

/// The common body for activity and strength: chips, chart, period, history.
private struct NoopFitnessMeasurePage<Top: View, Bottom: View>: View {
    @ObservedObject var navigation: NoopNavigation
    let title: String
    let now: Date
    let measures: [NoopFitnessMeasure]
    @Binding var selected: String
    @Binding var range: NoopFitnessRange
    @Binding var offset: Int
    var maxOffset: Int
    @ViewBuilder var top: Top
    @ViewBuilder var bottom: (NoopFitnessWindow) -> Bottom
    @State private var selection: Int?
    @State private var running = true

    var body: some View {
        let window = NoopFitnessWindow.make(range, offset: offset, now: now)
        let measure = measures.first { $0.id == selected } ?? measures[0]
        let current = measure.accumulates && running ? measure.running(window, now: now) : measure.perBucket(window)
        let previous = measure.accumulates && running ? measure.running(window.previous, now: now) : []
        let style: NoopFitnessMeasureChart.Style = measure.accumulates ? (running ? .running : .bars) : .line
        let summary = measure.summary(window)
        let values = current.compactMap { $0 }
        let average = style == .running || values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        NoopFitnessPage(navigation: navigation, title: title) {
            VStack(alignment: .leading, spacing: 16) {
                top
                header(window: window, measure: measure, current: current, previous: previous, summary: summary)
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(NoopMotion.swap) { selection = nil } }
                NoopFitnessMeasureChips(items: chips(window), selected: $selected)
                VStack(spacing: 10) {
                    NoopFitnessMeasureChart(window: window, current: current, previous: previous, style: style,
                                            tint: measure.tint, average: average, format: axisFormat(measure),
                                            selection: $selection)
                        .frame(height: 210)
                    HStack {
                        NoopFitnessChartCaption(text: caption(measure, window))
                        if measure.accumulates { NoopFitnessStyleToggle(running: $running) }
                    }
                }
                .padding(16)
                .fitnessCard()
                NoopFitnessRangeBar(range: $range, offset: $offset, maxOffset: maxOffset)
                bottom(window)
            }
        }
        .onChange(of: range) { selection = nil }
        .onChange(of: offset) { selection = nil }
        .onChange(of: selected) { selection = nil }
    }

    @ViewBuilder
    private func header(window: NoopFitnessWindow, measure: NoopFitnessMeasure, current: [Double?],
                        previous: [Double?], summary: Double?) -> some View {
        if let i = selection, window.buckets.indices.contains(i) {
            let v = current[safe: i] ?? nil
            let p = previous[safe: i] ?? nil
            NoopFitnessInstrumentHeader(
                value: v.map(measure.format) ?? "—",
                caption: window.label(i) + (style(measure) == .running ? " · running total" : ""),
                comparison: p.map { "Same point before: \(measure.format($0))" })
        } else {
            NoopFitnessInstrumentHeader(
                value: summary.map(measure.format) ?? "—",
                caption: window.title,
                comparison: NoopFitnessFormat.comparison(summary, measure.summary(window.previous), window: window,
                                                         format: measure.format))
        }
    }

    private func style(_ m: NoopFitnessMeasure) -> NoopFitnessMeasureChart.Style {
        m.accumulates ? (running ? .running : .bars) : .line
    }

    private func chips(_ w: NoopFitnessWindow) -> [NoopFitnessMeasureChips.Item] {
        measures.map { m in
            let now = m.summary(w), before = m.summary(w.previous)
            var trend: (up: Bool, good: Bool)?
            if let a = now, let b = before, abs(a - b) > 0.0001 { trend = (a > b, (a > b) != m.lowerIsBetter) }
            return .init(id: m.id, label: m.label, value: now.map(m.format) ?? "—",
                         previous: before.map(m.format), trend: trend)
        }
    }

    private func caption(_ m: NoopFitnessMeasure, _ w: NoopFitnessWindow) -> String {
        switch style(m) {
        case .running: "Running total by \(w.unitWord), against the period before"
        case .bars: "Total per \(w.unitWord)"
        case .line: m.combine == .max ? "Best per \(w.unitWord)" : m.combine == .latest ? "Reading per \(w.unitWord)" : "Average per \(w.unitWord)"
        }
    }

    private func axisFormat(_ m: NoopFitnessMeasure) -> (Double) -> String {
        switch m.id {
        case "time": { v in v >= 3600 ? String(format: "%.0fh", v / 3600) : String(format: "%.0fm", v / 60) }
        case "distance": { v in String(format: "%.0f", v / 1000) }
        case "volume", "heaviestVolume": { v in v >= 1000 ? String(format: "%.0fk", v / 1000) : String(format: "%.0f", v) }
        default: { v in v >= 1000 ? String(format: "%.1fk", v / 1000) : String(format: "%.0f", v) }
        }
    }
}

// MARK: - Activity

struct NoopFitnessActivityPage: View {
    @ObservedObject var navigation: NoopNavigation
    let history: NoopFitnessHistory
    @State private var selected: String
    @State private var range: NoopFitnessRange = .month
    @State private var offset = 0
    @State private var sport: String?

    init(navigation: NoopNavigation, history: NoopFitnessHistory, start: String) {
        self.navigation = navigation
        self.history = history
        _selected = State(initialValue: start)
    }

    var body: some View {
        let workouts = history.workouts.filter { sport == nil || Self.sportName($0.title) == sport }
        NoopFitnessMeasurePage(
            navigation: navigation, title: sport ?? "All activities", now: history.now, measures: measures(workouts),
            selected: $selected, range: $range, offset: $offset, maxOffset: maxOffset
        ) {
            NoopFitnessFilterChips(options: sports, selected: $sport)
        } bottom: { window in
            NoopFitnessHistoryList(
                sessions: history.sessions.filter { window.contains($0.start) && (sport == nil || Self.sportName($0.title) == sport) },
                navigation: navigation)
        }
    }

    private var maxOffset: Int { range == .ytd || range == .year ? 1 : 12 }

    private var sports: [String] {
        var count: [String: Int] = [:]
        for w in history.workouts { count[Self.sportName(w.title), default: 0] += 1 }
        return count.sorted { $0.value > $1.value }.map(\.key)
    }

    static func sportName(_ raw: String) -> String { WorkoutSource.displaySport(raw) }

    private func measures(_ ws: [NoopFitnessHistory.Workout]) -> [NoopFitnessMeasure] {
        var out: [NoopFitnessMeasure] = [
            .init(id: "time", label: "Active time", combine: .sum, events: ws.map { ($0.start, $0.durationS) },
                  format: NoopFitnessFormat.duration, tint: NoopHTMLColor.blue),
            .init(id: "energy", label: "Active energy", combine: .sum,
                  events: ws.compactMap { w in w.kcal.map { (w.start, $0) } }, format: NoopFitnessFormat.kcal,
                  tint: NoopHTMLColor.amber),
        ]
        if ws.contains(where: { ($0.distanceM ?? 0) > 0 }) {
            out.append(.init(id: "distance", label: "Distance", combine: .sum,
                             events: ws.compactMap { w in w.distanceM.flatMap { $0 > 0 ? (w.start, $0) : nil } },
                             format: NoopFitnessFormat.km, tint: NoopHTMLColor.green))
        }
        out.append(.init(id: "sessions", label: "Sessions", combine: .sum, events: ws.map { ($0.start, 1) },
                         format: NoopFitnessFormat.count, tint: NoopHTMLColor.blueLight))
        out.append(.init(id: "hr", label: "Average heart rate", combine: .mean,
                         events: ws.compactMap { w in w.averageHeartRate.map { (w.start, Double($0)) } },
                         format: NoopFitnessFormat.bpm, tint: NoopHTMLColor.blush))
        if ws.contains(where: { $0.effort != nil }) {
            out.append(.init(id: "effort", label: "Effort", combine: .mean,
                             events: ws.compactMap { w in w.effort.map { (w.start, $0) } },
                             format: NoopFitnessFormat.one, tint: NoopHTMLColor.warm))
        }
        return out
    }
}

// MARK: - Strength

struct NoopFitnessStrengthPage: View {
    @ObservedObject var navigation: NoopNavigation
    let history: NoopFitnessHistory
    @State private var selected: String
    @State private var range: NoopFitnessRange = .month
    @State private var offset = 0
    @State private var exercise: String?

    init(navigation: NoopNavigation, history: NoopFitnessHistory, start: String) {
        self.navigation = navigation
        self.history = history
        _selected = State(initialValue: start)
        _exercise = State(initialValue: navigation.fitnessExercise)
    }

    var body: some View {
        let sets = history.scoredSets.map(\.set).filter { exercise == nil || $0.exerciseId == exercise }
        let ms = measures(sets)
        NoopFitnessMeasurePage(
            navigation: navigation, title: exercise ?? "All muscles", now: history.now, measures: ms,
            selected: Binding(get: { ms.contains { $0.id == selected } ? selected : ms[0].id }, set: { selected = $0 }),
            range: $range, offset: $offset, maxOffset: range == .ytd || range == .year ? 1 : 12
        ) {
            picker
        } bottom: { window in
            VStack(alignment: .leading, spacing: 16) {
                if let exercise { records(exercise) }
                NoopFitnessHistoryList(sessions: sessions(in: window, exercise: exercise), navigation: navigation)
            }
        }
    }

    private var picker: some View {
        Menu {
            Button("All muscles") { withAnimation(NoopMotion.swap) { exercise = nil } }
            ForEach(exercises, id: \.self) { e in
                Button(e) { withAnimation(NoopMotion.swap) { exercise = e } }
            }
        } label: {
            HStack(spacing: 6) {
                Text(exercise == nil ? "Every exercise" : "One exercise")
                    .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(NoopHTMLColor.inkSoft)
            .padding(.horizontal, 12).frame(height: 30)
            .background(Color.white.opacity(0.06), in: Capsule())
        }
    }

    private var exercises: [String] {
        var n: [String: Int] = [:]
        for s in history.scoredSets { n[s.set.exerciseId, default: 0] += 1 }
        return n.sorted { $0.value > $1.value }.map(\.key)
    }

    private func measures(_ sets: [FitnessStrengthSet]) -> [NoopFitnessMeasure] {
        let body = history.bodyMassKg
        var out: [NoopFitnessMeasure] = [
            .init(id: "sets", label: "Working sets", combine: .sum, events: sets.map { ($0.date, 1) },
                  format: NoopFitnessFormat.count, tint: NoopHTMLColor.blush),
            .init(id: "volume", label: "Volume", combine: .sum,
                  events: sets.map { ($0.date, StrengthTotals.volumeKg($0, bodyMassKg: body)) },
                  format: NoopFitnessFormat.kg, tint: NoopHTMLColor.blush),
        ]
        if exercise != nil {
            out.append(.init(id: "heaviest", label: "Heaviest set", combine: .max,
                             events: sets.compactMap { s in s.weightKg.flatMap { $0 > 0 ? (s.date, $0) : nil } },
                             format: NoopFitnessFormat.kg, tint: NoopHTMLColor.warm))
            out.append(.init(id: "reps", label: "Most reps", combine: .max,
                             events: sets.compactMap { s in s.reps.map { (s.date, Double($0)) } },
                             format: { "\(Int($0)) reps" }, tint: NoopHTMLColor.warm))
        } else {
            let sessions = history.liftSessions.map { (Date(timeIntervalSince1970: Double($0.startTs)), 1.0) }
            out.append(.init(id: "sessions", label: "Sessions", combine: .sum, events: sessions.map { ($0.0, $0.1) },
                             format: NoopFitnessFormat.count, tint: NoopHTMLColor.blush))
        }
        return out
    }

    private func sessions(in w: NoopFitnessWindow, exercise: String?) -> [NoopFitnessSession] {
        history.sessions.filter { s in
            guard s.kind == .strength, w.contains(s.start) else { return false }
            guard let exercise else { return true }
            let end = s.start.addingTimeInterval(max(s.durationS, 3600) + 60)
            return history.scoredSets.contains { $0.set.exerciseId == exercise && $0.set.date >= s.start.addingTimeInterval(-60) && $0.set.date <= end }
        }
    }

    @ViewBuilder
    private func records(_ exercise: String) -> some View {
        let sets = history.scoredSets.map(\.set).filter { $0.exerciseId == exercise }
        let heaviest = sets.filter { ($0.weightKg ?? 0) > 0 }.max { ($0.weightKg ?? 0) < ($1.weightKg ?? 0) }
        let reps = sets.max { ($0.reps ?? 0) < ($1.reps ?? 0) }
        let best = sets.max {
            StrengthTotals.volumeKg($0, bodyMassKg: history.bodyMassKg) < StrengthTotals.volumeKg($1, bodyMassKg: history.bodyMassKg)
        }
        if heaviest != nil || reps != nil {
            NoopFitnessPanel(label: "Personal records") {
                if let h = heaviest, let w = h.weightKg {
                    record("Heaviest weight", NoopFitnessFormat.kg(w) + (h.reps.map { " × \($0)" } ?? ""), h.date)
                }
                if let r = reps, let n = r.reps {
                    record("Most reps in a set", "\(n) reps" + (r.weightKg.flatMap { $0 > 0 ? " at \(NoopFitnessFormat.kg($0))" : nil } ?? ""), r.date)
                }
                if let b = best {
                    record("Biggest set", NoopFitnessFormat.kg(StrengthTotals.volumeKg(b, bodyMassKg: history.bodyMassKg)), b.date)
                }
            }
        }
    }

    private func record(_ title: String, _ value: String, _ date: Date) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill").font(.system(size: 13)).foregroundStyle(NoopHTMLColor.warm)
                .frame(width: 34, height: 34).background(NoopHTMLColor.warm.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(NoopHTMLFont.sans(14.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                Text(title).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
            }
            Spacer()
            Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.muted)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Training load

struct NoopFitnessLoadPage: View {
    @ObservedObject var navigation: NoopNavigation
    let history: NoopFitnessHistory
    @State var kind: NoopFitnessHistory.LoadKind
    @State private var range: NoopFitnessRange = .month
    @State private var offset = 0
    @State private var selection: Int?

    init(navigation: NoopNavigation, history: NoopFitnessHistory, kind: NoopFitnessHistory.LoadKind) {
        self.navigation = navigation
        self.history = history
        _kind = State(initialValue: kind)
    }

    private static let ranges: [NoopFitnessRange] = [.week, .month, .quarter, .year]

    var body: some View {
        let window = NoopFitnessWindow.make(range, offset: offset, now: history.now)
        let points = readings(window)
        let shown = selection.flatMap { i in points.first { $0.i == i } } ?? points.last
        let decimals = kind == .cardio ? 1 : 0
        NoopFitnessPage(navigation: navigation, title: kind == .cardio ? "Cardio load" : "Muscular load") {
            VStack(alignment: .leading, spacing: 16) {
                kindSwitch
                if let shown {
                    NoopFitnessInstrumentHeader(
                        value: String(format: "%.\(decimals)f", shown.reading.acute),
                        caption: shown.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().year()),
                        comparison: shown.reading.status == .calibrating ? nil
                            : "Optimal \(fmt(shown.reading.optimal.lowerBound))–\(fmt(shown.reading.optimal.upperBound))",
                        status: (shown.reading.status.title, shown.reading.status.color),
                        trailing: shown.reading.ratio.map { String(format: "%.2f× your normal", $0) })
                }
                VStack(spacing: 8) {
                    chart(points).frame(height: 210)
                    statusStrip(points)
                    NoopFitnessChartCaption(text: "Seven-day load each \(window.unitWord == "day" ? "day" : "\(window.unitWord)'s end"), inside the band it was judged against")
                }
                .padding(16)
                .fitnessCard()
                NoopFitnessRangeBar(range: $range, offset: $offset, ranges: Self.ranges, maxOffset: range == .year ? 0 : 4)
                breakdown(points)
                explainer
                contributors(shown?.date ?? history.now)
            }
        }
        .onChange(of: range) { selection = nil }
        .onChange(of: offset) { selection = nil }
        .onChange(of: kind) { selection = nil }
    }

    private func fmt(_ v: Double) -> String { String(format: kind == .cardio ? "%.1f" : "%.0f", v) }

    private var kindSwitch: some View {
        HStack(spacing: 4) {
            ForEach([NoopFitnessHistory.LoadKind.cardio, .muscular], id: \.self) { k in
                Button { withAnimation(NoopMotion.swap) { kind = k } } label: {
                    Text(k == .cardio ? "Cardio" : "Muscular")
                        .font(NoopHTMLFont.sans(13, weight: .semibold))
                        .foregroundStyle(kind == k ? NoopHTMLColor.canvas : NoopHTMLColor.inkSoft)
                        .padding(.horizontal, 16).frame(height: 32)
                        .background(kind == k ? NoopHTMLColor.ink : Color.white.opacity(0.06), in: Capsule())
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
        }
    }

    private struct Point: Identifiable {
        let i: Int
        let date: Date
        let reading: AcuteChronicLoad.Reading
        var id: Int { i }
    }

    /// One reading per bucket: the day itself, or the last day of a week or month.
    private func readings(_ w: NoopFitnessWindow) -> [Point] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: history.now)
        return w.buckets.enumerated().compactMap { i, start in
            let next = w.buckets[safe: i + 1] ?? w.end
            let last = min(cal.date(byAdding: .day, value: -1, to: next) ?? start, today)
            guard last >= start || w.bucket == .day else { return nil }
            guard start <= today else { return nil }
            return Point(i: i, date: last, reading: history.load(kind, asOf: last))
        }
    }

    private func chart(_ points: [Point]) -> some View {
        let n = max(points.last.map { $0.i + 1 } ?? 1, 1)
        let window = NoopFitnessWindow.make(range, offset: offset, now: history.now)
        return Chart {
            ForEach(points.filter { $0.reading.status != .calibrating || $0.reading.chronic > 0 }) { p in
                AreaMark(x: .value("Day", p.i), yStart: .value("Low", p.reading.optimal.lowerBound),
                         yEnd: .value("High", p.reading.optimal.upperBound))
                    .foregroundStyle(NoopHTMLColor.green.opacity(0.14))
                    .interpolationMethod(.monotone)
            }
            ForEach(points) { p in
                LineMark(x: .value("Day", p.i), y: .value("Load", p.reading.acute))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Day", p.i), y: .value("Load", p.reading.acute))
                    .foregroundStyle(p.reading.status.color)
                    .symbolSize(points.count > 40 ? 10 : 26)
            }
            if let selection {
                RuleMark(x: .value("Selected", selection))
                    .foregroundStyle(NoopHTMLColor.inkSoft.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
            }
        }
        .chartXScale(domain: -0.5...Double(max(n, window.buckets.count)) - 0.5)
        .chartXAxis {
            AxisMarks(values: Array(stride(from: 0, to: window.buckets.count, by: max(1, window.buckets.count / 4)))) { v in
                AxisValueLabel {
                    if let i = v.as(Int.self) {
                        Text(window.tick(i)).font(NoopHTMLFont.sans(10)).foregroundStyle(NoopHTMLColor.muted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel {
                    if let d = v.as(Double.self) {
                        Text(fmt(d)).font(NoopHTMLFont.sans(9.5)).foregroundStyle(NoopHTMLColor.muted)
                    }
                }
            }
        }
        .stickyChartSelection($selection)
    }

    /// A thin bar under the chart, one segment per day in its status colour.
    private func statusStrip(_ points: [Point]) -> some View {
        HStack(spacing: points.count > 60 ? 0.5 : 2) {
            ForEach(points) { p in
                Capsule().fill(p.reading.status.color.opacity(p.i == selection ? 1 : 0.7)).frame(height: 4)
            }
        }
    }

    private func breakdown(_ points: [Point]) -> some View {
        let statuses: [AcuteChronicLoad.Status] = [.calibrating, .detraining, .maintaining, .productive, .fatigued]
        let total = Double(max(points.count, 1))
        let unit = NoopFitnessWindow.make(range, offset: offset, now: history.now).unitWord
        return NoopFitnessBreakdown(
            title: "How the period split", columns: ("Status", unit == "day" ? "Days" : unit.capitalized + "s"),
            rows: statuses.map { s in
                let n = points.filter { $0.reading.status == s }.count
                return .init(label: s.title, amount: "\(n)", share: Double(n) / total, color: s.color)
            })
    }

    private var explainer: some View {
        NoopFitnessExplainer(
            kind == .cardio ? "What cardio load is" : "What muscular load is",
            kind == .cardio
                ? "The heart-rate work of the last seven days, set against what your last six weeks have prepared you for. The band moves with you: train more and it rises."
                : "Every logged set, weighted by how close to failure it went, plus what cardio asks of your legs, over seven days against your last six weeks.",
            keys: [
                ("Detraining", "Less than your body is used to. Fine for a rest week; fitness slips if it lasts.", AcuteChronicLoad.Status.detraining.color),
                ("Maintaining", "Close to your normal. Holds what you have.", AcuteChronicLoad.Status.maintaining.color),
                ("Productive", "A little more than your normal. Where fitness is built.", AcuteChronicLoad.Status.productive.color),
                ("Fatigued", "Well above your normal. Injury risk rises; plan easier days.", AcuteChronicLoad.Status.fatigued.color),
                ("Calibrating", kind == .cardio
                    ? "Until there are ten cardio sessions in six weeks and one in the last four."
                    : "Until there are ten sessions in six weeks and one in the last four.", AcuteChronicLoad.Status.calibrating.color),
            ])
    }

    @ViewBuilder
    private func contributors(_ day: Date) -> some View {
        let top = history.contributors(kind, asOf: day)
        if !top.isEmpty {
            NoopFitnessPanel(label: "The week's load came from") {
                ForEach(Array(top.prefix(6).enumerated()), id: \.offset) { _, c in
                    NoopFitnessRow(title: WorkoutSource.displaySport(c.title),
                                   detail: c.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                                   value: fmt(c.load))
                }
            }
        }
    }
}

// MARK: - VO₂ max and recovery

struct NoopFitnessReadingPage: View {
    enum Kind { case vo2, recovery }

    @ObservedObject var navigation: NoopNavigation
    let history: NoopFitnessHistory
    let kind: Kind
    @State private var selected = "main"
    @State private var range: NoopFitnessRange = .quarter
    @State private var offset = 0

    var body: some View {
        let measure: NoopFitnessMeasure = kind == .vo2
            ? .init(id: "main", label: "VO₂ max", combine: .latest, events: history.vo2,
                    format: { String(format: "%.1f", $0) }, tint: NoopHTMLColor.green)
            : .init(id: "main", label: "One-minute drop", combine: .mean,
                    events: history.recoveries.map { ($0.date, $0.drop) }, format: NoopFitnessFormat.bpm,
                    tint: NoopHTMLColor.blush)
        NoopFitnessMeasurePage(
            navigation: navigation, title: kind == .vo2 ? "VO₂ max" : "Heart rate recovery", now: history.now,
            measures: [measure], selected: $selected, range: $range, offset: $offset, maxOffset: 1
        ) {
            EmptyView()
        } bottom: { window in
            VStack(alignment: .leading, spacing: 16) {
                if kind == .vo2 {
                    NoopFitnessExplainer(
                        "What VO₂ max is",
                        "The most oxygen your body can use, in millilitres per kilo per minute. It is one of the strongest single markers of long-term health, and it rises with steady and hard cardio. Noop Aura reads it from Apple Health; a watch estimates it from outdoor walks and runs with heart rate.")
                } else {
                    NoopFitnessExplainer(
                        "What recovery tells you",
                        "How far your heart rate falls in the first minute after a session ends. A bigger drop means a heart that switches off effort quickly, and it tends to grow as fitness does.",
                        keys: [
                            ("20 bpm or more", "A quick recovery.", NoopHTMLColor.green),
                            ("12 to 20 bpm", "Typical.", NoopHTMLColor.warm),
                            ("Under 12 bpm", "Slow. Worth mentioning to a doctor if it stays there.", NoopHTMLColor.red),
                        ])
                    let list = history.recoveries.filter { window.contains($0.date) }
                    NoopFitnessPanel(label: "Sessions") {
                        if list.isEmpty {
                            Text("No session in this period has heart rate after it ended. Keep the strap on for a minute after you stop.")
                                .font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(list) { r in
                            NoopFitnessRow(title: WorkoutSource.displaySport(r.title),
                                           detail: r.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)),
                                           value: NoopFitnessFormat.bpm(r.drop),
                                           valueColor: r.drop >= 20 ? NoopHTMLColor.green : r.drop >= 12 ? NoopHTMLColor.warm : NoopHTMLColor.red)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Cardio focus

struct NoopFitnessFocusPage: View {
    @ObservedObject var navigation: NoopNavigation
    let history: NoopFitnessHistory
    @State private var range: NoopFitnessRange = .month
    @State private var offset = 0
    @State private var sport: String?
    @State private var selection: Int?

    private struct Bar: Identifiable {
        let i: Int
        let band: CardioFocus.Band
        let minutes: Double
        var id: String { "\(i)-\(band.rawValue)" }
    }

    var body: some View {
        let window = NoopFitnessWindow.make(range, offset: offset, now: history.now)
        let workouts = history.workouts.filter { !$0.isStrength || true }
            .filter { sport == nil || WorkoutSource.displaySport($0.title) == sport }
        var perBucket = [[Double]](repeating: [0, 0, 0], count: window.buckets.count)
        for w in workouts {
            guard let i = window.index(of: w.start) else { continue }
            let z = w.zoneMinutes + [Double](repeating: 0, count: max(0, 5 - w.zoneMinutes.count))
            perBucket[i][0] += z[1] + z[2]
            perBucket[i][1] += z[3]
            perBucket[i][2] += z[4]
        }
        let bars = perBucket.enumerated().flatMap { i, v in
            CardioFocus.Band.allCases.enumerated().compactMap { j, b in v[j] > 0 ? Bar(i: i, band: b, minutes: v[j]) : nil }
        }
        let shown: [Double] = selection.flatMap { perBucket[safe: $0] }
            ?? perBucket.reduce([0, 0, 0]) { [$0[0] + $1[0], $0[1] + $1[1], $0[2] + $1[2]] }
        let total = shown.reduce(0, +)
        let lead = total > 0 ? CardioFocus.Band.allCases[shown.firstIndex(of: shown.max() ?? 0) ?? 0] : nil
        return NoopFitnessPage(navigation: navigation, title: "Cardio focus") {
            VStack(alignment: .leading, spacing: 16) {
                NoopFitnessFilterChips(options: sports, selected: $sport)
                NoopFitnessInstrumentHeader(
                    value: lead?.title ?? "No data",
                    caption: selection.map { window.label($0) } ?? window.title,
                    status: lead.map { ("\(Int(((shown[CardioFocus.Band.allCases.firstIndex(of: $0)!] / total) * 100).rounded()))%", NoopFitnessDetailScreen.focusColor($0)) },
                    trailing: total > 0 ? NoopFitnessFormat.duration(total * 60) : nil)
                VStack(spacing: 10) {
                    Chart(bars) { b in
                        BarMark(x: .value("Bucket", b.i), y: .value("Minutes", b.minutes), width: .ratio(0.62))
                            .foregroundStyle(by: .value("Band", b.band.title))
                            .opacity(selection == nil || selection == b.i ? 1 : 0.35)
                    }
                    .chartForegroundStyleScale(domain: CardioFocus.Band.allCases.map(\.title),
                                               range: CardioFocus.Band.allCases.map(NoopFitnessDetailScreen.focusColor))
                    .chartLegend(.hidden)
                    .chartXScale(domain: -0.5...Double(window.buckets.count) - 0.5)
                    .chartXAxis {
                        AxisMarks(values: Array(stride(from: 0, to: window.buckets.count, by: max(1, window.buckets.count / 4)))) { v in
                            AxisValueLabel {
                                if let i = v.as(Int.self) {
                                    Text(window.tick(i)).font(NoopHTMLFont.sans(10)).foregroundStyle(NoopHTMLColor.muted)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { v in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.06))
                            AxisValueLabel {
                                if let d = v.as(Double.self) {
                                    Text("\(Int(d))m").font(NoopHTMLFont.sans(9.5)).foregroundStyle(NoopHTMLColor.muted)
                                }
                            }
                        }
                    }
                    .stickyChartSelection($selection)
                    .frame(height: 200)
                    .overlay {
                        if bars.isEmpty {
                            Text("No heart-rate time in this period").font(NoopHTMLFont.sans(13.5, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                        }
                    }
                    NoopFitnessChartCaption(text: "Minutes per \(window.unitWord), by intensity")
                }
                .padding(16)
                .fitnessCard()
                NoopFitnessRangeBar(range: $range, offset: $offset, maxOffset: 6)
                NoopFitnessBreakdown(
                    title: "How the time split", columns: ("Intensity", "Time"),
                    rows: CardioFocus.Band.allCases.enumerated().map { j, b in
                        .init(label: b.title, amount: NoopFitnessFormat.duration(shown[j] * 60),
                              share: total > 0 ? shown[j] / total : 0, color: NoopFitnessDetailScreen.focusColor(b))
                    })
                NoopFitnessExplainer(
                    "What cardio focus is",
                    "Where your training time went, by intensity. Most endurance fitness is built in low aerobic work; a smaller share of high aerobic and anaerobic work sharpens it. Resting minutes are left out.",
                    keys: [
                        ("Low aerobic", "Your Easy and Steady zones. You could hold a conversation.", NoopFitnessDetailScreen.focusColor(.lowAerobic)),
                        ("High aerobic", "Your Hard zone. Sustained, breathing deep.", NoopFitnessDetailScreen.focusColor(.highAerobic)),
                        ("Anaerobic", "All out. Short efforts: intervals, sprints, the end of a race.", NoopFitnessDetailScreen.focusColor(.anaerobic)),
                    ])
            }
        }
        .onChange(of: range) { selection = nil }
        .onChange(of: offset) { selection = nil }
    }

    private var sports: [String] {
        var n: [String: Int] = [:]
        for w in history.workouts where w.zoneMinutes.reduce(0, +) > 0 { n[WorkoutSource.displaySport(w.title), default: 0] += 1 }
        return n.sorted { $0.value > $1.value }.map(\.key)
    }
}

// MARK: - Heart rate zones

struct NoopFitnessZonesPage: View {
    @ObservedObject var navigation: NoopNavigation
    let history: NoopFitnessHistory
    @State private var range: NoopFitnessRange = .week
    @State private var offset = 0
    @State private var sport: String?
    @State private var zone: Int?

    var body: some View {
        let window = NoopFitnessWindow.make(range, offset: offset, now: history.now)
        var minutes = [Double](repeating: 0, count: 5)
        for w in history.workouts where window.contains(w.start) && (sport == nil || WorkoutSource.displaySport(w.title) == sport) {
            for i in 0..<min(5, w.zoneMinutes.count) { minutes[i] += w.zoneMinutes[i] }
        }
        let total = minutes.reduce(0, +)
        let shown = zone ?? (total > 0 ? minutes.firstIndex(of: minutes.max() ?? 0) : nil)
        let colors = NoopFitnessZonesCard.colors
        return NoopFitnessPage(navigation: navigation, title: "Heart rate zones") {
            VStack(alignment: .leading, spacing: 16) {
                NoopFitnessFilterChips(options: sports, selected: $sport)
                if let z = shown, let def = history.zoneSet.zones[safe: z] {
                    NoopFitnessInstrumentHeader(
                        value: history.zoneNames[z],
                        caption: window.title,
                        comparison: "\(Int(def.lower))–\(Int(def.upper)) bpm",
                        status: (NoopFitnessFormat.duration(minutes[z] * 60), colors[z]),
                        trailing: total > 0 ? "\(Int((minutes[z] / total * 100).rounded()))% of the time" : nil)
                } else {
                    NoopFitnessInstrumentHeader(value: "No data", caption: window.title)
                }
                VStack(spacing: 12) {
                    HStack(alignment: .bottom, spacing: 10) {
                        ForEach(0..<5, id: \.self) { i in
                            Button { withAnimation(NoopMotion.swap) { zone = zone == i ? nil : i } } label: {
                                VStack(spacing: 6) {
                                    Text(total > 0 ? "\(Int((minutes[i] / total * 100).rounded()))%" : "")
                                        .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                                        .foregroundStyle(shown == i ? NoopHTMLColor.ink : NoopHTMLColor.muted)
                                    GeometryReader { g in
                                        VStack {
                                            Spacer(minLength: 0)
                                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                                .fill(LinearGradient(colors: [colors[i], colors[i].opacity(0.6)], startPoint: .top, endPoint: .bottom))
                                                .frame(height: max(3, g.size.height * (minutes[i] / max(minutes.max() ?? 1, 1))))
                                                .opacity(shown == nil || shown == i ? 1 : 0.35)
                                        }
                                    }
                                    HStack(spacing: 4) {
                                        Circle().fill(colors[i]).frame(width: 6, height: 6)
                                        Text("Z\(i + 1)").font(NoopHTMLFont.sans(11, weight: .semibold)).foregroundStyle(NoopHTMLColor.copy)
                                    }
                                }
                            }
                            .buttonStyle(NoopHTMLPressStyle())
                        }
                    }
                    .frame(height: 200)
                    .sensoryFeedback(.selection, trigger: zone)
                    NoopFitnessChartCaption(text: "Time in each zone during sessions · tap a zone")
                }
                .padding(16)
                .fitnessCard()
                NoopFitnessRangeBar(range: $range, offset: $offset, maxOffset: 12)
                NoopFitnessExplainer(
                    "Your zones",
                    "Ranges of heart rate that each train something different, from your own resting and maximum rates. Change them in You › Your zones.",
                    keys: (0..<5).map { i in
                        let d = history.zoneSet.zones[safe: i]
                        return ("\(history.zoneNames[i])" + (d.map { " · \(Int($0.lower))–\(Int($0.upper))" } ?? ""),
                                Self.meaning[i], colors[i])
                    })
                Button { navigation.push(.zones) } label: {
                    NoopFitnessPanel { NoopFitnessRow(title: "Change your zones", value: "›") }
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
        }
        .onChange(of: range) { zone = nil }
    }

    private static let meaning = [
        "Warming up, cooling down and easy movement.",
        "All-day pace. Builds the base that everything else sits on.",
        "Comfortably hard. Raises the pace you can hold.",
        "Hard and sustained. Breathing is heavy; it lifts your ceiling.",
        "Short, maximal efforts you can only hold briefly.",
    ]

    private var sports: [String] {
        var n: [String: Int] = [:]
        for w in history.workouts where w.zoneMinutes.reduce(0, +) > 0 { n[WorkoutSource.displaySport(w.title), default: 0] += 1 }
        return n.sorted { $0.value > $1.value }.map(\.key)
    }
}
#endif
