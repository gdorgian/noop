#if os(iOS)
import Charts
import SwiftUI

// MARK: - Last night

/// Today's sleep card (23 Oct 2026). It replaces the one-line "Last night" note and the Rest row:
/// the night gets the room it had as its own tab — time asleep against need, the stage timeline,
/// the four totals and any debt — and the whole card is the door to Rest.
struct NoopTodayNightCard: View {
    let night: NoopRestRecord.Night
    let needMin: Double
    var nightWorker = false
    let action: () -> Void

    static let stageColors: [Color] = [Color.white.opacity(0.32), NoopHTMLColor.nightLight,
                                       Color(hex: 0x4FB8E8), Color(hex: 0x5D6BC4)]

    private var recent: Bool { Date().timeIntervalSince(night.endDate) < 36 * 3600 }
    private var diff: Double { (night.asleepMin - needMin).rounded() }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Image(systemName: "moon.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(NoopHTMLColor.night)
                    NoopSectionLabel(recent ? (nightWorker ? "Last sleep" : "Last night") : night.longDate,
                                     color: NoopHTMLColor.nightLight)
                    Spacer()
                    Text(night.asleepWindow)
                        .font(NoopHTMLFont.sans(11.5)).monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.faint)
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.nightLight.opacity(0.7))
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(NoopRestRecord.duration(night.asleepMin))
                        .font(NoopHTMLFont.outfit(30, weight: .light))
                        .tracking(-0.8)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("asleep").font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                    Spacer(minLength: 6)
                    if needMin > 0 {
                        Text(diff >= 0 ? "\(NoopRestRecord.duration(diff)) over your need"
                                       : "\(NoopRestRecord.duration(-diff)) short of your need")
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(diff >= 0 ? Color(hex: 0x8FE3B4) : NoopHTMLColor.copy)
                    }
                }
                // The night at a glance: one strip, each slice in its stage's colour.
                if let slices = night.slices, slices.count > 3 {
                    HStack(spacing: 0) {
                        ForEach(Array(slices.enumerated()), id: \.offset) { _, stage in
                            Rectangle().fill(Self.stageColors[min(max(stage, 0), 3)])
                        }
                    }
                    .frame(height: 8)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.night.opacity(0.09), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(NoopHTMLColor.night.opacity(0.22), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Rest")
    }
}

/// A stepped hypnogram: four lanes (awake on top, deep at the bottom), each run of one stage a
/// rounded bar in its lane, joined by hairlines where the night changed stage.
struct NoopStageTimeline: View {
    let slices: [Int]
    let colors: [Color]
    /// When set, every other stage is drawn faint.
    var selected: Int? = nil

    var body: some View {
        Canvas { context, size in
            let laneH = size.height / 4
            let barH = max(6, laneH * 0.62)
            let w = size.width / CGFloat(slices.count)
            // Lanes top to bottom: awake, REM, light, deep.
            func laneY(_ stage: Int) -> CGFloat { CGFloat([0, 2, 1, 3][min(max(stage, 0), 3)]) * laneH + laneH / 2 }
            // Runs of the same stage.
            var runs: [(stage: Int, from: Int, to: Int)] = []
            for (i, s) in slices.enumerated() {
                if let last = runs.last, last.stage == s { runs[runs.count - 1].to = i } else { runs.append((s, i, i)) }
            }
            // Lane guides.
            for lane in 0..<4 {
                var guide = Path()
                guide.move(to: CGPoint(x: 0, y: CGFloat(lane) * laneH + laneH / 2))
                guide.addLine(to: CGPoint(x: size.width, y: CGFloat(lane) * laneH + laneH / 2))
                context.stroke(guide, with: .color(.white.opacity(0.04)), lineWidth: 1)
            }
            // Transitions.
            for i in 1..<max(runs.count, 1) where runs.count > 1 {
                let x = CGFloat(runs[i].from) * w
                var link = Path()
                link.move(to: CGPoint(x: x, y: laneY(runs[i - 1].stage)))
                link.addLine(to: CGPoint(x: x, y: laneY(runs[i].stage)))
                context.stroke(link, with: .color(.white.opacity(0.16)), lineWidth: 1)
            }
            for run in runs {
                let rect = CGRect(x: CGFloat(run.from) * w, y: laneY(run.stage) - barH / 2,
                                  width: max(2, CGFloat(run.to - run.from + 1) * w), height: barH)
                let base = colors[min(max(run.stage, 0), 3)]
                let color = selected == nil || selected == run.stage ? base : Color.white.opacity(0.07)
                if run.stage == 3 && (selected == nil || selected == 3) {
                    var glow = context
                    glow.addFilter(.shadow(color: color.opacity(0.8), radius: 5))
                    glow.fill(Path(roundedRect: rect, cornerRadius: barH / 2), with: .color(color))
                } else {
                    context.fill(Path(roundedRect: rect, cornerRadius: barH / 2), with: .color(color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Your day

/// Today's heart card (23 Oct 2026), replacing "The day so far" and the Heart row: one line from
/// last night's bedtime to now, so the night's low runs straight into the day. Sleep is shaded,
/// recorded sessions are marked, the resting line is dashed, and a finger scrubs any moment.
struct NoopTodayDayRibbon: View {
    let points: [(time: Date, bpm: Double)]
    let sleep: (start: Date, end: Date)?
    let sessions: [(start: Date, end: Date, sport: String)]
    let resting: Double?
    let liveBPM: Int?
    let action: () -> Void

    @State private var selected: Date?

    private var start: Date { sleep?.start ?? points.first?.time ?? Date() }
    private var now: Date { Date() }
    private var peak: (time: Date, bpm: Double)? {
        let awake = points.filter { p in sleep.map { p.time >= $0.end } ?? true }
        return awake.max { $0.bpm < $1.bpm }
    }
    private var sleepLow: Double? {
        guard let sleep else { return nil }
        return points.filter { $0.time >= sleep.start && $0.time <= sleep.end }.map(\.bpm).min()
    }
    /// The plot's top is the day's highest reading (to the next 5 bpm), so the line fills the
    /// height and the sleep and session bands' top edge sits right above it, as a ceiling.
    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.bpm) + [resting].compactMap { $0 }
        let lo = ((values.min() ?? 50) - 2) / 5, hi = ((values.max() ?? 120) + 1) / 5
        let floor = lo.rounded(.down) * 5, ceil = hi.rounded(.up) * 5
        return max(30, floor)...max(floor + 15, ceil)
    }
    private var selectedPoint: (time: Date, bpm: Double)? {
        guard let selected else { return nil }
        return points.min { abs($0.time.timeIntervalSince(selected)) < abs($1.time.timeIntervalSince(selected)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: action) {
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        NoopSectionLabel("Your day")
                        Text("\(AppClock.hourMinuteFormatter().string(from: start)) \u{2192} now")
                            .font(NoopHTMLFont.sans(11.5)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                    Spacer()
                    livePill
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(NoopHTMLPressStyle())

            if points.count >= 2 {
                chart.frame(height: 176)
                stats
            } else {
                Text("No heart rate recorded since \(AppClock.hourMinuteFormatter().string(from: start)). It fills in after the next sync.")
                    .font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var livePill: some View {
        let shown = liveBPM ?? points.last.map { Int($0.bpm.rounded()) }
        return HStack(spacing: 5) {
            NoopTodayBeatDot(live: liveBPM != nil)
            Text(shown.map(String.init) ?? "\u{2014}")
                .font(NoopHTMLFont.outfit(17)).monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink)
            Text(liveBPM != nil ? "now" : "last")
                .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .background(Color.white.opacity(0.05), in: Capsule())
    }

    private var chart: some View {
        Chart {
            // Sleep and sessions as bands: a soft fill, a bright top edge, and the icon centred
            // above it, so either reads at a glance across the whole line.
            if let sleep {
                band(from: sleep.start, to: min(sleep.end, now), tint: NoopHTMLColor.night, symbol: "moon.fill")
            }
            ForEach(Array(sessions.enumerated()), id: \.offset) { _, s in
                band(from: s.start, to: max(s.end, s.start.addingTimeInterval(600)), tint: NoopHTMLColor.warm,
                     symbol: NoopFitnessCardioLive.symbol(for: s.sport))
            }
            if let resting {
                RuleMark(y: .value("Resting", resting))
                    .foregroundStyle(Color.white.opacity(0.22))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                    .annotation(position: .bottom, alignment: .trailing, spacing: 1) {
                        Text("resting \(Int(resting.rounded()))")
                            .font(NoopHTMLFont.sans(9)).foregroundStyle(NoopHTMLColor.faint)
                    }
            }
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Time", p.time), yStart: .value("Floor", yDomain.lowerBound), yEnd: .value("bpm", p.bpm))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0x6FCFB4).opacity(0.16), Color(hex: 0x6FCFB4).opacity(0)],
                                                    startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Time", p.time), y: .value("bpm", p.bpm))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: 0xF29A5C), Color(hex: 0xC8B27A), Color(hex: 0x6FCFB4), Color(hex: 0x5FB8A8)],
                                                    startPoint: .top, endPoint: .bottom))
            }
            if let last = points.last, selected == nil {
                PointMark(x: .value("Time", last.time), y: .value("bpm", last.bpm))
                    .symbolSize(38)
                    .foregroundStyle(Color(hex: 0x6FCFB4))
            }
            // Inside a session the band already marks it; the label would sit on the band's edge.
            if let peak, selected == nil, !sessions.contains(where: { peak.time >= $0.start && peak.time <= $0.end }) {
                PointMark(x: .value("Time", peak.time), y: .value("bpm", peak.bpm))
                    .symbolSize(22)
                    .foregroundStyle(NoopHTMLColor.warm)
                    .annotation(position: .trailing, spacing: 3) {
                        Text("\(Int(peak.bpm.rounded()))").font(NoopHTMLFont.sans(10, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.warm)
                    }
            }
            if let p = selectedPoint {
                RuleMark(x: .value("Time", p.time))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 1) {
                            Text("\(Int(p.bpm.rounded())) bpm").font(NoopHTMLFont.sans(12, weight: .semibold))
                            Text(AppClock.hourMinuteFormatter().string(from: p.time)).font(NoopHTMLFont.sans(10))
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                        .foregroundStyle(NoopHTMLColor.ink)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(NoopHTMLColor.cardRaised, in: RoundedRectangle(cornerRadius: 8))
                    }
                PointMark(x: .value("Time", p.time), y: .value("bpm", p.bpm))
                    .symbolSize(40).foregroundStyle(NoopHTMLColor.ink)
            }
        }
        .padding(.top, 22)
        .chartXScale(domain: start...max(now, start.addingTimeInterval(3600)))
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel().font(NoopHTMLFont.sans(9)).foregroundStyle(NoopHTMLColor.faint)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel(format: .dateTime.hour()).font(NoopHTMLFont.sans(9.5)).foregroundStyle(NoopHTMLColor.faint)
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard let frame = proxy.plotFrame else { return }
                            let x = value.location.x - geo[frame].origin.x
                            if let date: Date = proxy.value(atX: x) { selected = date }
                        }
                        .onEnded { _ in withAnimation(.easeOut(duration: 0.2)) { selected = nil } })
            }
        }
        .sensoryFeedback(.selection, trigger: selectedPoint?.time)
        .accessibilityLabel("Heart rate from \(AppClock.hourMinuteFormatter().string(from: start)) to now")
    }

    @ChartContentBuilder
    private func band(from: Date, to: Date, tint: Color, symbol: String) -> some ChartContent {
        RectangleMark(xStart: .value("From", from), xEnd: .value("To", to),
                      yStart: .value("Floor", yDomain.lowerBound), yEnd: .value("Top", yDomain.upperBound))
            .foregroundStyle(LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.04)], startPoint: .top, endPoint: .bottom))
        RectangleMark(xStart: .value("From", from), xEnd: .value("To", to),
                      yStart: .value("Edge", yDomain.upperBound - (yDomain.upperBound - yDomain.lowerBound) * 0.012),
                      yEnd: .value("Top", yDomain.upperBound))
            .foregroundStyle(tint.opacity(0.9))
            .annotation(position: .top, alignment: .center, spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint == NoopHTMLColor.night ? NoopHTMLColor.nightLight : tint)
            }
    }

    private var stats: some View {
        let items: [(String, String, String?)] = [
            ("Resting", resting.map { "\(Int($0.rounded()))" } ?? "\u{2014}", nil),
            ("Asleep low", sleepLow.map { "\(Int($0.rounded()))" } ?? "\u{2014}", nil),
            ("Peak", peak.map { "\(Int($0.bpm.rounded()))" } ?? "\u{2014}",
             peak.map { AppClock.hourMinuteFormatter().string(from: $0.time) }),
        ]
        return HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.0).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.copy)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(item.1).font(NoopHTMLFont.outfit(19)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                        Text(item.2 ?? "bpm").font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if i < items.count - 1 {
                    Rectangle().fill(NoopHTMLColor.border).frame(width: 0.5, height: 28).padding(.trailing, 10)
                }
            }
        }
    }
}

/// A small heart that beats while live heart rate is arriving and rests when it isn't.
private struct NoopTodayBeatDot: View {
    let live: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(live ? Color(hex: 0xF07A6A) : NoopHTMLColor.faint)
            .scaleEffect(on ? 1.18 : 0.92)
            .onAppear {
                guard live, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { on = true }
            }
    }
}
#endif
