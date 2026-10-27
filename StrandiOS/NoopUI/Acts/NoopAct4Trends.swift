import Foundation
import StrandDesign
import StrandAnalytics
import SwiftUI

// MARK: - Act 4 · The bigger picture

struct NoopAct4Screens: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject private var ageTone = NoopAgeTone.shared
    /// The production shell's measured weekly lines. Nil only in the seeded Debug shell.
    let trends: NoopTrendsRecord
    var battery: Int? = nil
    /// Production body age for the hero door (same engine as `ages`).
    let ages: NoopAgesRecord
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

@MainActor
private enum NoopA4 {
    /// The page accent, which follows `NoopAgeTone`: green under the calendar age, amber over it.
    static var green: Color { NoopAgeTone.shared.accent }
    static var greenLight: Color { NoopAgeTone.shared.accentLight }
    /// Green that means "better" whatever the page tone, for up/down chips and verdicts.
    static let good = Color(hex: 0x2ECC80)
    static let goodLight = Color(hex: 0x8FEFC0)
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

/// Trends' catalog for the new-look choice; the screen itself is private to this file.
enum NoopTrendsCatalog {
    static var sections: [NoopPageSection] { NoopTrendsScreen.trendsSections }
}

private struct NoopTrendsScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @ObservedObject private var ageTone = NoopAgeTone.shared
    @EnvironmentObject private var repo: Repository
    @StateObject private var labBook = NoopLabBook()
    @State private var showingRecordingHistory = false
    @StateObject private var trendsLayout = NoopPageLayout(page: "trends", catalog: NoopTrendsScreen.trendsSections)
    @State private var trendsEditing = NoopPageEditing()
    @Binding var window: NoopTrendWindow
    let live: NoopTrendsRecord
    var battery: Int? = nil
    let ages: NoopAgesRecord

    /// Your ages, open as a sheet over Trends, with its own navigation for its inner pages.
    @State private var agesNavigation: NoopNavigation?

    private func openAges() {
        NoopHaptics.play(.tick)
        let nav = NoopNavigation()
        nav.reset(to: .ages)
        agesNavigation = nav
    }

    var body: some View {
        NoopScreen(topInset: 58) {
            VStack(alignment: .leading, spacing: 0) {
                NoopA4Header(title: "Trends", eyebrow: window.span) { EmptyView() }

                // Bloodwork waits until there is a lab result to show (26 Oct 2026); adding one stays
                // on You and in Goals.
                NoopEditableSections(layout: trendsLayout, editing: $trendsEditing, spacing: 0,
                                     isEmpty: { $0 == "bloodwork" && labBook.markers.isEmpty }) { id in
                    trendsSection(id)
                }
            }
        }
        .noopEditBar($trendsEditing, layout: trendsLayout) { navigation.push(.settingsScores) }
        .sheet(isPresented: Binding(get: { agesNavigation != nil }, set: { if !$0 { agesNavigation = nil } })) {
            if let agesNavigation {
                NoopAgesSheet(navigation: agesNavigation, measured: ages) { self.agesNavigation = nil }
                    .noopSheet()
            }
        }
        .task(id: repo.deviceId) {
            await labBook.load(store: await repo.storeHandle(), deviceId: repo.deviceId)
        }
    }

    /// Trends' sections in their default order; each carries the space above it, so the page reads
    /// as it did before it was editable.
    static let trendsSections: [NoopPageSection] = [
        NoopPageSection(id: "hero", title: "Body age", detail: "The orb, your body age and pace of aging"),
        NoopPageSection(id: "hero-rings", title: "Body age · Tree rings", detail: "One ring per year, amber past your real age", onByDefault: false),
        NoopPageSection(id: "hero-field", title: "Body age · Field", detail: "A breathing field in the orb's colours", onByDefault: false),
        NoopPageSection(id: "markers", title: "Markers", detail: "The measures you pinned"),
        NoopPageSection(id: "markers-tiles", title: "Markers · Tiles", detail: "Your pinned measures as a grid of tiles", onByDefault: false),
        NoopPageSection(id: "changes", title: "What changed", detail: "The window's verdict, six weeks to a year"),
        NoopPageSection(id: "bloodwork", title: "Bloodwork", detail: "Your lab results"),
        NoopPageSection(id: "explore", title: "Explore", detail: "Compare signals and relationships"),
        NoopPageSection(id: "summaries", title: "Your summaries", detail: "Weekly digest and the trends report"),
        NoopPageSection(id: "history", title: "Recording history", detail: "Which days the strap recorded", onByDefault: false)
    ]

    @ViewBuilder
    private func trendsSection(_ id: String) -> some View {
        switch id {
        case "hero", "hero-rings", "hero-field":
            NoopTrendsHero(
                style: id == "hero-rings" ? 1 : id == "hero-field" ? 2 : 0,
                bodyAge: ages.bodyAge,
                chronoAge: ages.chronoAge ?? 0,
                pace: ages.pace,
                paceWeeks: ages.paceWeeks ?? 0,
                waitingReason: ages.buildReason ?? "Checking recorded signals"
            ) { openAges() }
        case "markers":
            NoopTrendsMarkersSection(navigation: navigation)
                .padding(.top, 32)
        case "markers-tiles":
            NoopTrendsMarkersSection(navigation: navigation, tiles: true)
                .padding(.top, 32)
        case "changes":
            VStack(alignment: .leading, spacing: 0) {
                windowControl
                if live.readFailed {
                    Text("Some history could not be refreshed. Available readings are shown; try refreshing again.")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopA4.warm)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)
                }
                verdictCard.padding(.top, 14)
            }
            .padding(.top, 24)
        case "bloodwork":
            VStack(alignment: .leading, spacing: 9) {
                sectionLabel("Bloodwork", color: NoopHTMLColor.warm)
                bloodworkCard
            }
            .padding(.top, 9)
        case "explore":
            VStack(alignment: .leading, spacing: 9) {
                sectionLabel("Explore")
                NoopHTMLCard(radius: 22, padding: 0) {
                    VStack(spacing: 0) {
                        trendLink(NoopRoute.instrumentCompare.screenTitle, detail: "two patterns, their timing and paired days", symbol: "chart", route: .instrumentCompare)
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        trendLink(NoopRoute.instrumentEffects.screenTitle, detail: "associations in your own recorded history", symbol: "ask", route: .instrumentEffects)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }
            .padding(.top, 9)
        case "summaries":
            VStack(alignment: .leading, spacing: 9) {
                sectionLabel("Your summaries")
                NoopHTMLCard(radius: 22, padding: 0) {
                    VStack(spacing: 0) {
                        trendLink("Weekly digest", detail: "this week against last, in your own numbers", symbol: "digest", route: .digest)
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        trendLink("Trends report", detail: "a longer read across a window, exportable as a PDF", symbol: "report", route: .report)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }
            .padding(.top, 9)
        case "history":
            DisclosureGroup(isExpanded: $showingRecordingHistory) {
                NoopAttendanceCard(live: live.attendance).padding(.top, 10)
            } label: {
                Text("Recording history").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                    .frame(minHeight: 44)
            }
            .tint(NoopA4.greenLight)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
            .padding(.top, 9)
        default:
            EmptyView()
        }
    }

    private func sectionLabel(_ title: String, color: Color = NoopHTMLColor.muted) -> some View {
        NoopSectionLabel(title, color: color)
            .padding(.horizontal, 2)
            .padding(.top, 12)
            .padding(.bottom, 3)
            .accessibilityAddTraits(.isHeader)
    }

    /// "Is it working?" for the chosen window. Live text comes from TrendVerdict: each signal's
    /// first half of the window against its second, called only when it clears its own noise.
    private var verdictCard: some View {
        let kicker = window == .sixWeeks ? "Six weeks in" : window == .sixMonths ? "Six months in" : "Twelve months in"
        let (headline, body, tone) = liveVerdict
        let tint = tone == 0 ? NoopA4.lavender : tone == 1 ? NoopA4.green : NoopA4.warm

        return VStack(alignment: .leading, spacing: 9) {
            Text(kicker.uppercased())
                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(tone == 0 ? Color(hex: 0xC9D0EE) : tint)
            Text(headline)
                .font(NoopHTMLFont.outfit(NoopType.title1, weight: .light))
                .tracking(-1.024)
                .foregroundStyle(NoopHTMLColor.ink)
                .frame(minHeight: 34.56, alignment: .top)
            Text(body)
                .font(NoopHTMLFont.sans(NoopType.footnote))
                .foregroundStyle(Color(hex: 0xB4C9BE))
                .noopA4LineBox(fontSize: 13.5, ratio: 1.6)
            Text("Each signal's first half of the window against its second. A change is called only when it clears that signal's own week-to-week swing.")
                .font(NoopHTMLFont.sans(NoopType.eyebrow))
                .foregroundStyle(NoopHTMLColor.faint)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        
        }
        // A short sentence left the card hugging its text, narrower than the cards under it.
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 17)
        .background {
            NoopCSSLinearGradient(colors: [tint.opacity(tone == 0 ? 0.14 : 0.16), tint.opacity(0.03)])
                .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(tint.opacity(0.3), lineWidth: 0.5))
    }

    private var liveVerdict: (String, String, Int) {
        let n = window.count
        let signals = [
            TrendVerdict.Signal(key: "rhr", weekly: Array(live.restingPulse.suffix(n)), higherIsBetter: false, minimumChange: 1),
            TrendVerdict.Signal(key: "hrv", weekly: Array(live.variability.suffix(n)), higherIsBetter: true, minimumChange: 2),
            TrendVerdict.Signal(key: "sleep", weekly: Array(live.sleep.suffix(n)), higherIsBetter: true, minimumChange: 0.15),
            TrendVerdict.Signal(key: "cap", weekly: Array(live.capacity.suffix(n)), higherIsBetter: true, minimumChange: 0.5),
        ]
        let result = TrendVerdict.evaluate(signals, windowWeeks: n)
        let names = ["rhr": "resting pulse", "hrv": "variability", "sleep": "sleep", "cap": "capacity"]
        func phrase(_ r: TrendVerdict.Reading) -> String {
            let d = r.change ?? 0, up = d > 0, a = abs(d)
            switch r.key {
            case "rhr": return "resting pulse \(up ? "up" : "down") \(Int(a.rounded())) \(Int(a.rounded()) == 1 ? "beat" : "beats")"
            case "hrv": return "variability \(up ? "up" : "down") \(Int(a.rounded())) milliseconds"
            case "sleep": return "sleep \(up ? "up" : "down") \(Int((a * 60).rounded())) minutes a night"
            default: return "capacity \(up ? "up" : "down") \(a.formatted(.number.precision(.fractionLength(1)))) points"
            }
        }
        func list(_ items: [String]) -> String {
            items.count <= 1 ? items.joined() : items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
        func sentence(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }
        let moved = result.readings.filter { $0.call == .improved || $0.call == .worse }.map(phrase)
        let steady = result.readings.filter { $0.call == .steady }.compactMap { names[$0.key] }
        let unknown = result.readings.filter { $0.call == .unknown }.compactMap { names[$0.key] }
        var parts: [String] = []
        if !moved.isEmpty { parts.append(sentence(moved.joined(separator: ", ")) + ".") }
        if !steady.isEmpty { parts.append(sentence(list(steady)) + " held steady.") }
        if !unknown.isEmpty, result.headline != .tooEarly {
            parts.append(sentence(list(unknown)) + (unknown.count == 1 ? " has" : " have") + " too few recorded weeks to call.")
        }
        switch result.headline {
        case .tooEarly:
            return ("Too early to say.", n < TrendVerdict.minWindowWeeks
                ? "Six weeks can't separate a real change from an ordinary swing, and capacity barely moves in that time. Switch to six months for a verdict."
                : "This window doesn't have enough recorded weeks in both halves to compare them yet.", 0)
        case .working: return ("Yes, it's working.", parts.joined(separator: " "), 1)
        case .slowly: return ("Yes — slowly.", parts.joined(separator: " "), 1)
        case .steady: return ("Holding steady.", parts.joined(separator: " "), 0)
        case .mixed: return ("Some yes, some no.", parts.joined(separator: " "), 2)
        case .slipping: return ("Slipping a little.", parts.joined(separator: " "), 2)
        }
    }

    private var bloodworkSummary: String {
        guard labBook.hasLoaded else { return "Opening your recorded results…" }
        guard !labBook.unavailable else { return "Results could not be refreshed. Open the Lab Book to check." }
        guard labBook.recordedCount > 0 else { return "No results recorded yet. Add a report or enter results by hand." }
        return "\(labBook.recordedCount) markers recorded" + (labBook.latestDateLabel.map { " · \($0)" } ?? "")
    }

    private var bloodworkCard: some View {
        Button { navigation.push(.labs) } label: {
            NoopHTMLCard(radius: 22, padding: 16) {
                HStack(alignment: .top, spacing: 13) {
                    NoopCanonicalGlyph(name: .drop, size: 20, color: NoopHTMLColor.warm)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Biomarkers").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                        Text(bloodworkSummary).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                        Text("Lab results keep their own dates, independent of the chart period.")
                            .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    NoopA4CSSChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    private var windowControl: some View {
        HStack(spacing: 4) {
            ForEach(NoopTrendWindow.allCases, id: \.rawValue) { item in
                Button { withAnimation(.easeOut(duration: 0.18)) { window = item } } label: {
                    Text(item.rawValue)
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: item == window ? .semibold : .regular))
                        .foregroundStyle(item == window ? Color(hex: 0x9FE2FB) : NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .background(item == window ? NoopA4.green.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(item == window ? NoopA4.green.opacity(0.4) : .clear, lineWidth: 0.5))
                }
                .buttonStyle(NoopPlainHitStyle())
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
    }

    private var trendRows: [NoopTrendSignal] {
        liveRows(live)
    }

    // MARK: Measured rows

    /// Production rows describe only the weekly values actually present in the selected window.
    /// Missing weeks are not counted, and no cause, duration of a plateau, or clinical significance
    /// is inferred from the first and last recorded values.
    private func liveRows(_ live: NoopTrendsRecord) -> [NoopTrendSignal] {
        let n = window.count
        func row(_ key: String, _ name: String, _ series: [Double?], unit: String, digits: Int) -> NoopTrendSignal {
            let chart = DatedChartSeries(dates: Array(live.weekStarts.suffix(n)), values: Array(series.suffix(n)))
            let shown = chart.values
            let current = shown.last
            let value = current.map { $0.formatted(.number.precision(.fractionLength(digits))) } ?? "\u{2014}"
            guard let first = shown.first, let last = current, shown.count >= 2 else {
                let read = shown.isEmpty ? "No recorded weeks in this window." : "One recorded week in this window."
                return NoopTrendSignal(key: key, name: name, value: value, unit: unit, delta: "", read: read, chart: chart,
                                       color: Color(hex: 0x7F8A85), flat: true, improved: false)
            }
            let scale = pow(10.0, Double(digits))
            let displayedChange = (last * scale).rounded() / scale - (first * scale).rounded() / scale
            let amount = abs(displayedChange).formatted(.number.precision(.fractionLength(digits))) + " " + unit
            let firstText = first.formatted(.number.precision(.fractionLength(digits)))
            let lastText = last.formatted(.number.precision(.fractionLength(digits)))
            let read = "Recorded weekly average: \(firstText) to \(lastText) \(unit) across \(shown.count) weeks with data."
            return NoopTrendSignal(
                key: key, name: name, value: value, unit: unit,
                delta: displayedChange == 0 ? "unchanged" : (displayedChange > 0 ? "+" : "\u{2212}") + amount,
                read: read, chart: chart,
                color: Color(hex: 0x7F8A85),
                flat: true, improved: false)
        }
        return [
            row("rhr", "Resting pulse", live.restingPulse, unit: "bpm", digits: 0),
            row("hrv", "Variability", live.variability, unit: "ms", digits: 0),
            row("sleep", "Sleep", live.sleep, unit: "h", digits: 1),
            row("cap", "Capacity", live.capacity, unit: "ml/kg/min", digits: 1)
        ]
    }

    private func trendLink(_ title: String, detail: String?, symbol: String, route: NoopRoute) -> some View {
        let tint = symbol == "biomarkers" ? NoopHTMLColor.warm : symbol == "ask" ? NoopA4.lavender : NoopA4.green
        return Button { navigation.push(route) } label: {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: glyph(for: symbol), size: 20, color: tint)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                    if let detail {
                        Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
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
        case "digest": .file
        case "report": .chart
        case "biomarkers": .drop
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
            // The name first, in the same weight and size as Today's title; the window under it.
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NoopHTMLFont.outfit(NoopType.title3, weight: .medium))
                    .tracking(-0.4)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(eyebrow)
                    .font(NoopHTMLFont.sans(NoopType.footnote))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
            Spacer(minLength: 0)
            trailing
        }
        .frame(minHeight: 46.95, alignment: .top)
        .padding(.bottom, 4)
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
        NoopAnimatedTimeline(minimumInterval: 1.0 / 30.0, paused: reduceMotion || calibrating) { timeline in
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
                        .frame(minHeight: 68)
                        .shadow(color: .black.opacity(0.6), radius: 13, y: 2)
                    Text("BODY AGE")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                        .tracking(2.1)
                        .foregroundStyle(Color(hex: 0x93A0A6))
                        .padding(.top, 7)
                    Text(calibrating ? waitingReason : auraDelta)
                        .font(NoopHTMLFont.sans(NoopType.footnote))
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

private struct NoopTrendSignal: Identifiable {
    var id: String { key }
    let key: String
    let name: String
    let value: String
    let unit: String
    let delta: String
    let read: String
    let chart: DatedChartSeries
    let color: Color
    let flat: Bool
    let improved: Bool
}

private struct NoopAttendanceCard: View {
    /// The last 84 days (0 nothing · 1 slept, worn · 2 moved as well). Nil draws the prototype grid.
    var live: [Int]? = nil

    private var recordedDays: Int { live?.filter { $0 > 0 }.count ?? 79 }

    var body: some View {
        NoopHTMLCard(radius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    NoopSectionLabel("Recorded days")
                    Spacer()
                    Text("12 weeks \u{00B7} \(recordedDays) of 84 days")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow))
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
                    key("Sleep recorded", color: NoopA4.green.opacity(0.28))
                    key("Activity recorded", color: NoopA4.green)
                    key("No record", color: Color.white.opacity(0.06))
                }
                Text("A fixed twelve-week view of the available record. Gaps mean no data was recorded.")
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .noopA4LineBox(fontSize: 11.5, ratio: 1.55)
            }
        }
    }

    private func key(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 9, height: 9)
            Text(title).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x7F8A85))
        }
    }
}

private struct NoopCapacityScreen: View {
    @ObservedObject var navigation: NoopNavigation
    let window: NoopTrendWindow
    let live: NoopTrendsRecord

    private var chart: DatedChartSeries {
        return DatedChartSeries(dates: Array(live.weekStarts.suffix(window.count)),
                                values: Array(live.capacity.suffix(window.count)))
    }
    private var values: [Double] { chart.values }

    /// The comparison starts at the first recorded week, not an earlier empty window slot.
    private var inFrom: String {
        guard let first = chart.points.first?.date else { return "in this window" }
        let date = DateFormatter()
        date.setLocalizedDateFormatFromTemplate("d MMM y")
        return "on \(date.string(from: first))"
    }

    /// The HTML's read up to its first full stop; the age clause needs the unresolved age engine.
    private var read: String? {
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
                    Text("Capacity").font(NoopHTMLFont.outfit(NoopType.title2)).tracking(-0.6)
                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(values.last.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? ("\u{2014}"))
                            .font(NoopHTMLFont.outfit200(54)).tracking(-2.43)
                            .frame(minHeight: 54)
                        Text("ml/kg/min, estimated").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                    }
                    if let read {
                    Text(read)
                        .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
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
                            color: change >= 0 ? NoopA4.goodLight : Color(hex: 0xF3C888),
                            background: change >= 0 ? NoopA4.good : NoopA4.warm
                        )
                        }
                    }
                    NoopA4CapacityChart(chart: chart)
                        .frame(height: 118)
                    NoopA4Axis(labels: window.axis(weekStarts: live.weekStarts))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 13)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                }
                .padding(.top, 8)
            }
        }
    }

}

private struct NoopRhythmScreen: View {
    @ObservedObject var navigation: NoopNavigation
    let window: NoopTrendWindow
    let live: NoopTrendsRecord
    @AppStorage("noop.schedule.kind") private var scheduleKind = "mostly-nights"

    private var sleepChart: DatedChartSeries {
        return DatedChartSeries(dates: Array(live.weekStarts.suffix(window.count)),
                                values: Array(live.sleep.suffix(window.count)))
    }
    private var sleep: [Double] { sleepChart.values }
    /// Weekly drift; a week with no night stays an empty slot on the bars.
    private var driftSlots: [Double?] {
        return Array(live.drift.suffix(window.count))
    }
    private var drift: [Double] { driftSlots.compactMap { $0 } }
    /// The demo's 7h 12m, or the app's sleep planning target for a real record.
    private var needHours: Double { live.needMin / 60 }
    private var needText: String { NoopRestRecord.duration(live.needMin) }
    private var axisLabels: [String] { window.axis(weekStarts: live.weekStarts) }
    private var isNightWorker: Bool { NoopScheduleInference.isNightWorker(kind: scheduleKind) }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopA4BackHeader(label: navigation.previousScreenTitle ?? "Trends", action: navigation.back)
                VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Rhythm").font(NoopHTMLFont.outfit(NoopType.title2)).tracking(-0.6)
                    Text(sleep.isEmpty ? "" : "Average of the recorded weekly sleep durations: \(formattedSleep). The dashed line below is the app's sleep planning target, not a measured personal requirement.")
                        .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        .noopA4LineBox(fontSize: 13.5, ratio: 1.6)
                }

                VStack(alignment: .leading, spacing: 11) {
                    HStack {
                        NoopSectionLabel((isNightWorker ? "Main sleep against target" : "Sleep against target"))
                        Spacer()
                        Text("\("target") \(needText)")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                    }
                    NoopA4SleepChart(chart: sleepChart, need: needHours)
                        .frame(height: 112)
                    axis
                    Text("Dashes mark the app's sleep planning target.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                        .noopA4LineBox(fontSize: 11.5, ratio: 1.55)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 13)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel(isNightWorker ? "How far your anchor drifted" : "How far sleep onset drifted")
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
                        Text("Each bar is that week's average distance between sleep onset and the usual onset in this record.")
                            .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                            .noopA4LineBox(fontSize: 11.5, ratio: 1.55)
                    }
                }

                NoopHTMLCard(radius: 22, padding: 0) {
                    VStack(spacing: 0) {
                        rhythmRow("Nights at or above target",
                                  detail: "in this window", value: nightsOverNeed.map { "\($0)%" } ?? "\u{2014}")
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        rhythmRow("\(isNightWorker ? "Anchor" : "Sleep onset") drift, \("latest recorded week")", detail: "weekly average", value: drift.last.map { "\(Int($0.rounded())) min" } ?? "\u{2014}")
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        rhythmRow("\(isNightWorker ? "Anchor" : "Sleep onset") drift, \("first recorded week")", detail: "same window", value: drift.first.map { "\(Int($0.rounded())) min" } ?? "\u{2014}", warm: true)
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        rhythmRow("Longest steady stretch", detail: "under 30 minutes of drift", value: longestStretch)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }

                Text("These readings describe sleep timing and duration; they do not establish what caused changes in other readings.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
                    .noopA4LineBox(fontSize: 11.5, ratio: 1.6).padding(.horizontal, 2)
                }
                .padding(.top, 8)
            }
        }
    }

    private var axis: some View {
        HStack { ForEach(Array(axisLabels.enumerated()), id: \.offset) { i, label in Text(label); if i < axisLabels.count - 1 { Spacer() } } }
            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
    }

    /// Consecutive weeks under thirty minutes of drift; the example's "11 weeks" in the demo.
    private var longestStretch: String {
        guard driftSlots.contains(where: { $0 != nil }) else { return "\u{2014}" }
        var best = 0, run = 0
        for slot in driftSlots {
            if let v = slot, v < 30 { run += 1; best = max(best, run) } else { run = 0 }
        }
        return best == 1 ? "1 week" : "\(best) weeks"
    }

    private var formattedSleep: String {
        let hours = sleep.reduce(0, +) / Double(max(1, sleep.count))
        let minutes = Int((hours * 60).rounded())
        return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }

    private var nightsOverNeed: Int? {
        let from = live.weekStarts.suffix(window.count).first ?? .distantPast
        let nights = live.nights.filter { $0.day >= from }
        guard !nights.isEmpty else { return nil }
        return Int((Double(nights.filter { $0.minutes >= live.needMin }.count) / Double(nights.count) * 100).rounded())
    }

    private func rhythmRow(_ title: String, detail: String, value: String, warm: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(NoopType.footnote))
                Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
            }
            Spacer()
            Text(value)
                .font(NoopHTMLFont.outfit(NoopType.title3))
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
                    Text("The year so far").font(NoopHTMLFont.outfit(NoopType.title2)).tracking(-0.6)
                    Text("Eight months in four chapters, written the way you would tell it to someone — not as a chart you have to interpret.")
                        .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        .noopA4LineBox(fontSize: 13.5, ratio: 1.6)
                }

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(chapters.enumerated()), id: \.offset) { _, chapter in
                        VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(chapter.0.uppercased()).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.3).foregroundStyle(chapter.4)
                                    Spacer()
                                    Text(chapter.1).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                                }
                                Text(chapter.2).font(NoopHTMLFont.outfit(NoopType.title3)).tracking(-0.38)
                                    .frame(minHeight: 22.8, alignment: .top)
                                Text(chapter.3).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
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
                                        Text(item.0).font(NoopHTMLFont.sans(NoopType.footnote))
                                        Text(item.1).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                                    }
                                    Spacer()
                                    Text(item.2).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    NoopSectionLabel("Svea", color: Color(hex: 0xC9D0EE))
                    Text("Nothing here happened because of a hard week. It happened because you went to bed at roughly the same hour for four months and walked most days. The interesting part is that your body is now good enough at recovering that it can take the harder sessions you have been avoiding.")
                        .font(NoopHTMLFont.sans(NoopType.subhead)).foregroundStyle(Color(hex: 0xDCE3E0))
                        .noopA4LineBox(fontSize: 14, ratio: 1.68)
                }
                .padding(16)
                .background(NoopA4.lavender.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopA4.lavender.opacity(0.2), lineWidth: 0.5))

                Text("No year-in-review confetti, no personal bests you did not try for. A chapter only appears once there is enough of it to be true.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint)
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
            NoopBackButton(action: action)
            NoopBackTitle(label)
            Spacer(minLength: 0)
        }
        .frame(minHeight: NoopCloseButton.side)
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
            .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
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
        .font(NoopHTMLFont.sans(NoopType.eyebrow))
        .foregroundStyle(NoopHTMLColor.faint)
    }
}

private struct NoopA4CapacityChart: View {
    let chart: DatedChartSeries
    var body: some View { chartBody.noopChartZoom() }

    @ViewBuilder private var chartBody: some View {
        NoopHistoryPlot(presentation: .init(series: chart, showVariability: false), tint: NoopA4.greenLight,
                        valueLabel: { $0.formatted(.number.precision(.fractionLength(1))) })
    }
}

private struct NoopA4SleepChart: View {
    let chart: DatedChartSeries
    let need: Double
    var body: some View { chartBody.noopChartZoom() }

    @ViewBuilder private var chartBody: some View {
        NoopHistoryPlot(presentation: .init(series: chart, showVariability: false, references: [need]), tint: NoopA4.lavender,
                        referenceValue: need, valueLabel: { $0.formatted(.number.precision(.fractionLength(1))) })
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
