import WidgetKit
import SwiftUI

/// Last night, as Rest reads it: time asleep against your need, the night's stage architecture when a
/// real timeline exists, and the week behind it. Opens Rest.
struct SleepWidget: Widget {
    static let kind = "SleepWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PanelsProvider()) { entry in
            SleepWidgetView(entry: entry)
        }
        .configurationDisplayName("Sleep")
        .description("See last night against your need, with its stages and the week behind it.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct SleepWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    @Environment(\.widgetRenderingMode) private var systemRenderingMode
    /// Set only by the Debug widget board, which renders every family inside the app.
    var familyOverride: WidgetFamily? = nil
    var renderingOverride: WidgetRenderingMode? = nil
    private var family: WidgetFamily { familyOverride ?? systemFamily }
    private var renderingMode: WidgetRenderingMode { renderingOverride ?? systemRenderingMode }
    let entry: PanelsEntry

    private var night: WidgetPanels.Sleep? { entry.panels?.sleep }
    private let tint = PanelInk.night

    var body: some View {
        switch family {
        case .accessoryCircular: circular.accessoryChrome(.sleep)
        case .accessoryRectangular: rectangular.accessoryChrome(.sleep)
        case .accessoryInline: inline.accessoryChrome(.sleep)
        case .systemMedium: content(medium: true).panelChrome(tint: tint, link: .sleep)
        default: content(medium: false).panelChrome(tint: tint, link: .sleep)
        }
    }

    // MARK: Home Screen

    @ViewBuilder
    private func content(medium: Bool) -> some View {
        if let night {
            if medium { mediumBody(night) } else { smallBody(night) }
        } else {
            PanelEmpty(title: "Sleep", symbol: "moon.fill", tint: tint,
                       message: "Wear the strap tonight. Your first night lands here in the morning.")
                .medium(medium ? .bars : nil)
        }
    }

    private func nightLabel(_ night: WidgetPanels.Sleep) -> String {
        // A night older than a day and a half is still the newest on record, but it is named, not
        // passed off as last night.
        entry.date.timeIntervalSince(night.endedAt) < 36 * 3600
            ? "last night"
            : night.endedAt.formatted(.dateTime.weekday(.abbreviated).day())
    }

    private func smallBody(_ night: WidgetPanels.Sleep) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelKicker(title: "Sleep", symbol: "moon.fill", tint: tint, trailing: nightLabel(night))
            PanelFigure(value: PanelFormat.duration(night.asleepMin))
                .padding(.top, 6)
            needLine(night)
                .padding(.top, 1)
            Spacer(minLength: 8)
            SleepArchitecture(night: night, lanes: false, fullColor: renderingMode == .fullColor)
                .frame(height: 20)
            Text(night.window)
                .font(PanelType.sans(11))
                .monospacedDigit()
                .foregroundStyle(PanelInk.quiet)
                .padding(.top, 6)
        }
    }

    private func mediumBody(_ night: WidgetPanels.Sleep) -> some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                PanelKicker(title: "Sleep", symbol: "moon.fill", tint: tint)
                PanelFigure(value: PanelFormat.duration(night.asleepMin))
                    .padding(.top, 6)
                needLine(night)
                    .padding(.top, 1)
                Spacer(minLength: 8)
                SleepWeekBars(night: night, tint: tint, fullColor: renderingMode == .fullColor)
                    .frame(height: 34)
            }
            .frame(width: 128, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(nightLabel(night).prefix(1).uppercased() + nightLabel(night).dropFirst())
                    Spacer(minLength: 4)
                    Text(night.window).monospacedDigit()
                }
                .font(PanelType.sans(11))
                .foregroundStyle(PanelInk.quiet)
                .lineLimit(1)
                SleepArchitecture(night: night, lanes: true, fullColor: renderingMode == .fullColor)
                    .frame(height: 50)
                    .padding(.top, 7)
                Spacer(minLength: 8)
                stageLegend(night)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// "28m short of your 7h 45m" / "12m over" — the same rounding Rest uses, so the two never differ.
    @ViewBuilder
    private func needLine(_ night: WidgetPanels.Sleep) -> some View {
        Group {
            if let need = night.needMin, !night.needCalibrating {
                let diff = (night.asleepMin - need).rounded()
                if diff >= 0 {
                    Text("\(PanelFormat.duration(diff)) over your need")
                } else if -diff <= 5 {
                    Text("level with your need")
                } else {
                    Text("\(PanelFormat.duration(-diff)) short of \(PanelFormat.duration(need))")
                }
            } else {
                Text("need still calibrating")
            }
        }
        .font(PanelType.sans(12))
        .foregroundStyle(PanelInk.copy)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }

    private func stageLegend(_ night: WidgetPanels.Sleep) -> some View {
        let rows: [(String, Double, Int)] = [("Deep", night.deepMin, 3), ("REM", night.remMin, 2),
                                             ("Light", night.lightMin, 1), ("Awake", night.awakeMin, 0)]
        return Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 4) {
            GridRow {
                legendCell(rows[0])
                legendCell(rows[1])
            }
            GridRow {
                legendCell(rows[2])
                legendCell(rows[3])
            }
        }
    }

    private func legendCell(_ row: (String, Double, Int)) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(SleepArchitecture.color(row.2, fullColor: renderingMode == .fullColor))
                .frame(width: 7, height: 7)
            Text(row.0)
                .font(PanelType.sans(11))
                .foregroundStyle(PanelInk.quiet)
            Text(PanelFormat.compactDuration(row.1))
                .font(PanelType.strong(11))
                .monospacedDigit()
                .foregroundStyle(PanelInk.secondary)
        }
        .lineLimit(1)
    }

    // MARK: Lock Screen

    @ViewBuilder
    private var circular: some View {
        if let night, let need = night.needMin, !night.needCalibrating {
            Gauge(value: min(night.asleepMin, need), in: 0...need) {
                Image(systemName: "moon.fill")
            } currentValueLabel: {
                Text(PanelFormat.decimal(night.asleepMin / 60, 1))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel("Slept \(PanelFormat.duration(night.asleepMin)) of a \(PanelFormat.duration(need)) need")
        } else if let night {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "moon.fill").font(.system(size: 11, weight: .semibold))
                    Text(PanelFormat.decimal(night.asleepMin / 60, 1))
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text("h").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "moon.zzz").font(.system(size: 18, weight: .medium))
            }
            .accessibilityLabel("No night recorded yet")
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let night {
            VStack(alignment: .leading, spacing: 2) {
                Label("Sleep", systemImage: "moon.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .widgetAccentable()
                Text("\(PanelFormat.duration(night.asleepMin)) asleep")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                SleepArchitecture(night: night, lanes: false, fullColor: false)
                    .frame(height: 9)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label("Sleep", systemImage: "moon.fill").font(.system(size: 12, weight: .semibold))
                Text("No night recorded yet").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inline: some View {
        if let night {
            Text("\(Image(systemName: "moon.fill")) \(PanelFormat.duration(night.asleepMin)) asleep")
        } else {
            Text("\(Image(systemName: "moon.fill")) No night yet")
        }
    }
}

/// The night's structure. With a real timeline: each stage run at its true length — as a single
/// ribbon, or in four lanes (awake on top, deep at the bottom) like Rest's hypnogram. Imported nights
/// carry totals only, and draw as proportions in stage order rather than an invented sequence.
struct SleepArchitecture: View {
    let night: WidgetPanels.Sleep
    let lanes: Bool
    let fullColor: Bool

    static func color(_ stage: Int, fullColor: Bool) -> Color {
        if fullColor { return PanelInk.stages[max(0, min(3, stage))] }
        // Tinted and Lock Screen renderings keep the structure through brightness alone.
        return Color.white.opacity([0.3, 0.55, 0.78, 1][max(0, min(3, stage))])
    }

    var body: some View {
        Group {
            if let runs = night.runs, !runs.isEmpty {
                if lanes { hypnogram(runs) } else { ribbon(runs) }
            } else {
                proportions
            }
        }
        .widgetAccentable()
        .accessibilityElement()
        .accessibilityLabel("Deep \(PanelFormat.duration(night.deepMin)), REM \(PanelFormat.duration(night.remMin)), light \(PanelFormat.duration(night.lightMin)), awake \(PanelFormat.duration(night.awakeMin))")
    }

    /// Every run at its true length, side by side, in one rounded band. Drawn as one path per stage:
    /// WidgetKit archives a widget's views, and paths archive where a `Canvas` does not.
    private func ribbon(_ runs: [WidgetPanels.Sleep.Run]) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                ForEach(0..<4, id: \.self) { stage in
                    Path { path in
                        for run in runs where run.stage == stage {
                            path.addRect(CGRect(x: CGFloat(run.from) * size.width, y: 0,
                                                width: max(0.75, CGFloat(run.to - run.from) * size.width),
                                                height: size.height))
                        }
                    }
                    .fill(Self.color(stage, fullColor: fullColor))
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
    }

    /// Rest's hypnogram in miniature: awake on top, then REM, light and deep at the bottom, each run a rounded bar on its
    /// lane and a hairline stepping between lanes, so the night reads as one continuous line.
    private func hypnogram(_ runs: [WidgetPanels.Sleep.Run]) -> some View {
        GeometryReader { proxy in
            let size = proxy.size
            let lane = size.height / 4
            let bar = min(6, lane * 0.62)
            // Top to bottom as Rest draws it: awake, REM, light, deep.
            let row = [0, 2, 1, 3]
            let y = { (stage: Int) -> CGFloat in lane * CGFloat(row[max(0, min(3, stage))]) + lane / 2 }
            ZStack {
                Path { path in
                    for i in 0..<4 {
                        path.move(to: CGPoint(x: 0, y: lane * CGFloat(i) + lane / 2))
                        path.addLine(to: CGPoint(x: size.width, y: lane * CGFloat(i) + lane / 2))
                    }
                }
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                Path { path in
                    for (a, b) in zip(runs, runs.dropFirst()) where a.stage != b.stage {
                        let x = CGFloat(b.from) * size.width
                        path.move(to: CGPoint(x: x, y: y(a.stage)))
                        path.addLine(to: CGPoint(x: x, y: y(b.stage)))
                    }
                }
                .stroke(Color.white.opacity(0.22), lineWidth: 0.75)
                ForEach(0..<4, id: \.self) { stage in
                    Path { path in
                        for run in runs where run.stage == stage {
                            let rect = CGRect(x: CGFloat(run.from) * size.width, y: y(stage) - bar / 2,
                                              width: max(bar * 0.6, CGFloat(run.to - run.from) * size.width),
                                              height: bar)
                            path.addRoundedRect(in: rect, cornerSize: CGSize(width: bar / 2, height: bar / 2))
                        }
                    }
                    .fill(Self.color(stage, fullColor: fullColor))
                }
            }
            .frame(width: size.width, height: size.height)
        }
    }

    /// An imported night carries totals, not a sequence: its stages as proportions, in stage order.
    private var proportions: some View {
        let parts: [(Int, Double)] = [(3, night.deepMin), (2, night.remMin), (1, night.lightMin), (0, night.awakeMin)]
        let total = max(1, parts.reduce(0) { $0 + $1.1 })
        return GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(parts.filter { $0.1 > 0 }, id: \.0) { part in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Self.color(part.0, fullColor: fullColor))
                        .frame(width: max(2, CGFloat(part.1 / total) * (proxy.size.width - 6)))
                }
            }
            .frame(width: proxy.size.width, height: lanes ? min(proxy.size.height, 10) : proxy.size.height)
            .frame(maxHeight: .infinity)
        }
    }
}

/// Seven nights against the need: the need is a hairline, last night carries the accent.
struct SleepWeekBars: View {
    let night: WidgetPanels.Sleep
    let tint: Color
    let fullColor: Bool

    var body: some View {
        let values = night.week
        let need = night.needCalibrating ? nil : night.needMin
        let top = max(values.compactMap { $0 }.max() ?? 0, need ?? 0, 60) * 1.08
        VStack(spacing: 3) {
            GeometryReader { proxy in
                let h = proxy.size.height
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                            let last = index == values.count - 1
                            RoundedRectangle(cornerRadius: value == nil ? 0.5 : 2)
                                .fill(value == nil ? PanelInk.hairline
                                      : last ? (fullColor ? tint : .white) : Color.white.opacity(fullColor ? 0.2 : 0.45))
                                .frame(maxWidth: .infinity)
                                .frame(height: value.map { max(3, CGFloat($0 / top) * h) } ?? 1)
                        }
                    }
                    .widgetAccentable()
                    if let need {
                        Rectangle()
                            .fill(Color.white.opacity(0.35))
                            .frame(height: 1)
                            .offset(y: -CGFloat(need / top) * h)
                    }
                }
            }
            HStack(spacing: 4) {
                ForEach(Array(night.weekLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(PanelType.sans(9))
                        .foregroundStyle(PanelInk.kicker)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
        }
    }
}
