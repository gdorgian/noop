import Foundation
import SwiftUI

// MARK: - Act 4 · The bigger picture

struct NoopAct4Screens: View {
    @ObservedObject var navigation: NoopNavigation
    /// The production shell's measured weekly lines. Nil only in the seeded Debug shell.
    var trends: NoopTrendsRecord? = nil
    var battery: Int? = nil
    /// Production body age for the hero door (same engine as `ages`).
    var ages: NoopAgesRecord? = nil
    @SceneStorage("noop.act4.window") private var windowRaw = NoopTrendWindow.sixMonths.rawValue

    private var window: NoopTrendWindow {
        NoopTrendWindow(rawValue: windowRaw) ?? .sixMonths
    }

    private var windowBinding: Binding<NoopTrendWindow> {
        Binding(
            get: { window },
            set: { windowRaw = $0.rawValue }
        )
    }

    var body: some View {
        switch navigation.route {
        case .capacity:
            NoopCapacityScreen(navigation: navigation, window: window, live: trends)
        case .rhythm:
            NoopRhythmScreen(navigation: navigation, window: window, live: trends)
        case .year:
            NoopYearScreen(navigation: navigation)
        default:
            NoopTrendsScreen(navigation: navigation, window: windowBinding, live: trends, battery: battery, ages: ages)
        }
    }
}

private enum NoopTrendWindow: String, CaseIterable {
    case sixWeeks = "6 weeks"
    case sixMonths = "6 months"
    case year = "Year"

    var count: Int {
        switch self {
        case .sixWeeks: 6
        case .sixMonths: 26
        case .year: 52
        }
    }

    var span: String {
        switch self {
        case .sixWeeks: "Last six weeks"
        case .sixMonths: "Last six months"
        case .year: "Last twelve months"
        }
    }

    /// Four labels across the window's own weeks: "6w ago … now" on six weeks, month names otherwise.
    func axis(weekStarts: [Date]) -> [String] {
        let starts = Array(weekStarts.suffix(count))
        guard self != .sixWeeks, starts.count >= 4 else { return axis }
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMM")
        return [0, 1, 2, 3].map { f.string(from: starts[min(starts.count - 1, $0 * (starts.count - 1) / 3)]) }
    }

    var axis: [String] {
        switch self {
        case .sixWeeks: ["6w ago", "4w", "2w", "now"]
        case .sixMonths: ["Mar", "Apr", "Jun", "Aug"]
        case .year: ["Sep", "Dec", "Mar", "Aug"]
        }
    }

    var from: String {
        switch self {
        case .sixWeeks: "six weeks ago"
        case .sixMonths: "March"
        case .year: "last September"
        }
    }
}

private enum NoopA4 {
    static let green = Color(hex: 0x2ECC80)
    static let greenLight = Color(hex: 0x8FEFC0)
    static let lavender = Color(hex: 0x8B99D6)
    static let warm = Color(hex: 0xF2B45C)

    static func series(base: Double, drift: Double, amplitude: Double) -> [Double] {
        (0..<52).map { index in
            let i = Double(index)
            let wobble = amplitude * (sin(i * 1.71) * 0.6 + sin(i * 0.63) * 0.4)
            let raw = max(0, min(1, ((i / 51) - 0.35) / 0.65))
            let ramp = raw * raw * (3 - 2 * raw)
            return base + drift * ramp + wobble
        }
    }

    static let resting = series(base: 62.6, drift: -5.1, amplitude: 0.8)
    static let variability = series(base: 42.6, drift: 13.6, amplitude: 2.2)
    static let sleep = series(base: 6.85, drift: 0.51, amplitude: 0.28)
    static let capacity = series(base: 40.4, drift: 3.97, amplitude: 0.35)
    static let drift = series(base: 54, drift: -38, amplitude: 8).map { max(6, $0) }

    static func tail(_ values: [Double], for window: NoopTrendWindow) -> [Double] {
        Array(values.suffix(window.count))
    }
}

private struct NoopTrendsScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @Binding var window: NoopTrendWindow
    var live: NoopTrendsRecord? = nil
    var battery: Int? = nil
    var ages: NoopAgesRecord? = nil

    var body: some View {
        NoopScreen(topInset: 58) {
            VStack(alignment: .leading, spacing: 0) {
                NoopA4Header(title: "Trends", eyebrow: window.span) {
                    NoopBatteryChip(percent: live == nil ? 52 : battery) { navigation.push(.strap) }
                }

                Button { navigation.reset(to: .ages) } label: {
                    NoopBodyAgeHero(
                        live: ages?.bodyAge.map { (age: $0, chrono: ages?.chronoAge ?? 0) },
                        calibrating: live != nil,
                        profileNeeded: live != nil && ages?.loaded == true && (ages?.chronoAge ?? 0) == 0,
                        waitingReason: ages?.buildReason ?? "Checking recorded signals"
                    )
                }
                .buttonStyle(NoopHTMLPressStyle())
                .padding(.top, 10)

                VStack(alignment: .leading, spacing: 9) {
                    windowControl
                    // Six weeks always says "too early"; the longer verdicts assert the lines moved,
                    // and have no designed form for when they did not, so production shows only the
                    // six-week card (listed for design).
                    if live == nil || window == .sixWeeks {
                    verdictCard
                    }

                    ForEach(trendRows) { row in
                        NoopTrendSignalCard(row: row)
                    }

                    NoopAttendanceCard(live: live?.attendance)

                    NoopHTMLCard(radius: 22, padding: 0) {
                        VStack(spacing: 0) {
                            trendLink("Capacity", detail: live == nil ? "the estimate, and what moved it" : nil, symbol: "lungs", route: .capacity)
                            Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                            trendLink("Rhythm", detail: "sleep, and how regular it has been", symbol: "moon", route: .rhythm)
                            Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                            // The year's chapters and firsts are written for the example person; no engine
                            // writes them for a real record, so production has no door into an empty page.
                            if live == nil {
                            trendLink("The year so far", detail: "eight months in four chapters", symbol: "chart.bar.xaxis", route: .year)
                            Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                            }
                            trendLink("Ask it something", detail: "every signal you keep, and what moves it", symbol: "ask", route: .instrumentIndex)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }

                    Text("Four lines and a grid. Noop will not show you a trend it cannot defend — on a short window it says so instead of drawing an arrow.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .noopA4LineBox(fontSize: 11.5, ratio: 1.6)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 14)
            }
        }
    }

    private var windowControl: some View {
        HStack(spacing: 4) {
            ForEach(NoopTrendWindow.allCases, id: \.rawValue) { item in
                Button { withAnimation(.easeOut(duration: 0.18)) { window = item } } label: {
                    Text(item.rawValue)
                        .font(NoopHTMLFont.sans(12.5, weight: item == window ? .semibold : .regular))
                        .foregroundStyle(item == window ? Color(hex: 0x9FE2FB) : NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(item == window ? NoopA4.green.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(item == window ? NoopA4.green.opacity(0.4) : .clear, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
    }

    private var verdictCard: some View {
        let isShort = window == .sixWeeks
        let kicker = isShort ? "Six weeks in" : window == .sixMonths ? "Six months in" : "Twelve months in"
        let headline = isShort ? "Too early to say." : window == .sixMonths ? "Yes — slowly." : "Yes, and you can see where."
        let restingChange = abs(change(in: NoopA4.resting))
        let variabilityChange = abs(change(in: NoopA4.variability))
        let capacityChange = abs(change(in: NoopA4.capacity))
        let restingText = String(format: "%.0f", restingChange)
        let variabilityText = String(format: "%.0f", variabilityChange)
        let capacityText = String(format: "%.1f", capacityChange)
        let body = isShort
            ? (live == nil
                ? "Nothing here has cleared its own noise yet. Every line on this window moves as much on a warm room or a late dinner as it does on training. Ask again at three months — the app would rather say nothing than draw you an arrow it cannot defend."
                : "The recorded weekly averages are below. Six weeks alone cannot establish whether a change will last.")
            : window == .sixMonths
                ? "Resting pulse down \(restingText) beats, variability up \(variabilityText) milliseconds, capacity up \(capacityText) points. All three followed the sleep line, and the sleep line followed one decision: going to bed at roughly the same hour."
                : "The change is not spread evenly across the year — it starts in March and holds. Four chapters, one of which did most of the work."
        let tint = isShort ? NoopA4.lavender : NoopA4.green

        return VStack(alignment: .leading, spacing: 9) {
            Text(kicker.uppercased())
                .font(NoopHTMLFont.sans(10, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(isShort ? Color(hex: 0xC9D0EE) : NoopA4.green)
            Text(headline)
                .font(NoopHTMLFont.outfit(32, weight: .light))
                .tracking(-1.024)
                .foregroundStyle(NoopHTMLColor.ink)
                .frame(minHeight: 34.56, alignment: .top)
            Text(body)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(Color(hex: 0xB4C9BE))
                .noopA4LineBox(fontSize: 13.5, ratio: 1.6)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 17)
        .background {
            NoopCSSLinearGradient(
                colors: [tint.opacity(isShort ? 0.14 : 0.16), tint.opacity(0.03)]
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(tint.opacity(0.3), lineWidth: 0.5))
    }

    private func change(in values: [Double]) -> Double {
        let shown = NoopA4.tail(values, for: window)
        return (shown.last ?? 0) - (shown.first ?? 0)
    }

    private var trendRows: [NoopTrendSignal] {
        if let live { return liveRows(live) }
        return [
            signal(name: "Resting pulse", values: NoopA4.resting, unit: "bpm", digits: 0, lowerIsBetter: true,
                   short: "Six weeks is not enough to call this. It moves two beats either way with a warm room or a late meal.",
                   good: "{d} down since {from}, and it has held at this level for eleven weeks. The clearest thing on the screen.",
                   bad: "Up {d} over the window. Usually sleep before fitness — check Rhythm first."),
            signal(name: "Variability", values: NoopA4.variability, unit: "ms", digits: 0, lowerIsBetter: false,
                   short: "Too noisy at this length to mean anything. It swings ten milliseconds on a glass of wine.",
                   good: "Up {d} since {from}. Your body is absorbing effort better than it was in spring.",
                   bad: "Down {d} over the window, which usually follows a stretch of short nights."),
            signal(name: "Sleep", values: NoopA4.sleep, unit: "h", digits: 1, lowerIsBetter: false,
                   short: "Six weeks of sleep tells you about six weeks, not about you.",
                   good: "{m} a night more than {inFrom}. Every other line on this screen follows from that one.",
                   bad: "Down {m} a night. This is the line to fix first; the others follow it."),
            signal(name: "Capacity", values: NoopA4.capacity, unit: "ml/kg", digits: 1, lowerIsBetter: false,
                   short: "Capacity moves too slowly to show up in six weeks. Ask again in three months.",
                   good: "Up {d} since {from}. Ordinary walking and steady rides did that, not intervals.",
                   bad: "Down {d}, which after a quiet stretch is expected rather than alarming.")
        ]
    }

    private func signal(
        name: String,
        values: [Double],
        unit: String,
        digits: Int,
        lowerIsBetter: Bool,
        short: String,
        good: String,
        bad: String
    ) -> NoopTrendSignal {
        let shown = NoopA4.tail(values, for: window)
        let current = shown.last ?? 0
        let change = current - (shown.first ?? current)
        let threshold = name == "Variability" ? 3.4 : name == "Resting pulse" ? 1.3 : name == "Sleep" ? 0.34 : 0.5
        let flat = window == .sixWeeks || abs(change) < threshold
        let improved = lowerIsBetter ? change < 0 : change > 0
        let value = current.formatted(.number.precision(.fractionLength(digits)))
        let amount = abs(change).formatted(.number.precision(.fractionLength(digits))) + " " + unit
        let minutes = "\(Int((abs(change) * 60).rounded())) minutes"
        let copy = (window == .sixWeeks ? short : improved ? good : bad)
            .replacingOccurrences(of: "{d}", with: amount)
            .replacingOccurrences(of: "{m}", with: minutes)
            .replacingOccurrences(of: "{from}", with: window.from)
            .replacingOccurrences(of: "{inFrom}", with: window == .sixMonths ? "in March" : window == .year ? "last September" : "six weeks ago")
        return NoopTrendSignal(
            name: name,
            value: value,
            unit: unit,
            delta: flat ? "no real change" : (change > 0 ? "+" : "−") + amount,
            read: copy,
            values: shown,
            color: flat ? Color(hex: 0x7F8A85) : improved ? NoopA4.green : NoopA4.warm,
            flat: flat,
            improved: improved
        )
    }

    // MARK: Measured rows

    /// Production rows describe only the weekly values actually present in the selected window.
    /// Missing weeks are not counted, and no cause, duration of a plateau, or clinical significance
    /// is inferred from the first and last recorded values.
    private func liveRows(_ live: NoopTrendsRecord) -> [NoopTrendSignal] {
        let n = window.count
        func row(_ name: String, _ series: [Double?], unit: String, digits: Int) -> NoopTrendSignal {
            let shown = Array(series.suffix(n)).compactMap { $0 }
            let current = shown.last
            let value = current.map { $0.formatted(.number.precision(.fractionLength(digits))) } ?? "\u{2014}"
            guard let first = shown.first, let last = current, shown.count >= 2 else {
                let read = shown.isEmpty ? "No recorded weeks in this window." : "One recorded week in this window."
                return NoopTrendSignal(name: name, value: value, unit: unit, delta: "", read: read, values: shown,
                                       color: Color(hex: 0x7F8A85), flat: true, improved: false)
            }
            let scale = pow(10.0, Double(digits))
            let displayedChange = (last * scale).rounded() / scale - (first * scale).rounded() / scale
            let amount = abs(displayedChange).formatted(.number.precision(.fractionLength(digits))) + " " + unit
            let firstText = first.formatted(.number.precision(.fractionLength(digits)))
            let lastText = last.formatted(.number.precision(.fractionLength(digits)))
            let read = "Recorded weekly average: \(firstText) to \(lastText) \(unit) across \(shown.count) weeks with data."
            return NoopTrendSignal(
                name: name, value: value, unit: unit,
                delta: displayedChange == 0 ? "unchanged" : (displayedChange > 0 ? "+" : "\u{2212}") + amount,
                read: read, values: shown,
                color: Color(hex: 0x7F8A85),
                flat: true, improved: false)
        }
        return [
            row("Resting pulse", live.restingPulse, unit: "bpm", digits: 0),
            row("Variability", live.variability, unit: "ms", digits: 0),
            row("Sleep", live.sleep, unit: "h", digits: 1),
            row("Capacity", live.capacity, unit: "ml/kg", digits: 1)
        ]
    }

    private func trendLink(_ title: String, detail: String?, symbol: String, route: NoopRoute) -> some View {
        let tint = symbol == "ask" ? NoopA4.lavender : NoopA4.green
        return Button { navigation.push(route) } label: {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: glyph(for: symbol), size: 20, color: tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                    if let detail {
                        Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                    }
                }
                Spacer()
                NoopA4CSSChevron(direction: .right, color: NoopHTMLColor.chevronDim)
            }
            .frame(minHeight: 60)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private func glyph(for symbol: String) -> NoopCanonicalGlyphName {
        switch symbol {
        case "lungs": .lungs
        case "moon": .moon
        case "ask": .ask
        default: .trends
        }
    }
}

private struct NoopA4Header<Trailing: View>: View {
    let title: String
    let eyebrow: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .frame(height: 16.5, alignment: .top)
                Text(title)
                    .font(NoopHTMLFont.outfit(23))
                    .tracking(-0.46)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .frame(height: 26.45, alignment: .top)
            }
            Spacer(minLength: 0)
            trailing
        }
        .frame(height: 46.95, alignment: .top)
        .padding(.bottom, 4)
    }
}

private struct NoopBodyAgeHero: View {
    var live: (age: Double, chrono: Int)? = nil
    /// Only used in the measured shell when VitalityEngine has no defensible result yet.
    var calibrating = false
    var profileNeeded = false
    var waitingReason = "Checking recorded signals"

    private var awaitingAge: Bool { calibrating && live == nil }
    private var olderThanChronological: Bool {
        live.map { $0.chrono > 0 && $0.age > Double($0.chrono) } ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                NoopSectionLabel("Body age", color: Color(hex: 0x8B958F))
                Spacer()
                if live == nil && !calibrating {
                Text("next update Saturday")
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
                }
            }

            NoopA4AnimatedAgeAura(live: live, calibrating: awaitingAge, waitingReason: waitingReason)
                .frame(maxWidth: .infinity)
                .frame(height: 246)

            if live == nil && !calibrating {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 10) {
                    NoopSectionLabel("Pace of aging", color: Color(hex: 0x8B958F))
                    Spacer()
                    Text("slower vs last month")
                        .font(NoopHTMLFont.sans(11, weight: .semibold))
                        .foregroundStyle(NoopA4.greenLight)
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background(NoopA4.green.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
                }

                NoopPaceScale()

                Text("At this pace you are putting on about 10 months of body age a year instead of twelve. Read it as a direction, not a promise.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .noopA4LineBox(fontSize: 11.5, ratio: 1.55)
            }
            .padding(.top, 4)
            }

            HStack(spacing: 10) {
                Text(awaitingAge
                     ? (profileNeeded ? "Confirm your profile to begin" : "Your ages — gathering measured inputs")
                     : (live == nil ? "Your ages — five drivers, the ±5 band, and how it is figured" : "Your ages"))
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                Spacer(minLength: 0)
                NoopA4CSSChevron(direction: .right, color: olderThanChronological ? NoopA4.warm : NoopA4.greenLight)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
            .padding(.top, 13)
        }
    }
}

private struct NoopA4AnimatedAgeAura: View {
    var live: (age: Double, chrono: Int)? = nil
    var calibrating = false
    var waitingReason = "Checking recorded signals"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var olderThanChronological: Bool {
        live.map { $0.chrono > 0 && $0.age > Double($0.chrono) } ?? false
    }
    private var accent: Color { olderThanChronological ? NoopA4.warm : NoopA4.green }
    private var accentLight: Color { olderThanChronological ? Color(hex: 0xFFE0A5) : NoopA4.greenLight }
    private var accentMiddle: Color { olderThanChronological ? Color(hex: 0xF2B45C, alpha: 0.78) : Color(hex: 0x30CE84, alpha: 0.78) }
    private var accentOuter: Color { olderThanChronological ? Color(hex: 0xFFE0A5, alpha: 0.42) : Color(hex: 0x9EF0CC, alpha: 0.42) }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || calibrating)) { timeline in
            let seconds = calibrating ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = calibrating ? 0.55 : (reduceMotion ? 1 : 0.72 + 0.28 * NoopA4Animation.pulse(seconds: seconds, duration: 8))
            let main = NoopA4Animation.morph(seconds: seconds, duration: 22, reversed: false)
            let halo = NoopA4Animation.morph(seconds: seconds, duration: 31, reversed: true)
            let spin = (reduceMotion || calibrating) ? 0 : seconds.truncatingRemainder(dividingBy: 52) / 52 * 360

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: accent.opacity(0.30), location: 0),
                                .init(color: .clear, location: 0.62)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 209.3
                        )
                    )
                    .frame(width: 296, height: 296)
                    .blur(radius: 16)
                    .opacity(pulse)

                NoopA4BlobShape(radii: main.radii)
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: 0x080B0A), location: 0),
                                .init(color: Color(hex: 0x080B0A), location: 0.33),
                                .init(color: accent.opacity(0.09), location: 0.41),
                                .init(color: accent.opacity(0.34), location: 0.54),
                                .init(color: accentMiddle, location: 0.70),
                                .init(color: accentOuter, location: 0.85),
                                .init(color: accent.opacity(0.10), location: 0.95),
                                .init(color: .clear, location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 159.81
                        )
                    )
                    .frame(width: 226, height: 226)
                    .scaleEffect(main.scale)
                    .rotationEffect(.degrees(main.rotation))
                    .blur(radius: 5)

                NoopA4BlobShape(radii: halo.radii)
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: .clear, location: 0.48),
                                .init(color: accent.opacity(0.13), location: 0.64),
                                .init(color: accentLight.opacity(0.17), location: 0.80),
                                .init(color: .clear, location: 0.96)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 168.29
                        )
                    )
                    .frame(width: 238, height: 238)
                    .scaleEffect(halo.scale)
                    .rotationEffect(.degrees(halo.rotation))
                    .blur(radius: 10)

                NoopA4SpeckField(tint: olderThanChronological ? NoopA4.warm : nil)
                    .frame(width: 224, height: 224)
                    .rotationEffect(.degrees(spin))
                    .opacity(calibrating ? 0.45 : 1)

                VStack(spacing: 0) {
                    Text(calibrating ? "—" : live.map { "\(Int($0.age.rounded()))" } ?? "34")
                        .font(NoopHTMLFont.outfit200(68))
                        .tracking(-3.4)
                        .monospacedDigit()
                        .frame(height: 68)
                        .shadow(color: .black.opacity(0.6), radius: 13, y: 2)
                    Text("BODY AGE")
                        .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                        .tracking(2.1)
                        .foregroundStyle(Color(hex: 0x93A0A6))
                        .padding(.top, 7)
                    Text(calibrating ? waitingReason : auraDelta)
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(calibrating ? NoopHTMLColor.inkSoft : accentLight)
                        .padding(.top, 9)
                }
            }
        }
    }
}

private extension NoopA4AnimatedAgeAura {
    var auraDelta: String {
        guard let live else { return "6 years younger" }
        let years = Double(live.chrono) - live.age
        if years == 0 { return "the same as your age" }
        if abs(years) < 0.5 { return "less than a year \(years > 0 ? "younger" : "older")" }
        let rounded = Int(abs(years).rounded())
        return "\(rounded) \(rounded == 1 ? "year" : "years") \(years > 0 ? "younger" : "older")"
    }
}

private struct NoopA4Speck: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let opacity: Double
    let big: Bool
}

private struct NoopA4SpeckField: View {
    var tint: Color? = nil

    private static func hash(_ n: Int) -> Double {
        let x = sin(Double(n) * 127.1 + 311.7) * 43_758.5453
        return x - floor(x)
    }

    private static let specks: [NoopA4Speck] = (0..<76).map { index in
        let angle = Double(index) * 2.39996 + hash(index) * 1.1
        let radius = 0.56 + hash(index + 90) * 0.46
        let big = hash(index + 210) > 0.86
        let size = big ? 4.6 + hash(index + 7) * 2.6 : 1.2 + hash(index + 31) * 2.4
        let opacity = big ? 0.16 + hash(index + 55) * 0.16 : 0.20 + hash(index + 11) * 0.5
        return NoopA4Speck(
            id: index,
            x: CGFloat(0.5 + cos(angle) * radius * 0.47),
            y: CGFloat(0.5 + sin(angle) * radius * 0.47),
            size: CGFloat(size),
            opacity: opacity,
            big: big
        )
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                ForEach(Self.specks) { speck in
                    Circle()
                        .fill(tint?.opacity(speck.opacity) ?? Color(hex: 0xD8FFEC, alpha: speck.opacity))
                        .frame(width: speck.size, height: speck.size)
                        .shadow(
                            color: tint?.opacity(speck.big ? 0.5 : 0.8) ?? Color(hex: 0x68E6A4, alpha: speck.big ? 0.5 : 0.8),
                            radius: speck.size * (speck.big ? 2.1 : 1.3)
                        )
                        .position(x: speck.x * proxy.size.width, y: speck.y * proxy.size.height)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct NoopA4BlobRadii {
    var tlx: CGFloat; var tly: CGFloat
    var trx: CGFloat; var try_: CGFloat
    var brx: CGFloat; var bry: CGFloat
    var blx: CGFloat; var bly: CGFloat

    static func mix(_ a: Self, _ b: Self, _ t: CGFloat) -> Self {
        func m(_ x: CGFloat, _ y: CGFloat) -> CGFloat { x + (y - x) * t }
        return .init(
            tlx: m(a.tlx, b.tlx), tly: m(a.tly, b.tly),
            trx: m(a.trx, b.trx), try_: m(a.try_, b.try_),
            brx: m(a.brx, b.brx), bry: m(a.bry, b.bry),
            blx: m(a.blx, b.blx), bly: m(a.bly, b.bly)
        )
    }
}

struct NoopA4BlobShape: Shape {
    let radii: NoopA4BlobRadii

    func path(in rect: CGRect) -> Path {
        let k: CGFloat = 0.5522847498
        let tl = CGSize(width: rect.width * radii.tlx, height: rect.height * radii.tly)
        let tr = CGSize(width: rect.width * radii.trx, height: rect.height * radii.try_)
        let br = CGSize(width: rect.width * radii.brx, height: rect.height * radii.bry)
        let bl = CGSize(width: rect.width * radii.blx, height: rect.height * radii.bly)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + tl.width, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - tr.width, y: rect.minY))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + tr.height),
            control1: CGPoint(x: rect.maxX - tr.width + tr.width * k, y: rect.minY),
            control2: CGPoint(x: rect.maxX, y: rect.minY + tr.height - tr.height * k)
        )
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br.height))
        p.addCurve(
            to: CGPoint(x: rect.maxX - br.width, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - br.height + br.height * k),
            control2: CGPoint(x: rect.maxX - br.width + br.width * k, y: rect.maxY)
        )
        p.addLine(to: CGPoint(x: rect.minX + bl.width, y: rect.maxY))
        p.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - bl.height),
            control1: CGPoint(x: rect.minX + bl.width - bl.width * k, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - bl.height + bl.height * k)
        )
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl.height))
        p.addCurve(
            to: CGPoint(x: rect.minX + tl.width, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.minY + tl.height - tl.height * k),
            control2: CGPoint(x: rect.minX + tl.width - tl.width * k, y: rect.minY)
        )
        p.closeSubpath()
        return p
    }
}

enum NoopA4Animation {
    struct Morph {
        let radii: NoopA4BlobRadii
        let rotation: Double
        let scale: CGFloat
    }

    static func pulse(seconds: Double, duration: Double) -> Double {
        let p = seconds.truncatingRemainder(dividingBy: duration) / duration
        let half = p < 0.5 ? p * 2 : (1 - p) * 2
        return easeInOut(half)
    }

    static func morph(seconds: Double, duration: Double, reversed: Bool) -> Morph {
        var p = seconds.truncatingRemainder(dividingBy: duration) / duration
        if reversed { p = 1 - p }
        let states: [Morph] = [
            .init(radii: .init(tlx: 0.63, tly: 0.52, trx: 0.37, try_: 0.61, brx: 0.45, bry: 0.39, blx: 0.55, bly: 0.48), rotation: 0, scale: 1),
            .init(radii: .init(tlx: 0.40, tly: 0.58, trx: 0.60, try_: 0.42, brx: 0.62, bry: 0.58, blx: 0.38, bly: 0.42), rotation: 6, scale: 1.03),
            .init(radii: .init(tlx: 0.55, tly: 0.41, trx: 0.45, try_: 0.60, brx: 0.38, bry: 0.40, blx: 0.62, bly: 0.59), rotation: -5, scale: 0.98),
            .init(radii: .init(tlx: 0.63, tly: 0.52, trx: 0.37, try_: 0.61, brx: 0.45, bry: 0.39, blx: 0.55, bly: 0.48), rotation: 0, scale: 1)
        ]
        let cuts = [0.0, 0.33, 0.66, 1.0]
        let segment = p < cuts[1] ? 0 : p < cuts[2] ? 1 : 2
        let local = easeInOut((p - cuts[segment]) / (cuts[segment + 1] - cuts[segment]))
        let a = states[segment], b = states[segment + 1]
        return .init(
            radii: .mix(a.radii, b.radii, CGFloat(local)),
            rotation: a.rotation + (b.rotation - a.rotation) * local,
            scale: a.scale + (b.scale - a.scale) * CGFloat(local)
        )
    }

    private static func easeInOut(_ value: Double) -> Double {
        let target = max(0, min(1, value))
        var u = target
        for _ in 0..<8 {
            let omt = 1 - u
            let x = 3 * omt * omt * u * 0.42 + 3 * omt * u * u * 0.58 + u * u * u
            let dx = 3 * omt * omt * 0.42 + 6 * omt * u * (0.58 - 0.42) + 3 * u * u * (1 - 0.58)
            if abs(dx) > 0.0001 { u -= (x - target) / dx }
            u = max(0, min(1, u))
        }
        return 3 * (1 - u) * u * u + u * u * u
    }
}

private struct NoopPaceScale: View {
    private let position: CGFloat = 0.45

    var body: some View {
        VStack(spacing: 9) {
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<47, id: \.self) { index in
                            let at = CGFloat(index) / 46
                            let distance = abs(at - position)
                            RoundedRectangle(cornerRadius: 1)
                                .fill(distance < 0.045 ? NoopA4.greenLight.opacity(0.92) : distance < 0.13 ? Color.white.opacity(0.26) : Color.white.opacity(0.13))
                                .frame(maxWidth: .infinity)
                                .frame(height: distance < 0.045 ? 28 : distance < 0.13 ? 22 : 16)
                        }
                    }
                    .frame(height: 28, alignment: .bottom)
                    .offset(y: 24)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(NoopHTMLColor.ink)
                        .frame(width: 2, height: 40)
                        .shadow(color: NoopHTMLColor.ink.opacity(0.55), radius: 6)
                        .offset(x: proxy.size.width * position - 1, y: 12)

                    Text("0.8×")
                        .font(NoopHTMLFont.outfit(21))
                        .tracking(-0.525)
                        .monospacedDigit()
                        .fixedSize()
                        .position(x: proxy.size.width * position, y: 12.5)
                }
            }
            .frame(height: 52)

            HStack {
                Text("−1.0×")
                Spacer()
                Text("1.0× = aging in real time")
                Spacer()
                Text("3.0×")
            }
            .font(NoopHTMLFont.sans(10.5))
            .foregroundStyle(NoopHTMLColor.faint)
        }
    }
}

private struct NoopTrendSignal: Identifiable {
    let id = UUID()
    let name: String
    let value: String
    let unit: String
    let delta: String
    let read: String
    let values: [Double]
    let color: Color
    let flat: Bool
    let improved: Bool
}

private struct NoopTrendSignalCard: View {
    let row: NoopTrendSignal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.name)
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text(row.value)
                            .font(NoopHTMLFont.outfit(26, weight: .light))
                            .tracking(-0.78)
                            .monospacedDigit()
                            .frame(height: 26)
                        Text(row.unit)
                            .font(NoopHTMLFont.sans(11))
                            .foregroundStyle(NoopHTMLColor.muted)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    if !row.delta.isEmpty {
                    Text(row.delta)
                        .font(NoopHTMLFont.sans(11, weight: .semibold))
                        .foregroundStyle(row.flat ? NoopHTMLColor.inkSoft : row.improved ? NoopA4.greenLight : Color(hex: 0xF3C888))
                        .padding(.horizontal, 9)
                        .frame(height: 25)
                        .background(
                            row.flat ? Color.white.opacity(0.06) : row.improved ? NoopA4.green.opacity(0.13) : NoopA4.warm.opacity(0.13),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                    }
                    NoopA4Sparkline(values: row.values, color: row.color)
                        .frame(width: 108, height: 34)
                }
            }
            if !row.read.isEmpty {
            Text(row.read)
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(row.flat ? Color(hex: 0x7F8A85) : NoopHTMLColor.copy)
                .noopA4LineBox(fontSize: 11.5, ratio: 1.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

private struct NoopA4Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, let low = values.min(), let high = values.max() else { return }
            let span = max(0.001, high - low)
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: CGFloat(index) / CGFloat(values.count - 1) * 108,
                    y: 30 - CGFloat((value - low) / span) * 30 + 2
                )
            }
            var line = Path()
            line.move(to: points[0])
            for point in points.dropFirst() { line.addLine(to: point) }
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.9, lineCap: .round, lineJoin: .round))
            if let last = points.last {
                context.fill(Path(ellipseIn: CGRect(x: last.x - 2.8, y: last.y - 2.8, width: 5.6, height: 5.6)), with: .color(color))
            }
        }
        .frame(width: 108, height: 34)
    }
}

private struct NoopAttendanceCard: View {
    /// The last 84 days (0 nothing · 1 slept, worn · 2 moved as well). Nil draws the prototype grid.
    var live: [Int]? = nil

    private var recordedDays: Int { live?.filter { $0 > 0 }.count ?? 79 }

    var body: some View {
        NoopHTMLCard(radius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    NoopSectionLabel("Showing up")
                    Spacer()
                    Text("12 weeks \u{00B7} \(recordedDays) of 84 days")
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(NoopHTMLColor.faint)
                }
                HStack(spacing: 4) {
                    ForEach(0..<12, id: \.self) { column in
                        VStack(spacing: 4) {
                            ForEach(0..<7, id: \.self) { row in
                                let index = column * 7 + row
                                let state = live.map { $0.indices.contains(index) ? $0[index] : 0 }
                                let gap = state.map { $0 == 0 } ?? (index % 23 == 4 || (index > 30 && index < 34))
                                let moved = state.map { $0 == 2 } ?? (!gap && (index % 3 == 0 || index % 7 == 5))
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(gap ? Color.white.opacity(0.06) : moved ? NoopA4.green : NoopA4.green.opacity(0.28))
                                    .frame(height: 9)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                NoopFlowLayout(spacing: 12) {
                    key("Slept, worn", color: NoopA4.green.opacity(0.28))
                    key("Moved as well", color: NoopA4.green)
                    key("Nothing recorded", color: Color.white.opacity(0.06))
                }
                // The read names the example person's missing week; production has no template for it.
                if live == nil {
                Text("Five days missing in twelve weeks, and four of them were one week in June. Attendance is the only number Noop counts, because it predicts every other one.")
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .noopA4LineBox(fontSize: 11.5, ratio: 1.55)
                }
            }
        }
    }

    private func key(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 9, height: 9)
            Text(title).font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x7F8A85))
        }
    }
}

private struct NoopCapacityScreen: View {
    @ObservedObject var navigation: NoopNavigation
    let window: NoopTrendWindow
    var live: NoopTrendsRecord? = nil

    private var values: [Double] {
        guard let live else { return NoopA4.tail(NoopA4.capacity, for: window) }
        return Array(live.capacity.suffix(window.count)).compactMap { $0 }
    }

    /// "six weeks ago" / "in March" / "last September", from the window's own first week.
    private var inFrom: String {
        guard let live, let first = live.weekStarts.suffix(window.count).first else {
            return window == .year ? "last September" : window == .sixMonths ? "in March" : "six weeks ago"
        }
        let month = DateFormatter(); month.setLocalizedDateFormatFromTemplate("MMMM")
        switch window {
        case .sixWeeks: return "six weeks ago"
        case .sixMonths: return "in \(month.string(from: first))"
        case .year: return "last \(month.string(from: first))"
        }
    }

    /// The HTML's read up to its first full stop; the age clause needs the unresolved age engine.
    private var read: String? {
        guard live != nil else {
            return "\(change >= 0 ? "Up" : "Down") from \((values.first ?? 40.4).formatted(.number.precision(.fractionLength(1)))) \(inFrom). Around four years under your age, which matters far less than the direction."
        }
        guard values.count >= 2, let first = values.first else { return nil }
        return "\(change >= 0 ? "Up" : "Down") from \(first.formatted(.number.precision(.fractionLength(1)))) \(inFrom)."
    }
    private var change: Double { (values.last ?? 0) - (values.first ?? 0) }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopA4BackHeader(label: "Trends", action: navigation.back)
                VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Capacity").font(NoopHTMLFont.outfit(25)).tracking(-0.6)
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(values.last.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? (live == nil ? "44.4" : "\u{2014}"))
                            .font(NoopHTMLFont.outfit200(54)).tracking(-2.43)
                            .frame(height: 54)
                        Text("ml/kg/min, estimated").font(NoopHTMLFont.sans(13)).foregroundStyle(NoopHTMLColor.copy)
                    }
                    if let read {
                    Text(read)
                        .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                        .noopA4LineBox(fontSize: 13.5, ratio: 1.6)
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        NoopSectionLabel(window.span)
                        Spacer()
                        if values.count >= 2 {
                        NoopA4Chip(
                            text: "\(change >= 0 ? "+" : "−")\(abs(change).formatted(.number.precision(.fractionLength(1)))) over the window",
                            color: change >= 0 ? NoopA4.greenLight : Color(hex: 0xF3C888),
                            background: change >= 0 ? NoopA4.green : NoopA4.warm
                        )
                        }
                    }
                    NoopA4CapacityChart(values: values)
                        .frame(height: 118)
                    NoopA4Axis(labels: live.map { window.axis(weekStarts: $0.weekStarts) } ?? window.axis)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 13)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                if live == nil {
                    NoopHTMLCard(radius: 22, padding: 16) {
                        VStack(alignment: .leading, spacing: 13) {
                            NoopSectionLabel("What moved it")
                            VStack(alignment: .leading, spacing: 12) {
                                capacityFactor("Sleep, and the regularity of it", value: "46%", progress: 0.46, note: "The single biggest contributor: \(sleepChangeMinutes) minutes more a night over this window, taken at roughly the same hour.")
                                capacityFactor("Steady, easy sessions", value: "38%", progress: 0.38, note: "Four to five hours a week at conversation pace. Unglamorous and responsible for most of the curve.")
                                capacityFactor("Hard efforts", value: "16%", progress: 0.16, note: "You have done nine of them in six months. This is the one with room left in it.")
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 9) {
                        Text("What would move it next").font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        Text("One session a week with real intensity, on a day your readiness allows it. Everything else you are already doing. Noop will offer it when the morning agrees — it will not put it in a plan you then have to obey.")
                            .font(NoopHTMLFont.sans(12.5)).foregroundStyle(Color(hex: 0xB4C9BE))
                            .noopA4LineBox(fontSize: 12.5, ratio: 1.6)
                    }
                    .padding(16)
                    .background(NoopA4.green.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopA4.green.opacity(0.2), lineWidth: 0.5))

                    Text("Estimated from resting pulse, recovery after effort and the pace you hold at a given heart rate. It is a direction with an error bar, not a laboratory figure.")
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint)
                        .noopA4LineBox(fontSize: 11.5, ratio: 1.6).padding(.horizontal, 2)
                }
                }
                .padding(.top, 8)
            }
        }
    }

    private func capacityFactor(_ title: String, value: String, progress: Double, note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Text(title); Spacer(); Text(value).foregroundStyle(NoopHTMLColor.copy) }
                .font(NoopHTMLFont.sans(13))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.07))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(NoopA4.green)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 6)
            Text(note).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                .noopA4LineBox(fontSize: 11.5, ratio: 1.5)
        }
    }

    private var sleepChangeMinutes: Int {
        let values = NoopA4.tail(NoopA4.sleep, for: window)
        return Int((((values.last ?? 0) - (values.first ?? 0)) * 60).rounded())
    }
}

private struct NoopRhythmScreen: View {
    @ObservedObject var navigation: NoopNavigation
    let window: NoopTrendWindow
    var live: NoopTrendsRecord? = nil
    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"

    private var sleep: [Double] {
        guard let live else { return NoopA4.tail(NoopA4.sleep, for: window) }
        return Array(live.sleep.suffix(window.count)).compactMap { $0 }
    }
    /// Weekly drift; a week with no night stays an empty slot on the bars.
    private var driftSlots: [Double?] {
        guard let live else { return NoopA4.tail(NoopA4.drift, for: window).map { Optional($0) } }
        return Array(live.drift.suffix(window.count))
    }
    private var drift: [Double] { driftSlots.compactMap { $0 } }
    /// The demo's 7h 12m, or the app's sleep planning target for a real record.
    private var needHours: Double { live.map { $0.needMin / 60 } ?? 7.2 }
    private var needText: String { live.map { NoopRestRecord.duration($0.needMin) } ?? "7h 12m" }
    private var axisLabels: [String] { live.map { window.axis(weekStarts: $0.weekStarts) } ?? window.axis }
    private var isNightWorker: Bool { NoopScheduleInference.isNightWorker(kind: scheduleKind) }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopA4BackHeader(label: "Trends", action: navigation.back)
                VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rhythm").font(NoopHTMLFont.outfit(25)).tracking(-0.6)
                    Text(sleep.isEmpty ? "" : live == nil
                         ? "Average nightly sleep is \(formattedSleep), against a need of \(needText). The average is the less interesting half of this screen."
                         : "Average of the recorded weekly sleep durations: \(formattedSleep). The dashed line below is the app's sleep planning target, not a measured personal requirement.")
                        .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                        .noopA4LineBox(fontSize: 13.5, ratio: 1.6)
                }

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        NoopSectionLabel(live == nil
                                         ? (isNightWorker ? "Main sleep against your need" : "Sleep against your need")
                                         : (isNightWorker ? "Main sleep against target" : "Sleep against target"))
                        Spacer()
                        Text("\(live == nil ? "need" : "target") \(needText)")
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
                    }
                    NoopA4SleepChart(values: sleep, need: needHours)
                        .frame(height: 112)
                    axis
                    Text(live == nil ? "Dashes are your need. You have been over it more weeks than under it since April, which is the whole reason the other three lines moved." : "Dashes mark the app's sleep planning target.")
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                        .noopA4LineBox(fontSize: 11.5, ratio: 1.55)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 13)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel(isNightWorker ? "How far your anchor drifted" : live == nil ? "How far bedtime drifted" : "How far sleep onset drifted")
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(Array(driftSlots.enumerated()), id: \.offset) { _, slot in
                                let value = slot ?? 0
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(slot == nil ? Color.clear : value > 40 ? NoopA4.warm : value > 26 ? NoopA4.lavender.opacity(0.75) : NoopA4.green)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: max(4, 72 * value / max(1, drift.max() ?? 1)))
                            }
                        }
                        .frame(height: 76, alignment: .bottom)
                        axis
                        Text(live == nil
                             ? (isNightWorker
                                ? "Each bar is how far that week’s main sleep moved from your anchor. On a rotating roster this is the only regularity available, and it is the one that counts."
                                : "Each bar is how many minutes that week’s bedtime wandered from your own hour. Under half an hour is where your body stops noticing.")
                             : "Each bar is that week's average distance between sleep onset and the usual onset in this record.")
                            .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                            .noopA4LineBox(fontSize: 11.5, ratio: 1.55)
                    }
                }

                NoopHTMLCard(radius: 22, padding: 0) {
                    VStack(spacing: 0) {
                        rhythmRow(live == nil ? "Nights over your need" : "Nights at or above target",
                                  detail: "in this window", value: nightsOverNeed.map { "\($0)%" } ?? "\u{2014}")
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        rhythmRow("\(isNightWorker ? "Anchor" : live == nil ? "Bedtime" : "Sleep onset") drift, \(live == nil ? "now" : "latest recorded week")", detail: "weekly average", value: drift.last.map { "\(Int($0.rounded())) min" } ?? "\u{2014}")
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        rhythmRow("\(isNightWorker ? "Anchor" : live == nil ? "Bedtime" : "Sleep onset") drift, \(live == nil ? "at the start" : "first recorded week")", detail: "same window", value: drift.first.map { "\(Int($0.rounded())) min" } ?? "\u{2014}", warm: true)
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        rhythmRow("Longest steady stretch", detail: "under 30 minutes of drift", value: longestStretch)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                Text(live == nil
                     ? "Regularity beats duration in the long run. It is the one thing on this screen you can decide tonight."
                     : "These readings describe sleep timing and duration; they do not establish what caused changes in other readings.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint)
                    .noopA4LineBox(fontSize: 11.5, ratio: 1.6).padding(.horizontal, 2)
                }
                .padding(.top, 8)
            }
        }
    }

    private var axis: some View {
        HStack { ForEach(Array(axisLabels.enumerated()), id: \.offset) { i, label in Text(label); if i < axisLabels.count - 1 { Spacer() } } }
            .font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint)
    }

    /// Consecutive weeks under thirty minutes of drift; the example's "11 weeks" in the demo.
    private var longestStretch: String {
        guard live != nil else { return "11 weeks" }
        guard driftSlots.contains(where: { $0 != nil }) else { return "\u{2014}" }
        var best = 0, run = 0
        for slot in driftSlots {
            if let v = slot, v < 30 { run += 1; best = max(best, run) } else { run = 0 }
        }
        return best == 1 ? "1 week" : "\(best) weeks"
    }

    private var formattedSleep: String {
        let hours = live == nil ? (sleep.last ?? 7.2) : sleep.reduce(0, +) / Double(max(1, sleep.count))
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }

    private var nightsOverNeed: Int? {
        if let live {
            let from = live.weekStarts.suffix(window.count).first ?? .distantPast
            let nights = live.nights.filter { $0.day >= from }
            guard !nights.isEmpty else { return nil }
            return Int((Double(nights.filter { $0.minutes >= live.needMin }.count) / Double(nights.count) * 100).rounded())
        }
        guard !sleep.isEmpty else { return nil }
        return Int((Double(sleep.filter { $0 >= 7.2 }.count) / Double(sleep.count) * 100).rounded())
    }

    private func rhythmRow(_ title: String, detail: String, value: String, warm: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(13))
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
            }
            Spacer()
            Text(value)
                .font(NoopHTMLFont.outfit(19))
                .foregroundStyle(warm ? Color(hex: 0xF3C888) : NoopHTMLColor.ink)
                .monospacedDigit()
        }
        .frame(minHeight: 56)
    }
}

private struct NoopYearScreen: View {
    @ObservedObject var navigation: NoopNavigation

    private let chapters: [(String, String, String, String, Color)] = [
        ("January – February", "drift 52 min", "The flat start", "Six or seven hours a night at whatever hour the evening ended. Resting pulse 62, variability in the low forties, and nothing moving in either direction.", NoopHTMLColor.faint),
        ("March – April", "drift 34 min", "The walking months", "You started going to bed inside the same hour and walking most days. Nothing else changed, and by the end of April resting pulse was down two beats.", NoopA4.lavender),
        ("May – June", "drift 21 min", "It took", "The first stretch where sleep was over your need more weeks than under it. Variability climbed eight milliseconds and the rides stopped feeling like efforts.", NoopA4.green),
        ("July – August", "drift 18 min", "The heat, and holding", "Two hot weeks pushed breathing rate up and sleep down, and it recovered on its own within ten days. That recovery is what the last eight months bought you.", NoopA4.green)
    ]

    private let firsts: [(String, String, String, String)] = [
        ("Resting pulse under 60 for a full month", "it had never been under 60 for a week", "May", "heart"),
        ("Eleven weeks inside your own bedtime hour", "previous best was three", "Jun", "clock"),
        ("A hard session your body actually wanted", "readiness said yes and it was right", "Jul", "bolt"),
        ("A hot fortnight you recovered from unaided", "no debt carried into August", "Aug", "checkmark")
    ]

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopA4BackHeader(label: "Trends", action: navigation.back)
                VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("The year so far").font(NoopHTMLFont.outfit(25)).tracking(-0.6)
                    Text("Eight months in four chapters, written the way you would tell it to someone — not as a chart you have to interpret.")
                        .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy)
                        .noopA4LineBox(fontSize: 13.5, ratio: 1.6)
                }

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { _, chapter in
                        VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(chapter.0.uppercased()).font(NoopHTMLFont.sans(10, weight: .semibold)).tracking(1.3).foregroundStyle(chapter.4)
                                    Spacer()
                                    Text(chapter.1).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
                                }
                                Text(chapter.2).font(NoopHTMLFont.outfit(19)).tracking(-0.38)
                                    .frame(height: 22.8, alignment: .top)
                                Text(chapter.3).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                                    .noopA4LineBox(fontSize: 12.5, ratio: 1.6)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 15)
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                    }
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 13) {
                        NoopSectionLabel("Firsts")
                        VStack(alignment: .leading, spacing: 11) {
                            ForEach(Array(firsts.enumerated()), id: \.offset) { _, item in
                                HStack(alignment: .top, spacing: 11) {
                                    NoopCanonicalGlyph(name: firstGlyph(item.3), size: 17, color: NoopA4.green).frame(width: 18)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.0).font(NoopHTMLFont.sans(13))
                                        Text(item.1).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                                    }
                                    Spacer()
                                    Text(item.2).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    NoopSectionLabel("Svea", color: Color(hex: 0xC9D0EE))
                    Text("Nothing here happened because of a hard week. It happened because you went to bed at roughly the same hour for four months and walked most days. The interesting part is that your body is now good enough at recovering that it can take the harder sessions you have been avoiding.")
                        .font(NoopHTMLFont.sans(14)).foregroundStyle(Color(hex: 0xDCE3E0))
                        .noopA4LineBox(fontSize: 14, ratio: 1.68)
                }
                .padding(16)
                .background(NoopA4.lavender.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopA4.lavender.opacity(0.2), lineWidth: 0.5))

                Text("No year-in-review confetti, no personal bests you did not try for. A chapter only appears once there is enough of it to be true.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint)
                    .noopA4LineBox(fontSize: 11.5, ratio: 1.6).padding(.horizontal, 2)
                }
                .padding(.top, 8)
            }
        }
    }

    private func firstGlyph(_ name: String) -> NoopCanonicalGlyphName {
        switch name {
        case "heart": .heart
        case "clock": .clock
        case "bolt": .bolt
        default: .check
        }
    }
}

private struct NoopA4BackHeader: View {
    let label: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                    NoopA4CSSChevron(direction: .left, color: NoopHTMLColor.inkSoft)
                        .offset(x: -1)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            Text(label)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .padding(.horizontal, -2)
        .padding(.bottom, 8)
    }
}

struct NoopA4CSSChevron: View {
    enum Direction: Equatable { case left, right }
    let direction: Direction
    let color: Color

    var body: some View {
        Canvas { context, _ in
            var path = Path()
            if direction == .left {
                path.move(to: CGPoint(x: 8.2, y: 0.8))
                path.addLine(to: CGPoint(x: 0.8, y: 8.2))
                path.addLine(to: CGPoint(x: 8.2, y: 15.6))
            } else {
                path.move(to: CGPoint(x: 0.8, y: 0.8))
                path.addLine(to: CGPoint(x: 7.2, y: 7.2))
                path.addLine(to: CGPoint(x: 0.8, y: 13.6))
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .butt, lineJoin: .miter))
        }
        .frame(width: direction == .left ? 9 : 8, height: direction == .left ? 16.4 : 14.4)
    }
}

private struct NoopA4Chip: View {
    let text: String
    let color: Color
    let background: Color

    var body: some View {
        Text(text)
            .font(NoopHTMLFont.sans(11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(background.opacity(0.13), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct NoopA4Axis: View {
    let labels: [String]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                Text(label)
                if index < labels.count - 1 { Spacer() }
            }
        }
        .font(NoopHTMLFont.sans(10.5))
        .foregroundStyle(NoopHTMLColor.faint)
    }
}

private struct NoopA4CapacityChart: View {
    let values: [Double]

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, let minimum = values.min(), let maximum = values.max() else { return }
            let low = minimum - 0.6
            let high = maximum + 0.6
            let span = max(0.001, high - low)
            let scale = min(size.width / 300, size.height / 118)
            let ox = (size.width - 300 * scale) / 2
            let oy = (size.height - 118 * scale) / 2
            let points = values.enumerated().map { index, value in
                CGPoint(
                    x: ox + CGFloat(index) / CGFloat(values.count - 1) * 300 * scale,
                    y: oy + (110 - CGFloat((value - low) / span) * 100) * scale
                )
            }
            var area = Path()
            area.move(to: CGPoint(x: ox, y: oy + 112 * scale))
            for point in points { area.addLine(to: point) }
            area.addLine(to: CGPoint(x: ox + 300 * scale, y: oy + 112 * scale))
            area.closeSubpath()
            context.fill(area, with: .color(NoopA4.green.opacity(0.11)))

            var line = Path()
            line.move(to: points[0])
            for point in points.dropFirst() { line.addLine(to: point) }
            context.stroke(line, with: .color(NoopA4.green), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            if let last = points.last {
                context.fill(Path(ellipseIn: CGRect(x: last.x - 4, y: last.y - 4, width: 8, height: 8)), with: .color(NoopA4.green))
            }
        }
    }
}

private struct NoopA4SleepChart: View {
    let values: [Double]
    let need: Double

    var body: some View {
        Canvas { context, size in
            guard values.count > 1, let minimum = values.min(), let maximum = values.max() else { return }
            let low = minimum - 0.35
            let high = maximum + 0.35
            let span = max(0.001, high - low)
            let scale = min(size.width / 300, size.height / 112)
            let ox = (size.width - 300 * scale) / 2
            let oy = (size.height - 112 * scale) / 2
            func y(_ value: Double) -> CGFloat {
                oy + (104 - CGFloat((value - low) / span) * 94) * scale
            }

            var needPath = Path()
            needPath.move(to: CGPoint(x: ox, y: y(need)))
            needPath.addLine(to: CGPoint(x: ox + 300 * scale, y: y(need)))
            context.stroke(needPath, with: .color(NoopHTMLColor.ink.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

            let points = values.enumerated().map { index, value in
                CGPoint(x: ox + CGFloat(index) / CGFloat(values.count - 1) * 300 * scale, y: y(value))
            }
            var line = Path()
            line.move(to: points[0])
            for point in points.dropFirst() { line.addLine(to: point) }
            context.stroke(line, with: .color(NoopA4.lavender), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct NoopA4LineBoxModifier: ViewModifier {
    let fontSize: CGFloat
    let ratio: CGFloat

    func body(content: Content) -> some View {
        // Instrument Sans' bundled face has a 1.22 em native line box. CSS supplies
        // explicit leading around that box, including half-leading above and below.
        let native = fontSize * 1.22
        let target = fontSize * ratio
        let leading = max(0, target - native)
        content
            .lineSpacing(leading)
            .padding(.vertical, leading / 2)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private extension View {
    func noopA4LineBox(fontSize: CGFloat, ratio: CGFloat) -> some View {
        modifier(NoopA4LineBoxModifier(fontSize: fontSize, ratio: ratio))
    }
}
