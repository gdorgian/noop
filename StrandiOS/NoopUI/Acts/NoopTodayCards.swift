#if os(iOS)
import Charts
import StrandAnalytics
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
                        .font(NoopHTMLFont.sans(NoopType.caption)).monospacedDigit()
                        .foregroundStyle(NoopHTMLColor.faint)
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.nightLight.opacity(0.7))
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(NoopRestRecord.duration(night.asleepMin))
                        .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light))
                        .tracking(-0.8)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("asleep").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                    Spacer(minLength: 6)
                    if needMin > 0 {
                        Text(diff >= 0 ? "\(NoopRestRecord.duration(diff)) over your need"
                                       : "\(NoopRestRecord.duration(-diff)) short of your need")
                            .font(NoopHTMLFont.sans(NoopType.caption))
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
    /// Today's stress on the 0–3 scale, summarised in a row under the stats that opens the Stress sheet.
    var stress: [(time: Date, level: Double?, masked: Bool)] = []
    var onStress: (() -> Void)? = nil
    let action: () -> Void

    @State private var selected: Date?

    private var hasStress: Bool { stress.contains { $0.level != nil } }

    private var start: Date { sleep?.start ?? points.first?.time ?? Calendar.current.startOfDay(for: Date()) }
    /// Without a night or a reading there is no start to name, only the day itself.
    private var hasRecord: Bool { sleep != nil || !points.isEmpty }
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
                        Text(hasRecord ? "\(AppClock.hourMinuteFormatter().string(from: start)) \u{2192} now" : "Since midnight")
                            .font(NoopHTMLFont.sans(NoopType.caption)).monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                    Spacer()
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(NoopHTMLPressStyle())

            if points.count >= 2 {
                chart.frame(height: 176)
                stats
                if hasStress, let onStress { stressRow(onStress) }
            } else {
                Text(hasRecord
                     ? "No heart rate recorded since \(AppClock.hourMinuteFormatter().string(from: start)). It fills in after the next sync."
                     : "No heart rate recorded today yet. It fills in after the next sync.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
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

    // Built once, not once per point.
    private static let areaFill = LinearGradient(colors: [Color(hex: 0x6FCFB4).opacity(0.16), Color(hex: 0x6FCFB4).opacity(0)],
                                                 startPoint: .top, endPoint: .bottom)
    private static let lineFill = LinearGradient(colors: [Color(hex: 0xF29A5C), Color(hex: 0xC8B27A), Color(hex: 0x6FCFB4), Color(hex: 0x5FB8A8)],
                                                 startPoint: .top, endPoint: .bottom)

    private var chart: some View {
        // The scale and its floor are read once for the whole chart: as computed properties inside
        // the loop they rescanned every point for every point (25 Oct 2026, profiled on device).
        let domain = yDomain
        let floor = domain.lowerBound
        let peak = self.peak
        let selectedPoint = self.selectedPoint
        let now = self.now
        return Chart {
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
                            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                    }
            }
            // A strap off for a quarter hour or more reads as a gap, not a straight line across it.
            NoopGapAwareLine(points: points.map { ($0.time, $0.bpm) }, tint: Color(hex: 0x6FCFB4), floor: floor,
                             lineWidth: 1.8, minimumGap: 15 * 60,
                             lineStyle: AnyShapeStyle(Self.lineFill), areaStyle: AnyShapeStyle(Self.areaFill))
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
                        Text("\(Int(peak.bpm.rounded()))").font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.warm)
                    }
            }
            if let p = selectedPoint {
                RuleMark(x: .value("Time", p.time))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 1) {
                            Text("\(Int(p.bpm.rounded())) bpm").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            Text(AppClock.hourMinuteFormatter().string(from: p.time)).font(NoopHTMLFont.sans(NoopType.eyebrow))
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
        .chartYScale(domain: domain)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.05))
                AxisValueLabel().font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisValueLabel(format: .dateTime.hour()).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
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
        .noopChartZoom()
        .accessibilityLabel("Heart rate from \(AppClock.hourMinuteFormatter().string(from: start)) to now")
    }

    private func stressRow(_ open: @escaping () -> Void) -> some View {
        let current = stress.last(where: { $0.level != nil })?.level
        let highHalfHours = stress.filter { ($0.level ?? 0) >= DaytimeStress.highBandFloor }.count
        return Button(action: open) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(colors: [NoopStressPalette.low, NoopStressPalette.medium, NoopStressPalette.high],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 18, height: 6)
                Text("Stress").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                if let current {
                    Text("\(NoopStressPalette.name(current)) now").font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopStressPalette.color(current))
                }
                if highHalfHours > 0 {
                    Text("· high for about \(NoopRestRecord.duration(Double(highHalfHours * 30)))")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer(minLength: 4)
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
            }
            .frame(minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .padding(.top, 2)
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
                    Text(item.0).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.copy)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(item.1).font(NoopHTMLFont.outfit(NoopType.title3)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                        Text(item.2 ?? "bpm").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
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
#endif
