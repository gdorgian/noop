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
            NoopInstrumentMetricScreen(
                navigation: navigation,
                range: range
            )
        case .instrumentCompare:
            NoopInstrumentCompareScreen(navigation: navigation, range: range)
        case .instrumentEffects:
            NoopInstrumentEffectsScreen(navigation: navigation, range: range)
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
                NoopInstrumentBackHeader(label: "Trends") {
                    navigation.back(or: .trends)
                }

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
            NoopInstrumentRangeTabs(range: $range)

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

private struct NoopInstrumentRangeTabs: View {
    @Binding var range: NoopInstrumentRange

    var body: some View {
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

private struct NoopInstrumentBackHeader: View {
    let label: String
    let action: () -> Void

    init(label: String, action: @escaping () -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
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
            Text(label)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
            Spacer()
        }
        .padding(.horizontal, -2)
        .padding(.bottom, 16)
    }
}

private struct NoopInstrumentMetricScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @Binding var range: NoopInstrumentRange

    private let data = NoopInstrumentDemoData.shared
    private var model: NoopInstrumentMetricModel {
        data.metric(key: navigation.instrumentMetricKey, range: range)
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopInstrumentBackHeader(label: "Every signal") {
                    navigation.back(or: .instrumentIndex)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(model.signal.name)
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .foregroundStyle(NoopHTMLColor.ink)

                    HStack(alignment: .firstTextBaseline, spacing: 9) {
                        Text(model.value)
                            .font(NoopHTMLFont.outfit(52, weight: .thin))
                            .tracking(-2.34)
                            .monospacedDigit()
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text(model.unit)
                            .font(NoopHTMLFont.sans(13))
                            .foregroundStyle(NoopHTMLColor.copy)
                    }

                    Text(model.read)
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4.2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NoopInstrumentRangeControl(range: $range, worn: model.worn)
                    .padding(.top, 14)

                VStack(alignment: .leading, spacing: 11) {
                    metricChartCard

                    if model.thin {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("Not enough of it yet")
                                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text(model.thinNote)
                                .font(NoopHTMLFont.sans(12.5))
                                .foregroundStyle(Color(hex: 0xC9D0EE))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(16)
                        .background(NoopHTMLColor.night.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.night.opacity(0.22), lineWidth: 0.5))
                    }

                    if !model.moves.isEmpty {
                        metricMovesCard
                    }

                    metricLinksCard

                    Text("Correlations are computed over the nights where both signals exist, at the best of three lags, and shown only above twenty-one nights and 0.22. Association, not cause.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 14)
            }
        }
    }

    private var metricChartCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(model.span.uppercased())
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                NoopInstrumentDeltaChip(text: model.delta, style: model.style, fontSize: 11, radius: 8, horizontalPadding: 9)
            }

            NoopInstrumentMetricChart(chart: model.chart)

            HStack {
                ForEach(Array(model.chart.axis.enumerated()), id: \.offset) { index, label in
                    Text(label)
                    if index < model.chart.axis.count - 1 { Spacer() }
                }
            }
            .font(NoopHTMLFont.sans(10.5))
            .foregroundStyle(NoopHTMLColor.faint)

            Text(model.chartNote)
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(Color(hex: 0x7F8A85))
                .lineSpacing(3.3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var metricMovesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("WHAT IT MOVES WITH")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text("strongest first")
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(model.moves) { move in
                    Button {
                        navigation.instrumentCompareAKey = model.signal.key
                        navigation.instrumentCompareBKey = move.signal.key
                        navigation.instrumentCompareShift = move.lag
                        navigation.push(.instrumentCompare)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(move.signal.name)
                                    .font(NoopHTMLFont.sans(13))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                Text(move.lagLabel.uppercased())
                                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                                    .tracking(0.4)
                                    .foregroundStyle(move.lag == 0 ? NoopHTMLColor.copy : Color(hex: 0xB7C0E8))
                                    .padding(.horizontal, 7)
                                    .frame(height: 20)
                                    .background(move.lag == 0 ? Color.white.opacity(0.05) : NoopHTMLColor.night.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                                    .fixedSize(horizontal: true, vertical: false)
                                Text(move.coefficient)
                                    .font(NoopHTMLFont.outfit(16))
                                    .monospacedDigit()
                                    .foregroundStyle(Color(hex: 0xB7C0E8))
                                    .fixedSize()
                            }

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.white.opacity(0.07))
                                    Capsule()
                                        .fill(NoopHTMLColor.night)
                                        .frame(width: proxy.size.width * move.barFraction)
                                }
                            }
                            .frame(height: 5)

                            Text(move.read)
                                .font(NoopHTMLFont.sans(11.5))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .lineSpacing(3.1)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var metricLinksCard: some View {
        VStack(spacing: 0) {
            NoopInstrumentDoor(title: "Put it against something", detail: "two on one axis, with the day-shift", glyph: .overlay) {
                navigation.instrumentCompareAKey = model.signal.key
                navigation.instrumentCompareBKey = model.signal.key == "hrv" ? "reg" : "hrv"
                navigation.instrumentCompareShift = 0
                navigation.push(.instrumentCompare)
            }
            Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
            NoopInstrumentDoor(title: "Ask Svea about this", detail: "she gets this dossier, not just the number", glyph: .chat) {
                navigation.reset(to: .coach)
            }
            Divider().overlay(NoopHTMLColor.border).frame(height: 0.5)
            NoopInstrumentDoor(title: "Where it comes from", detail: "the sensor, the window, and the gaps", glyph: .clock) {
                navigation.reset(to: .data)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

private struct NoopInstrumentDeltaChip: View {
    let text: String
    let style: NoopInstrumentChangeStyle
    var fontSize: CGFloat = 10.5
    var radius: CGFloat = 7
    var horizontalPadding: CGFloat = 8

    var body: some View {
        Text(text)
            .font(NoopHTMLFont.sans(fontSize, weight: .semibold))
            .foregroundStyle(style.chipInk)
            .padding(.horizontal, horizontalPadding)
            .frame(height: fontSize == 11 ? 24 : 23)
            .background(style.chipFill, in: RoundedRectangle(cornerRadius: radius))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}

private struct NoopInstrumentMetricChart: View {
    let chart: NoopInstrumentMetricChartModel

    var body: some View {
        Canvas { context, size in
            let xOffset = max(0, (size.width - 300) / 2)
            func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + xOffset, y: p.y) }

            if let first = chart.bandTop.first {
                var band = Path()
                band.move(to: point(first))
                for item in chart.bandTop.dropFirst() { band.addLine(to: point(item)) }
                for item in chart.bandBottom { band.addLine(to: point(item)) }
                band.closeSubpath()
                context.fill(band, with: .color(NoopHTMLColor.night.opacity(0.13)))
            }

            if let first = chart.line.first {
                var line = Path()
                line.move(to: point(first))
                for item in chart.line.dropFirst() { line.addLine(to: point(item)) }
                context.stroke(line, with: .color(NoopHTMLColor.night), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }

            if let fitStart = chart.fitStart, let fitEnd = chart.fitEnd {
                var fit = Path()
                fit.move(to: point(fitStart))
                fit.addLine(to: point(fitEnd))
                context.stroke(fit, with: .color(NoopHTMLColor.ink.opacity(0.42)), style: StrokeStyle(lineWidth: 1.2, dash: [4, 5]))
            }

            if let last = chart.line.last {
                let center = point(last)
                context.fill(Path(ellipseIn: CGRect(x: center.x - 3.6, y: center.y - 3.6, width: 7.2, height: 7.2)), with: .color(NoopHTMLColor.night))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 122)
        .accessibilityHidden(true)
    }
}

private struct NoopInstrumentCompareScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @Binding var range: NoopInstrumentRange

    private let data = NoopInstrumentDemoData.shared
    private var model: NoopInstrumentComparisonModel {
        data.comparison(
            firstKey: navigation.instrumentCompareAKey,
            secondKey: navigation.instrumentCompareBKey,
            shift: navigation.instrumentCompareShift,
            range: range
        )
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopInstrumentBackHeader(label: "Every signal") {
                    navigation.back(or: .instrumentIndex)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Two at once")
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text("Same axis, same window. The shift control asks whether one of them arrives a day late.")
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4.2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        NoopInstrumentCompareSlotButton(tag: "A", signal: model.first, color: NoopHTMLColor.night) {
                            navigation.show(.instrumentSignalPickerA)
                        }
                        NoopInstrumentCompareSlotButton(tag: "B", signal: model.second, color: NoopHTMLColor.green) {
                            navigation.show(.instrumentSignalPickerB)
                        }
                    }

                    NoopInstrumentRangeControl(range: $range, worn: model.worn)

                    comparisonChartCard
                    comparisonFitCard
                    comparisonShiftCard

                    Text("Two lines that move together is not one causing the other. The fit is only drawn when it clears the bar, and it is left off when it does not.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 14)
            }
        }
    }

    private var comparisonChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            NoopInstrumentComparisonChart(model: model)

            HStack {
                ForEach(Array(model.axis.enumerated()), id: \.offset) { index, label in
                    Text(label)
                    if index < model.axis.count - 1 { Spacer() }
                }
            }
            .font(NoopHTMLFont.sans(10.5))
            .foregroundStyle(NoopHTMLColor.faint)

            HStack(spacing: 14) {
                comparisonLegend(color: NoopHTMLColor.night, label: model.first.name)
                comparisonLegend(color: NoopHTMLColor.green, label: model.secondLegend)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 13)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func comparisonLegend(color: Color, label: String) -> some View {
        HStack(spacing: 7) {
            Capsule().fill(color).frame(width: 16, height: 3)
            Text(label)
                .font(NoopHTMLFont.sans(11))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineLimit(1)
        }
    }

    private var comparisonFitCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(model.clears ? "THE FIT" : "NO FIT DRAWN")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(model.clears ? Color(hex: 0xC9D0EE) : NoopHTMLColor.muted)
                Spacer()
                Text("\(model.fitCount) nights with both")
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .monospacedDigit()
            }
            Text(model.fitCoefficient)
                .font(NoopHTMLFont.outfit(26, weight: .light))
                .tracking(-0.78)
                .monospacedDigit()
                .foregroundStyle(NoopHTMLColor.ink)
            Text(model.fitRead)
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(Color(hex: 0xC9D0EE))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 17)
        .background {
            if model.clears {
                NoopCSSLinearGradient(colors: [NoopHTMLColor.night.opacity(0.16), NoopHTMLColor.night.opacity(0.03)], degrees: 158)
            } else {
                NoopHTMLColor.card
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(model.clears ? NoopHTMLColor.night.opacity(0.30) : Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var comparisonShiftCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("SHIFT BY A DAY")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text(model.bestLabel)
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }

            HStack(spacing: 5) {
                ForEach(model.shifts) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            navigation.instrumentCompareShift = option.lag
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(option.label)
                                .font(NoopHTMLFont.sans(10.5))
                                .foregroundStyle(option.selected ? Color(hex: 0xC6CEE8) : Color(hex: 0x7F8A85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Text(option.coefficient)
                                .font(NoopHTMLFont.outfit(16))
                                .monospacedDigit()
                                .foregroundStyle(option.selected ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(option.selected ? NoopHTMLColor.night.opacity(0.18) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(option.selected ? NoopHTMLColor.night.opacity(0.40) : Color.white.opacity(0.06), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
            }

            Text(model.shiftRead)
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(Color(hex: 0x7F8A85))
                .lineSpacing(3.3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

private struct NoopInstrumentCompareSlotButton: View {
    let tag: String
    let signal: NoopInstrumentSignal
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(tag)
                    .font(NoopHTMLFont.sans(11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x0B0E1A))
                    .frame(width: 22, height: 22)
                    .background(color, in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text(signal.name)
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .lineLimit(1)
                    Text(signal.behavior ? "days a week" : signal.unit)
                        .font(NoopHTMLFont.sans(10.5))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.07), lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopInstrumentComparisonChart: View {
    let model: NoopInstrumentComparisonModel

    var body: some View {
        Canvas { context, size in
            let xOffset = max(0, (size.width - 300) / 2)
            func point(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + xOffset, y: p.y) }
            func draw(_ points: [CGPoint], color: Color, dash: [CGFloat]) {
                guard let first = points.first else { return }
                var path = Path()
                path.move(to: point(first))
                for item in points.dropFirst() { path.addLine(to: point(item)) }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: dash))
                if let last = points.last {
                    let center = point(last)
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 3.4, y: center.y - 3.4, width: 6.8, height: 6.8)), with: .color(color))
                }
            }
            draw(model.firstLine, color: NoopHTMLColor.night, dash: [])
            draw(model.secondLine, color: NoopHTMLColor.green, dash: [5, 4])
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
        .accessibilityHidden(true)
    }
}

enum NoopInstrumentSignalSlot {
    case first
    case second
}

struct NoopInstrumentSignalPickerSheet: View {
    @ObservedObject var navigation: NoopNavigation
    let slot: NoopInstrumentSignalSlot

    private let data = NoopInstrumentDemoData.shared
    private var selectedKey: String {
        slot == .first ? navigation.instrumentCompareAKey : navigation.instrumentCompareBKey
    }

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            ZStack(alignment: .bottom) {
                NoopBackdropBlur(style: .regular, intensity: 0.18)
                Color(hex: 0x040605, alpha: 0.66)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: navigation.dismissOverlay)

                VStack(spacing: 0) {
                    VStack(spacing: 11) {
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .frame(width: 38, height: 4)

                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(slot == .first ? "First signal" : "Second signal")
                                    .font(NoopHTMLFont.outfit(21))
                                    .tracking(-0.525)
                                    .foregroundStyle(NoopHTMLColor.ink)
                                Text("Any signal Noop keeps, including the things you log")
                                    .font(NoopHTMLFont.sans(11.5))
                                    .foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            Spacer(minLength: 0)
                            Button(action: navigation.dismissOverlay) {
                                NoopCanonicalGlyph(name: .x, size: 14, color: NoopHTMLColor.inkSoft)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.07), in: Circle())
                            }
                            .buttonStyle(NoopHTMLPressStyle())
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(data.signals.enumerated()), id: \.element.id) { index, signal in
                                if index > 0 {
                                    Divider().overlay(Color.white.opacity(0.055)).frame(height: 0.5)
                                }
                                Button {
                                    if slot == .first {
                                        navigation.instrumentCompareAKey = signal.key
                                    } else {
                                        navigation.instrumentCompareBKey = signal.key
                                    }
                                    navigation.dismissOverlay()
                                } label: {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(signal.name)
                                                .font(NoopHTMLFont.sans(13.5, weight: signal.key == selectedKey ? .semibold : .regular))
                                                .foregroundStyle(signal.key == selectedKey ? Color(hex: 0xC6CEE8) : NoopHTMLColor.ink)
                                            Text(signal.group == .logged ? "what you log" : "\(signal.group.rawValue.lowercased()) · \(signal.unit)")
                                                .font(NoopHTMLFont.sans(10.5))
                                                .foregroundStyle(Color(hex: 0x7F8A85))
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                        if signal.key == selectedKey {
                                            Circle()
                                                .fill(NoopHTMLColor.night)
                                                .frame(width: 9, height: 9)
                                                .shadow(color: NoopHTMLColor.night.opacity(0.6), radius: 5)
                                        } else {
                                            Circle()
                                                .stroke(Color.white.opacity(0.16), lineWidth: 1.2)
                                                .frame(width: 9, height: 9)
                                        }
                                    }
                                    .frame(minHeight: 54)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(NoopHTMLPressStyle())
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 28)
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(width: viewportWidth)
                .frame(maxHeight: proxy.size.height * 0.76)
                .background(NoopHTMLColor.card, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.6), radius: 22, y: -14)
            }
            .frame(width: viewportWidth, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

private struct NoopInstrumentEffectsScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @Binding var range: NoopInstrumentRange

    @State private var selectedBehaviorKey: String?
    private let data = NoopInstrumentDemoData.shared

    init(navigation: NoopNavigation, range: Binding<NoopInstrumentRange>) {
        self.navigation = navigation
        self._range = range
        _selectedBehaviorKey = State(initialValue: nil)
    }

    private var model: NoopInstrumentEffectsModel {
        data.effects(
            range: range,
            selectedKey: selectedBehaviorKey,
            mode: NoopInstrumentEffectsMode.debugRequested,
            doseMode: NoopInstrumentDoseMode.debugRequested
        )
    }

    var body: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopInstrumentBackHeader(label: "Every signal") {
                    navigation.back(or: .instrumentIndex)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("What actually moves you")
                        .font(NoopHTMLFont.outfit(25))
                        .tracking(-0.625)
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(model.intro)
                        .font(NoopHTMLFont.sans(13.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(4.2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 11) {
                    // The final HTML intentionally omits the nights-count line on this route.
                    NoopInstrumentRangeTabs(range: $range)

                    switch model.state {
                    case .ranked:
                        rankedCard
                    case .learning:
                        learningCard
                    case .nothing:
                        nothingCard
                    }

                    withWithoutCard
                    doseCard

                    Text("Every line on this screen is an association in your own days, written by the engine that found it. None of them is a claim that one thing caused another.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(3.9)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 14)
            }
        }
    }

    private var rankedCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().overlay(Color.white.opacity(0.055)).frame(height: 0.5)
                }
                Button {
                    selectedBehaviorKey = row.key
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(row.name)
                                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Text(row.effect)
                                .font(NoopHTMLFont.outfit(19))
                                .monospacedDigit()
                                .foregroundStyle(row.positive ? Color(hex: 0x8FEFC0) : Color(hex: 0xB7C0E8))
                        }

                        HStack(spacing: 0) {
                            ForEach(NoopInstrumentLag.allCases) { lag in
                                NoopInstrumentLagMarker(lag: lag, selectedLag: row.lag)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        Text(row.read)
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .lineSpacing(3.1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 15)
                    .contentShape(Rectangle())
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var learningCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Still learning")
                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.ink)
            Text("A behaviour needs five days with it and five without before Noop will rank it. These are the ones that are short, and which side is short — because “log a few days without it” is something you can act on, and “not enough data” is not.")
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(Color(hex: 0xC9D0EE))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.learningLines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 9) {
                        Circle()
                            .fill(NoopHTMLColor.night)
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(line)
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(Color(hex: 0xC9D0EE))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(17)
        .background(NoopHTMLColor.night.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.night.opacity(0.22), lineWidth: 0.5))
    }

    private var nothingCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Nothing here clears the bar")
                .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                .foregroundStyle(NoopHTMLColor.ink)
            Text("Six behaviours, \(model.eligibleCount) of them with enough days on both sides, and not one of them moves your readiness by more than the day-to-day wobble. That is a real answer, and a slightly uncomfortable one: at this window, what you are doing is not what is deciding your mornings.")
                .font(NoopHTMLFont.sans(12.5))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            Text("Sleep regularity is doing the work instead. It is on Rhythm, and it is not a behaviour you log — it is one you keep.")
                .font(NoopHTMLFont.sans(12))
                .foregroundStyle(Color(hex: 0x7F8A85))
                .lineSpacing(3.6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(17)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    private var withWithoutCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("WITH AND WITHOUT")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text(model.pair.name)
                    .font(NoopHTMLFont.sans(10.5))
                    .foregroundStyle(NoopHTMLColor.faint)
            }

            if model.pair.ready {
                VStack(spacing: 13) {
                    NoopInstrumentMeanRow(label: "With it", value: model.pair.withValue, days: model.pair.withDays, spread: model.pair.withSpread, marker: model.pair.withMarker, color: NoopHTMLColor.warm)
                    NoopInstrumentMeanRow(label: "Without it", value: model.pair.withoutValue, days: model.pair.withoutDays, spread: model.pair.withoutSpread, marker: model.pair.withoutMarker, color: NoopHTMLColor.green)
                }

                Text(model.pair.read)
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                Text(model.pair.overlap)
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .lineSpacing(3.3)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(model.pair.thinRead)
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(Color(hex: 0xC9D0EE))
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private var doseCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("WHAT ONE MORE COSTS")
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(NoopHTMLColor.muted)
                Spacer()
                Text(model.dose.state.uppercased())
                    .font(NoopHTMLFont.sans(10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(model.dose.chipInk)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(model.dose.chipFill, in: RoundedRectangle(cornerRadius: 6))
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.dose.number)
                    .font(NoopHTMLFont.outfit(34, weight: .thin))
                    .tracking(-1.02)
                    .monospacedDigit()
                    .foregroundStyle(model.dose.hue)
                Text("% deep sleep, per drink")
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(Color(hex: 0x8B958F))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule().fill(NoopHTMLColor.night).frame(width: proxy.size.width * model.dose.ownership)
                }
            }
            .frame(height: 5)

            Text(model.dose.read)
                .font(NoopHTMLFont.sans(12))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(3.2)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 7) {
                ForEach(model.dose.steps) { step in
                    HStack(spacing: 10) {
                        Text(step.label)
                            .font(NoopHTMLFont.sans(11.5))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                            .frame(width: 52, alignment: .leading)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.06))
                                Capsule()
                                    .fill(model.dose.hue)
                                    .opacity(model.dose.ownership)
                                    .frame(width: proxy.size.width * step.fraction)
                            }
                        }
                        .frame(height: 6)
                        Text(step.value)
                            .font(NoopHTMLFont.sans(11.5))
                            .monospacedDigit()
                            .foregroundStyle(model.dose.hue)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
            .padding(.top, 2)

            Text("Colour is ownership: grey while the figure is borrowed from the literature, the screen’s hue once enough of your own nights sit behind it. It never shows a borrowed number as though it were measured.")
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(NoopHTMLColor.faint)
                .lineSpacing(3.3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

private struct NoopInstrumentLagMarker: View {
    let lag: NoopInstrumentLag
    let selectedLag: Int

    var body: some View {
        VStack(spacing: 5) {
            if lag.rawValue == selectedLag {
                Circle()
                    .fill(NoopHTMLColor.night)
                    .frame(width: 9, height: 9)
                    .shadow(color: NoopHTMLColor.night.opacity(0.6), radius: 5)
            } else {
                Circle()
                    .stroke(Color.white.opacity(lag.rawValue < selectedLag ? 0.22 : 0.13), lineWidth: 1.2)
                    .frame(width: 7, height: 7)
                    .frame(height: 9)
            }
            Text(lag.effectLabel.uppercased())
                .font(NoopHTMLFont.sans(9.5, weight: .semibold))
                .tracking(0.57)
                .foregroundStyle(lag.rawValue == selectedLag ? Color(hex: 0xB7C0E8) : NoopHTMLColor.faint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }
}

private struct NoopInstrumentMeanRow: View {
    let label: String
    let value: String
    let days: String
    let spread: ClosedRange<CGFloat>
    let marker: CGFloat
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(label)
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                Spacer()
                Text(value)
                    .font(NoopHTMLFont.outfit(20))
                    .monospacedDigit()
                    .foregroundStyle(NoopHTMLColor.ink)
                Text(days)
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(NoopHTMLColor.muted)
            }
            GeometryReader { proxy in
                let left = proxy.size.width * spread.lowerBound
                let width = proxy.size.width * max(0.02, spread.upperBound - spread.lowerBound)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(color.opacity(0.28))
                        .frame(width: width)
                        .offset(x: left)
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: 14)
                        .offset(x: proxy.size.width * marker - 1.25)
                }
            }
            .frame(height: 8)
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

private struct NoopInstrumentMetricChartModel {
    let line: [CGPoint]
    let bandTop: [CGPoint]
    let bandBottom: [CGPoint]
    let fitStart: CGPoint?
    let fitEnd: CGPoint?
    let axis: [String]
}

private struct NoopInstrumentMove: Identifiable {
    let signal: NoopInstrumentSignal
    let coefficient: String
    let lag: Int
    let lagLabel: String
    let barFraction: CGFloat
    let read: String

    var id: String { signal.key }
}

private struct NoopInstrumentMetricModel {
    let signal: NoopInstrumentSignal
    let value: String
    let unit: String
    let read: String
    let worn: Int
    let span: String
    let delta: String
    let style: NoopInstrumentChangeStyle
    let thin: Bool
    let thinNote: String
    let chartNote: String
    let chart: NoopInstrumentMetricChartModel
    let moves: [NoopInstrumentMove]
}

private struct NoopInstrumentShiftOption: Identifiable {
    let lag: Int
    let label: String
    let coefficient: String
    let selected: Bool
    var id: Int { lag }
}

private struct NoopInstrumentComparisonModel {
    let first: NoopInstrumentSignal
    let second: NoopInstrumentSignal
    let worn: Int
    let firstLine: [CGPoint]
    let secondLine: [CGPoint]
    let axis: [String]
    let secondLegend: String
    let fitCount: Int
    let fitCoefficient: String
    let clears: Bool
    let fitRead: String
    let shifts: [NoopInstrumentShiftOption]
    let bestLabel: String
    let shiftRead: String
}

private enum NoopInstrumentLag: Int, CaseIterable, Identifiable {
    case same = 0
    case next = 1
    case twoDays = 2

    var id: Int { rawValue }
    var effectLabel: String {
        switch self {
        case .same: "Same day"
        case .next: "Next morning"
        case .twoDays: "Two days"
        }
    }
}

private enum NoopInstrumentEffectsMode: String {
    case ranked, learning, nothing

    static var debugRequested: Self {
        #if DEBUG
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--noop-instrument-effects"),
           arguments.indices.contains(flag + 1),
           let value = Self(rawValue: arguments[flag + 1]) {
            return value
        }
        #endif
        return .ranked
    }
}

private enum NoopInstrumentDoseMode: String {
    case auto, borrowed, blending, yours, disagrees

    static var debugRequested: Self {
        #if DEBUG
        let arguments = CommandLine.arguments
        if let flag = arguments.firstIndex(of: "--noop-instrument-dose"),
           arguments.indices.contains(flag + 1),
           let value = Self(rawValue: arguments[flag + 1]) {
            return value
        }
        #endif
        return .auto
    }
}

private enum NoopInstrumentEffectsState {
    case ranked, learning, nothing
}

private struct NoopInstrumentEffectRow: Identifiable {
    let key: String
    let name: String
    let effect: String
    let positive: Bool
    let lag: Int
    let read: String
    var id: String { key }
}

private struct NoopInstrumentPairModel {
    let name: String
    let ready: Bool
    let withValue: String
    let withDays: String
    let withSpread: ClosedRange<CGFloat>
    let withMarker: CGFloat
    let withoutValue: String
    let withoutDays: String
    let withoutSpread: ClosedRange<CGFloat>
    let withoutMarker: CGFloat
    let read: String
    let overlap: String
    let thinRead: String
}

private struct NoopInstrumentDoseStep: Identifiable {
    let label: String
    let fraction: CGFloat
    let value: String
    var id: String { label }
}

private struct NoopInstrumentDoseModel {
    let state: String
    let number: String
    let ownership: CGFloat
    let hue: Color
    let chipInk: Color
    let chipFill: Color
    let read: String
    let steps: [NoopInstrumentDoseStep]
}

private struct NoopInstrumentEffectsModel {
    let state: NoopInstrumentEffectsState
    let intro: String
    let rows: [NoopInstrumentEffectRow]
    let learningLines: [String]
    let eligibleCount: Int
    let pair: NoopInstrumentPairModel
    let dose: NoopInstrumentDoseModel
}

private struct NoopInstrumentCorrelation {
    let coefficient: Double
    let count: Int
    let lag: Int
}

private struct NoopInstrumentGroupStats {
    let withMean: Double
    let withoutMean: Double
    let withCount: Int
    let withoutCount: Int
    let withDeviation: Double
    let withoutDeviation: Double
}

private struct NoopInstrumentBehavior {
    let key: String
    let name: String
    let onPhrase: String
}

private struct NoopInstrumentRankedBehavior {
    let behavior: NoopInstrumentBehavior
    let difference: Double
    let lag: Int
    let stats: NoopInstrumentGroupStats?
    let percent: Double
}

private struct NoopInstrumentDemoData {
    static let shared = NoopInstrumentDemoData()
    private static let count = 258

    let signals: [NoopInstrumentSignal]
    private let values: [String: [Double?]]
    private let drinkDoses: [Double]

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
        drinkDoses = drinks

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

private extension NoopInstrumentDemoData {
    static let axisLabels: [NoopInstrumentRange: [String]] = [
        .thirty: ["30d", "20d", "10d", "now"],
        .ninety: ["90d", "60d", "30d", "now"],
        .year: ["365d", "240d", "120d", "now"],
        .all: ["Dec", "Mar", "Jun", "now"]
    ]

    static let lagWords = ["same night", "next morning", "two days on"]

    static let behaviors: [NoopInstrumentBehavior] = [
        .init(key: "b_drink", name: "A drink after 20:00", onPhrase: "on the evenings you had one"),
        .init(key: "b_caff", name: "Caffeine after 14:00", onPhrase: "on the days you had some"),
        .init(key: "b_hard", name: "A hard session", onPhrase: "on the days you went hard"),
        .init(key: "b_late", name: "A late meal", onPhrase: "on the nights you ate late"),
        .init(key: "b_screen", name: "Screen past midnight", onPhrase: "on the nights you were up late on a screen"),
        .init(key: "b_walk", name: "A walk over 8k steps", onPhrase: "on the days you walked")
    ]

    func metric(key: String, range: NoopInstrumentRange) -> NoopInstrumentMetricModel {
        let metricSignal = signal(key: key) ?? signals.first(where: { $0.key == "hrv" })!
        let raw = tail(values[metricSignal.key] ?? [], count: range.dayCount)
        let series = metricSignal.behavior ? trailingWeeklyRate(raw) : raw
        let clean = series.compactMap { $0 }
        let ends = firstAndLast(series)
        let thin = clean.count < 21
        let change = (ends.last ?? 0) - (ends.first ?? ends.last ?? 0)
        let flat = thin || abs(change) < metricSignal.threshold
        let good = metricSignal.better != 0 && (metricSignal.better < 0 ? change < 0 : change > 0)
        let style: NoopInstrumentChangeStyle = thin
            ? .thin
            : flat
                ? .flat
                : metricSignal.better == 0
                    ? .neutral
                    : good ? .good : .bad

        let changeAmount: String = {
            if metricSignal.hours { return "\(Int((abs(change) * 60).rounded())) minutes" }
            return "\(Self.decimal(abs(change), places: metricSignal.decimals)) \(metricSignal.unit)"
        }()
        let read: String = {
            if thin {
                return "There are \(clean.count) nights of this. Noop will keep it on the list and say nothing else about it until there are twenty-one."
            }
            if flat {
                return "Flat across this window, inside the wobble your own days produce. Nothing to read into it."
            }
            let ending = metricSignal.better == 0
                ? "."
                : good ? ", in the direction you would want." : ", which is the direction you would not."
            return "\(change > 0 ? "Up" : "Down") \(changeAmount) over \(wornCount(for: range)) nights\(ending)"
        }()

        let deltaAmount = metricSignal.hours
            ? "\(Int((abs(change) * 60).rounded())) min"
            : Self.decimal(abs(change), places: metricSignal.decimals)
        let delta = thin ? "\(clean.count) nights" : flat ? "no real change" : Self.signed(change, amount: deltaAmount)

        let sampled = sampledInterpolated(series, maximum: 60)
        let scale = chartScale(values: sampled, width: 300, height: 122, padding: 8)
        let line = sampled.enumerated().map { scale.point(value: $0.element, index: $0.offset) }
        let rolling = rollingRange(sampled, radius: 3)
        let bandTop = rolling.enumerated().map { scale.point(value: $0.element.upperBound, index: $0.offset) }
        let bandBottom = rolling.enumerated().reversed().map { scale.point(value: $0.element.lowerBound, index: $0.offset) }
        let fit = (!thin && !flat) ? regression(values: sampled, scale: scale) : nil

        let moves = signals
            .filter { $0.key != metricSignal.key }
            .map { other -> (NoopInstrumentSignal, NoopInstrumentCorrelation) in
                let result = bestLag(first: tail(values[other.key] ?? [], count: range.dayCount), second: raw)
                return (other, result)
            }
            .filter { $0.1.count >= 21 && abs($0.1.coefficient) >= 0.22 }
            .sorted { abs($0.1.coefficient) > abs($1.1.coefficient) }
            .prefix(4)
            .map { other, result in
                let positive = result.coefficient > 0
                let lagDescription = Self.lagWords[result.lag]
                let relation: String
                if other.behavior {
                    let day = result.lag == 0 ? "same day" : result.lag == 1 ? "morning after" : "second day after"
                    relation = "On the \(day) \(other.name.lowercased()), your \(metricSignal.name.lowercased()) runs \(positive ? "higher" : "lower") than on days without it."
                } else {
                    relation = "A \(positive ? "higher" : "lower") \(other.name.lowercased()) comes with a \(positive ? "higher" : "lower") \(metricSignal.name.lowercased()), strongest \(lagDescription)."
                }
                return NoopInstrumentMove(
                    signal: other,
                    coefficient: Self.signed(result.coefficient, amount: Self.decimal(abs(result.coefficient), places: 2)),
                    lag: result.lag,
                    lagLabel: lagDescription,
                    barFraction: CGFloat(min(1, abs(result.coefficient) / 0.8)),
                    read: relation
                )
            }

        return NoopInstrumentMetricModel(
            signal: metricSignal,
            value: Self.format(ends.last, signal: metricSignal),
            unit: metricSignal.behavior ? "days a week" : metricSignal.unit,
            read: read,
            worn: wornCount(for: range),
            span: range == .all ? "All 258 nights" : "Last \(range.rawValue) days",
            delta: delta,
            style: style,
            thin: thin,
            thinNote: "Blood oxygen started recording nineteen nights ago and two of those were not worn. Noop needs twenty-one to say anything about direction, so it says this instead of drawing you an arrow.",
            chartNote: thin
                ? "The band is the day-to-day spread. With this few nights it is most of the picture, which is the honest reading."
                : "The band is the three-day spread around each point. The dashed line is the fit, and it is only drawn when the change clears the noise at this length.",
            chart: .init(
                line: line,
                bandTop: bandTop,
                bandBottom: bandBottom,
                fitStart: fit?.start,
                fitEnd: fit?.end,
                axis: Self.axisLabels[range] ?? []
            ),
            moves: Array(moves)
        )
    }

    func comparison(firstKey: String, secondKey: String, shift: Int, range: NoopInstrumentRange) -> NoopInstrumentComparisonModel {
        let first = signal(key: firstKey) ?? signals.first(where: { $0.key == "hrv" })!
        let second = signal(key: secondKey) ?? signals.first(where: { $0.key == "reg" })!
        let safeShift = min(2, max(0, shift))
        let firstRaw = tail(values[first.key] ?? [], count: range.dayCount)
        let secondRaw = tail(values[second.key] ?? [], count: range.dayCount)
        let firstSampled = sampledInterpolated(firstRaw, maximum: 60)
        let secondSampled = sampledInterpolated(secondRaw, maximum: 60)
        let firstScale = chartScale(values: firstSampled, width: 300, height: 130, padding: 10)
        let secondScale = chartScale(values: secondSampled, width: 300, height: 130, padding: 10)
        let firstLine = firstSampled.enumerated().map { firstScale.point(value: $0.element, index: $0.offset) }
        let secondLine = secondSampled.enumerated().map { secondScale.point(value: $0.element, index: $0.offset) }
        let fit = correlation(first: firstRaw, second: secondRaw, lag: safeShift)
        let clears = abs(fit.coefficient) >= 0.28 && fit.count >= 21
        let strength = abs(fit.coefficient) >= 0.6
            ? "They move together."
            : abs(fit.coefficient) >= 0.4
                ? "They move together, loosely."
                : abs(fit.coefficient) >= 0.28 ? "A weak relationship." : "No relationship worth drawing."
        let shiftPhrase = safeShift == 0 ? "" : ", with \(second.name.lowercased()) read \(safeShift) day\(safeShift > 1 ? "s" : "") later"
        let fitRead = clears
            ? "\(strength) \(first.name) and \(second.name.lowercased())\(shiftPhrase). That is a tendency across \(fit.count) nights, not a rule about any one of them."
            : "At this length and this shift the two do not track each other closely enough to draw a line through. Noop leaves it off rather than drawing something faint and letting you read meaning into it."

        let options = (0...2).map { lag -> NoopInstrumentShiftOption in
            let result = correlation(first: firstRaw, second: secondRaw, lag: lag)
            return .init(
                lag: lag,
                label: lag == 0 ? "same day" : lag == 1 ? "+1 day" : "+2 days",
                coefficient: Self.signed(result.coefficient, amount: Self.decimal(abs(result.coefficient), places: 2)),
                selected: lag == safeShift
            )
        }
        let best = (0...2)
            .map { correlation(first: firstRaw, second: secondRaw, lag: $0) }
            .max { abs($0.coefficient) < abs($1.coefficient) } ?? .init(coefficient: 0, count: 0, lag: 0)
        let bestName = best.lag == 0 ? "same day" : "+\(best.lag) day\(best.lag > 1 ? "s" : "")"
        let shiftRead = best.lag == 0
            ? "Shifting does not improve it: whatever these two share, they share it on the same day."
            : "Reading \(second.name.lowercased()) \(best.lag) day\(best.lag > 1 ? "s" : "") later fits better than reading them together — the effect arrives after the day it was caused on, which is exactly what the lag treatment on the effects screen is for."

        return NoopInstrumentComparisonModel(
            first: first,
            second: second,
            worn: wornCount(for: range),
            firstLine: firstLine,
            secondLine: secondLine,
            axis: Self.axisLabels[range] ?? [],
            secondLegend: second.name + (safeShift == 0 ? "" : " · shifted \(safeShift) day\(safeShift > 1 ? "s" : "")"),
            fitCount: fit.count,
            fitCoefficient: Self.signed(fit.coefficient, amount: Self.decimal(abs(fit.coefficient), places: 2)),
            clears: clears,
            fitRead: fitRead,
            shifts: options,
            bestLabel: "strongest at \(bestName)",
            shiftRead: shiftRead
        )
    }

    func effects(
        range: NoopInstrumentRange,
        selectedKey: String?,
        mode: NoopInstrumentEffectsMode,
        doseMode: NoopInstrumentDoseMode
    ) -> NoopInstrumentEffectsModel {
        let target = tail(values["recovery"] ?? [], count: range.dayCount)
        let targetValues = target.compactMap { $0 }
        let targetMean = targetValues.reduce(0, +) / Double(max(1, targetValues.count))
        let ranked = Self.behaviors.map { behavior -> NoopInstrumentRankedBehavior in
            let behaviorValues = tail(values[behavior.key] ?? [], count: range.dayCount)
            var bestDifference = 0.0
            var bestLag = 0
            var bestStats: NoopInstrumentGroupStats?
            for lag in 0...2 {
                let stats = groupStats(behavior: behaviorValues, target: target, lag: lag)
                guard stats.withCount >= 5, stats.withoutCount >= 5 else { continue }
                let difference = stats.withMean - stats.withoutMean
                if abs(difference) > abs(bestDifference) {
                    bestDifference = difference
                    bestLag = lag
                    bestStats = stats
                }
            }
            return .init(
                behavior: behavior,
                difference: bestDifference,
                lag: bestLag,
                stats: bestStats,
                percent: targetMean == 0 ? 0 : bestDifference / targetMean * 100
            )
        }
        let eligible = ranked.filter { $0.stats != nil }
        let cleared = eligible
            .filter { abs($0.percent) >= 3.5 }
            .sorted { abs($0.percent) > abs($1.percent) }
        let short = ranked.filter { $0.stats == nil }

        let state: NoopInstrumentEffectsState = {
            switch mode {
            case .learning: return .learning
            case .nothing: return .nothing
            case .ranked:
                if !cleared.isEmpty { return .ranked }
                return short.count > 2 ? .learning : .nothing
            }
        }()
        let intro: String = {
            switch state {
            case .nothing:
                return "Six behaviours against your readiness, at three lags each. This window has an answer you may not enjoy."
            case .learning:
                return "Six behaviours against your readiness. Two of them do not have enough days on both sides yet, and it says which side is short."
            case .ranked:
                return "Six behaviours against your readiness, at the lag where the effect actually lands — not the day you did the thing."
            }
        }()

        let rows = cleared.map { item in
            let stats = item.stats!
            let amount = Int(abs(item.percent).rounded())
            return NoopInstrumentEffectRow(
                key: item.behavior.key,
                name: item.behavior.name,
                effect: "\(item.percent > 0 ? "+" : "−")\(amount)%",
                positive: item.percent > 0,
                lag: item.lag,
                read: "Readiness runs \(amount)% \(item.percent > 0 ? "higher" : "lower") \(Self.lagWords[item.lag]), across \(stats.withCount) days with and \(stats.withoutCount) without."
            )
        }

        let learningSource: [(behavior: NoopInstrumentBehavior, stats: NoopInstrumentGroupStats)] = {
            if !short.isEmpty {
                var thinRows: [(behavior: NoopInstrumentBehavior, stats: NoopInstrumentGroupStats)] = []
                for item in short {
                    let behaviorValues = tail(values[item.behavior.key] ?? [], count: range.dayCount)
                    let stats = groupStats(behavior: behaviorValues, target: target, lag: 1)
                    thinRows.append((behavior: item.behavior, stats: stats))
                }
                return thinRows
            }

            var candidates: [(behavior: NoopInstrumentBehavior, stats: NoopInstrumentGroupStats)] = []
            for behavior in Self.behaviors {
                let behaviorValues = tail(values[behavior.key] ?? [], count: range.dayCount)
                let stats = groupStats(behavior: behaviorValues, target: target, lag: 1)
                candidates.append((behavior: behavior, stats: stats))
            }
            candidates.sort {
                let leftCount = min($0.stats.withCount, $0.stats.withoutCount)
                let rightCount = min($1.stats.withCount, $1.stats.withoutCount)
                return leftCount < rightCount
            }
            return Array(candidates.prefix(2))
        }()
        let learningLines = learningSource.map { item -> String in
            let stats = item.stats
            let thinWith = stats.withCount <= stats.withoutCount
            let missing = max(1, 5 - (thinWith ? stats.withCount : stats.withoutCount))
            let action = thinWith
                ? "Log \(missing) more day\(missing > 1 ? "s" : "") with it."
                : "Give it \(missing) more day\(missing > 1 ? "s" : "") off."
            return "\(item.behavior.name) — \(stats.withCount) days with it, \(stats.withoutCount) without. \(action)"
        }

        let selected = selectedKey.flatMap { key in ranked.first { $0.behavior.key == key } }
            ?? cleared.first
            ?? ranked.first { $0.behavior.key == "b_drink" }!
        let pairStats = selected.stats ?? groupStats(
            behavior: tail(values[selected.behavior.key] ?? [], count: range.dayCount),
            target: target,
            lag: 1
        )
        let pair = pairModel(behavior: selected.behavior, rank: selected, stats: pairStats)

        return NoopInstrumentEffectsModel(
            state: state,
            intro: intro,
            rows: rows,
            learningLines: learningLines,
            eligibleCount: eligible.count,
            pair: pair,
            dose: doseModel(range: range, forced: doseMode)
        )
    }

    func pairModel(
        behavior: NoopInstrumentBehavior,
        rank: NoopInstrumentRankedBehavior,
        stats: NoopInstrumentGroupStats
    ) -> NoopInstrumentPairModel {
        let low = min(stats.withMean - stats.withDeviation, stats.withoutMean - stats.withoutDeviation) - 3
        let high = max(stats.withMean + stats.withDeviation, stats.withoutMean + stats.withoutDeviation) + 3
        let span = high - low == 0 ? 1 : high - low
        func fraction(_ value: Double) -> CGFloat { CGFloat((value - low) / span) }
        let withSpread = fraction(stats.withMean - stats.withDeviation)...fraction(stats.withMean + stats.withDeviation)
        let withoutSpread = fraction(stats.withoutMean - stats.withoutDeviation)...fraction(stats.withoutMean + stats.withoutDeviation)
        let difference = stats.withMean - stats.withoutMean
        let lag = rank.stats == nil ? 1 : rank.lag
        let read = abs(difference) < 3
            ? "No real difference. \(stats.withCount) days with and \(stats.withoutCount) without, and the two averages sit inside each other’s ordinary spread."
            : "Readiness averages \(Int(abs(difference).rounded())) points \(difference > 0 ? "higher" : "lower") \(Self.lagWords[lag]) \(behavior.onPhrase)."
        let overlapLow = max(stats.withMean - stats.withDeviation, stats.withoutMean - stats.withoutDeviation)
        let overlapHigh = min(stats.withMean + stats.withDeviation, stats.withoutMean + stats.withoutDeviation)
        let overlap = overlapHigh > overlapLow
            ? "The shaded spans overlap between \(Int(overlapLow.rounded())) and \(Int(overlapHigh.rounded())), which is why this is a tendency and not a rule. Plenty of individual days go the other way."
            : "The two spans do not overlap at all across this window, which is as clean as an association in one person’s data gets."
        let thin = "Only \(stats.withCount) days with it and \(stats.withoutCount) without in this window. Noop needs five on each side before it will put two averages next to each other."
        return .init(
            name: behavior.name,
            ready: stats.withCount >= 5 && stats.withoutCount >= 5,
            withValue: "\(Int(stats.withMean.rounded()))",
            withDays: "\(stats.withCount) days",
            withSpread: withSpread,
            withMarker: fraction(stats.withMean),
            withoutValue: "\(Int(stats.withoutMean.rounded()))",
            withoutDays: "\(stats.withoutCount) days",
            withoutSpread: withoutSpread,
            withoutMarker: fraction(stats.withoutMean),
            read: read,
            overlap: overlap,
            thinRead: thin
        )
    }

    func doseModel(range: NoopInstrumentRange, forced: NoopInstrumentDoseMode) -> NoopInstrumentDoseModel {
        let deep = tail(values["deep"] ?? [], count: range.dayCount)
        let doses = Array(drinkDoses.suffix(min(range.dayCount, drinkDoses.count)))
        var doseNights = 0
        for index in deep.indices where deep[index] != nil && doses[max(0, index - 1)] > 0 {
            doseNights += 1
        }

        var sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumXY = 0.0
        var count = 0
        if deep.count > 1 {
            for index in 1..<deep.count {
                guard let y = deep[index] else { continue }
                let x = doses[index - 1]
                count += 1
                sumX += x
                sumY += y
                sumXX += x * x
                sumXY += x * y
            }
        }
        let denominator = Double(count) * sumXX - sumX * sumX
        let personal = count > 2 ? (Double(count) * sumXY - sumX * sumY) / (denominator == 0 ? 1 : denominator) : 0
        let published = -6.0
        let weight = Double(doseNights) / Double(doseNights + 18)
        let blended = published * (1 - weight) + personal * weight
        let disagrees = doseNights >= 40 && abs(personal - published) > 3
        let state: NoopInstrumentDoseMode = forced == .auto
            ? (doseNights < 8 ? .borrowed : disagrees ? .disagrees : doseNights < 40 ? .blending : .yours)
            : forced
        let shown = state == .borrowed ? published : (state == .yours || state == .disagrees ? personal : blended)
        let ownership: CGFloat = state == .borrowed ? 0.06 : state == .blending ? 0.48 : state == .disagrees ? 0.88 : 1
        let hue = state == .borrowed ? NoopHTMLColor.inkSoft : state == .blending ? Color(hex: 0xAFB9E2) : NoopHTMLColor.night
        let read: String
        switch state {
        case .borrowed:
            read = "Published figure. \(doseNights) of your nights so far — not you yet."
        case .blending, .auto:
            read = "\(doseNights) of your nights. Half yours, and moving — watch it across weeks, not visits."
        case .yours:
            read = "\(doseNights) of your nights behind it. This is your own number now, not the literature’s."
        case .disagrees:
            read = "\(doseNights) nights, and yours point \(abs(personal) < abs(published) ? "gentler" : "harder") than the literature’s −6. Both are shown; neither is hidden."
        }
        let chipInk = state == .borrowed ? NoopHTMLColor.copy : state == .disagrees ? Color(hex: 0xE9C48A) : Color(hex: 0xB7C0E8)
        let chipFill = state == .borrowed ? Color.white.opacity(0.06) : state == .disagrees ? NoopHTMLColor.warm.opacity(0.14) : NoopHTMLColor.night.opacity(0.14)
        let labels = ["One", "Two", "Three"]
        let steps = (1...3).map { multiplier -> NoopInstrumentDoseStep in
            let value = shown * Double(multiplier)
            return .init(
                label: labels[multiplier - 1],
                fraction: CGFloat(min(1, abs(value) / 20)),
                value: Self.signed(value, amount: Self.decimal(abs(value), places: 1))
            )
        }
        return .init(
            state: state.rawValue.prefix(1).uppercased() + state.rawValue.dropFirst(),
            number: Self.signed(shown, amount: Self.decimal(abs(shown), places: 1)),
            ownership: ownership,
            hue: hue,
            chipInk: chipInk,
            chipFill: chipFill,
            read: read,
            steps: steps
        )
    }

    func trailingWeeklyRate(_ values: [Double?]) -> [Double?] {
        values.indices.map { index in
            let lower = max(0, index - 6)
            let window = values[lower...index].compactMap { $0 }
            return window.isEmpty ? nil : window.reduce(0, +) / Double(window.count) * 7
        }
    }

    func firstAndLast(_ values: [Double?]) -> (first: Double?, last: Double?) {
        (values.compactMap { $0 }.first, values.compactMap { $0 }.last)
    }

    func sampledInterpolated(_ values: [Double?], maximum: Int) -> [Double] {
        let step = values.count > maximum ? Int(ceil(Double(values.count) / Double(maximum))) : 1
        let sampled = values.enumerated().filter { $0.offset.isMultiple(of: step) }.map(\.element)
        var result = sampled
        var previous: Double?
        for index in result.indices {
            if let value = result[index] {
                previous = value
                continue
            }
            var nextIndex = index
            while nextIndex < result.count, result[nextIndex] == nil { nextIndex += 1 }
            let next = nextIndex < result.count ? result[nextIndex] : previous
            result[index] = previous == nil ? next : next == nil ? previous : ((previous ?? 0) + (next ?? 0)) / 2
        }
        return result.compactMap { $0 }
    }

    struct ChartScale {
        let low: Double
        let span: Double
        let count: Int
        let width: CGFloat
        let height: CGFloat
        let padding: CGFloat

        func point(value: Double, index: Int) -> CGPoint {
            let x = CGFloat(index) / CGFloat(max(1, count - 1)) * width
            let y = height - CGFloat((value - low) / span) * (height - padding * 2) - padding
            return CGPoint(x: x, y: y)
        }
    }

    func chartScale(values: [Double], width: CGFloat, height: CGFloat, padding: CGFloat) -> ChartScale {
        let low = values.min() ?? 0
        let high = values.max() ?? low + 1
        return .init(low: low, span: high == low ? 1 : high - low, count: values.count, width: width, height: height, padding: padding)
    }

    func rollingRange(_ values: [Double], radius: Int) -> [ClosedRange<Double>] {
        values.indices.map { index in
            let lower = max(0, index - radius)
            let upper = min(values.count - 1, index + radius)
            let window = values[lower...upper]
            return (window.min() ?? 0)...(window.max() ?? 0)
        }
    }

    func regression(values: [Double], scale: ChartScale) -> (start: CGPoint, end: CGPoint)? {
        guard !values.isEmpty else { return nil }
        var sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumXY = 0.0
        for (index, value) in values.enumerated() {
            let x = Double(index)
            sumX += x
            sumY += value
            sumXX += x * x
            sumXY += x * value
        }
        let count = Double(values.count)
        let denominator = count * sumXX - sumX * sumX
        let slope = (count * sumXY - sumX * sumY) / (denominator == 0 ? 1 : denominator)
        let intercept = (sumY - slope * sumX) / count
        return (
            scale.point(value: intercept, index: 0),
            scale.point(value: intercept + slope * Double(values.count - 1), index: values.count - 1)
        )
    }

    func correlation(first: [Double?], second: [Double?], lag: Int) -> NoopInstrumentCorrelation {
        var count = 0
        var sumA = 0.0, sumB = 0.0, sumAA = 0.0, sumBB = 0.0, sumAB = 0.0
        guard lag >= 0, first.count > lag else { return .init(coefficient: 0, count: 0, lag: lag) }
        for index in 0..<(first.count - lag) {
            guard let a = first[index], let b = second[index + lag] else { continue }
            count += 1
            sumA += a
            sumB += b
            sumAA += a * a
            sumBB += b * b
            sumAB += a * b
        }
        guard count >= 8 else { return .init(coefficient: 0, count: count, lag: lag) }
        let n = Double(count)
        let covariance = sumAB / n - (sumA / n) * (sumB / n)
        let varianceA = sumAA / n - pow(sumA / n, 2)
        let varianceB = sumBB / n - pow(sumB / n, 2)
        guard varianceA > 0, varianceB > 0 else { return .init(coefficient: 0, count: count, lag: lag) }
        return .init(coefficient: covariance / sqrt(varianceA * varianceB), count: count, lag: lag)
    }

    func bestLag(first: [Double?], second: [Double?]) -> NoopInstrumentCorrelation {
        (0...2)
            .map { correlation(first: first, second: second, lag: $0) }
            .max { abs($0.coefficient) < abs($1.coefficient) }
            ?? .init(coefficient: 0, count: 0, lag: 0)
    }

    func groupStats(behavior: [Double?], target: [Double?], lag: Int) -> NoopInstrumentGroupStats {
        var withValues: [Double] = []
        var withoutValues: [Double] = []
        guard behavior.count > lag else {
            return .init(withMean: 0, withoutMean: 0, withCount: 0, withoutCount: 0, withDeviation: 0, withoutDeviation: 0)
        }
        for index in 0..<(behavior.count - lag) {
            guard let flag = behavior[index], let value = target[index + lag] else { continue }
            if flag > 0 { withValues.append(value) } else { withoutValues.append(value) }
        }
        func mean(_ values: [Double]) -> Double { values.reduce(0, +) / Double(max(1, values.count)) }
        func deviation(_ values: [Double], mean: Double) -> Double {
            guard values.count >= 2 else { return 0 }
            return sqrt(values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1))
        }
        let withMean = mean(withValues)
        let withoutMean = mean(withoutValues)
        return .init(
            withMean: withMean,
            withoutMean: withoutMean,
            withCount: withValues.count,
            withoutCount: withoutValues.count,
            withDeviation: deviation(withValues, mean: withMean),
            withoutDeviation: deviation(withoutValues, mean: withoutMean)
        )
    }

    static func signed(_ value: Double, amount: String) -> String {
        (value > 0 ? "+" : "−") + amount
    }

    static func decimal(_ value: Double, places: Int) -> String {
        String(format: "%.*f", places, value)
    }
}
#endif
