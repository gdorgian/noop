import WidgetKit
import SwiftUI
import StrandDesign

// The shared vocabulary of the Sleep, Steps, Vitals, Weight, Workouts, Consistency and Goal widgets:
// one timeline, one surface, one type scale, one empty state. Values mirror the app's Aura tokens
// (`NoopHTMLColor`, `NoopType`), which the widget extension does not compile; a widget that drifted from
// the screen it opens would read as a different product.

// MARK: - Timeline

struct PanelsEntry: TimelineEntry {
    let date: Date
    let panels: WidgetPanels?
}

struct PanelsProvider: TimelineProvider {
    func placeholder(in context: Context) -> PanelsEntry {
        // Drawn redacted by the system, so the shapes show and the numbers never do.
        PanelsEntry(date: Date(), panels: PanelSamples.panels)
    }

    func getSnapshot(in context: Context, completion: @escaping (PanelsEntry) -> Void) {
        // The gallery shows the wearer's own figures once the app has published them. Before that,
        // Debug simulator builds preview a sample; a release gallery shows the honest empty state.
        var panels = WidgetPanels.load()
        #if DEBUG && targetEnvironment(simulator)
        if panels == nil, context.isPreview { panels = PanelSamples.panels }
        #endif
        completion(PanelsEntry(date: Date(), panels: panels))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PanelsEntry>) -> Void) {
        let now = Date()
        let panels = WidgetPanels.load()
        // A second entry at midnight lets "today" turn over without the app: a day's count stops
        // being shown as today's the moment the day ends.
        let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0),
                                                 matchingPolicy: .nextTime) ?? now.addingTimeInterval(3600)
        let entries = [PanelsEntry(date: now, panels: panels), PanelsEntry(date: midnight, panels: panels)]
        let refresh = min(midnight.addingTimeInterval(60), now.addingTimeInterval(30 * 60))
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}

// MARK: - Ink

enum PanelInk {
    static let surface = Color(hex: "#0F1312")
    static let primary = Color(hex: "#EDF1EF")
    static let secondary = Color(hex: "#C6CEC9")
    static let copy = Color(hex: "#ABB3AE")
    static let quiet = Color(hex: "#7F8A85")
    static let kicker = Color(hex: "#6C7570")
    static let track = Color.white.opacity(0.08)
    static let hairline = Color.white.opacity(0.14)

    // Section accents, as the app's shell tints each act.
    static let night = Color(hex: "#8B99D6")
    static let nightLight = Color(hex: "#9AA7E0")
    static let blue = Color(hex: "#17A2E6")
    static let blueLight = Color(hex: "#8FD3F5")
    static let blush = Color(hex: "#E08A9B")
    static let volt = Color(hex: "#D2F04A")
    static let warm = Color(hex: "#F2B45C")
    static let green = Color(hex: "#2ECC80")
    static let red = Color(hex: "#E66F62")

    /// Rest's hypnogram: awake · light · REM · deep.
    static let stages: [Color] = [Color.white.opacity(0.32), nightLight, Color(hex: "#4FB8E8"), Color(hex: "#5D6BC4")]
}

// MARK: - Type

enum PanelType {
    static func hero(_ size: CGFloat) -> Font { .custom(NoopSpecType.Face.outfitLight, fixedSize: size) }
    static func sans(_ size: CGFloat) -> Font { .custom(NoopSpecType.Face.sansRegular, fixedSize: size) }
    static func strong(_ size: CGFloat) -> Font { .custom(NoopSpecType.Face.sansSemiBold, fixedSize: size) }
}

// MARK: - Surface

/// The widget's background: Aura's surface with the section's light falling from the top edge, the
/// way each screen's ambient glow sits behind its header. Removed by the system on tinted and clear
/// Home Screens, where only the content is drawn.
struct PanelSurface: View {
    let tint: Color

    var body: some View {
        ZStack {
            PanelInk.surface
            RadialGradient(colors: [tint.opacity(0.16), .clear],
                           center: .init(x: 0.18, y: -0.1), startRadius: 0, endRadius: 190)
        }
    }
}

extension View {
    /// Applies the surface, the link and the standard 16 pt margin to a Home Screen panel.
    func panelChrome(tint: Color, link: WidgetLink) -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .containerBackground(for: .widget) { PanelSurface(tint: tint) }
            .widgetURL(link.url)
    }
}

extension View {
    /// Lock Screen accessories: the system draws their backing, but WidgetKit still requires a declared
    /// container background on every family.
    func accessoryChrome(_ link: WidgetLink) -> some View {
        self
            .containerBackground(for: .widget) { Color.clear }
            .widgetURL(link.url)
    }
}

/// The small caption over every panel: the section's glyph and its name.
struct PanelKicker: View {
    let title: String
    let symbol: String
    let tint: Color
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .widgetAccentable()
            Text(title)
                .font(PanelType.strong(11))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(PanelInk.kicker)
                .lineLimit(1)
            if let trailing {
                Spacer(minLength: 4)
                Text(trailing)
                    .font(PanelType.sans(11))
                    .foregroundStyle(PanelInk.quiet)
                    .lineLimit(1)
            }
        }
    }
}

/// A large figure with its unit set in the quiet sans beside it.
struct PanelFigure: View {
    let value: String
    var unit: String? = nil
    var size: CGFloat = 34
    var dim = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(PanelType.hero(size))
                .tracking(-size * 0.035)
                .monospacedDigit()
                .foregroundStyle(dim ? PanelInk.quiet : PanelInk.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .widgetAccentable()
            if let unit {
                Text(unit)
                    .font(PanelType.sans(12))
                    .foregroundStyle(PanelInk.quiet)
                    .lineLimit(1)
            }
        }
    }
}

/// What a panel says when there is nothing it can stand behind: a dash, then one sentence that tells
/// the wearer what fills it in. Never a zero, never a sample.
struct PanelEmpty: View {
    let title: String
    let symbol: String
    let tint: Color
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelKicker(title: title, symbol: symbol, tint: tint)
            Spacer(minLength: 6)
            Text("—")
                .font(PanelType.hero(30))
                .foregroundStyle(PanelInk.quiet)
            Text(message)
                .font(PanelType.sans(12))
                .foregroundStyle(PanelInk.quiet)
                .lineSpacing(1.5)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
    }
}

/// The outline of the chart a medium panel will draw, at a whisper, beside its empty-state sentence: it
/// shows what is coming without a single invented value.
struct PanelGhost: View {
    enum Style { case bars, grid, tracks, line, progress }
    let style: Style

    private let ink = Color.white.opacity(0.05)

    var body: some View {
        Group {
            switch style {
            case .bars:
                HStack(alignment: .bottom, spacing: 7) {
                    ForEach([0.55, 0.8, 0.4, 0.95, 0.65, 0.75, 0.5], id: \.self) { h in
                        GeometryReader { proxy in
                            RoundedRectangle(cornerRadius: 3).fill(ink)
                                .frame(width: min(10, proxy.size.width), height: proxy.size.height * 0.62 * h)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                }
            case .grid:
                VStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { _ in
                        HStack(spacing: 3) {
                            ForEach(0..<12, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 2.5).stroke(ink, lineWidth: 0.75)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            case .tracks:
                VStack(spacing: 14) {
                    ForEach(0..<5, id: \.self) { _ in Capsule().fill(ink).frame(height: 3) }
                }
                .frame(maxHeight: .infinity)
            case .line:
                GeometryReader { proxy in
                    Path { path in
                        let w = proxy.size.width, h = proxy.size.height
                        path.move(to: CGPoint(x: 0, y: h * 0.35))
                        path.addCurve(to: CGPoint(x: w, y: h * 0.7),
                                      control1: CGPoint(x: w * 0.35, y: h * 0.2),
                                      control2: CGPoint(x: w * 0.6, y: h * 0.85))
                    }
                    .stroke(ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [3, 4]))
                }
            case .progress:
                VStack(alignment: .leading, spacing: 10) {
                    ForEach([0.9, 0.7, 0.8], id: \.self) { w in
                        GeometryReader { proxy in
                            Capsule().fill(ink).frame(width: proxy.size.width * w, height: 8)
                        }
                        .frame(height: 8)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
        }
        .accessibilityHidden(true)
    }
}

extension PanelEmpty {
    /// The medium layout: the sentence on the left, the chart's outline on the right.
    @ViewBuilder
    func medium(_ ghost: PanelGhost.Style?) -> some View {
        if let ghost {
            HStack(alignment: .top, spacing: 18) {
                self.frame(width: 150, alignment: .leading)
                PanelGhost(style: ghost).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            self
        }
    }
}

// MARK: - Formatting

enum PanelFormat {
    /// "7h 12m"; "48m" under an hour.
    static func duration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let h = total / 60, m = total % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    /// "1h22" / "48m" — for tight legends.
    static func compactDuration(_ minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let h = total / 60, m = total % 60
        return h == 0 ? "\(m)m" : String(format: "%dh%02d", h, m)
    }

    static func grouped(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static func decimal(_ value: Double, _ places: Int) -> String {
        String(format: "%.\(places)f", value)
    }

    /// A signed change with a real minus sign, or "steady" inside half a unit of rounding.
    static func signed(_ value: Double, places: Int = 1) -> String {
        let text = decimal(abs(value), places)
        if Double(text) == 0 { return "steady" }
        return (value < 0 ? "\u{2212}" : "+") + text
    }

    /// "today", "yesterday", or a short weekday and date.
    static func day(_ date: Date, now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(date, inSameDayAs: now) { return "today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    static func isToday(_ date: Date, now: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: now)
    }
}

// MARK: - Samples

/// Shapes for the redacted placeholder and the Debug simulator gallery. Never shown as data.
enum PanelSamples {
    /// The first morning after setup: one night, one session, zones still from the population, a single
    /// weigh-in, a goal with nothing measured yet. The Debug widget board checks the early state with it.
    static var firstDay: WidgetPanels {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let full = panels
        let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? today
        let todayIndex = max(0, min(6, calendar.dateComponents([.day], from: monday, to: today).day ?? 0))
        let gridToday = 77 + todayIndex
        let grid: [Int?] = (0..<84).map { i -> Int? in i == gridToday ? 34 : nil }
        let weekMinutes: [Int?] = (0..<7).map { i -> Int? in i == todayIndex ? 34 : nil }
        let weekSessions: [Int] = (0..<7).map { i -> Int in i == todayIndex ? 1 : 0 }
        var sleep = full.sleep
        sleep?.needCalibrating = true
        sleep?.week = [nil, nil, nil, nil, nil, nil, 412]
        sleep?.asleepMin = 412
        var vitals = full.vitals
        let population: [WidgetPanels.Vitals.Item] = (full.vitals?.items ?? []).map { item in
            var judged = item
            judged.baseline = nil
            return judged
        }
        vitals?.items = population
        return WidgetPanels(
            updated: now,
            sleep: sleep,
            steps: .init(today: 3_204, source: "strap", week: [nil, nil, nil, nil, nil, nil, 3_204],
                         weekLetters: full.steps?.weekLetters ?? [], goal: nil),
            vitals: vitals,
            weight: .init(unit: "kg", latest: 80.4, latestAt: now.addingTimeInterval(-3_600), trend: 80.4,
                          trendReliable: false, change30: nil,
                          readings: [.init(at: now.addingTimeInterval(-3_600), value: 80.4)],
                          trendLine: [.init(at: now.addingTimeInterval(-3_600), value: 80.4)]),
            training: .init(weekMinutes: weekMinutes, weekSessions: weekSessions,
                            weekLetters: full.training?.weekLetters ?? [], todayIndex: todayIndex,
                            last: .init(title: "Outdoor run", strength: false, symbol: "figure.run",
                                        start: now.addingTimeInterval(-2 * 3_600), minutes: 34),
                            grid: grid, trained28: 1),
            goal: .init(title: "Get to 75 kg by spring", kind: "Body weight", symbol: "scalemass.fill", progress: nil,
                        health: "Building evidence", healthRank: 4, reason: "Two weeks of weigh-ins set the trend.",
                        deadline: calendar.date(byAdding: .day, value: 150, to: today), current: "80.4 kg",
                        target: "75 kg", nextMilestone: nil, streakWeeks: 0, today: [], measured: true))
    }

    static var panels: WidgetPanels {
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let letters = (0..<7).map { i -> String in
            let d = calendar.date(byAdding: .day, value: i - 6, to: today) ?? today
            return calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: d) - 1]
        }
        let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? today
        let weekLetters = (0..<7).map { i -> String in
            let d = calendar.date(byAdding: .day, value: i, to: monday) ?? monday
            return calendar.veryShortStandaloneWeekdaySymbols[calendar.component(.weekday, from: d) - 1]
        }
        let todayIndex = max(0, min(6, (calendar.dateComponents([.day], from: monday, to: today).day ?? 0)))
        let runs: [(Int, Double, Double)] = [
            (0, 0, 0.03), (1, 0.03, 0.12), (3, 0.12, 0.24), (1, 0.24, 0.33), (2, 0.33, 0.40),
            (1, 0.40, 0.48), (3, 0.48, 0.55), (1, 0.55, 0.66), (0, 0.66, 0.675), (2, 0.675, 0.78),
            (1, 0.78, 0.88), (2, 0.88, 0.97), (0, 0.97, 1),
        ]
        let minutesPattern: [Int] = [0, 45, 0, 62, 30, 0, 90, 0, 48, 0]
        var grid: [Int?] = (0..<84).map { i -> Int? in minutesPattern[i % 10] }
        let sampleMinutes: [Int] = [48, 0, 62, 0, 35, 90, 0]
        let sampleSessions: [Int] = [1, 0, 1, 0, 1, 2, 0]
        let weekMinutes: [Int?] = (0..<7).map { i -> Int? in i > todayIndex ? nil : sampleMinutes[i] }
        let weekSessions: [Int] = (0..<7).map { i -> Int in i > todayIndex ? 0 : sampleSessions[i] }
        let gridStart = calendar.date(byAdding: .day, value: -77, to: monday) ?? monday
        for i in grid.indices {
            if let d = calendar.date(byAdding: .day, value: i, to: gridStart), d > today { grid[i] = nil }
        }
        let wobble: [Double] = [0.35, -0.2, 0.05]
        let weights: [WidgetPanels.Weight.Point] = (0..<24).map { i in
            let daysAgo = Double(90 - i * 4)
            let value: Double = 81.6 - Double(i) * 0.06 + wobble[i % 3]
            return WidgetPanels.Weight.Point(at: now.addingTimeInterval(-daysAgo * 86_400), value: value)
        }
        let trend: [WidgetPanels.Weight.Point] = weights.enumerated().map { i, point in
            WidgetPanels.Weight.Point(at: point.at, value: 81.6 - Double(i) * 0.055)
        }
        return WidgetPanels(
            updated: now,
            sleep: .init(endedAt: today.addingTimeInterval(6.6 * 3600), asleepMin: 437, deepMin: 82, remMin: 104,
                         lightMin: 251, awakeMin: 31, window: "23:24 \u{2013} 06:52", needMin: 465,
                         needCalibrating: false, runs: runs.map { .init(stage: $0.0, from: $0.1, to: $0.2) },
                         week: [452, 401, nil, 468, 422, 489, 437], weekLetters: letters),
            steps: .init(today: 6_480, source: "health", week: [9_120, 7_340, 11_205, 6_010, 8_870, 10_400, 6_480],
                         weekLetters: letters, goal: 8_000),
            vitals: .init(measuredAt: today, items: [
                .init(id: "rhr", name: "Resting heart rate", short: "Resting", unit: "bpm", decimals: 0, value: 51,
                      low: 48, high: 56, scaleLow: 41.6, scaleHigh: 62.4, baseline: 52, outside: false),
                .init(id: "hrv", name: "Heart rhythm", short: "HRV", unit: "ms", decimals: 0, value: 64,
                      low: 48, high: 78, scaleLow: 24, scaleHigh: 102, baseline: 63, outside: false),
                .init(id: "resp", name: "Breathing rate", short: "Breathing", unit: "/min", decimals: 1, value: 14.6,
                      low: 13.4, high: 15.6, scaleLow: 11.6, scaleHigh: 17.4, baseline: 14.5, outside: false),
                .init(id: "spo2", name: "Blood oxygen", short: "Oxygen", unit: "%", decimals: 0, value: 96,
                      low: 95, high: 100, scaleLow: 91, scaleHigh: 100, baseline: nil, outside: false),
                .init(id: "skin", name: "Skin temperature", short: "Skin temp", unit: "\u{00B0}C", decimals: 1,
                      value: 0.7, low: -0.6, high: 0.6, scaleLow: -1.6, scaleHigh: 1.6, baseline: nil, outside: true),
            ]),
            weight: .init(unit: "kg", latest: 80.4, latestAt: now.addingTimeInterval(-6 * 3600), trend: 80.3,
                          trendReliable: true, change30: -0.8, readings: weights,
                          trendLine: trend),
            training: .init(weekMinutes: weekMinutes, weekSessions: weekSessions,
                            weekLetters: weekLetters, todayIndex: todayIndex,
                            last: .init(title: "Upper body", strength: true, symbol: "dumbbell.fill",
                                        start: now.addingTimeInterval(-26 * 3600), minutes: 52),
                            grid: grid, trained28: 15),
            goal: .init(title: "Half marathon, comfortably", kind: "Running", symbol: "figure.run", progress: 0.62,
                        health: "On track", healthRank: 3, reason: "Your long run is growing on schedule.",
                        deadline: calendar.date(byAdding: .day, value: 46, to: today), current: "13 km",
                        target: "21.1 km", nextMilestone: "15 km", streakWeeks: 4,
                        today: [.init(label: "Easy 40 min", done: true), .init(label: "8,000 steps", done: false)]))
    }
}
