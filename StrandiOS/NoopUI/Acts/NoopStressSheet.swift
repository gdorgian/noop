#if os(iOS)
import Charts
import StrandAnalytics
import SwiftUI

/// Stress on the shared 0–3 scale: low under 1, medium under 2, high from 2 (`DaytimeStress.highBandFloor`).
enum NoopStressPalette {
    static let low = Color(hex: 0x5B9BE0)
    static let medium = Color(hex: 0x5FCF9A)
    static let high = Color(hex: 0xF2A65C)

    static func color(_ level: Double) -> Color {
        level >= DaytimeStress.highBandFloor ? high : level >= 1 ? medium : low
    }

    static func name(_ level: Double) -> String {
        level >= DaytimeStress.highBandFloor ? "High" : level >= 1 ? "Medium" : "Low"
    }
}

/// The Stress sheet opened from Your day (23 Oct 2026): a 0–3 gauge for now, the day's line with sleep
/// and sessions marked, one sentence about the day, and time in each band.
struct NoopStressSheet: View {
    let timeline: [(time: Date, level: Double?, masked: Bool)]
    let scoredHours: [(start: Date, level: Double?, masked: Bool)]
    let sleep: (start: Date, end: Date)?
    let sessions: [(start: Date, end: Date, sport: String)]
    let personal: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Date?

    private var current: (time: Date, level: Double)? {
        timeline.last(where: { $0.level != nil }).map { ($0.time, $0.level!) }
    }
    private var dayStart: Date {
        min(sleep?.start ?? Date(), timeline.first?.time ?? Date(), Calendar.current.startOfDay(for: Date()))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Stress").font(NoopHTMLFont.outfit(26)).foregroundStyle(NoopHTMLColor.ink)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(width: 32, height: 32).background(Color.white.opacity(0.07), in: Circle())
                    }
                    .accessibilityLabel("Close")
                }

                gauge.frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    NoopSectionLabel("Today")
                    chart.frame(height: 200)
                }
                .padding(16)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Text(summary)
                    .font(NoopHTMLFont.sans(14)).foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [NoopStressPalette.low.opacity(0.5), NoopStressPalette.high.opacity(0.5)],
                                                     startPoint: .leading, endPoint: .trailing), lineWidth: 0.8))

                timeInBands

                Text(personal
                     ? "Each hour's heart rate is compared with your own calm daytime level over the last 30 days. Hours you were moving are left out, because exertion is not stress. An estimate, not a diagnosis."
                     : "There isn't enough history for your own baseline yet, so each hour is compared with today's calmest hours. A calm day can still show some high hours this way. It switches to your 30-day baseline on its own once it has the days.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
    }

    // MARK: Gauge

    private var gauge: some View {
        let level = current.map { ($0.level * 10).rounded() / 10 }
        let fraction = min(1, max(0, (level ?? 0) / 3))
        return ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.white.opacity(0.07), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(AngularGradient(colors: [NoopStressPalette.low, NoopStressPalette.medium, NoopStressPalette.high],
                                        center: .center, startAngle: .degrees(0), endAngle: .degrees(270)),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(135))
                .opacity(level == nil ? 0.25 : 1)
            if level != nil {
                Circle()
                    .fill(NoopHTMLColor.ink)
                    .frame(width: 18, height: 18)
                    .overlay(Circle().stroke(NoopHTMLColor.canvas, lineWidth: 3))
                    .offset(y: -100)
                    .rotationEffect(.degrees(-135 + 270 * fraction))
            }
            VStack(spacing: 4) {
                Text(level.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "\u{2014}")
                    .font(NoopHTMLFont.outfit(52, weight: .light)).monospacedDigit()
                    .foregroundStyle(NoopHTMLColor.ink)
                if let level {
                    Text(NoopStressPalette.name(level).uppercased())
                        .font(NoopHTMLFont.sans(13, weight: .bold)).tracking(1.4)
                        .foregroundStyle(NoopStressPalette.color(level))
                }
                Text(current.map { "Updated \(AppClock.hourMinuteFormatter().string(from: $0.time))" } ?? "No scored hour yet today")
                    .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
            }
            HStack {
                Text("0").padding(.leading, 36)
                Spacer()
                Text("3").padding(.trailing, 36)
            }
            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
            .offset(y: 92)
        }
        .frame(width: 200, height: 200)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
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
            if let sleep {
                bandMarks(from: sleep.start, to: min(sleep.end, Date()), tint: NoopHTMLColor.night, symbol: "moon.fill")
            }
            ForEach(Array(sessions.enumerated()), id: \.offset) { _, s in
                bandMarks(from: s.start, to: max(s.end, s.start.addingTimeInterval(600)), tint: NoopHTMLColor.warm,
                          symbol: NoopFitnessCardioLive.symbol(for: s.sport))
            }
            ForEach(Array(segments.enumerated()), id: \.offset) { index, seg in
                ForEach(Array(seg.enumerated()), id: \.offset) { _, p in
                    LineMark(x: .value("Time", p.time), y: .value("Stress", p.level), series: .value("Run", index))
                        .interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(Self.levelGradient(seg.map(\.level)))
                }
            }
            if let p = selectedPoint {
                RuleMark(x: .value("Time", p.time))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        VStack(spacing: 1) {
                            Text("\(p.level.formatted(.number.precision(.fractionLength(1)))) · \(NoopStressPalette.name(p.level))")
                                .font(NoopHTMLFont.sans(12, weight: .semibold))
                            Text(AppClock.hourMinuteFormatter().string(from: p.time)).font(NoopHTMLFont.sans(10))
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
        .chartXScale(domain: dayStart...max(Date(), dayStart.addingTimeInterval(3600)))
        .chartYScale(domain: 0...3)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 1, 2, 3]) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel { Text("\(v.as(Int.self) ?? 0).0") }
                    .font(NoopHTMLFont.sans(9.5)).foregroundStyle(NoopHTMLColor.faint)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.hour()).font(NoopHTMLFont.sans(9.5)).foregroundStyle(NoopHTMLColor.faint)
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

    // MARK: Words and bands

    private var bandMinutes: (low: Int, medium: Int, high: Int, moving: Int) {
        var r = (low: 0, medium: 0, high: 0, moving: 0)
        for h in scoredHours {
            if let l = h.level {
                if l >= DaytimeStress.highBandFloor { r.high += 60 } else if l >= 1 { r.medium += 60 } else { r.low += 60 }
            } else if h.masked { r.moving += 60 }
        }
        return r
    }

    /// One plain sentence: where most of the waking day sat, and the longest high stretch.
    private var summary: String {
        let m = bandMinutes
        let total = m.low + m.medium + m.high
        guard total > 0 else {
            return "No hour has been scored yet today. It needs about an hour of heart rate while you're awake and still."
        }
        let dominant = [("low", m.low), ("medium", m.medium), ("high", m.high)].max { $0.1 < $1.1 }!.0
        var text = "Most of your scored time today was \(dominant) stress."
        // Longest run of consecutive high hours, on the same scored hours as the band totals below.
        var best: (start: Date, count: Int)?, run: (start: Date, count: Int)?
        for h in scoredHours {
            if let l = h.level, l >= DaytimeStress.highBandFloor {
                run = run.map { ($0.start, $0.count + 1) } ?? (h.start, 1)
                if (run?.count ?? 0) > (best?.count ?? 0) { best = run }
            } else { run = nil }
        }
        if let best {
            text += " Your longest high stretch began at \(AppClock.hourMinuteFormatter().string(from: best.start)) and lasted \(best.count == 1 ? "an hour" : "\(best.count) hours")."
        } else {
            text += " Nothing reached high."
        }
        if m.moving > 0 {
            text += " \(NoopRestRecord.duration(Double(m.moving))) of moving is left out."
        }
        return text
    }

    private var timeInBands: some View {
        let m = bandMinutes
        let total = max(1, m.low + m.medium + m.high)
        let items: [(String, Int, Color)] = [("Low", m.low, NoopStressPalette.low), ("Medium", m.medium, NoopStressPalette.medium),
                                             ("High", m.high, NoopStressPalette.high)]
        return VStack(alignment: .leading, spacing: 12) {
            NoopSectionLabel("Time in each band")
            GeometryReader { proxy in
                HStack(spacing: 3) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        if item.1 > 0 {
                            RoundedRectangle(cornerRadius: 4).fill(item.2)
                                .frame(width: max(6, (proxy.size.width - 6) * CGFloat(item.1) / CGFloat(total)))
                        }
                    }
                }
            }
            .frame(height: 10)
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.1 > 0 ? NoopRestRecord.duration(Double(item.1)) : "0m")
                            .font(NoopHTMLFont.outfit(20)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2).fill(item.2).frame(width: 8, height: 8)
                            Text(item.0.uppercased()).font(NoopHTMLFont.sans(10.5, weight: .semibold)).tracking(0.8)
                                .foregroundStyle(NoopHTMLColor.copy)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
#endif
