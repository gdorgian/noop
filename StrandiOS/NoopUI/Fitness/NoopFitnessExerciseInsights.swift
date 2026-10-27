#if os(iOS)
import SwiftUI
import Charts
import StrandAnalytics
import WhoopStore

/// One exercise's progress, records and history, read from every session it was ever logged in.
///
/// The three tabs of the exercise page that are about the lifter rather than the movement: Summary (the
/// best set and a trend line), Records (each record and when it was set, plus the rep-max table) and
/// History (every session, its sets, and which of them set a record). Warm-ups are listed in History but
/// never counted (`LiftRecords`).
@MainActor
final class NoopExerciseInsightsModel: ObservableObject {
    @Published private(set) var exercise: LiftRecords.Exercise = .empty
    @Published private(set) var history: [LiftHistorySet] = []
    @Published private(set) var loaded = false

    func load(name: String, repo: Repository) async {
        guard let store = await repo.storeHandle() else { loaded = true; return }
        let rows = (try? await store.liftExerciseHistory(deviceId: repo.deviceId, exercise: name)) ?? []
        history = rows
        exercise = LiftRecords.exercise(rows)
        loaded = true
    }
}

enum NoopExerciseInsightsTab: Hashable { case summary, records, history, howTo }

/// The Summary tab: the best set ever done, then one trend over the chosen window.
struct NoopExerciseSummary: View {
    let exercise: LiftRecords.Exercise
    let units: UnitSystem

    enum Metric: String, CaseIterable { case max = "Est. max", heaviest = "Heaviest", volume = "Volume", reps = "Reps" }
    enum Window: String, CaseIterable { case quarter = "3M", year = "1Y", all = "All" }

    @State private var metric: Metric = .max
    @State private var window: Window = .year

    private var metrics: [Metric] { exercise.isBodyweight ? [.reps] : Metric.allCases }

    var body: some View {
        if exercise.sessions.isEmpty {
            NoopExerciseEmpty(text: "Nothing logged for this exercise yet. Its best set, records and trend start with the first session.")
        } else {
            VStack(alignment: .leading, spacing: NoopSpace.m) {
                bestSet
                VStack(alignment: .leading, spacing: NoopSpace.s) {
                    if metrics.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: NoopSpace.xs) {
                                ForEach(metrics, id: \.self) { m in NoopChip(title: m.rawValue, isOn: metric == m) { metric = m } }
                            }
                        }
                    }
                    chartCard
                    NoopTabs(options: Window.allCases.map { ($0.rawValue, $0) }, selection: $window)
                }
            }
            .onAppear { if exercise.isBodyweight { metric = .reps } }
        }
    }

    private var bestSet: some View {
        let best = exercise.isBodyweight ? exercise.records[.mostReps] : exercise.records[.bestOneRepMax]
        return NoopSessionCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("BEST SET").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.1)
                    .foregroundStyle(NoopHTMLColor.muted)
                Text(NoopExerciseFormat.set(best?.weightKg, best?.reps, units))
                    .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light)).foregroundStyle(NoopHTMLColor.ink)
                    .monospacedDigit()
                HStack(spacing: 6) {
                    if !exercise.isBodyweight, let max = exercise.records[.bestOneRepMax]?.value {
                        Text("Estimated max \(NoopExerciseFormat.kg(max, units))")
                    }
                    if let at = best?.sessionStartTs { Text("·"); Text(NoopExerciseFormat.date(at)) }
                }
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                Text("\(exercise.sessions.count) \(exercise.sessions.count == 1 ? "session" : "sessions") · \(exercise.sessions.reduce(0) { $0 + $1.workingSets }) working sets")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
            }
        }
    }

    private var points: [NoopTrendPoint] {
        exercise.sessions.compactMap { p in
            let v: Double? = switch metric {
            case .max: p.bestOneRepMaxKg
            case .heaviest: p.heaviestKg
            case .volume: p.volumeKg
            case .reps: Double(p.totalReps)
            }
            return v.map { NoopTrendPoint(id: p.sessionId, ts: p.startTs,
                                          value: metric == .reps ? $0 : LiftFormat.display(fromKilograms: $0, system: units)) }
        }
    }

    private func label(_ value: Double) -> String {
        metric == .reps ? "\(Int(value)) reps" : "\(LiftFormat.trim(value.rounded(toPlaces: 1))) \(LiftFormat.weightUnit(units))"
    }

    private var chartCard: some View {
        NoopTrendChartCard(points: NoopTrendPoint.within(window, points), label: label)
            .animation(NoopMotion.swap, value: metric)
            .animation(NoopMotion.swap, value: window)
    }
}

/// One session's value on a trend line.
struct NoopTrendPoint: Equatable {
    let id: String
    /// Unix seconds.
    let ts: Int
    let value: Double

    var date: Date { Date(timeIntervalSince1970: Double(ts)) }

    static func within(_ window: NoopExerciseSummary.Window, _ points: [NoopTrendPoint]) -> [NoopTrendPoint] {
        let days: Double? = switch window { case .quarter: 91; case .year: 365; case .all: nil }
        guard let days else { return points }
        let cutoff = Int(Date().addingTimeInterval(-days * 86_400).timeIntervalSince1970)
        return points.filter { $0.ts >= cutoff }
    }
}

/// A trend over sessions: the latest (or touched) value large, the change across the window, and a line
/// you can drag along to read any session.
struct NoopTrendChartCard: View {
    let points: [NoopTrendPoint]
    let label: (Double) -> String
    var tint: Color = NoopHTMLColor.volt

    @State private var selected: NoopTrendPoint?

    var body: some View {
        let shown = selected ?? points.last
        let change = (points.first?.value).flatMap { first in points.last.map { $0.value - first } }
        NoopSessionCard {
            VStack(alignment: .leading, spacing: NoopSpace.s) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(shown.map { label($0.value) } ?? "—")
                            .font(NoopHTMLFont.outfit(NoopType.title3, weight: .regular)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.ink)
                            .contentTransition(.numericText())
                        Text(shown.map { NoopExerciseFormat.date($0.ts) } ?? "No sessions in this window")
                            .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                    }
                    Spacer()
                    if selected == nil, let change, points.count > 1, abs(change) > 0.05 {
                        Text("\(change > 0 ? "+" : "−")\(label(abs(change)))")
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).monospacedDigit()
                            .foregroundStyle(change > 0 ? NoopHTMLColor.green : NoopHTMLColor.copy)
                            .padding(.horizontal, 9).frame(height: 24)
                            .background((change > 0 ? NoopHTMLColor.green : Color.white).opacity(0.10), in: Capsule())
                    }
                }
                if points.count < 2 {
                    Text("A trend needs two sessions in this window.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
                        .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    chart
                }
            }
        }
    }

    private var chart: some View {
        let low = points.map(\.value).min() ?? 0, high = points.map(\.value).max() ?? 1
        let pad = max(1, (high - low) * 0.25)
        return Chart {
            ForEach(points, id: \.id) { p in
                AreaMark(x: .value("Date", p.date), yStart: .value("Floor", low - pad), yEnd: .value("Value", p.value))
                    .foregroundStyle(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Date", p.date), y: .value("Value", p.value))
                    .foregroundStyle(tint)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                PointMark(x: .value("Date", p.date), y: .value("Value", p.value))
                    .foregroundStyle(selected?.id == p.id ? NoopHTMLColor.ink : tint)
                    .symbolSize(selected?.id == p.id ? 70 : (points.count > 30 ? 0 : 26))
            }
        }
        .chartYScale(domain: (low - pad)...(high + pad))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: false)
                    .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel().font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            guard let plot = proxy.plotFrame else { return }
                            guard let date: Date = proxy.value(atX: drag.location.x - geo[plot].origin.x) else { return }
                            let nearest = points.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
                            if nearest != selected { selected = nearest }
                        }
                        .onEnded { _ in selected = nil })
            }
        }
        .sensoryFeedback(.selection, trigger: selected?.id)
        .noopChartZoom()
        .frame(height: 170)
    }
}

/// The Records tab: each record as a tile, then the heaviest weight for each rep count.
struct NoopExerciseRecordsView: View {
    let exercise: LiftRecords.Exercise
    let units: UnitSystem

    private var kinds: [LiftRecords.Kind] {
        exercise.isBodyweight ? [.mostReps, .mostSessionReps]
            : [.heaviestWeight, .bestOneRepMax, .bestSetVolume, .bestSessionVolume, .mostReps]
    }

    var body: some View {
        if exercise.sessions.isEmpty {
            NoopExerciseEmpty(text: "No records yet. The first session of this exercise sets them; every one after can break them.")
        } else {
            VStack(alignment: .leading, spacing: NoopSpace.m) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(kinds, id: \.self) { kind in
                        if let value = exercise.records[kind] { tile(kind, value) }
                    }
                }
                if !exercise.isBodyweight, !exercise.repBests.isEmpty { repTable }
            }
        }
    }

    private func tile(_ kind: LiftRecords.Kind, _ value: LiftRecords.Value) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: NoopExerciseFormat.symbol(kind)).font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NoopExerciseFormat.tint(kind))
                Text(NoopExerciseFormat.title(kind)).font(NoopHTMLFont.sans(NoopType.caption, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.copy).lineLimit(1).minimumScaleFactor(0.85)
            }
            Text(NoopExerciseFormat.value(kind, value, units))
                .font(NoopHTMLFont.outfit(NoopType.title3, weight: .regular)).monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(detail(kind, value)).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(14)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
        .accessibilityElement(children: .combine)
    }

    private func detail(_ kind: LiftRecords.Kind, _ value: LiftRecords.Value) -> String {
        let when = NoopExerciseFormat.date(value.sessionStartTs)
        switch kind {
        case .bestOneRepMax, .bestSetVolume: return "\(NoopExerciseFormat.set(value.weightKg, value.reps, units)) · \(when)"
        default: return when
        }
    }

    private var repTable: some View {
        NoopSessionCard {
            VStack(alignment: .leading, spacing: 10) {
                NoopSessionCardTitle(symbol: "list.number", title: "Best weight by reps")
                HStack {
                    Text("REPS").frame(width: 52, alignment: .leading)
                    Text("BEST").frame(maxWidth: .infinity, alignment: .leading)
                    Text("WHEN").frame(maxWidth: .infinity, alignment: .trailing)
                }
                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(0.8).foregroundStyle(NoopHTMLColor.muted)
                ForEach(exercise.repBests.keys.sorted(), id: \.self) { reps in
                    if let best = exercise.repBests[reps] {
                        HStack {
                            Text("\(reps)").frame(width: 52, alignment: .leading).foregroundStyle(NoopHTMLColor.copy)
                            Text(NoopExerciseFormat.kg(best.value, units)).frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text(NoopExerciseFormat.date(best.sessionStartTs)).frame(maxWidth: .infinity, alignment: .trailing)
                                .foregroundStyle(NoopHTMLColor.muted)
                        }
                        .font(NoopHTMLFont.sans(NoopType.footnote)).monospacedDigit()
                        .frame(minHeight: 30)
                    }
                }
            }
        }
    }
}

/// The History tab: every session newest first, its sets in order, and a mark on each set that set a
/// record still standing.
struct NoopExerciseHistoryView: View {
    let history: [LiftHistorySet]
    let exercise: LiftRecords.Exercise
    let units: UnitSystem

    var body: some View {
        if history.isEmpty {
            NoopExerciseEmpty(text: "Every session of this exercise will be listed here, with its sets.")
        } else {
            let standing = Set(exercise.records.values.compactMap(\.setId))
            let sessions = Dictionary(grouping: history, by: \.set.sessionId)
            let order = exercise.sessions.map(\.sessionId).reversed() + sessions.keys.filter { id in
                !exercise.sessions.contains { $0.sessionId == id }
            }
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(Array(order), id: \.self) { id in
                    if let sets = sessions[id], let first = sets.first {
                        NoopSessionCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NoopExerciseFormat.longDate(first.sessionStartTs))
                                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                                ForEach(Array(sets.enumerated()), id: \.element.set.id) { index, h in
                                    row(h.set, number: sets.prefix(index).filter { !$0.set.isWarmup }.count + 1,
                                        record: standing.contains(h.set.id))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func row(_ s: LiftSetRow, number: Int, record: Bool) -> some View {
        let letter: String = s.isWarmup ? "W" : s.setKind == .drop ? "D" : s.setKind == .failure ? "F" : "\(number)"
        let tint: Color = s.isWarmup ? NoopHTMLColor.warm : s.setKind == .drop ? NoopHTMLColor.nightLight
            : s.setKind == .failure ? NoopHTMLColor.red : NoopHTMLColor.copy
        return HStack(spacing: 10) {
            Text(letter).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 26, height: 26).background(tint.opacity(0.12), in: Circle())
            Text(NoopExerciseFormat.set(s.weightKg, s.reps, units))
                .font(NoopHTMLFont.sans(NoopType.footnote)).monospacedDigit()
                .foregroundStyle(s.isWarmup ? NoopHTMLColor.copy : NoopHTMLColor.ink)
            Spacer()
            if record {
                Label("Record", systemImage: "trophy.fill")
                    .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.volt)
                    .padding(.horizontal, 8).frame(height: 22)
                    .background(NoopHTMLColor.volt.opacity(0.12), in: Capsule())
            }
        }
    }
}

struct NoopExerciseEmpty: View {
    let text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 22, weight: .light)).foregroundStyle(NoopHTMLColor.muted)
            Text(text).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 36).padding(.horizontal, 20)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

enum NoopExerciseFormat {
    static func kg(_ v: Double, _ units: UnitSystem) -> String {
        "\(LiftFormat.trim(LiftFormat.display(fromKilograms: v, system: units).rounded(toPlaces: 1))) \(LiftFormat.weightUnit(units))"
    }

    static func set(_ w: Double?, _ r: Int?, _ units: UnitSystem) -> String {
        switch (w.flatMap { $0 > 0 ? $0 : nil }, r) {
        case let (w?, r?): return "\(kg(w, units)) × \(r)"
        case let (w?, nil): return kg(w, units)
        case let (nil, r?): return "\(r) reps"
        default: return "—"
        }
    }

    /// "Oct 26" this year, "Oct 26, 2025" before it. A two-digit year read as a second day ("Oct 26, 26").
    static func date(_ ts: Int) -> String {
        let d = Date(timeIntervalSince1970: Double(ts))
        return Calendar.current.isDate(d, equalTo: Date(), toGranularity: .year)
            ? d.formatted(.dateTime.day().month(.abbreviated))
            : d.formatted(.dateTime.day().month(.abbreviated).year())
    }

    static func longDate(_ ts: Int) -> String {
        Date(timeIntervalSince1970: Double(ts)).formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    static func title(_ kind: LiftRecords.Kind) -> String {
        switch kind {
        case .heaviestWeight: "Heaviest weight"
        case .bestOneRepMax: "Estimated max"
        case .bestSetVolume: "Best set volume"
        case .bestSessionVolume: "Session volume"
        case .mostReps: "Most reps"
        case .mostSessionReps: "Session reps"
        }
    }

    static func value(_ kind: LiftRecords.Kind, _ v: LiftRecords.Value, _ units: UnitSystem) -> String {
        switch kind {
        case .mostReps, .mostSessionReps: "\(Int(v.value)) reps"
        default: kg(v.value, units)
        }
    }

    static func symbol(_ kind: LiftRecords.Kind) -> String {
        switch kind {
        case .heaviestWeight: "arrow.up"
        case .bestOneRepMax: "bolt.fill"
        case .bestSetVolume: "square.stack.3d.up.fill"
        case .bestSessionVolume: "chart.bar.fill"
        case .mostReps, .mostSessionReps: "repeat"
        }
    }

    static func tint(_ kind: LiftRecords.Kind) -> Color {
        switch kind {
        case .heaviestWeight: NoopHTMLColor.warm
        case .bestOneRepMax: NoopHTMLColor.blueLight
        case .bestSetVolume, .bestSessionVolume: NoopHTMLColor.blush
        case .mostReps, .mostSessionReps: NoopHTMLColor.green
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (self * p).rounded() / p
    }
}
#endif
