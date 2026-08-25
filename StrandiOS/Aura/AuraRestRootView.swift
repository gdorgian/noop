#if os(iOS)
import SwiftUI
import StrandDesign

/// Act 1 home chrome. The HTML reference owns the visual hierarchy; `AuraRestReading`
/// supplies every value shown inside it.
struct AuraRestView: View {
    private let reading: AuraRestReading
    private let onOpenWhy: (Int) -> Void
    private let onOpenDebt: () -> Void
    private let onOpenTonight: () -> Void
    private let onOpenBand: () -> Void

    @EnvironmentObject private var live: LiveState

    init(
        reading: AuraRestReading,
        onOpenWhy: @escaping (Int) -> Void,
        onOpenDebt: @escaping () -> Void,
        onOpenTonight: @escaping () -> Void,
        onOpenBand: @escaping () -> Void
    ) {
        self.reading = reading
        self.onOpenWhy = onOpenWhy
        self.onOpenDebt = onOpenDebt
        self.onOpenTonight = onOpenTonight
        self.onOpenBand = onOpenBand
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            AuraRestReferenceContent(
                reading: reading,
                onOpenWhy: onOpenWhy,
                onOpenDebt: onOpenDebt,
                onOpenTonight: onOpenTonight
            )
        }
        // The HTML's 58pt top inset already includes the iPhone status area. AuraShell's
        // zero-height scroll anchor contributes one card gap, so cancel that gap here.
        .padding(.top, -17)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Last night"))
                    .font(.custom("Instrument Sans", fixedSize: 13.5))
                    .foregroundStyle(AuraPalette.textTertiary)
                Text(String(localized: "Rest"))
                    .font(.custom("Outfit", fixedSize: 23).weight(.regular))
                    .tracking(-0.46)
                    .foregroundStyle(AuraPalette.textPrimary)
            }

            Spacer(minLength: 14)

            NoopStrapBatteryChip(
                level: live.connected ? live.batteryPct.map { $0 / 100 } : nil,
                charging: live.charging == true,
                action: onOpenBand
            )
            .offset(y: -6)
        }
        .padding(.bottom, 4)
    }
}

enum AuraRestScoreBand {
    case poor, fair, good, optimal

    init(score: Double) {
        switch min(max(score, 0), 100) {
        case ..<50: self = .poor
        case ..<70: self = .fair
        case ..<85: self = .good
        default: self = .optimal
        }
    }

    var label: String {
        switch self {
        case .poor: return String(localized: "Poor")
        case .fair: return String(localized: "Fair")
        case .good: return String(localized: "Good")
        case .optimal: return String(localized: "Optimal")
        }
    }
}
#endif
