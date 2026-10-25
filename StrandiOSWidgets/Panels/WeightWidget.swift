import WidgetKit
import SwiftUI

/// The latest weigh-in, and the smoothed trend that a change is honestly read from — a salty dinner is
/// a dot off the line, not a gain. Opens Body.
struct WeightWidget: Widget {
    static let kind = "WeightWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PanelsProvider()) { entry in
            WeightWidgetView(entry: entry)
        }
        .configurationDisplayName("Weight")
        .description("See your latest weigh-in and where the trend is heading.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

struct WeightWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    @Environment(\.widgetRenderingMode) private var systemRenderingMode
    /// Set only by the Debug widget board, which renders every family inside the app.
    var familyOverride: WidgetFamily? = nil
    var renderingOverride: WidgetRenderingMode? = nil
    private var family: WidgetFamily { familyOverride ?? systemFamily }
    private var renderingMode: WidgetRenderingMode { renderingOverride ?? systemRenderingMode }
    let entry: PanelsEntry

    private let tint = PanelInk.blush
    private var weight: WidgetPanels.Weight? { entry.panels?.weight }

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular.accessoryChrome(.weight)
        case .accessoryInline: inline.accessoryChrome(.weight)
        case .systemMedium: content(medium: true).panelChrome(tint: tint, link: .weight)
        default: content(medium: false).panelChrome(tint: tint, link: .weight)
        }
    }

    private func value(_ x: Double) -> String { PanelFormat.decimal(x, 1) }

    private func changeLine(_ weight: WidgetPanels.Weight) -> String {
        guard weight.trendReliable, let change = weight.change30 else {
            return "the trend is still settling"
        }
        let signed = PanelFormat.signed(change)
        return signed == "steady" ? "steady over 30 days" : "\(signed) \(weight.unit) in 30 days"
    }

    @ViewBuilder
    private func content(medium: Bool) -> some View {
        if let weight {
            if medium {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 0) {
                        headline(weight)
                        Spacer(minLength: 6)
                        Text("trend \(value(weight.trend)) \(weight.unit)")
                            .font(PanelType.sans(11))
                            .monospacedDigit()
                            .foregroundStyle(PanelInk.quiet)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    WeightChart(weight: weight, tint: tint, fullColor: renderingMode == .fullColor, axis: true)
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    headline(weight)
                    Spacer(minLength: 8)
                    WeightChart(weight: weight, tint: tint, fullColor: renderingMode == .fullColor, axis: false)
                        .frame(height: 34)
                }
            }
        } else {
            PanelEmpty(title: "Weight", symbol: "scalemass.fill", tint: tint,
                       message: "Log a weigh-in on Body, or let Apple Health share your scale.")
                .medium(medium ? .line : nil)
        }
    }

    private func headline(_ weight: WidgetPanels.Weight) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            PanelKicker(title: "Weight", symbol: "scalemass.fill", tint: tint,
                        trailing: PanelFormat.day(weight.latestAt, now: entry.date))
            PanelFigure(value: value(weight.latest), unit: weight.unit)
                .padding(.top, 6)
            Text(changeLine(weight))
                .font(PanelType.sans(12))
                .foregroundStyle(PanelInk.copy)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.top, 1)
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Weight", systemImage: "scalemass.fill")
                .font(.system(size: 12, weight: .semibold))
                .widgetAccentable()
            if let weight {
                Text("\(value(weight.latest)) \(weight.unit)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(changeLine(weight)).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            } else {
                Text("No weigh-in yet").font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Text("\(Image(systemName: "scalemass.fill")) \(weight.map { "\(value($0.latest)) \($0.unit)" } ?? "No weigh-in yet")")
    }
}

/// Ninety days: each weigh-in as a faint dot, the smoothed trend as the line, today's end marked.
struct WeightChart: View {
    let weight: WidgetPanels.Weight
    let tint: Color
    let fullColor: Bool
    let axis: Bool

    var body: some View {
        if weight.readings.count < 2 {
            firstReading
        } else {
            chart
        }
    }

    /// One weigh-in is a point, not a trend: it sits at today's end of an empty track.
    private var firstReading: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(Color.white.opacity(0.14))
                .frame(height: 1)
                .mask(HStack(spacing: 3) { ForEach(0..<40, id: \.self) { _ in Rectangle().frame(width: 3) } })
            Circle()
                .fill(fullColor ? tint : .white)
                .frame(width: 7, height: 7)
                .widgetAccentable()
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .accessibilityLabel("One weigh-in so far")
    }

    @ViewBuilder
    private var chart: some View {
        let all = weight.readings.map(\.value) + weight.trendLine.map(\.value)
        let lo = (all.min() ?? weight.latest) , hi = (all.max() ?? weight.latest)
        let pad = max(0.4, (hi - lo) * 0.18)
        let domain = (lo - pad)...(hi + pad)
        let start = (weight.readings.first?.at ?? weight.latestAt).addingTimeInterval(-86_400)
        let end = max(weight.latestAt, weight.trendLine.last?.at ?? weight.latestAt).addingTimeInterval(86_400)
        HStack(alignment: .top, spacing: 6) {
            GeometryReader { proxy in
                let w = proxy.size.width, h = proxy.size.height
                let x = { (d: Date) in CGFloat(d.timeIntervalSince(start) / max(1, end.timeIntervalSince(start))) * w }
                let y = { (v: Double) in h - CGFloat((v - domain.lowerBound) / (domain.upperBound - domain.lowerBound)) * h }
                ZStack(alignment: .topLeading) {
                    ForEach(Array(weight.readings.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(Color.white.opacity(fullColor ? 0.22 : 0.4))
                            .frame(width: 3, height: 3)
                            .position(x: x(point.at), y: y(point.value))
                    }
                    if weight.trendLine.count >= 2 {
                        Path { path in
                            for (i, point) in weight.trendLine.enumerated() {
                                let p = CGPoint(x: x(point.at), y: y(point.value))
                                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                            }
                        }
                        .stroke(fullColor ? tint : .white,
                                style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
                        .widgetAccentable()
                    }
                    if let last = weight.trendLine.last {
                        Circle()
                            .fill(fullColor ? tint : .white)
                            .overlay(Circle().stroke(PanelInk.surface, lineWidth: 1.5))
                            .frame(width: 7, height: 7)
                            .position(x: x(last.at), y: y(last.value))
                            .widgetAccentable()
                    }
                }
            }
            if axis {
                VStack(alignment: .trailing) {
                    Text(PanelFormat.decimal(domain.upperBound, 0))
                    Spacer()
                    Text(PanelFormat.decimal(domain.lowerBound, 0))
                }
                .font(PanelType.sans(9))
                .monospacedDigit()
                .foregroundStyle(PanelInk.kicker)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Weight trend over ninety days")
    }
}
