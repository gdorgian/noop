#if os(iOS)
import Charts
import StrandAnalytics
import StrandDesign
import SwiftUI
import WhoopProtocol

/// Stress on the shared 0–3 scale: low under 1, medium under 2, high from 2 (`DaytimeStress.highBandFloor`).
enum NoopStressPalette {
    static let low = Color(hex: 0x5B9BE0)
    static let medium = Color(hex: 0x5FCF9A)
    static let high = Color(hex: 0xF2A65C)

    static func color(_ level: Double) -> Color {
        level >= DaytimeStress.highBandFloor ? high : level >= 1 ? medium : low
    }

    /// The level as a one-decimal figure, cut rather than rounded so 1.97 shows 1.9, not a
    /// 2.0 that would sit in a different band from its own name.
    static func shown(_ level: Double) -> Double { (level * 10).rounded(.down) / 10 }

    static func name(_ level: Double) -> String {
        level >= DaytimeStress.highBandFloor ? "High" : level >= 1 ? "Medium" : "Low"
    }
}

/// Minutes in each band, from non-overlapping scored hours (each one a full hour).
struct NoopStressBands: Equatable {
    var low = 0, medium = 0, high = 0, moving = 0
    var scored: Int { low + medium + high }

    init() {}
    init(hours: [(level: Double?, masked: Bool)]) {
        for h in hours {
            if let l = h.level {
                if l >= DaytimeStress.highBandFloor { high += 60 } else if l >= 1 { medium += 60 } else { low += 60 }
            } else if h.masked { moving += 60 }
        }
    }
}

/// What the sheet reads beyond today's curve: the same weekday over the last four weeks, scored the
/// same way as today, and the overnight stress model (resting pulse and HRV against a 30-day normal).
@MainActor
final class NoopStressReport: ObservableObject {
    @Published private(set) var typical: NoopStressBands?
    @Published private(set) var typicalDays = 0
    @Published private(set) var overnight: StressModel?
    @Published private(set) var loaded = false

    static let weeksBack = 4

    func load(repo: Repository) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        overnight = StressModel(days: repo.days, stored: await repo.series(key: "stress", source: "my-whoop"))

        let mode = await DaytimeStressMode.selected(repo: repo, startOfToday: today, calendar: calendar,
                                                    personalBaseline: true)
        let sessions = await repo.allSleepSessions(days: 40)
        var days: [NoopStressBands] = []
        for week in 1...Self.weeksBack {
            guard let dayStart = calendar.date(byAdding: .day, value: -7 * week, to: today).map(calendar.startOfDay),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart).map(calendar.startOfDay) else { continue }
            let from = Int(dayStart.timeIntervalSince1970), to = Int(dayEnd.timeIntervalSince1970) - 1
            // Scored the same way as today: that day's sleep is drawn but kept out of its reference.
            let sleeps = sessions.filter { $0.endTs >= from && $0.effectiveStartTs <= to }
                .map { $0.effectiveStartTs...$0.endTs }
            let hr = await repo.hrSamples(from: from, to: to, limit: 200_000)
            guard hr.count >= DaytimeStress.minHourHRSamples * 3 else { continue }
            let rr = await repo.rrIntervals(from: from, to: to, limit: 200_000)
            let gravity = await repo.gravitySamplesUnion(from: from, to: to, limit: 200_000)
            let tz = TimeZone.current.secondsFromGMT(for: dayStart)
            let result = await Task.detached(priority: .utility) {
                DaytimeStress.analyze(hr: hr, rr: rr, gravity: gravity, tzOffsetSeconds: tz, mode: mode, asleep: sleeps)
            }.value
            let bands = NoopStressBands(hours: result.hours.map { ($0.level, $0.maskedForActivity) })
            if bands.scored >= 180 { days.append(bands) }
        }
        typicalDays = days.count
        if !days.isEmpty {
            var avg = NoopStressBands()
            avg.low = days.map(\.low).reduce(0, +) / days.count
            avg.medium = days.map(\.medium).reduce(0, +) / days.count
            avg.high = days.map(\.high).reduce(0, +) / days.count
            typical = avg
        }
        loaded = true
    }
}

/// The Stress sheet opened from Your day (23 Oct 2026).
struct NoopStressSheet: View {
    let timeline: [(time: Date, level: Double?, masked: Bool)]
    let scoredHours: [(start: Date, level: Double?, masked: Bool)]
    let sleep: (start: Date, end: Date)?
    let sessions: [(start: Date, end: Date, sport: String)]
    let personal: Bool
    var onBreathe: (() -> Void)? = nil

    @EnvironmentObject private var repo: Repository
    @Environment(\.dismiss) private var dismiss
    @StateObject private var report = NoopStressReport()
    @State private var selected: Date?

    private var weekday: String { Date().formatted(.dateTime.weekday(.wide)) }
    private var today: NoopStressBands { NoopStressBands(hours: scoredHours.map { ($0.level, $0.masked) }) }
    private var current: (time: Date, level: Double)? {
        timeline.last(where: { $0.level != nil }).map { ($0.time, NoopStressPalette.shown($0.level!)) }
    }
    private var chartStart: Date {
        let first = timeline.first(where: { $0.level != nil })?.time.addingTimeInterval(-1800)
        return [sleep?.start, first].compactMap { $0 }.min() ?? Calendar.current.startOfDay(for: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                NoopStressGauge(level: current?.level, updated: current?.time, comparison: gaugeComparison)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                card { VStack(alignment: .leading, spacing: 10) { label("Today"); chart.frame(height: 190) } }
                insight
                comparisonCard
                overnightCard
                if let onBreathe { breatheCard(onBreathe) }
                Text(methodNote)
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .task { await report.load(repo: repo) }
    }

    // MARK: Pieces

    private var header: some View {
        NoopSheetHeader(title: "Stress", subtitle: Date().formatted(.dateTime.weekday(.wide).day().month(.wide))) {
            dismiss()
        }
        .padding(.top, 18)
    }

    private func card<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func label(_ text: String) -> some View { NoopSectionLabel(text) }

    /// Under the gauge: how the day so far compares with a typical one of the same weekday.
    private var gaugeComparison: String? {
        guard let typical = report.typical, today.scored > 0, typical.scored > 0 else { return nil }
        let t = Double(today.high) / Double(today.scored), u = Double(typical.high) / Double(typical.scored)
        if abs(t - u) < 0.1 { return "About as much high stress as a typical \(weekday)" }
        return t > u ? "More high stress than a typical \(weekday)" : "Less high stress than a typical \(weekday)"
    }

    private var insight: some View {
        let b = today
        let text: String
        if b.scored == 0 {
            text = "No hour has been scored yet today. It needs about an hour of heart rate while you're awake and still."
        } else {
            let dominant = [("low", b.low), ("medium", b.medium), ("high", b.high)].max { $0.1 < $1.1 }!.0
            var t = "Most of your scored time today was \(dominant) stress."
            var best: (start: Date, count: Int)?, run: (start: Date, count: Int)?
            for h in scoredHours {
                if let l = h.level, l >= DaytimeStress.highBandFloor {
                    run = run.map { ($0.start, $0.count + 1) } ?? (h.start, 1)
                    if (run?.count ?? 0) > (best?.count ?? 0) { best = run }
                } else { run = nil }
            }
            if let best {
                t += " The longest high stretch began at \(AppClock.hourMinuteFormatter().string(from: best.start)) and lasted \(best.count == 1 ? "an hour" : "\(best.count) hours")."
            } else {
                t += " Nothing reached high."
            }
            if let peak = scoredHours.filter({ $0.level != nil }).max(by: { $0.level! < $1.level! }), let l = peak.level {
                t += " Peak \(l.formatted(.number.precision(.fractionLength(1)))) at \(AppClock.hourMinuteFormatter().string(from: peak.start))."
            }
            text = t
        }
        return Text(text)
            .font(NoopHTMLFont.sans(NoopType.subhead)).foregroundStyle(NoopHTMLColor.inkSoft)
            .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(LinearGradient(colors: [NoopStressPalette.low.opacity(0.5), NoopStressPalette.medium.opacity(0.4),
                                                      NoopStressPalette.high.opacity(0.5)],
                                             startPoint: .leading, endPoint: .trailing), lineWidth: 0.8))
    }

    // MARK: Today vs typical weekday

    private var comparisonCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    label("Today")
                    Text("vs typical \(weekday)".uppercased())
                        .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.2)
                        .foregroundStyle(NoopHTMLColor.faint)
                }
                bandBar(today, dim: false)
                if let typical = report.typical { bandBar(typical, dim: true) }
                HStack(alignment: .top, spacing: 0) {
                    column("Low", today.low, report.typical?.low, NoopStressPalette.low, higherIsBetter: true)
                    column("Medium", today.medium, report.typical?.medium, NoopStressPalette.medium, higherIsBetter: nil)
                    column("High", today.high, report.typical?.high, NoopStressPalette.high, higherIsBetter: false)
                }
                Text(report.typical != nil
                     ? "Upper bar today so far, lower bar the average of your last \(report.typicalDays) \(weekday)\(report.typicalDays == 1 ? "" : "s"), whole days."
                     : report.loaded
                        ? "No earlier \(weekday) has enough scored hours yet. The comparison appears once one does."
                        : "Reading your last \(NoopStressReport.weeksBack) \(weekday)s…")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func bandBar(_ b: NoopStressBands, dim: Bool) -> some View {
        GeometryReader { proxy in
            let total = CGFloat(max(b.scored, 1))
            HStack(spacing: 3) {
                ForEach([(b.low, NoopStressPalette.low), (b.medium, NoopStressPalette.medium), (b.high, NoopStressPalette.high)],
                        id: \.1.description) { minutes, color in
                    if minutes > 0 {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(dim ? 0.38 : 1))
                            .frame(width: max(6, (proxy.size.width - 6) * CGFloat(minutes) / total))
                    }
                }
                if b.scored == 0 {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06))
                }
            }
        }
        .frame(height: dim ? 7 : 12)
    }

    private func column(_ name: String, _ minutes: Int, _ typical: Int?, _ color: Color, higherIsBetter: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(NoopStressSheet.clock(minutes))
                .font(NoopHTMLFont.outfit(NoopType.title3)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
            if let typical, typical > 0 {
                let delta = Double(minutes - typical) / Double(typical)
                let good = higherIsBetter.map { $0 == (delta >= 0) }
                HStack(spacing: 3) {
                    Image(systemName: delta >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill").font(.system(size: 7))
                    Text("\(Int(abs(delta * 100).rounded()))%").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).monospacedDigit()
                }
                .foregroundStyle(good == nil ? NoopHTMLColor.inkSoft : good! ? Color(hex: 0x8FE3B4) : NoopStressPalette.high)
                .padding(.horizontal, 6).frame(minHeight: 20)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
                Text(name.uppercased()).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func clock(_ minutes: Int) -> String { String(format: "%d:%02d", minutes / 60, minutes % 60) }

    // MARK: Overnight

    @ViewBuilder private var overnightCard: some View {
        if let m = report.overnight {
            card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        label("Coming into today")
                        Spacer()
                        Text("\(m.score.formatted(.number.precision(.fractionLength(1)))) \u{00B7} \(NoopStressPalette.name(m.score))")
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            .foregroundStyle(NoopStressPalette.color(m.score))
                            .padding(.horizontal, 9).frame(minHeight: 24)
                            .background(NoopStressPalette.color(m.score).opacity(0.13), in: Capsule())
                    }
                    Text(m.explanation)
                        .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.inkSoft)
                        .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 0) {
                        overnightStat("Resting pulse", m.rhrToday.map { "\($0)" }, "bpm",
                                      m.rhrDelta.map { String(format: "%+.0f vs normal", $0) })
                        overnightStat("HRV", m.hrvToday.map { String(format: "%.0f", $0) }, "ms",
                                      m.hrvDelta.map { String(format: "%+.0f vs normal", $0) })
                        overnightStat("Calm days", m.calmTimeValue, nil, m.calmTimeCaption)
                    }
                    if m.sparkValues.count >= 3 {
                        VStack(alignment: .leading, spacing: 5) {
                            Chart {
                                ForEach(Array(m.sparkValues.enumerated()), id: \.offset) { i, v in
                                    BarMark(x: .value("Night", i), y: .value("Stress", v), width: .fixed(9))
                                        .foregroundStyle(NoopStressPalette.color(v).opacity(i == m.sparkValues.count - 1 ? 1 : 0.55))
                                        .cornerRadius(3)
                                }
                            }
                            .chartYScale(domain: 0...3)
                            .chartXAxis(.hidden).chartYAxis(.hidden)
                            .noopChart(x: Int.self, snap: Array(m.sparkValues.indices)) { i in
                                m.sparkValues.indices.contains(i)
                                    ? NoopChartReadout(value: NoopStressPalette.name(m.sparkValues[i]),
                                                       detail: i == m.sparkValues.count - 1 ? "Last night"
                                                           : "\(m.sparkValues.count - 1 - i) nights ago")
                                    : nil
                            }
                            .frame(height: 46)
                            Text("Last \(m.sparkValues.count) nights").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                        }
                    }
                }
            }
        }
    }

    private func overnightStat(_ name: String, _ value: String?, _ unit: String?, _ note: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.copy)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value ?? "\u{2014}").font(NoopHTMLFont.outfit(NoopType.title3)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                if let unit, value != nil { Text(unit).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint) }
            }
            if let note { Text(note).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineLimit(1).minimumScaleFactor(0.8) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func breatheCard(_ open: @escaping () -> Void) -> some View {
        Button {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: open)
        } label: {
            HStack(spacing: 14) {
                Circle()
                    .fill(RadialGradient(colors: [NoopHTMLColor.blueLight, NoopHTMLColor.blue.opacity(0.4)],
                                         center: .center, startRadius: 2, endRadius: 22))
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Bring it down").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text("Breathe with the orb: four in, four held, four out, four held.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
            }
            .padding(16)
            .background(NoopHTMLColor.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(NoopHTMLColor.blue.opacity(0.24), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var methodNote: String {
        var t = personal
            ? "Each waking hour's heart rate is compared with your own calm daytime level over the last 30 days."
            : "There isn't enough history for your own baseline yet, so each waking hour is compared with today's calmest waking hours. It switches to your 30-day baseline on its own once it has the days."
        t += " Sleep is scored and drawn, but never used as the calm reference. Hours you were moving are left out, because exertion is not stress"
        t += today.moving > 0 ? " (\(NoopRestRecord.duration(Double(today.moving))) of moving today)." : "."
        t += " Coming into today reads last night's resting pulse and HRV against your 30-day normal. Estimates, not a diagnosis."
        return t
    }

    // MARK: Chart

    private var segments: [[(time: Date, level: Double)]] {
        var out: [[(time: Date, level: Double)]] = [[]]
        for p in timeline {
            if let level = p.level { out[out.count - 1].append((p.time, level)) }
            else if !(out.last ?? []).isEmpty { out.append([]) }
        }
        return out.filter { !$0.isEmpty }
    }

    private var selectedPoint: (time: Date, level: Double)? {
        guard let selected else { return nil }
        return timeline.compactMap { p in p.level.map { (p.time, $0) } }
            .min { abs($0.time.timeIntervalSince(selected)) < abs($1.time.timeIntervalSince(selected)) }
    }

    private var chart: some View {
        Chart {
            if let sleep, sleep.end > chartStart {
                bandMarks(from: max(sleep.start, chartStart), to: min(sleep.end, Date()), tint: NoopHTMLColor.night, symbol: "moon.fill")
            }
            ForEach(Array(sessions.enumerated()), id: \.offset) { _, s in
                bandMarks(from: s.start, to: max(s.end, s.start.addingTimeInterval(600)), tint: NoopHTMLColor.warm,
                          symbol: NoopFitnessCardioLive.symbol(for: s.sport))
            }
            let runs = segments
            ForEach(Array(runs.enumerated()), id: \.offset) { index, seg in
                ForEach(Array(seg.enumerated()), id: \.offset) { _, p in
                    LineMark(x: .value("Time", p.time), y: .value("Stress", p.level), series: .value("Run", index))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(Self.levelGradient(seg.map(\.level)))
                }
            }
            // Where no reading was taken, the runs are joined by the dim dashed bridge every chart uses.
            ForEach(Array(runs.indices.dropFirst()), id: \.self) { k in
                if let a = runs[k - 1].last, let b = runs[k].first {
                    ForEach([a, b], id: \.time) { p in
                        LineMark(x: .value("Time", p.time), y: .value("Stress", p.level), series: .value("Run", "gap\(k)"))
                            .foregroundStyle(NoopChartGaps.bridgeStyle)
                            .lineStyle(NoopChartGaps.bridgeStroke)
                    }
                }
            }
            if let p = selectedPoint {
                RuleMark(x: .value("Time", p.time))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 1) {
                            Text("\(p.level.formatted(.number.precision(.fractionLength(1)))) · \(NoopStressPalette.name(p.level))")
                                .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            Text(AppClock.hourMinuteFormatter().string(from: p.time)).font(NoopHTMLFont.sans(NoopType.eyebrow))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        .foregroundStyle(NoopHTMLColor.ink)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 8))
                    }
                PointMark(x: .value("Time", p.time), y: .value("Stress", p.level))
                    .symbolSize(40).foregroundStyle(NoopStressPalette.color(p.level))
            }
        }
        .padding(.top, 22)
        .chartXScale(domain: chartStart...max(Date(), chartStart.addingTimeInterval(3600)))
        .chartYScale(domain: 0...3)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 1, 2, 3]) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel { Text("\(v.as(Int.self) ?? 0).0") }
                    .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.hour()).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let frame = proxy.plotFrame else { return }
                            if let date: Date = proxy.value(atX: value.location.x - geo[frame].origin.x) { selected = date }
                        }
                        .onEnded { _ in withAnimation(.easeOut(duration: 0.2)) { selected = nil } })
            }
        }
        .sensoryFeedback(.selection, trigger: selectedPoint?.time)
        .noopChartZoom()
    }

    /// A gradient pinned to the 0–3 scale rather than to the segment's own height. Swift Charts
    /// stretches a series' gradient over that series' bounds, so the stops are placed where each
    /// band edge falls inside this segment's range.
    static func levelGradient(_ levels: [Double]) -> LinearGradient {
        let lo = levels.min() ?? 0, hi = levels.max() ?? 3
        let span = max(hi - lo, 0.001)
        func at(_ level: Double) -> Double { min(1, max(0, (hi - level) / span)) }   // 0 = top
        let stops: [Gradient.Stop] = [
            .init(color: NoopStressPalette.color(hi), location: 0),
            .init(color: NoopStressPalette.high, location: at(DaytimeStress.highBandFloor)),
            .init(color: NoopStressPalette.medium, location: at(DaytimeStress.highBandFloor - 0.001)),
            .init(color: NoopStressPalette.medium, location: at(1)),
            .init(color: NoopStressPalette.low, location: at(0.999)),
            .init(color: NoopStressPalette.color(lo), location: 1),
        ].sorted { $0.location < $1.location }
        return LinearGradient(stops: stops, startPoint: .top, endPoint: .bottom)
    }

    @ChartContentBuilder
    private func bandMarks(from: Date, to: Date, tint: Color, symbol: String) -> some ChartContent {
        RectangleMark(xStart: .value("From", from), xEnd: .value("To", to), yStart: .value("Floor", 0), yEnd: .value("Top", 3))
            .foregroundStyle(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.04)], startPoint: .top, endPoint: .bottom))
        RectangleMark(xStart: .value("From", from), xEnd: .value("To", to), yStart: .value("Edge", 2.96), yEnd: .value("Top", 3))
            .foregroundStyle(tint.opacity(0.9))
            .annotation(position: .top, alignment: .center, spacing: 5) {
                Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint == NoopHTMLColor.night ? NoopHTMLColor.nightLight : tint)
            }
    }
}

// MARK: - Gauge

/// A 240° dial in three bands. The bands sit dim; the part up to now is lit in its band's colour
/// with a soft glow, ticks mark every half point, and a thin needle tip rides the outer edge.
struct NoopStressGauge: View {
    let level: Double?
    let updated: Date?
    let comparison: String?

    private static let sweep = 240.0
    private static let startAngle = 150.0          // degrees, clockwise from 3 o'clock
    private let size: CGFloat = 230
    private let line: CGFloat = 14

    private func angle(_ v: Double) -> Double { Self.startAngle + Self.sweep * min(max(v, 0), 3) / 3 }

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { band in
                let from = Double(band), to = Double(band + 1)
                let color = [NoopStressPalette.low, NoopStressPalette.medium, NoopStressPalette.high][band]
                arc(from: from + (band == 0 ? 0 : 0.04), to: to - (band == 2 ? 0 : 0.04))
                    .stroke(color.opacity(0.16), style: StrokeStyle(lineWidth: line, lineCap: .round))
                if let level, level > from {
                    arc(from: from + (band == 0 ? 0 : 0.04), to: min(level, to - (band == 2 ? 0 : 0.04)))
                        .stroke(color, style: StrokeStyle(lineWidth: line, lineCap: .round))
                        .shadow(color: color.opacity(level < to ? 0.7 : 0.25), radius: level < to ? 9 : 3)
                }
            }
            ForEach(0...6, id: \.self) { i in
                let a = angle(Double(i) / 2) * .pi / 180
                let r1 = size / 2 + line / 2 + 5, r2 = r1 + (i % 2 == 0 ? 7 : 4)
                Path { p in
                    p.move(to: CGPoint(x: size / 2 + cos(a) * r1, y: size / 2 + sin(a) * r1))
                    p.addLine(to: CGPoint(x: size / 2 + cos(a) * r2, y: size / 2 + sin(a) * r2))
                }
                .stroke(Color.white.opacity(i % 2 == 0 ? 0.35 : 0.18), lineWidth: 1.2)
            }
            if let level {
                let a = angle(level) * .pi / 180
                let r = size / 2
                Circle()
                    .fill(NoopHTMLColor.ink)
                    .frame(width: line - 4, height: line - 4)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .position(x: size / 2 + cos(a) * r, y: size / 2 + sin(a) * r)
            }
            VStack(spacing: 2) {
                Text(level.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "\u{2014}")
                    .font(NoopHTMLFont.outfit(58, weight: .light)).monospacedDigit()
                    .foregroundStyle(NoopHTMLColor.ink)
                if let level {
                    Text(NoopStressPalette.name(level).uppercased())
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .bold)).tracking(2)
                        .foregroundStyle(NoopStressPalette.color(level))
                }
                Text(updated.map { "Updated \(AppClock.hourMinuteFormatter().string(from: $0))" } ?? "No scored hour yet today")
                    .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                    .padding(.top, 2)
            }
            .offset(y: 6)
            HStack {
                Text("0")
                Spacer()
                Text("3")
            }
            .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).foregroundStyle(NoopHTMLColor.faint)
            .frame(width: size * 0.62)
            .offset(y: size * 0.42)
        }
        .frame(width: size, height: size)
        .padding(.bottom, -size * 0.06)
        .overlay(alignment: .bottom) {
            if let comparison {
                Text(comparison)
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft)
                    .padding(.horizontal, 12).frame(minHeight: 28)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .offset(y: 30)
            }
        }
        .padding(.bottom, comparison == nil ? 0 : 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(level.map { "Stress \($0.formatted(.number.precision(.fractionLength(1)))) of 3, \(NoopStressPalette.name($0))" } ?? "No stress score yet")
    }

    private func arc(from: Double, to: Double) -> Path {
        Path { p in
            p.addArc(center: CGPoint(x: size / 2, y: size / 2), radius: size / 2,
                     startAngle: .degrees(angle(from)), endAngle: .degrees(angle(to)), clockwise: false)
        }
    }
}
#endif
