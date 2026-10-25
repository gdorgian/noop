import WidgetKit
import SwiftUI

/// The one goal you are working toward, as its journey reads it: how far along, the tracker's verdict
/// in words, the time left, and what today asks of you. Opens the goal.
struct GoalWidget: Widget {
    static let kind = "GoalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PanelsProvider()) { entry in
            GoalWidgetView(entry: entry)
        }
        .configurationDisplayName("Goal")
        .description("Track your goal's progress, its verdict and what today asks of you.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct GoalWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    @Environment(\.widgetRenderingMode) private var systemRenderingMode
    /// Set only by the Debug widget board, which renders every family inside the app.
    var familyOverride: WidgetFamily? = nil
    var renderingOverride: WidgetRenderingMode? = nil
    private var family: WidgetFamily { familyOverride ?? systemFamily }
    private var renderingMode: WidgetRenderingMode { renderingOverride ?? systemRenderingMode }
    let entry: PanelsEntry

    private let tint = PanelInk.warm
    private var goal: WidgetPanels.Goal? { entry.panels?.goal }
    private var fullColor: Bool { renderingMode == .fullColor }

    var body: some View {
        switch family {
        case .accessoryCircular: circular.accessoryChrome(.goal)
        case .accessoryRectangular: rectangular.accessoryChrome(.goal)
        case .systemMedium: content(medium: true).panelChrome(tint: tint, link: .goal)
        default: content(medium: false).panelChrome(tint: tint, link: .goal)
        }
    }

    /// The verdict's colour, always beside its words: green on track, amber for attention, red at risk.
    private func healthColor(_ goal: WidgetPanels.Goal) -> Color {
        switch goal.healthRank {
        case 0, 1: PanelInk.red
        case 2: PanelInk.warm
        case 3: PanelInk.green
        default: PanelInk.quiet
        }
    }

    private func timeLeft(_ goal: WidgetPanels.Goal) -> String? {
        guard let deadline = goal.deadline else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: entry.date),
                                                   to: Calendar.current.startOfDay(for: deadline)).day ?? 0
        if days < 0 { return "date passed" }
        if days == 0 { return "today" }
        if days < 21 { return "\(days) \(days == 1 ? "day" : "days") left" }
        return "\(days / 7) weeks left"
    }

    @ViewBuilder
    private func content(medium: Bool) -> some View {
        if let goal {
            if medium {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 0) {
                        summary(goal, titleLines: 2)
                        Spacer(minLength: 8)
                        progress(goal)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    today(goal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    summary(goal, titleLines: 2)
                    Spacer(minLength: 8)
                    progress(goal)
                }
            }
        } else {
            PanelEmpty(title: "Goal", symbol: "flag.fill", tint: tint,
                       message: "Set one goal on You. Its progress and today's steps toward it live here.")
                .medium(medium ? .progress : nil)
        }
    }

    private func summary(_ goal: WidgetPanels.Goal, titleLines: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelKicker(title: "Goal", symbol: goal.symbol, tint: tint, trailing: timeLeft(goal))
            Text(goal.title)
                .font(PanelType.strong(15))
                .foregroundStyle(PanelInk.primary)
                .lineLimit(titleLines)
                .lineSpacing(1)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 7)
            HStack(spacing: 5) {
                Circle()
                    .fill(fullColor ? healthColor(goal) : .white)
                    .frame(width: 6, height: 6)
                    .widgetAccentable()
                Text(goal.health)
                    .font(PanelType.strong(12))
                    .foregroundStyle(fullColor ? healthColor(goal) : PanelInk.primary)
                    .lineLimit(1)
            }
            .padding(.top, 5)
        }
    }

    @ViewBuilder
    private func progress(_ goal: WidgetPanels.Goal) -> some View {
        if let fraction = goal.progress {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(PanelType.hero(20))
                        .monospacedDigit()
                        .foregroundStyle(PanelInk.primary)
                        .widgetAccentable()
                    Spacer(minLength: 4)
                    if let current = goal.current, let target = goal.target {
                        Text("\(current) of \(target)")
                            .font(PanelType.sans(11))
                            .monospacedDigit()
                            .foregroundStyle(PanelInk.quiet)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(PanelInk.track)
                        Capsule()
                            .fill(fullColor
                                  ? AnyShapeStyle(LinearGradient(colors: [tint.opacity(0.75), tint],
                                                                 startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(Color.white))
                            .frame(width: max(5, proxy.size.width * min(1, max(0, fraction))))
                            .widgetAccentable()
                    }
                }
                .frame(height: 5)
            }
        } else {
            // No percentage yet. A measured goal still building its trend shows where it stands; a held
            // goal (strength, stress, something of your own) says it is held rather than draw an empty bar.
            Group {
                if goal.measured != false, let current = goal.current {
                    Text(goal.target.map { "\(current) now · aiming for \($0)" } ?? "\(current) now")
                } else if goal.measured != false {
                    Text("no measurement yet")
                } else {
                    Text(goal.streakWeeks > 0 ? "\(goal.streakWeeks)-week streak" : "held, not measured")
                }
            }
            .font(PanelType.sans(12))
            .foregroundStyle(PanelInk.copy)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }
    }

    @ViewBuilder
    private func today(_ goal: WidgetPanels.Goal) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(goal.today.isEmpty ? "Next" : "Today")
                .font(PanelType.strong(11))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(PanelInk.kicker)
            if goal.today.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    if let milestone = goal.nextMilestone {
                        row(symbol: "flag", text: "Waypoint at \(milestone)", done: false)
                    }
                    if goal.streakWeeks > 0 {
                        row(symbol: "flame", text: "\(goal.streakWeeks)-week streak", done: false)
                    }
                    if goal.nextMilestone == nil && goal.streakWeeks == 0 {
                        Text(goal.reason.isEmpty ? "Nothing planned for today." : goal.reason)
                            .font(PanelType.sans(12))
                            .foregroundStyle(PanelInk.copy)
                            .lineLimit(4)
                    }
                }
                .padding(.top, 9)
            } else {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(Array(goal.today.enumerated()), id: \.offset) { _, action in
                        row(symbol: action.done ? "checkmark.circle.fill" : "circle", text: action.label, done: action.done)
                    }
                }
                .padding(.top, 9)
            }
        }
    }

    private func row(symbol: String, text: String, done: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(done ? (fullColor ? PanelInk.green : .white) : PanelInk.quiet)
                .widgetAccentable(done)
            Text(text)
                .font(PanelType.sans(12))
                .foregroundStyle(done ? PanelInk.quiet : PanelInk.primary)
                .strikethrough(done, color: PanelInk.quiet)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "done" : "")
    }

    // MARK: Lock Screen

    @ViewBuilder
    private var circular: some View {
        if let goal, let fraction = goal.progress {
            Gauge(value: min(1, max(0, fraction))) {
                Image(systemName: goal.symbol)
            } currentValueLabel: {
                Text("\(Int((fraction * 100).rounded()))")
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .accessibilityLabel("\(goal.title), \(Int((fraction * 100).rounded())) percent")
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: goal?.symbol ?? "flag").font(.system(size: 18, weight: .medium))
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let goal {
                Text(goal.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .widgetAccentable()
                if let fraction = goal.progress {
                    Gauge(value: min(1, max(0, fraction))) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                }
                Text([goal.health, timeLeft(goal)].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Label("Goal", systemImage: "flag.fill").font(.system(size: 12, weight: .semibold))
                Text("No goal set").font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
