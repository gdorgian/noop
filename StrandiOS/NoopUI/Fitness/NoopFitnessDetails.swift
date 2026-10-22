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
        default: NoopFitnessHome(navigation: navigation, fitness: fitness, layout: layout)
        }
    }
}

// MARK: - Shared pieces

struct NoopFitnessPage<Content: View>: View {
    @ObservedObject var navigation: NoopNavigation
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopBackHeader(label: "Fitness") { navigation.back(or: .fitness) }
                    .padding(.bottom, 14)
                Text(title)
                    .font(NoopHTMLFont.outfit(27))
                    .foregroundStyle(NoopHTMLColor.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(NoopHTMLFont.sans(13.5))
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
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { d in
                Button { withAnimation(NoopMotion.swap) { days = d } } label: {
                    Text("\(d) days")
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                        .foregroundStyle(days == d ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 34)
                        .background(days == d ? Color.white.opacity(0.09) : .clear,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                Text(title).font(NoopHTMLFont.sans(14, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                if let detail {
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.copy)
                }
            }
            Spacer(minLength: 10)
            Text(value).font(NoopHTMLFont.sans(14, weight: .semibold)).foregroundStyle(valueColor)
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
                Text(title).font(NoopHTMLFont.sans(13.5, weight: .medium)).foregroundStyle(NoopHTMLColor.ink).lineLimit(1)
                if let detail { Text(detail).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.muted) }
                Spacer()
                Text(text).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
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

struct NoopFitnessMuscleGroupsScreen: View {
    enum Mode: String, CaseIterable { case freshness = "Freshness", load = "Muscular load", volume = "Volume" }

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
        case .load: h.loadByGroup(asOf: day)
        case .volume: h.volumeByGroup(asOf: day)
        }
        let top = max(values.values.max() ?? 1, 0.0001)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                ForEach(Mode.allCases, id: \.self) { m in
                    chip(m.rawValue, selected: mode == m) { withAnimation(NoopMotion.swap) { mode = m; filter = nil } }
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
                    .font(NoopHTMLFont.sans(13.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
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
                        .font(NoopHTMLFont.sans(11.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
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
                            Text(g.title).font(NoopHTMLFont.sans(14.5, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                            Text(line(g, values: values, fresh: fresh))
                                .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                        }
                        Spacer()
                        if mode == .freshness, let r = fresh[g] {
                            NoopFitnessDotMeter(percent: r.untracked ? 0 : r.percent, color: NoopFitnessFreshnessCard.color(r.status))
                        }
                    }
                    .padding(14)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
                }
            }
            Text(mode == .freshness
                 ? "Freshness falls with each set and with the leg work in cardio, and recovers at each muscle's own pace — about a day and a half to halve for legs and lower back, less for arms, calves and abs."
                 : mode == .load ? "Muscular load per muscle: hard sets count in full, easy ones less, helpers half."
                 : "Weight moved, credited to each exercise's main muscle.")
                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.muted)
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
        case .load: return String(format: "%.0f load", values[g] ?? 0)
        case .volume: return "\(Int((values[g] ?? 0).rounded()).formatted()) kg"
        }
    }

    private func color(_ g: FitnessMuscleGroup, mode: Mode, values: [FitnessMuscleGroup: Double],
                       fresh: [FitnessMuscleGroup: MuscleFreshness.Reading], top: Double) -> Color {
        if let filter, fresh[g]?.status != filter { return Color.white.opacity(0.08) }
        switch mode {
        case .freshness:
            return NoopFitnessFreshnessCard.color(fresh[g]?.status ?? .calibrating).opacity(0.85)
        case .load, .volume:
            let v = (values[g] ?? 0) / top
            return v <= 0 ? Color.white.opacity(0.1) : (mode == .load ? NoopHTMLColor.warm : NoopHTMLColor.blush).opacity(0.25 + 0.7 * v)
        }
    }

    private func chip(_ t: String, selected: Bool, dot: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
                Text(t).font(NoopHTMLFont.sans(12, weight: .semibold))
            }
            .foregroundStyle(selected ? NoopHTMLColor.canvas : NoopHTMLColor.inkSoft)
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(selected ? NoopHTMLColor.ink : Color.white.opacity(0.06), in: Capsule())
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func arrow(_ d: NoopFixedChevron.Direction, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            NoopFixedChevron(direction: d, color: enabled ? NoopHTMLColor.inkSoft : NoopHTMLColor.chevronDim)
                .frame(width: 36, height: 32)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
    }
}

#endif
