import WidgetKit
import SwiftUI

/// Last night's five vitals, each against the zone Today's Vitals judged it by — your own baseline once
/// it is trusted, the typical adult range before that. Opens Vitals.
struct VitalsWidget: Widget {
    static let kind = "VitalsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: PanelsProvider()) { entry in
            VitalsWidgetView(entry: entry)
        }
        .configurationDisplayName("Vitals")
        .description("Check last night's vitals against your own normal zone.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

struct VitalsWidgetView: View {
    @Environment(\.widgetFamily) private var systemFamily
    @Environment(\.widgetRenderingMode) private var systemRenderingMode
    /// Set only by the Debug widget board, which renders every family inside the app.
    var familyOverride: WidgetFamily? = nil
    var renderingOverride: WidgetRenderingMode? = nil
    private var family: WidgetFamily { familyOverride ?? systemFamily }
    private var renderingMode: WidgetRenderingMode { renderingOverride ?? systemRenderingMode }
    let entry: PanelsEntry

    private let tint = PanelInk.blue
    private var vitals: WidgetPanels.Vitals? { entry.panels?.vitals }
    private var fullColor: Bool { renderingMode == .fullColor }

    var body: some View {
        switch family {
        case .accessoryRectangular: rectangular.accessoryChrome(.vitals)
        case .systemMedium: content(medium: true).panelChrome(tint: tint, link: .vitals)
        default: content(medium: false).panelChrome(tint: tint, link: .vitals)
        }
    }

    private var when: String? {
        guard let measured = vitals?.measuredAt else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: entry.date)
        if measured >= today { return "last night" }
        return measured.formatted(.dateTime.weekday(.abbreviated).day())
    }

    /// Aura's count line: "Four in your normal zone, one outside it".
    private func summary(_ vitals: WidgetPanels.Vitals) -> String {
        let words = ["none", "one", "two", "three", "four", "five"]
        let out = vitals.outsideCount, inside = vitals.items.count - out
        if out == 0 { return inside == vitals.items.count && inside > 1 ? "All \(words[inside]) in your normal zone" : "In your normal zone" }
        let lead = words[min(5, inside)]
        return lead.prefix(1).uppercased() + lead.dropFirst() + " in your zone, " + words[min(5, out)] + " outside"
    }

    @ViewBuilder
    private func content(medium: Bool) -> some View {
        if let vitals {
            VStack(alignment: .leading, spacing: 0) {
                PanelKicker(title: "Vitals", symbol: "waveform.path.ecg", tint: tint, trailing: when)
                if medium {
                    Text(summary(vitals))
                        .font(PanelType.sans(12))
                        .foregroundStyle(PanelInk.copy)
                        .lineLimit(1)
                        .padding(.top, 5)
                    Spacer(minLength: 6)
                    VStack(spacing: 5) {
                        ForEach(vitals.items) { item in VitalRow(item: item, fullColor: fullColor) }
                    }
                } else {
                    Spacer(minLength: 6)
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(vitals.items) { item in compactRow(item) }
                    }
                }
            }
        } else {
            PanelEmpty(title: "Vitals", symbol: "waveform.path.ecg", tint: tint,
                       message: "A night on the strap gives your resting pulse, HRV, breathing and more.")
                .medium(medium ? .tracks : nil)
        }
    }

    private func compactRow(_ item: WidgetPanels.Vitals.Item) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(item.outside ? (fullColor ? PanelInk.warm : .white) : Color.white.opacity(0.25))
                .frame(width: 5, height: 5)
                .widgetAccentable(item.outside)
            Text(item.short)
                .font(PanelType.sans(12))
                .foregroundStyle(item.outside ? PanelInk.primary : PanelInk.copy)
            Spacer(minLength: 4)
            Text(VitalRow.format(item.value, item: item))
                .font(PanelType.strong(12))
                .monospacedDigit()
                .foregroundStyle(item.outside && fullColor ? PanelInk.warm : PanelInk.primary)
            Text(item.unit)
                .font(PanelType.sans(11))
                .foregroundStyle(PanelInk.quiet)
                .frame(width: 26, alignment: .leading)
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityValue(item.outside ? "outside your zone" : "in your zone")
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label("Vitals", systemImage: "waveform.path.ecg")
                .font(.system(size: 12, weight: .semibold))
                .widgetAccentable()
            if let vitals {
                Text(vitals.outsideCount == 0 ? "All in your zone" : "\(vitals.outsideCount) outside your zone")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text(vitals.items.map { "\($0.short) \(VitalRow.format($0.value, item: $0))" }.prefix(3).joined(separator: " · "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("No night recorded").font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One vital on its scale: the zone as a soft band, your baseline as a tick, last night as a dot.
struct VitalRow: View {
    let item: WidgetPanels.Vitals.Item
    let fullColor: Bool

    static func format(_ value: Double, item: WidgetPanels.Vitals.Item) -> String {
        let text = PanelFormat.decimal(abs(value), item.decimals)
        let negative = value < 0 && text.contains { $0 != "0" && $0 != "." }
        return (item.id == "skin" && !negative && value > 0 && item.unit.contains("C") && value < 20 ? "+" : "")
            + (negative ? "\u{2212}" : "") + text
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(item.short)
                .font(PanelType.sans(11))
                .foregroundStyle(item.outside ? PanelInk.primary : PanelInk.copy)
                .frame(width: 62, alignment: .leading)
                .lineLimit(1)
            GeometryReader { proxy in
                let w = proxy.size.width, mid = proxy.size.height / 2
                let lo = CGFloat(item.fraction(item.low)) * w, hi = CGFloat(item.fraction(item.high)) * w
                let x = CGFloat(item.fraction(item.value)) * w
                ZStack(alignment: .leading) {
                    Capsule().fill(PanelInk.track).frame(height: 3).offset(y: 0)
                    Capsule()
                        .fill(fullColor ? PanelInk.blue.opacity(0.38) : Color.white.opacity(0.35))
                        .frame(width: max(4, hi - lo), height: 3)
                        .offset(x: lo)
                    if let baseline = item.baseline {
                        Rectangle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 1, height: 8)
                            .offset(x: CGFloat(item.fraction(baseline)) * w - 0.5)
                    }
                    Circle()
                        .fill(item.outside ? (fullColor ? PanelInk.warm : .white) : (fullColor ? PanelInk.blueLight : .white))
                        .overlay(Circle().stroke(PanelInk.surface, lineWidth: 1.5))
                        .frame(width: 8, height: 8)
                        .offset(x: min(max(0, x - 4), w - 8))
                        .widgetAccentable()
                }
                .frame(height: proxy.size.height)
                .position(x: w / 2, y: mid)
            }
            .frame(height: 10)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(Self.format(item.value, item: item))
                    .font(PanelType.strong(12))
                    .monospacedDigit()
                    .foregroundStyle(item.outside && fullColor ? PanelInk.warm : PanelInk.primary)
                Text(item.unit)
                    .font(PanelType.sans(10))
                    .foregroundStyle(PanelInk.quiet)
            }
            .frame(width: 62, alignment: .trailing)
            .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.name)
        .accessibilityValue("\(Self.format(item.value, item: item)) \(item.unit), \(item.outside ? "outside" : "inside") your zone")
    }
}
