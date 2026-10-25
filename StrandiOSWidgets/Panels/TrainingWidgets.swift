import WidgetKit
import SwiftUI

// Workouts and Consistency read the same sessions the Fitness tab counts: every workout source, with
// a lift held in the Lift log counted once.

private func mondayIndex(_ date: Date) -> Int {
    (Calendar.current.component(.weekday, from: date) + 5) % 7
}

private func sameWeek(_ a: Date, _ b: Date) -> Bool {
    var calendar = Calendar.current
    calendar.firstWeekday = 2
    return calendar.isDate(a, equalTo: b, toGranularity: .weekOfYear)
}

// MARK: - Workouts

/// This training week: how many sessions, how long, which days, and the last one. Opens Fitness.
struct WorkoutsWidget: Widget {
    static let kind = "WorkoutsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PanelsProvider()) { entry in
            WorkoutsWidgetView(entry: entry)
        }
        .configurationDisplayName("Workouts")
        .description("Keep this week's sessions and your last workout in view.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct WorkoutsWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    @Environment(\.widgetRenderingMode) private var systemRenderingMode
    /// Set only by the Debug widget board, which renders every family inside the app.
    var familyOverride: WidgetFamily? = nil
    var renderingOverride: WidgetRenderingMode? = nil
    private var family: WidgetFamily { familyOverride ?? systemFamily }
    private var renderingMode: WidgetRenderingMode { renderingOverride ?? systemRenderingMode }
    let entry: PanelsEntry

    private let tint = PanelInk.volt
    private var training: WidgetPanels.Training? { entry.panels?.training }

    /// The week as published, unless it is over: a new week starts empty rather than showing the last.
    private var week: (minutes: [Int?], sessions: [Int])? {
        guard let training, let updated = entry.panels?.updated else { return nil }
        if sameWeek(updated, entry.date) { return (training.weekMinutes, training.weekSessions) }
        return (Array(repeating: nil, count: 7), Array(repeating: 0, count: 7))
    }

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular.accessoryChrome(.workouts)
        case .accessoryInline: inline.accessoryChrome(.workouts)
        case .systemMedium: content(medium: true).panelChrome(tint: tint, link: .workouts)
        default: content(medium: false).panelChrome(tint: tint, link: .workouts)
        }
    }

    @ViewBuilder
    private func content(medium: Bool) -> some View {
        if let training, let week {
            let count = week.sessions.reduce(0, +)
            let minutes = week.minutes.compactMap { $0 }.reduce(0, +)
            if medium {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 0) {
                        headline(count: count, minutes: minutes)
                        Spacer(minLength: 8)
                        WeekStrip(minutes: week.minutes, letters: training.weekLetters,
                                  todayIndex: mondayIndex(entry.date), tint: tint,
                                  fullColor: renderingMode == .fullColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    lastSession(training.last)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    headline(count: count, minutes: minutes)
                    Spacer(minLength: 8)
                    WeekStrip(minutes: week.minutes, letters: training.weekLetters,
                              todayIndex: mondayIndex(entry.date), tint: tint,
                              fullColor: renderingMode == .fullColor)
                }
            }
        } else {
            PanelEmpty(title: "Workouts", symbol: "figure.run", tint: tint,
                       message: "Record a session, log a lift or bring in Apple Health workouts.")
                .medium(medium ? .bars : nil)
        }
    }

    private func headline(count: Int, minutes: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelKicker(title: "Workouts", symbol: "figure.run", tint: tint)
            PanelFigure(value: "\(count)", unit: count == 1 ? "session" : "sessions", dim: count == 0)
                .padding(.top, 6)
            Text(count == 0 ? "none yet this week" : "\(PanelFormat.duration(Double(minutes))) this week")
                .font(PanelType.sans(12))
                .foregroundStyle(PanelInk.copy)
                .lineLimit(1)
                .padding(.top, 1)
        }
    }

    @ViewBuilder
    private func lastSession(_ last: WidgetPanels.Training.Session?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Last session")
                .font(PanelType.strong(11))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(PanelInk.kicker)
            if let last {
                ZStack {
                    Circle().fill(renderingMode == .fullColor ? tint.opacity(0.16) : Color.white.opacity(0.14))
                    Image(systemName: last.symbol)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(renderingMode == .fullColor ? tint : .white)
                        .widgetAccentable()
                }
                .frame(width: 38, height: 38)
                .padding(.top, 10)
                Text(last.title)
                    .font(PanelType.strong(14))
                    .foregroundStyle(PanelInk.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 8)
                Text("\(PanelFormat.duration(Double(last.minutes))) · \(PanelFormat.day(last.start, now: entry.date))")
                    .font(PanelType.sans(12))
                    .foregroundStyle(PanelInk.quiet)
                    .lineLimit(1)
                    .padding(.top, 1)
            } else {
                Text("None recorded yet")
                    .font(PanelType.sans(12))
                    .foregroundStyle(PanelInk.quiet)
                    .padding(.top, 10)
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("Workouts", systemImage: "figure.run")
                .font(.system(size: 12, weight: .semibold))
                .widgetAccentable()
            if let training, let week {
                let count = week.sessions.reduce(0, +)
                Text("\(count) this week · \(PanelFormat.duration(Double(week.minutes.compactMap { $0 }.reduce(0, +))))")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                WeekStrip(minutes: week.minutes, letters: training.weekLetters, todayIndex: mondayIndex(entry.date),
                          tint: tint, fullColor: false, compact: true)
            } else {
                Text("No sessions yet").font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        let count = week?.sessions.reduce(0, +) ?? 0
        return Text("\(Image(systemName: "figure.run")) \(count) \(count == 1 ? "workout" : "workouts") this week")
    }
}

/// Monday to Sunday: a trained day is a filled pill whose height grows with the minutes, today is
/// ringed, the days still to come are hairlines.
struct WeekStrip: View {
    let minutes: [Int?]
    let letters: [String]
    let todayIndex: Int
    let tint: Color
    let fullColor: Bool
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 5) {
            ForEach(0..<7, id: \.self) { index in
                let value = index < minutes.count ? minutes[index] : nil
                let trained = (value ?? 0) > 0
                VStack(spacing: 3) {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index > todayIndex ? Color.white.opacity(0.05) : PanelInk.track)
                        if trained, let value {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(fullColor ? tint : .white)
                                .frame(height: (compact ? 12 : 22) * CGFloat(min(1, 0.35 + Double(value) / 90 * 0.65)))
                                .widgetAccentable()
                        }
                        if index == todayIndex {
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                        }
                    }
                    .frame(height: compact ? 12 : 22)
                    if !compact {
                        Text(index < letters.count ? letters[index] : "")
                            .font(index == todayIndex ? PanelType.strong(9) : PanelType.sans(9))
                            .foregroundStyle(index == todayIndex ? PanelInk.secondary : PanelInk.kicker)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Trained \(minutes.compactMap { $0 }.filter { $0 > 0 }.count) of 7 days this week")
    }
}

// MARK: - Consistency

/// Training days over the last weeks as a calendar grid, and how many of the last 28 had a session.
/// A rest day is a day, not a broken streak. Opens the Fitness calendar.
struct ConsistencyWidget: Widget {
    static let kind = "ConsistencyWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PanelsProvider()) { entry in
            ConsistencyWidgetView(entry: entry)
        }
        .configurationDisplayName("Consistency")
        .description("See the weeks you've trained at a glance, rest days included.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct ConsistencyWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    @Environment(\.widgetRenderingMode) private var systemRenderingMode
    /// Set only by the Debug widget board, which renders every family inside the app.
    var familyOverride: WidgetFamily? = nil
    var renderingOverride: WidgetRenderingMode? = nil
    private var family: WidgetFamily { familyOverride ?? systemFamily }
    private var renderingMode: WidgetRenderingMode { renderingOverride ?? systemRenderingMode }
    let entry: PanelsEntry

    private let tint = PanelInk.volt
    private var training: WidgetPanels.Training? {
        guard let training = entry.panels?.training, training.hasAnyRecord else { return nil }
        return training
    }

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular.accessoryChrome(.consistency)
        case .systemMedium: content(medium: true).panelChrome(tint: tint, link: .consistency)
        default: content(medium: false).panelChrome(tint: tint, link: .consistency)
        }
    }

    /// The last `weeks` whole weeks of the grid, so every column is one Monday-to-Sunday week.
    private func columns(_ training: WidgetPanels.Training, weeks: Int) -> [Int?] {
        Array(training.grid.suffix(weeks * 7))
    }

    @ViewBuilder
    private func content(medium: Bool) -> some View {
        if let training {
            if medium {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 0) {
                        headline(training)
                        Spacer(minLength: 8)
                        legend
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    TrainingGrid(days: columns(training, weeks: 12), weeks: 12, tint: tint,
                                 fullColor: renderingMode == .fullColor)
                        .frame(width: 176)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    PanelKicker(title: "Consistency", symbol: "square.grid.3x3.fill", tint: tint)
                    PanelFigure(value: "\(training.trained28)", unit: "of 28 days", size: 30)
                        .padding(.top, 5)
                    Spacer(minLength: 8)
                    TrainingGrid(days: columns(training, weeks: 12), weeks: 12, tint: tint,
                                 fullColor: renderingMode == .fullColor)
                }
            }
        } else {
            PanelEmpty(title: "Consistency", symbol: "square.grid.3x3.fill", tint: tint,
                       message: "Your training days fill in here, week by week.")
                .medium(medium ? .grid : nil)
        }
    }

    private func headline(_ training: WidgetPanels.Training) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelKicker(title: "Consistency", symbol: "square.grid.3x3.fill", tint: tint)
            PanelFigure(value: "\(training.trained28)", unit: "of 28 days")
                .padding(.top, 6)
            Text("trained, last four weeks")
                .font(PanelType.sans(12))
                .foregroundStyle(PanelInk.copy)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.top, 1)
        }
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("rest").font(PanelType.sans(10)).foregroundStyle(PanelInk.kicker)
            ForEach([0, 20, 45, 90], id: \.self) { minutes in
                RoundedRectangle(cornerRadius: 2)
                    .fill(TrainingGrid.fill(minutes, tint: tint, fullColor: renderingMode == .fullColor))
                    .frame(width: 9, height: 9)
            }
            Text("an hour+").font(PanelType.sans(10)).foregroundStyle(PanelInk.kicker)
        }
        .accessibilityHidden(true)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let training {
                Text("\(training.trained28) of 28 days trained")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .widgetAccentable()
                TrainingGrid(days: columns(training, weeks: 8), weeks: 8, tint: tint, fullColor: false, cell: 6)
            } else {
                Label("Consistency", systemImage: "square.grid.3x3.fill").font(.system(size: 12, weight: .semibold))
                Text("No sessions yet").font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Weeks as columns, Monday at the top. A day with no record yet (before you started, or still to
/// come) is left blank; a rest day is a quiet square; a trained day brightens with its minutes.
struct TrainingGrid: View {
    let days: [Int?]
    let weeks: Int
    let tint: Color
    let fullColor: Bool
    var cell: CGFloat? = nil

    static func fill(_ minutes: Int, tint: Color, fullColor: Bool) -> Color {
        let level: Double = minutes <= 0 ? 0 : minutes < 30 ? 0.4 : minutes < 60 ? 0.7 : 1
        if level == 0 { return Color.white.opacity(0.07) }
        return fullColor ? tint.opacity(level) : Color.white.opacity(0.3 + 0.7 * level)
    }

    var body: some View {
        GeometryReader { proxy in
            let gap: CGFloat = cell == nil ? 3 : 2
            let side = cell ?? min((proxy.size.width - gap * CGFloat(weeks - 1)) / CGFloat(weeks),
                                   (proxy.size.height - gap * 6) / 7)
            HStack(spacing: gap) {
                ForEach(0..<weeks, id: \.self) { column in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { row in
                            let index = column * 7 + row
                            let value = index < days.count ? days[index] : nil
                            RoundedRectangle(cornerRadius: side * 0.26)
                                .fill(value.map { Self.fill($0, tint: tint, fullColor: fullColor) } ?? .clear)
                                .overlay {
                                    if value == nil {
                                        RoundedRectangle(cornerRadius: side * 0.26)
                                            .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                                    }
                                }
                                .frame(width: side, height: side)
                        }
                    }
                }
            }
            .widgetAccentable()
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: cell == nil ? .bottomLeading : .topLeading)
        }
        .frame(height: cell.map { $0 * 7 + 2 * 6 })
        .accessibilityElement()
        .accessibilityLabel("Trained \(days.compactMap { $0 }.filter { $0 > 0 }.count) days in the last \(weeks) weeks")
    }
}
