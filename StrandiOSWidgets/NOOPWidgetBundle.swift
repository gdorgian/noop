import WidgetKit
import SwiftUI
import StrandDesign

// MARK: - Aura widget additions

private enum AuraWidgetInk {
    static let surface = Color(hex: "#0F1312")
    static let primary = Color(hex: "#EDF1EF")
    static let secondary = Color(hex: "#C6CEC9")
    static let quiet = Color(hex: "#7F8A85")
    static let kicker = Color(hex: "#6C7570")
    static let aura = Color(hex: "#17A2E6")
    static let auraLight = Color(hex: "#8FD3F5")
}

private extension Font {
    static func noopOutfit(_ size: CGFloat, face: String = NoopSpecType.Face.outfitLight) -> Font {
        .custom(face, fixedSize: size)
    }

    static func noopSans(_ size: CGFloat, face: String = NoopSpecType.Face.sansRegular) -> Font {
        .custom(face, fixedSize: size)
    }
}

private struct RestingPulseWidgetView: View {
    let entry: NOOPEntry

    private var values: [Int?] {
        let stored = entry.snapshot.restingHrWeek ?? []
        if stored.count >= 7 { return Array(stored.suffix(7)) }
        return Array<Int?>(repeating: nil, count: 7 - stored.count) + stored
    }

    private var measured: [Int] { values.compactMap { $0 } }

    private var rangeLine: String {
        guard let low = measured.min(), let high = measured.max() else {
            return "no resting pulse recorded this week"
        }
        if values.last == nil {
            return "7-day range \(low) – \(high) · latest night not recorded"
        }
        return "7-day range \(low) – \(high)"
    }

    private func barHeight(_ value: Int?) -> CGFloat {
        guard let value else { return 1 }
        // A fixed physiological display domain makes two weeks comparable. Values outside the
        // ordinary 40–80 bpm band clamp at the edge; the printed number remains unaltered.
        return 4 + CGFloat(max(0, min(40, value - 40))) / 40 * 26
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Resting pulse")
                .font(.noopSans(9.5, face: NoopSpecType.Face.sansSemiBold))
                .tracking(1.33)
                .textCase(.uppercase)
                .foregroundStyle(AuraWidgetInk.kicker)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(entry.snapshot.restingHr.map(String.init) ?? "—")
                    .font(.noopOutfit(36))
                    .tracking(-1.26)
                    .monospacedDigit()
                    .foregroundStyle(entry.snapshot.restingHr == nil
                                     ? AuraWidgetInk.quiet : AuraWidgetInk.primary)
                if entry.snapshot.restingHr != nil {
                    Text("bpm")
                        .font(.noopSans(11))
                        .foregroundStyle(AuraWidgetInk.quiet)
                }
            }
            .padding(.top, 7)

            Spacer(minLength: 8)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: value == nil ? 0.5 : 2)
                        .fill(value == nil
                              ? Color.white.opacity(0.14)
                              : (index == values.indices.last && entry.snapshot.restingHr != nil
                                 ? AuraWidgetInk.auraLight : Color.white.opacity(0.17)))
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight(value))
                }
            }
            .frame(height: 30, alignment: .bottom)

            Text(rangeLine)
                .font(.noopSans(10))
                .foregroundStyle(AuraWidgetInk.quiet)
                .lineLimit(2)
                .padding(.top, 7)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }
}

private struct RestingPulseWidget: Widget {
    static let kind = NoopWidgetFamilyRegistry.family(.restingPulse).configurationKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NOOPProvider()) { entry in
            RestingPulseWidgetView(entry: entry)
                .containerBackground(AuraWidgetInk.surface, for: .widget)
        }
        .configurationDisplayName(NoopWidgetFamilyRegistry.family(.restingPulse).title)
        .description("This morning’s resting pulse with the seven nights behind it.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

private struct EnergyWidgetView: View {
    let entry: NOOPEntry

    private var energy: NoopWidgetEnergySnapshot? {
        guard let energy = entry.snapshot.energy, energy.profileConfirmed == true else { return nil }
        return energy
    }

    private func whole(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    private var sourceLabel: String {
        switch energy?.source {
        case "appleSplit", "strapWornTime": "measured"
        case "mixed": "mixed"
        case "stepsEstimate": "modelled"
        default: "cold start"
        }
    }

    private var coverageLine: String {
        guard let coverage = energy?.coverage else { return "coverage not available yet" }
        if coverage >= 0.8 { return "saw most of the day" }
        if coverage >= 0.4 { return "saw part of the day" }
        return "saw only a little of the day"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Text("What today has cost")
                    .font(.noopSans(9.5, face: NoopSpecType.Face.sansSemiBold))
                    .tracking(1.33)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraWidgetInk.kicker)
                Spacer(minLength: 8)
                Text(sourceLabel)
                    .font(.noopSans(9, face: NoopSpecType.Face.sansSemiBold))
                    .tracking(0.99)
                    .textCase(.uppercase)
                    .foregroundStyle(energy?.totalBurnedSoFar == nil
                                     ? AuraWidgetInk.secondary : AuraWidgetInk.auraLight)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                (energy?.totalBurnedSoFar == nil
                                 ? AuraWidgetInk.secondary : AuraWidgetInk.auraLight).opacity(0.42),
                                lineWidth: 0.5
                            )
                    )
            }

            if let total = energy?.totalBurnedSoFar {
                measuredBody(total)
            } else if let basal = energy?.estimatedBMR24h {
                coldStartBody(basal)
            } else {
                unavailableBody
            }
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func measuredBody(_ total: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(whole(total))
                .font(.noopOutfit(32))
                .tracking(-1.12)
                .monospacedDigit()
                .foregroundStyle(AuraWidgetInk.primary)
            Text("kcal so far")
                .font(.noopSans(11))
                .foregroundStyle(AuraWidgetInk.quiet)
        }
        .padding(.top, 7)

        if let basal = energy?.basalBurnedSoFar,
           let active = energy?.activeBurnedSoFar,
           basal + active > 0 {
            GeometryReader { proxy in
                let gap: CGFloat = 3
                let usable = max(0, proxy.size.width - gap)
                let basalWidth = usable * CGFloat(basal) / CGFloat(basal + active)
                HStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AuraWidgetInk.aura)
                        .frame(width: basalWidth)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AuraWidgetInk.auraLight)
                }
            }
            .frame(height: 5)
            .padding(.top, 10)

            HStack(spacing: 14) {
                energySplitLabel("basal", value: basal)
                energySplitLabel("active", value: active)
            }
            .padding(.top, 6)
        }

        Spacer(minLength: 6)

        HStack(alignment: .firstTextBaseline, spacing: 12) {
            if let low = energy?.projectedLow, let high = energy?.projectedHigh {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("heading for ")
                    Text("\(whole(low)) – \(whole(high))")
                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                }
            } else {
                Text("no defensible forecast yet")
            }
            Spacer(minLength: 8)
            Text(coverageLine)
                .font(.noopSans(10.5))
                .foregroundStyle(AuraWidgetInk.quiet)
        }
        .font(.noopSans(11.5))
        .foregroundStyle(AuraWidgetInk.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
    }

    private func energySplitLabel(_ label: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(AuraWidgetInk.quiet)
            Text(whole(value))
                .font(.noopSans(10.5, face: NoopSpecType.Face.sansSemiBold))
                .foregroundStyle(AuraWidgetInk.secondary)
        }
        .font(.noopSans(10.5))
    }

    @ViewBuilder
    private func coldStartBody(_ basal: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("about")
                .font(.noopSans(13))
                .foregroundStyle(AuraWidgetInk.quiet)
            Text(whole(basal))
                .font(.noopOutfit(32))
                .tracking(-1.12)
                .monospacedDigit()
                .foregroundStyle(AuraWidgetInk.secondary)
            Text("kcal, all day")
                .font(.noopSans(11))
                .foregroundStyle(AuraWidgetInk.quiet)
        }
        .padding(.top, 7)

        RoundedRectangle(cornerRadius: 2)
            .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
            .frame(height: 5)
            .padding(.top, 10)
        Text("no measured spend yet · nothing to split")
            .font(.noopSans(10.5))
            .foregroundStyle(AuraWidgetInk.quiet)
            .padding(.top, 6)
        Spacer(minLength: 6)
        Text("A model of your basal day, stated as a model. The projection is absent because there is nothing yet to project from.")
            .font(.noopSans(11))
            .foregroundStyle(AuraWidgetInk.quiet)
            .lineLimit(2)
    }

    private var unavailableBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("—")
                .font(.noopOutfit(32))
                .foregroundStyle(AuraWidgetInk.quiet)
            Text("Add your body details before Noop can model a basal day. No spend or projection is shown in their place.")
                .font(.noopSans(11))
                .foregroundStyle(AuraWidgetInk.quiet)
                .lineLimit(3)
        }
        .padding(.top, 7)
    }
}

private struct EnergyWidget: Widget {
    static let kind = NoopWidgetFamilyRegistry.family(.energy).configurationKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: NOOPProvider()) { entry in
            EnergyWidgetView(entry: entry)
                .containerBackground(AuraWidgetInk.surface, for: .widget)
        }
        .configurationDisplayName(NoopWidgetFamilyRegistry.family(.energy).title)
        .description("What today has cost and the defensible range it is heading toward.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

/// The widget extension entry point. Bundles the glanceable widget, the three-ring widget, the
/// live-HR Live Activity, the K10 Coach brief widget (stored morning brief on Lock Screen / Home
/// Screen), the heart-rate trace widget (#1957), the stress curve widget (#2040), and the Lift Log
/// session Live Activity.
///
/// `NOOPRingsWidget` arrived complete with the Today redesign and was never registered here, so it
/// has never been installable despite shipping in the binary. It leads on Charge at systemSmall,
/// which the glanceable widget's lock-screen accessory also does; that overlap is deliberate and
/// belongs to the widget gallery's copy, not to this list.
@main
struct NOOPWidgetBundle: WidgetBundle {
    init() {
        // Widgets are a separate process; registering in the app does not make the package fonts
        // available here. Without this every gallery preview silently falls back to San Francisco.
        NoopSpecType.registerFonts()

        #if DEBUG
        let registeredFamilyKinds: Set<String> = [
            NOOPWidget.kind,
            HeartRateWidget.kind,
            CoachBriefWidget.kind,
            RestingPulseWidget.kind,
            StressWidget.kind,
            NoopWidgetFamilyRegistry.family(.liftSession).configurationKind,
            EnergyWidget.kind,
            NOOPRingsWidget.kind,
        ]
        precondition(
            registeredFamilyKinds == Set(NoopWidgetFamilyRegistry.families.map(\.configurationKind)),
            "Widget bundle and NoopWidgetFamilyRegistry have drifted"
        )
        #endif
    }

    var body: some Widget {
        NOOPWidget()
        HeartRateWidget()
        NOOPLiveActivity()
        CoachBriefWidget()
        RestingPulseWidget()
        StressWidget()
        LiftLiveActivity()
        EnergyWidget()
        NOOPRingsWidget()
    }
}
