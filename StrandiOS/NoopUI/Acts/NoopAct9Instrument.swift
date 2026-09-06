#if os(iOS)
import SwiftUI

// MARK: - Act 9 · The instrument

/// The Instrument is entered from Trends; it deliberately does not add a sixth tab. The fixture
/// below is the prototype's deterministic 258-night record and is visible only through the
/// Debug-only `--demo-seed` shell. Release data is supplied by the verified app shell instead.
struct NoopAct9Screens: View {
    @ObservedObject var navigation: NoopNavigation
    @SceneStorage("noop.act9.range") private var rangeRaw = NoopInstrumentRange.ninety.rawValue
    @SceneStorage("noop.act9.filter") private var filterRaw = NoopInstrumentGroupFilter.all.rawValue

    private var range: Binding<NoopInstrumentRange> {
        Binding(
            get: { NoopInstrumentRange(rawValue: rangeRaw) ?? .ninety },
            set: { rangeRaw = $0.rawValue }
        )
    }

    var body: some View {
        switch navigation.route {
        case .instrumentIndex:
            NoopInstrumentIndexScreen(
                navigation: navigation,
                range: range,
                filterRaw: $filterRaw
            )
        case .instrumentMetric:
            NoopInstrumentPendingScreen(
                navigation: navigation,
                backLabel: "Every signal",
                title: NoopInstrumentDemoData.shared.signal(key: navigation.instrumentMetricKey)?.name ?? "Variability"
            )
        case .instrumentCompare:
            NoopInstrumentPendingScreen(navigation: navigation, backLabel: "Every signal", title: "Two at once")
        case .instrumentEffects:
            NoopInstrumentPendingScreen(navigation: navigation, backLabel: "Every signal", title: "What moves you")
        default:
            NoopInstrumentIndexScreen(
                navigation: navigation,
                range: range,
                filterRaw: $filterRaw
            )
        }
    }
}

private struct NoopInstrumentIndexScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @Binding var range: NoopInstrumentRange
    @Binding var filterRaw: String

    private let data = NoopInstrumentDemoData.shared

    private var filter: NoopInstrumentGroupFilter {
        NoopInstrumentGroupFilter(rawValue: filterRaw) ?? .all
    }

    private var visibleGroups: [NoopInstrumentGroup] {
        NoopInstrumentGroup.allCases.filter { filter == .all || filter.group == $0 }
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                instrumentBackHeader

                VStack(alignment: .leading, spacing: 7) {
                    Text("Ask it something")
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("Every signal Noop keeps, with the one number that says whether it has moved. Open any of them to see what it moves with.")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4.2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NoopInstrumentRangeControl(range: $range, worn: data.wornCount(for: range))
                    // Swift's multiline text block resolves seven points shorter than the
                    // browser's explicit 13.5/21.6 line box. Keep the next authored edge at
                    // the HTML's y=222 instead of letting every row drift upward.
                    .padding(.top, 18)

                NoopFlowLayout(spacing: 6) {
                    ForEach(NoopInstrumentGroupFilter.allCases) { item in
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) { filterRaw = item.rawValue }
                        } label: {
                            Text(item.rawValue)
                                .font(NoopHTMLFont.sans(11.5, weight: .medium))
                                .foregroundStyle(item == filter ? Color(hex: 0xC6CEE8) : NoopHTMLColor.copy)
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(
                                    item == filter ? NoopHTMLColor.night.opacity(0.20) : Color.white.opacity(0.05),
                                    in: RoundedRectangle(cornerRadius: 11)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11)
                                        .stroke(item == filter ? NoopHTMLColor.night.opacity(0.42) : Color.white.opacity(0.07), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .accessibilityAddTraits(item == filter ? .isSelected : [])
                    }
                }
                .padding(.top, 12)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(visibleGroups) { group in
                        NoopInstrumentGroupCard(
                            group: group,
                            rows: data.snapshots(group: group, range: range),
                            open: open
                        )
                    }
                }
                .padding(.top, 13)

                VStack(alignment: .leading, spacing: 9) {
                    VStack(spacing: 0) {
                        NoopInstrumentDoor(
                            title: "Two at once",
                            detail: "put any two on the same axis",
                            glyph: .overlay,
                            action: { navigation.push(.instrumentCompare) }
                        )
                        Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
                        NoopInstrumentDoor(
                            title: "What actually moves you",
                            detail: "the ranking, the lag, and what one more costs",
                            glyph: .bolt,
                            action: { navigation.push(.instrumentEffects) }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    Text("Everything here is an association in your own data. Noop will not tell you one thing caused another, and it will not draw a line it cannot defend at the length you asked for.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 16)
            }
        }
    }

    private var instrumentBackHeader: some View {
        HStack(spacing: 12) {
            Button { navigation.back(or: .trends) } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
                    NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft)
                        .offset(x: -1)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            Text("Trends")
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
            Spacer()
        }
        .padding(.horizontal, -2)
        .padding(.bottom, 16)
    }

    private func open(_ row: NoopInstrumentSnapshot) {
        navigation.instrumentMetricKey = row.signal.key
        navigation.push(.instrumentMetric)
    }
}

private struct NoopInstrumentRangeControl: View {
    @Binding var range: NoopInstrumentRange
    let worn: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                ForEach(NoopInstrumentRange.allCases) { item in
                    Button {
                        guard item.isAvailable else { return }
                        withAnimation(.easeInOut(duration: 0.22)) { range = item }
                    } label: {
                        Text(item.rawValue)
                            .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                            .foregroundStyle(item == range ? Color(hex: 0xC6CEE8) : item.isAvailable ? NoopHTMLColor.copy : NoopHTMLColor.ink.opacity(0.38))
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(item == range ? NoopHTMLColor.night.opacity(0.20) : .clear, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .disabled(!item.isAvailable)
                    .accessibilityAddTraits(item == range ? .isSelected : [])
                }
            }
            .padding(3)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.07), lineWidth: 0.5))

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("\(worn)")
                    .font(NoopHTMLFont.outfit(17, weight: .light))
                    .monospacedDigit()
                    .foregroundStyle(NoopHTMLColor.ink)
                Text(note)
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 3)
        }
    }

    private var note: String {
        switch range {
        case .all:
            "nights actually behind this answer, of 258 on record"
        case .year:
            "nights on record — there is no more history than this"
        case .thirty, .ninety:
            "nights actually behind this answer. You asked for \(range.dayCount)."
        }
    }
}

private struct NoopInstrumentGroupCard: View {
    let group: NoopInstrumentGroup
    let rows: [NoopInstrumentSnapshot]
    let open: (NoopInstrumentSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.heading.uppercased())
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.3)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text("\(rows.count) signals")
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }
            .padding(.horizontal, 3)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Divider().overlay(Color.white.opacity(0.055)).frame(height: 0.5)
                    }
                    Button { open(row) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.signal.name)
                                    .font(NoopHTMLFont.sans(13.5))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                    .lineLimit(1)
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text(row.value)
                                        .font(NoopHTMLFont.outfit(19, weight: .light))
                                        .tracking(-0.38)
                                        .monospacedDigit()
                                        .foregroundStyle(NoopHTMLColor.ink)
                                    Text(row.unit)
                                        .font(NoopHTMLFont.sans(11))
                                        .foregroundStyle(NoopHTMLColor.muted)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(alignment: .trailing, spacing: 6) {
                                Text(row.delta)
                                    .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                                    .foregroundStyle(row.style.chipInk)
                                    .padding(.horizontal, 8)
                                    .frame(height: 23)
                                    .background(row.style.chipFill, in: RoundedRectangle(cornerRadius: 7))
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                NoopInstrumentSparkline(points: row.points, color: row.style.stroke)
                            }
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 86, alignment: .trailing)

                            NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
                                .frame(width: 7)
                        }
                        .frame(minHeight: 68)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 2)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
        }
    }
}

private struct NoopInstrumentSparkline: View {
    let points: [CGPoint]
    let color: Color

    var body: some View {
        Canvas { context, _ in
            guard let first = points.first else { return }
            var path = Path()
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            if let last = points.last {
                context.fill(Path(ellipseIn: CGRect(x: last.x - 2.4, y: last.y - 2.4, width: 4.8, height: 4.8)), with: .color(color))
            }
        }
        .frame(width: 86, height: 26)
        .accessibilityHidden(true)
    }
}

private struct NoopInstrumentDoor: View {
    let title: String
    let detail: String
    let glyph: NoopCanonicalGlyphName
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: glyph, size: 20, color: NoopHTMLColor.night)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                }
                Spacer(minLength: 8)
                NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
            }
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

/// Kept only while each of the remaining three screens is completed and pixel-checked in order.
/// It is unreachable in Release because the prototype shell itself is Debug-only.
private struct NoopInstrumentPendingScreen: View {
    @ObservedObject var navigation: NoopNavigation
    let backLabel: String
    let title: String

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 6) {
                NoopBackHeader(label: backLabel) { navigation.back(or: .instrumentIndex) }
                    .padding(.horizontal, -2)
                Text(title)
                    .font(NoopHTMLFont.outfit(25))
                    .tracking(-0.625)
                Text("This Instrument screen is the next parity unit.")
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
        }
    }
}

private enum NoopInstrumentRange: String, CaseIterable, Identifiable {
    case thirty = "30"
    case ninety = "90"
    case year = "365"
    case all = "All"

    var id: String { rawValue }
    var dayCount: Int {
        switch self {
        case .thirty: 30
        case .ninety: 90
        case .year: 365
        case .all: 258
        }
    }
    var isAvailable: Bool { dayCount <= 258 }
}

private enum NoopInstrumentGroup: String, CaseIterable, Identifiable {
    case night = "Night"
    case day = "Day"
    case effort = "Effort"
    case body = "Body"
    case logged = "Logged"

    var id: String { rawValue }
    var heading: String { self == .logged ? "What you log" : rawValue }
}

private enum NoopInstrumentGroupFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case night = "Night"
    case day = "Day"
    case effort = "Effort"
    case body = "Body"
    case logged = "Logged"

    var id: String { rawValue }
    var group: NoopInstrumentGroup? { NoopInstrumentGroup(rawValue: rawValue) }
}

private struct NoopInstrumentSignal: Identifiable {
    let key: String
    let name: String
    let group: NoopInstrumentGroup
    let unit: String
    let decimals: Int
    let better: Int
    let threshold: Double
    var hours = false
    var big = false
    var behavior = false

    var id: String { key }
}

private enum NoopInstrumentChangeStyle {
    case thin, flat, neutral, good, bad

    var stroke: Color {
        switch self {
        case .thin: Color(hex: 0x4A5450)
        case .flat: Color(hex: 0x7F8A85)
        case .neutral: NoopHTMLColor.night
        case .good: NoopHTMLColor.green
        case .bad: NoopHTMLColor.warm
        }
    }

    var chipInk: Color {
        switch self {
        case .thin: Color(hex: 0x7F8A85)
        case .flat: NoopHTMLColor.inkSoft
        case .neutral: Color(hex: 0xC6CEE8)
        case .good: Color(hex: 0x8FEFC0)
        case .bad: Color(hex: 0xF3C888)
        }
    }

    var chipFill: Color {
        switch self {
        case .thin: Color.white.opacity(0.05)
        case .flat: Color.white.opacity(0.06)
        case .neutral: NoopHTMLColor.night.opacity(0.16)
        case .good: NoopHTMLColor.green.opacity(0.13)
        case .bad: NoopHTMLColor.warm.opacity(0.13)
        }
    }
}

private struct NoopInstrumentSnapshot: Identifiable {
    let signal: NoopInstrumentSignal
    let value: String
    let unit: String
    let delta: String
    let style: NoopInstrumentChangeStyle
    let points: [CGPoint]

    var id: String { signal.key }
}

private struct NoopInstrumentDemoData {
    static let shared = NoopInstrumentDemoData()
    private static let count = 258

    let signals: [NoopInstrumentSignal]
    private let values: [String: [Double?]]

    init() {
        let gaps = Set([3, 17, 34, 52, 61, 79, 96, 112, 130, 151, 177, 203].map { Self.count - 1 - $0 })
        var regularity: [Double] = []
        var drink: [Double] = []
        var drinks: [Double] = []
        var caffeine: [Double] = []
        var late: [Double] = []
        var screen: [Double] = []
        var walk: [Double] = []
        var hard: [Double] = []
        var load: [Double] = []

        for index in 0..<Self.count {
            let progress = Double(index) / Double(Self.count - 1)
            let reg = max(0.05, min(1, 0.33 + 0.53 * max(0, (progress - 0.22) / 0.78) + (Self.hash(index) - 0.5) * 0.16))
            regularity.append(reg)
            let hadDrink = Self.hash(index + 11) > 0.74 ? 1.0 : 0.0
            drink.append(hadDrink)
            let drinksHash = Self.hash(index + 12)
            drinks.append(hadDrink > 0 ? (drinksHash > 0.72 ? 3 : drinksHash > 0.42 ? 2 : 1) : 0)
            caffeine.append(Self.hash(index + 21) > 0.6 ? 1 : 0)
            late.append(Self.hash(index + 31) > 0.78 ? 1 : 0)
            screen.append(Self.hash(index + 41) > 0.72 - 0.24 * reg ? 1 : 0)
            walk.append(Self.hash(index + 51) > 0.44 ? 1 : 0)
            hard.append(Self.hash(index + 61) > 0.85 ? 1 : 0)
            load.append(hard[index] > 0 ? 68 + Self.hash(index + 62) * 42 : (Self.hash(index + 63) > 0.44 ? 16 + Self.hash(index + 64) * 32 : 0))
        }

        func previous(_ array: [Double], _ index: Int) -> Double { array[max(0, index - 1)] }
        func make(first: Int = 0, _ value: (Int) -> Double) -> [Double?] {
            (0..<Self.count).map { index in
                gaps.contains(index) || index < first ? nil : value(index)
            }
        }

        var generated: [String: [Double?]] = [:]
        generated["sleep"] = make { 6.34 + 1.18 * regularity[$0] - 0.44 * previous(drink, $0) - 0.24 * previous(late, $0) - 0.3 * previous(screen, $0) + (Self.hash($0 + 70) - 0.5) * 0.52 }
        generated["reg"] = make { 64 - 46 * regularity[$0] + (Self.hash($0 + 80) - 0.5) * 15 }
        generated["deep"] = make { 19.4 + 6.3 * regularity[$0] - 2.9 * previous(drinks, $0) - 0.9 * previous(late, $0) + (Self.hash($0 + 90) - 0.5) * 3.3 }
        generated["rem"] = make { 20.2 + 3.5 * regularity[$0] - 1.9 * previous(drink, $0) + (Self.hash($0 + 100) - 0.5) * 3.7 }
        generated["hrv"] = make { 33 + 17.2 * regularity[$0] - 7.2 * previous(drink, $0) - 0.034 * previous(load, $0) + (Self.hash($0 + 110) - 0.5) * 6.6 }
        generated["rhr"] = make { 62.4 - 5.2 * regularity[$0] + 2.4 * previous(drink, $0) + 0.014 * previous(load, $0) + (Self.hash($0 + 120) - 0.5) * 2.1 }
        generated["breath"] = make { 14.6 - 0.56 * regularity[$0] + 0.42 * previous(drink, $0) + (Self.hash($0 + 130) - 0.5) * 0.48 }
        generated["temp"] = make { -0.02 + 0.16 * previous(drink, $0) + (Self.hash($0 + 140) - 0.5) * 0.2 }
        generated["spo2"] = make(first: Self.count - 19) { 96.4 + 0.6 * regularity[$0] - 0.3 * previous(drink, $0) + (Self.hash($0 + 150) - 0.5) * 0.66 }
        generated["recovery"] = make { max(6, min(99, 54 + 31 * regularity[$0] - 15 * previous(drink, $0) - 0.12 * previous(load, $0) + (Self.hash($0 + 160) - 0.5) * 12)) }
        generated["stress"] = make { max(0, 74 - 34 * regularity[$0] + 17 * late[$0] + 0.055 * load[$0] + (Self.hash($0 + 170) - 0.5) * 28) }
        generated["steps"] = make { 4100 + 5600 * walk[$0] + 1800 * regularity[$0] + (Self.hash($0 + 180) - 0.5) * 2300 }
        generated["load"] = make { load[$0] }
        generated["cap"] = make { 40.3 + 3.9 * max(0, (Double($0) / Double(Self.count - 1) - 0.3) / 0.7) + (Self.hash($0 + 190) - 0.5) * 0.5 }
        generated["age"] = make { 38.6 - 4.4 * max(0, (Double($0) / Double(Self.count - 1) - 0.25) / 0.75) + (Self.hash($0 + 200) - 0.5) * 0.4 }
        generated["weight"] = make { 78.4 - 1.8 * max(0, (Double($0) / Double(Self.count - 1) - 0.2) / 0.8) + (Self.hash($0 + 210) - 0.5) * 0.66 }
        generated["b_drink"] = make { drink[$0] }
        generated["b_caff"] = make { caffeine[$0] }
        generated["b_late"] = make { late[$0] }
        generated["b_screen"] = make { screen[$0] }
        generated["b_walk"] = make { walk[$0] }
        generated["b_hard"] = make { hard[$0] }
        values = generated

        signals = [
            .init(key: "rhr", name: "Resting pulse", group: .night, unit: "bpm", decimals: 0, better: -1, threshold: 1.2),
            .init(key: "hrv", name: "Variability", group: .night, unit: "ms", decimals: 0, better: 1, threshold: 3.2),
            .init(key: "sleep", name: "Time asleep", group: .night, unit: "hours", decimals: 1, better: 1, threshold: 0.32, hours: true),
            .init(key: "reg", name: "Bedtime drift", group: .night, unit: "minutes", decimals: 0, better: -1, threshold: 7),
            .init(key: "deep", name: "Deep sleep", group: .night, unit: "% of the night", decimals: 1, better: 1, threshold: 1.4),
            .init(key: "rem", name: "REM", group: .night, unit: "% of the night", decimals: 1, better: 1, threshold: 1.6),
            .init(key: "breath", name: "Breathing rate", group: .night, unit: "breaths a minute", decimals: 1, better: -1, threshold: 0.32),
            .init(key: "temp", name: "Skin temperature", group: .night, unit: "°C from your own", decimals: 2, better: 0, threshold: 0.09),
            .init(key: "spo2", name: "Blood oxygen", group: .night, unit: "%", decimals: 1, better: 1, threshold: 0.4),
            .init(key: "recovery", name: "Readiness", group: .day, unit: "out of 100", decimals: 0, better: 1, threshold: 4),
            .init(key: "stress", name: "Stress minutes", group: .day, unit: "minutes", decimals: 0, better: -1, threshold: 9),
            .init(key: "steps", name: "Steps", group: .day, unit: "a day", decimals: 0, better: 1, threshold: 700, big: true),
            .init(key: "load", name: "Training load", group: .effort, unit: "a day", decimals: 0, better: 0, threshold: 8),
            .init(key: "cap", name: "Capacity", group: .body, unit: "ml/kg/min", decimals: 1, better: 1, threshold: 0.5),
            .init(key: "age", name: "Body age", group: .body, unit: "years", decimals: 1, better: -1, threshold: 0.4),
            .init(key: "weight", name: "Weight", group: .body, unit: "kg", decimals: 1, better: 0, threshold: 0.5),
            .init(key: "b_drink", name: "A drink after 20:00", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.4, behavior: true),
            .init(key: "b_caff", name: "Caffeine after 14:00", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.4, behavior: true),
            .init(key: "b_late", name: "A late meal", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.4, behavior: true),
            .init(key: "b_screen", name: "Screen past midnight", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.4, behavior: true),
            .init(key: "b_walk", name: "A walk over 8k steps", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.4, behavior: true),
            .init(key: "b_hard", name: "A hard session", group: .logged, unit: "days a week", decimals: 1, better: 0, threshold: 0.3, behavior: true)
        ]
    }

    func signal(key: String) -> NoopInstrumentSignal? { signals.first { $0.key == key } }

    func wornCount(for range: NoopInstrumentRange) -> Int {
        tail(values["hrv"] ?? [], count: range.dayCount).compactMap { $0 }.count
    }

    func snapshots(group: NoopInstrumentGroup, range: NoopInstrumentRange) -> [NoopInstrumentSnapshot] {
        signals.filter { $0.group == group }.map { snapshot($0, range: range) }
    }

    private func snapshot(_ signal: NoopInstrumentSignal, range: NoopInstrumentRange) -> NoopInstrumentSnapshot {
        let shown = tail(values[signal.key] ?? [], count: range.dayCount)
        let clean = shown.compactMap { $0 }
        let first = shown.compactMap { $0 }.first
        let last = shown.compactMap { $0 }.last
        let thin = clean.count < 21
        let value: String
        let delta: String
        let style: NoopInstrumentChangeStyle

        if signal.behavior {
            let rate = clean.reduce(0, +) / Double(max(1, clean.count)) * 7
            value = String(format: "%.1f", rate)
            let half = shown.count / 2
            let early = shown.prefix(half).compactMap { $0 }
            let late = shown.suffix(from: half).compactMap { $0 }
            let earlyRate = early.reduce(0, +) / Double(max(1, early.count))
            let lateRate = late.reduce(0, +) / Double(max(1, late.count))
            let movement = (lateRate - earlyRate) * 7
            let flat = abs(movement) < signal.threshold
            delta = flat ? "about the same" : (movement > 0 ? "+" : "−") + String(format: "%.1f a week", abs(movement))
            style = flat ? .flat : .neutral
        } else {
            value = Self.format(last, signal: signal)
            let movement = (last ?? 0) - (first ?? last ?? 0)
            let flat = thin || abs(movement) < signal.threshold
            let good = signal.better != 0 && (signal.better < 0 ? movement < 0 : movement > 0)
            if thin {
                delta = "\(clean.count) nights so far"
                style = .thin
            } else if flat {
                delta = "no real change"
                style = .flat
            } else {
                let amount: String
                if signal.hours {
                    amount = "\(Int((abs(movement) * 60).rounded())) min"
                } else if signal.big {
                    amount = Self.integerFormatter.string(from: NSNumber(value: Int(abs(movement).rounded()))) ?? "\(Int(abs(movement).rounded()))"
                } else {
                    amount = String(format: "%.*f", signal.decimals, abs(movement))
                }
                delta = (movement > 0 ? "+" : "−") + amount
                style = signal.better == 0 ? .neutral : good ? .good : .bad
            }
        }

        return NoopInstrumentSnapshot(
            signal: signal,
            value: value,
            unit: signal.behavior ? "days a week" : signal.unit,
            delta: delta,
            style: style,
            points: Self.sparkPoints(shown)
        )
    }

    private func tail(_ values: [Double?], count: Int) -> [Double?] {
        Array(values.suffix(min(count, values.count)))
    }

    private static func hash(_ value: Int) -> Double {
        let raw = sin(Double(value) * 127.1 + 311.7) * 43_758.5453
        return raw - floor(raw)
    }

    private static func format(_ value: Double?, signal: NoopInstrumentSignal) -> String {
        guard let value else { return "—" }
        if signal.big {
            return integerFormatter.string(from: NSNumber(value: Int(value.rounded()))) ?? "\(Int(value.rounded()))"
        }
        if signal.hours {
            let minutes = Int((value * 60).rounded())
            return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
        }
        return signal.decimals == 0 ? "\(Int(value.rounded()))" : String(format: "%.*f", signal.decimals, value)
    }

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static func sparkPoints(_ values: [Double?]) -> [CGPoint] {
        let step = values.count > 46 ? Int(ceil(Double(values.count) / 46.0)) : 1
        let sampled: [Double?] = values.enumerated()
            .filter { $0.offset.isMultiple(of: step) }
            .map(\.element)
        var interpolated = sampled
        var previous: Double?
        for index in interpolated.indices {
            if let value = interpolated[index] {
                previous = value
            } else {
                var nextIndex = index
                while nextIndex < interpolated.count, interpolated[nextIndex] == nil { nextIndex += 1 }
                let next = nextIndex < interpolated.count ? interpolated[nextIndex] : previous
                interpolated[index] = previous == nil ? next : next == nil ? previous : ((previous ?? 0) + (next ?? 0)) / 2
            }
        }
        let clean = interpolated.compactMap { $0 }
        guard !clean.isEmpty else { return [] }
        let low = clean.min() ?? 0
        let high = clean.max() ?? low + 1
        let span = high - low == 0 ? 1 : high - low
        return clean.enumerated().map { index, value in
            let x = CGFloat(index) / CGFloat(max(1, clean.count - 1)) * 86
            let y = 26 - CGFloat((value - low) / span) * 20 - 3
            return CGPoint(x: x, y: y)
        }
    }
}
#endif
