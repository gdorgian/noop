import WidgetKit
import SwiftUI

/// Today's steps against your own step target when you set one in a goal, or against the week's
/// finished days when you have not. Opens Today.
struct StepsWidget: Widget {
    static let kind = "StepsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PanelsProvider()) { entry in
            StepsWidgetView(entry: entry)
        }
        .configurationDisplayName("Steps")
        .description("Follow today's steps against your target and the week so far.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct StepsWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    @Environment(\.widgetRenderingMode) private var systemRenderingMode
    /// Set only by the Debug widget board, which renders every family inside the app.
    var familyOverride: WidgetFamily? = nil
    var renderingOverride: WidgetRenderingMode? = nil
    private var family: WidgetFamily { familyOverride ?? systemFamily }
    private var renderingMode: WidgetRenderingMode { renderingOverride ?? systemRenderingMode }
    let entry: PanelsEntry

    private let tint = PanelInk.blue
    private var steps: WidgetPanels.Steps? { entry.panels?.steps }

    /// A count belongs to the day it was published on. After midnight it is yesterday's, and is not
    /// shown as today's while the app has not counted again.
    private var publishedToday: Bool {
        guard let updated = entry.panels?.updated else { return false }
        return PanelFormat.isToday(updated, now: entry.date)
    }

    private var today: Int? { publishedToday ? steps?.today : nil }

    var body: some View {
        switch family {
        case .accessoryCircular: circular.accessoryChrome(.steps)
        case .accessoryRectangular: rectangular.accessoryChrome(.steps)
        case .accessoryInline: inline.accessoryChrome(.steps)
        case .systemMedium: content(medium: true).panelChrome(tint: tint, link: .steps)
        default: content(medium: false).panelChrome(tint: tint, link: .steps)
        }
    }

    @ViewBuilder
    private func content(medium: Bool) -> some View {
        if let steps {
            if medium {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 0) {
                        headline(steps)
                        Spacer(minLength: 8)
                        if steps.goal != nil { goalBar(steps) }
                        footnote(steps).padding(.top, 6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    StepsWeekBars(steps: steps, liveToday: publishedToday, tint: tint,
                                  fullColor: renderingMode == .fullColor, showValues: true)
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    headline(steps)
                    Spacer(minLength: 8)
                    StepsWeekBars(steps: steps, liveToday: publishedToday, tint: tint,
                                  fullColor: renderingMode == .fullColor, showValues: false)
                        .frame(height: 34)
                }
            }
        } else {
            PanelEmpty(title: "Steps", symbol: "figure.walk", tint: tint,
                       message: "Steps arrive from the strap or Apple Health as soon as either counts.")
                .medium(medium ? .bars : nil)
        }
    }

    private func headline(_ steps: WidgetPanels.Steps) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelKicker(title: "Steps", symbol: "figure.walk", tint: tint, trailing: "today")
            PanelFigure(value: today.map(PanelFormat.grouped) ?? "—", dim: today == nil)
                .padding(.top, 6)
            Text(progressLine(steps))
                .font(PanelType.sans(12))
                .foregroundStyle(PanelInk.copy)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.top, 1)
        }
    }

    private func progressLine(_ steps: WidgetPanels.Steps) -> String {
        guard let today else { return "nothing counted yet today" }
        if let goal = steps.goal {
            return today >= goal ? "past your \(PanelFormat.grouped(goal))" : "\(PanelFormat.grouped(goal - today)) more to \(PanelFormat.grouped(goal))"
        }
        if let average = steps.priorAverage { return "\(PanelFormat.grouped(average)) a day this week" }
        return "counting since midnight"
    }

    private func goalBar(_ steps: WidgetPanels.Steps) -> some View {
        let fraction = min(1, Double(today ?? 0) / Double(max(1, steps.goal ?? 1)))
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(PanelInk.track)
                Capsule()
                    .fill(renderingMode == .fullColor
                          ? AnyShapeStyle(LinearGradient(colors: [tint, PanelInk.blueLight], startPoint: .leading, endPoint: .trailing))
                          : AnyShapeStyle(Color.white))
                    .frame(width: max(5, proxy.size.width * fraction))
                    .widgetAccentable()
            }
        }
        .frame(height: 5)
    }

    private func footnote(_ steps: WidgetPanels.Steps) -> some View {
        Text(steps.source == "strap" ? "counted by the strap" : steps.source == "health" ? "from Apple Health" : " ")
            .font(PanelType.sans(11))
            .foregroundStyle(PanelInk.quiet)
            .lineLimit(1)
    }

    // MARK: Lock Screen

    @ViewBuilder
    private var circular: some View {
        if let today, let goal = steps?.goal {
            Gauge(value: Double(min(today, goal)), in: 0...Double(goal)) {
                Image(systemName: "figure.walk")
            } currentValueLabel: {
                Text(compact(today))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel("\(today) of \(goal) steps")
        } else {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: "figure.walk").font(.system(size: 11, weight: .semibold))
                    Text(today.map(compact) ?? "—")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.6)
                }
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Steps", systemImage: "figure.walk")
                .font(.system(size: 12, weight: .semibold))
                .widgetAccentable()
            Text(today.map(PanelFormat.grouped) ?? "Not counted yet")
                .font(.system(size: today == nil ? 13 : 17, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let steps {
                Text(progressLine(steps)).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Text("\(Image(systemName: "figure.walk")) \(today.map { "\(PanelFormat.grouped($0)) steps" } ?? "No steps yet")")
    }

    private func compact(_ value: Int) -> String {
        value >= 10_000 ? "\(PanelFormat.decimal(Double(value) / 1000, 0))k"
            : value >= 1000 ? "\(PanelFormat.decimal(Double(value) / 1000, 1))k" : "\(value)"
    }
}

/// Seven days of steps, today carrying the accent and the target drawn as a hairline.
struct StepsWeekBars: View {
    let steps: WidgetPanels.Steps
    let liveToday: Bool
    let tint: Color
    let fullColor: Bool
    let showValues: Bool

    var body: some View {
        let values: [Int?] = steps.week.enumerated().map { index, value in
            index == steps.week.count - 1 && !liveToday ? nil : value
        }
        let top = Double(max(values.compactMap { $0 }.max() ?? 0, steps.goal ?? 0, 1_000)) * (showValues ? 1.3 : 1.1)
        VStack(spacing: 4) {
            GeometryReader { proxy in
                let h = proxy.size.height
                ZStack(alignment: .bottomLeading) {
                    HStack(alignment: .bottom, spacing: showValues ? 6 : 4) {
                        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                            let last = index == values.count - 1
                            let met = steps.goal.map { (value ?? 0) >= $0 } ?? false
                            RoundedRectangle(cornerRadius: value == nil ? 0.5 : 2.5)
                                .fill(value == nil ? PanelInk.hairline
                                      : last ? (fullColor ? tint : .white)
                                      : Color.white.opacity(fullColor ? (met ? 0.34 : 0.18) : (met ? 0.7 : 0.4)))
                                .frame(maxWidth: showValues ? 14 : .infinity)
                                .frame(height: value.map { max(3, CGFloat(Double($0) / top) * h) } ?? 1)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .widgetAccentable()
                    if let goal = steps.goal {
                        Rectangle()
                            .fill(Color.white.opacity(0.32))
                            .frame(height: 1)
                            .offset(y: -CGFloat(Double(goal) / top) * h)
                    }
                }
            }
            HStack(spacing: showValues ? 6 : 4) {
                ForEach(Array(steps.weekLetters.enumerated()), id: \.offset) { index, letter in
                    Text(letter)
                        .font(index == steps.weekLetters.count - 1 ? PanelType.strong(9) : PanelType.sans(9))
                        .foregroundStyle(index == steps.weekLetters.count - 1 ? PanelInk.secondary : PanelInk.kicker)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Steps over the last seven days")
        .accessibilityValue(values.compactMap { $0 }.map(String.init).joined(separator: ", "))
    }
}
