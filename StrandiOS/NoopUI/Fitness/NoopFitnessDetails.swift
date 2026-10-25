#if os(iOS)
import SwiftUI
import StrandFitness

/// The card a Fitness detail page is about.
enum NoopFitnessMetric: Hashable {
    case cardioLoad, muscularLoad, activeTime, activeEnergy, vo2, recovery, focus, zones, sets, volume

    var title: String {
        switch self {
        case .cardioLoad: "Cardio load"
        case .muscularLoad: "Muscular load"
        case .activeTime: "Active time"
        case .activeEnergy: "Active energy"
        case .vo2: "VO₂ max"
        case .recovery: "Heart rate recovery"
        case .focus: "Cardio focus"
        case .zones: "Heart rate zones"
        case .sets: "Working sets"
        case .volume: "Volume"
        }
    }
}

/// Routes every Fitness screen to its view.
struct NoopFitnessScreens: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @ObservedObject var layout: NoopFitnessSettings
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore

    var body: some View {
        screen.task { await fitness.load(repo: repo, profile: profile) }
    }

    @ViewBuilder
    private var screen: some View {
        switch navigation.route {
        case .fitnessDetail: NoopFitnessDetailScreen(navigation: navigation, fitness: fitness)
        case .fitnessMuscles: NoopFitnessMuscleGroupsScreen(navigation: navigation, fitness: fitness)
        case .fitnessEdit: NoopFitnessEditScreen(navigation: navigation, layout: layout)
        case .fitnessRoutine: NoopFitnessRoutineScreen(navigation: navigation, fitness: fitness)
        case .fitnessCalendar: NoopFitnessCalendarScreen(navigation: navigation, fitness: fitness)
        case .fitnessRoutineEdit: NoopFitnessRoutineEditor(navigation: navigation, fitness: fitness)
        case .fitnessBody: NoopFitnessBodyScreen(navigation: navigation)
        case .fitnessReport: NoopFitnessReportScreen(navigation: navigation, fitness: fitness)
        case .fitnessProgram: NoopFitnessProgramBuilder(navigation: navigation, fitness: fitness).environmentObject(layout)
        default: NoopFitnessHome(navigation: navigation, fitness: fitness, layout: layout)
        }
    }
}

// MARK: - Shared pieces

private struct NoopFitnessInSheetKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// True inside the Fitness detail sheet: pages draw the sheet's close header instead of Back.
    var noopFitnessInSheet: Bool {
        get { self[NoopFitnessInSheetKey.self] }
        set { self[NoopFitnessInSheetKey.self] = newValue }
    }
}

/// The Fitness detail pages as a native large sheet over the Fitness page, the same container the
/// metric details use: grabber, swipe down to dismiss, the page underneath stays where it was.
struct NoopFitnessSheet: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var profile: ProfileStore
    @State private var scrollMemory = NoopScrollMemory()

    var body: some View {
        Group {
            switch navigation.fitnessSheet {
            case .fitnessMuscles: NoopFitnessMuscleGroupsScreen(navigation: navigation, fitness: fitness)
            default: NoopFitnessDetailScreen(navigation: navigation, fitness: fitness)
            }
        }
        .environment(\.noopFitnessInSheet, true)
        .environment(\.noopLiveBarInset, 0)
        // Its own scroll memory, fresh per presentation: the shared one restored the Fitness page's
        // offset into the sheet, which opened at the bottom of Muscle groups.
        .environment(\.noopScrollMemory, scrollMemory)
        .environment(\.noopScrollKey, "fitness-sheet")
        .task { await fitness.load(repo: repo, profile: profile) }
        .noopSheet()
        .preferredColorScheme(.dark)
    }
}

struct NoopFitnessPage<Content: View>: View {
    @ObservedObject var navigation: NoopNavigation
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content
    @Environment(\.noopFitnessInSheet) private var inSheet

    var body: some View {
        if inSheet { sheetBody } else { pageBody }
    }

    /// Close button and centred title pinned above the scroll, as in the metric sheet.
    private var sheetBody: some View {
        VStack(spacing: 0) {
            NoopMetricTopBar(title: title) { navigation.back() }
            NoopScreen(bottomInset: 32, topInset: 6) {
                VStack(alignment: .leading, spacing: 0) {
                    if let subtitle {
                        Text(subtitle)
                            .font(NoopHTMLFont.sans(NoopType.footnote))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 12)
                    }
                    content
                }
            }
        }
        .background(NoopHTMLColor.canvas)
    }

    private var pageBody: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopBackHeader(label: "Fitness") { navigation.back(or: .fitness) }
                    .padding(.bottom, 14)
                Text(title)
                    .font(NoopHTMLFont.outfit(NoopType.title2))
                    .foregroundStyle(NoopHTMLColor.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
                content.padding(.top, 18)
            }
        }
    }
}

struct NoopFitnessPeriodPicker: View {
    @Binding var days: Int
    var options: [Int] = [7, 30, 60]

    var body: some View {
        NoopTabs(options: options.map { ("\($0) days", $0) }, selection: $days)
    }
}

/// A plain card for detail pages.
struct NoopFitnessPanel<Content: View>: View {
    var label: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let label { NoopSectionLabel(label) }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

struct NoopFitnessRow: View {
    let title: String
    var detail: String? = nil
    let value: String
    var valueColor: Color = NoopHTMLColor.ink

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                if let detail {
                    Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                }
            }
            Spacer(minLength: 10)
            Text(value).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(valueColor)
        }
        .padding(.vertical, 4)
    }
}

private func fmtDate(_ d: Date) -> String { d.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)) }

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

struct NoopFitnessBarRow: View {
    let title: String
    var detail: String? = nil
    let value: Double
    let top: Double
    let text: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.ink).lineLimit(1)
                if let detail { Text(detail).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted) }
                Spacer()
                Text(text).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule().fill(tint).frame(width: max(0, g.size.width * min(1, value / max(top, 0.0001))))
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 3)
    }
}

/// Six weeks of seven-day load, drawn over the optimal band it was judged against that day.
struct NoopFitnessLoadHistoryChart: View {
    let series: [(date: Date, reading: AcuteChronicLoad.Reading)]

    var body: some View {
        GeometryReader { geo in
            let top = max(series.map { max($0.reading.acute, $0.reading.optimal.upperBound) }.max() ?? 1, 0.0001) * 1.1
            let n = max(1, series.count - 1)
            let x = { (i: Int) in geo.size.width * Double(i) / Double(n) }
            let y = { (v: Double) in geo.size.height * (1 - v / top) }
            ZStack {
                Path { p in
                    for (i, s) in series.enumerated() {
                        let pt = CGPoint(x: x(i), y: y(s.reading.optimal.upperBound))
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                    for (i, s) in series.enumerated().reversed() { p.addLine(to: CGPoint(x: x(i), y: y(s.reading.optimal.lowerBound))) }
                    p.closeSubpath()
                }
                .fill(NoopHTMLColor.green.opacity(0.16))
                Path { p in
                    for (i, s) in series.enumerated() {
                        let pt = CGPoint(x: x(i), y: y(s.reading.acute))
                        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
                    }
                }
                .stroke(NoopHTMLColor.ink, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                if let last = series.last {
                    Circle().fill(last.reading.status.color).frame(width: 8, height: 8)
                        .position(x: x(series.count - 1), y: y(last.reading.acute))
                }
            }
        }
    }
}

// MARK: - Muscle groups

/// Six weeks of one muscle's working sets as small bars, the 10–20 range drawn behind them; this week
/// is the last, brighter bar.
struct NoopFitnessWeeklySetBars: View {
    let weeks: [Double]
    let range: ClosedRange<Double>

    var body: some View {
        let ceiling = max(range.upperBound + 4, weeks.max() ?? 0)
        let h: CGFloat = 32
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(NoopHTMLColor.green.opacity(0.07))
                .frame(height: h * CGFloat((range.upperBound - range.lowerBound) / ceiling))
                .offset(y: -h * CGFloat(range.lowerBound / ceiling))
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(weeks.enumerated()), id: \.offset) { i, n in
                    let isNow = i == weeks.count - 1
                    let tint: Color = n > range.upperBound ? NoopHTMLColor.warm : n >= range.lowerBound ? NoopHTMLColor.green : NoopHTMLColor.inkSoft
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(tint.opacity(n == 0 ? 0.2 : isNow ? 0.95 : 0.45))
                        .frame(width: 7, height: max(2, h * CGFloat(min(n, ceiling) / ceiling)))
                }
            }
        }
        .frame(width: CGFloat(weeks.count) * 11, height: h, alignment: .bottom)
        .accessibilityElement()
        .accessibilityLabel("Last six weeks: \(weeks.map { String(format: "%.0f", $0) }.joined(separator: ", ")) sets")
    }
}

struct NoopFitnessMuscleGroupsScreen: View {
    enum Mode: String, CaseIterable { case freshness = "Freshness", sets = "Sets", load = "Muscular load", volume = "Volume" }

    /// The weekly working-set range the growth research centres on: clear gains from about ten hard sets a
    /// week per muscle, with returns flattening past about twenty. A reference line, not a target.
    static let setRange: ClosedRange<Double> = 10...20

    @ObservedObject var navigation: NoopNavigation
    @ObservedObject var fitness: NoopFitnessModel
    @State private var mode: Mode = .freshness
    @State private var filter: MuscleFreshness.Status?
    @State private var dayOffset = 0
    @State private var leastFirst = true

    var body: some View {
        NoopFitnessPage(navigation: navigation, title: "Muscle groups") {
            if let h = fitness.snapshot?.history {
                content(h)
            }
        }
    }

    @ViewBuilder
    private func content(_ h: NoopFitnessHistory) -> some View {
        let day = Calendar.current.date(byAdding: .day, value: -dayOffset, to: h.now) ?? h.now
        let fresh = Dictionary(uniqueKeysWithValues: h.freshness(asOf: day).map { ($0.group, $0) })
        let values: [FitnessMuscleGroup: Double] = switch mode {
        case .freshness: fresh.mapValues(\.percent)
        case .sets: h.setsByGroup(asOf: day)
        case .load: h.loadByGroup(asOf: day)
        case .volume: h.volumeByGroup(asOf: day)
        }
        let top = max(values.values.max() ?? 1, 0.0001)
        let weekly = mode == .sets ? h.weeklySetsByGroup(weeks: 6, endingAt: day) : []
        VStack(alignment: .leading, spacing: 14) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        chip(m.rawValue, selected: mode == m) { withAnimation(NoopMotion.swap) { mode = m; filter = nil } }
                    }
                }
            }
            NoopFitnessBodyMap(color: { g in color(g, mode: mode, values: values, fresh: fresh, top: top) })
                .frame(height: 300)
                .frame(maxWidth: .infinity)
            if mode == .freshness {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chip("All", selected: filter == nil) { filter = nil }
                        ForEach([MuscleFreshness.Status.recovered, .fatigued, .depleted, .calibrating], id: \.self) { s in
                            chip(s.rawValue.capitalized, selected: filter == s, dot: NoopFitnessFreshnessCard.color(s)) { filter = s }
                        }
                    }
                }
            }
            HStack {
                arrow(.left, enabled: dayOffset < 41) { dayOffset += 1 }
                Text(dayOffset == 0 ? "Today" : fmtDate(day))
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    .frame(maxWidth: .infinity)
                arrow(.right, enabled: dayOffset > 0) { dayOffset -= 1 }
            }
            .padding(6)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack {
                NoopSectionLabel(mode == .freshness ? "All muscles" : "Last seven days")
                Spacer()
                Button { leastFirst.toggle() } label: {
                    Text(leastFirst ? (mode == .freshness ? "Least recovered first" : "Most first")
                                    : (mode == .freshness ? "Most recovered first" : "Least first"))
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
            let groups = FitnessMuscleGroup.allCases
                .filter { filter == nil || fresh[$0]?.status == filter }
                .sorted { a, b in
                    let va = values[a] ?? 0, vb = values[b] ?? 0
                    let asc = mode == .freshness ? leastFirst : !leastFirst
                    return asc ? va < vb : va > vb
                }
            VStack(spacing: 8) {
                ForEach(groups, id: \.self) { g in
                    HStack(spacing: 12) {
                        Circle().fill(color(g, mode: mode, values: values, fresh: fresh, top: top)).frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            Text(line(g, values: values, fresh: fresh))
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        }
                        Spacer()
                        if mode == .freshness, let r = fresh[g] {
                            NoopFitnessDotMeter(percent: r.untracked ? 0 : r.percent, color: NoopFitnessFreshnessCard.color(r.status))
                        }
                        if mode == .sets {
                            NoopFitnessWeeklySetBars(weeks: weekly.map { $0[g] ?? 0 }, range: Self.setRange)
                        }
                    }
                    .padding(14)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
                }
            }
            Text(mode == .freshness
                 ? "Freshness falls with each set and with the leg work in cardio, and recovers at each muscle's own pace — about a day and a half to halve for legs and lower back, less for arms, calves and abs."
                 : mode == .sets ? "Working sets in the seven days shown: a set counts once for its main muscle and half for each helper. Most growth studies see clear gains from about 10 hard sets a week per muscle, with less to gain past about 20. The bars are the last six weeks."
                 : mode == .load ? "Muscular load per muscle: hard sets count in full, easy ones less, helpers half."
                 : "Weight moved, credited to each exercise's main muscle.")
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func line(_ g: FitnessMuscleGroup, values: [FitnessMuscleGroup: Double],
                      fresh: [FitnessMuscleGroup: MuscleFreshness.Reading]) -> String {
        switch mode {
        case .freshness:
            guard let r = fresh[g] else { return "" }
            if r.untracked { return "No sets logged yet" }
            let status = r.status == .calibrating ? "Calibrating" : r.status.rawValue.capitalized
            return "\(status) · \(Int(r.percent.rounded()))%"
        case .sets:
            let n = values[g] ?? 0
            let count = n == n.rounded() ? "\(Int(n))" : String(format: "%.1f", n)
            let place = n == 0 ? "none this week" : n < Self.setRange.lowerBound ? "under 10"
                : n > Self.setRange.upperBound ? "over 20" : "in the 10–20 range"
            return "\(count) \(n == 1 ? "set" : "sets") · \(place)"
        case .load: return String(format: "%.0f load", values[g] ?? 0)
        case .volume: return NoopFitnessFormat.kg(values[g] ?? 0)
        }
    }

    private func color(_ g: FitnessMuscleGroup, mode: Mode, values: [FitnessMuscleGroup: Double],
                       fresh: [FitnessMuscleGroup: MuscleFreshness.Reading], top: Double) -> Color {
        if let filter, fresh[g]?.status != filter { return Color.white.opacity(0.08) }
        switch mode {
        case .freshness:
            return NoopFitnessFreshnessCard.color(fresh[g]?.status ?? .calibrating).opacity(0.85)
        case .sets:
            let n = values[g] ?? 0
            if n <= 0 { return Color.white.opacity(0.1) }
            if n < Self.setRange.lowerBound { return NoopHTMLColor.green.opacity(0.22 + 0.4 * n / Self.setRange.lowerBound) }
            return n > Self.setRange.upperBound ? NoopHTMLColor.warm.opacity(0.85) : NoopHTMLColor.green.opacity(0.9)
        case .load, .volume:
            let v = (values[g] ?? 0) / top
            return v <= 0 ? Color.white.opacity(0.1) : (mode == .load ? NoopHTMLColor.warm : NoopHTMLColor.blush).opacity(0.25 + 0.7 * v)
        }
    }

    private func chip(_ t: String, selected: Bool, dot: Color? = nil, action: @escaping () -> Void) -> some View {
        NoopChip(title: t, dot: dot, isOn: selected, action: action)
    }

    private func arrow(_ d: NoopFixedChevron.Direction, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            NoopFixedChevron(direction: d, color: enabled ? NoopHTMLColor.inkSoft : NoopHTMLColor.chevronDim)
                .frame(width: 44, height: 40)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
    }
}

#endif
