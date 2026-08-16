#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Band
//
// The strap's own screen. It answers "is it working and how long have I got" first, and everything else
// after — which is the opposite order to most device screens and the right one for a band you are
// wearing rather than configuring.

struct AuraBandView: View {
    private let reading: AuraBandReading
    /// Opens the app's real device manager (pair / switch straps), which Aura does not reimplement.
    let onManageDevices: () -> Void
    let onSync: () -> Void

    init(
        reading: AuraBandReading = .prototype,
        onManageDevices: @escaping () -> Void,
        onSync: @escaping () -> Void
    ) {
        self.reading = reading
        self.onManageDevices = onManageDevices
        self.onSync = onSync
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            batteryCard

            HStack(spacing: 8) {
                AuraIconTile(symbol: "arrow.triangle.2.circlepath", tint: AuraPalette.accent,
                             tag: String(localized: "Live"),
                             title: String(localized: "Last sync"),
                             detail: reading.lastSync)
                AuraIconTile(symbol: "cpu", tint: AuraPalette.rest,
                             tag: String(localized: "Safe"),
                             title: String(localized: "On-band storage"),
                             detail: reading.buffered)
            }

            VStack(spacing: 0) {
                ForEach(Array(reading.rows.enumerated()), id: \.element.id) { index, row in
                    AuraListRow(key: row.key, value: row.value,
                                showsDivider: index < reading.rows.count - 1)
                }
            }
            .padding(.horizontal, 17)
            .auraCard()

            AuraListRow(key: String(localized: "Manage straps"),
                        subtitle: String(localized: "Pair, switch or forget a band"),
                        showsDivider: false,
                        action: onManageDevices)
                .padding(.horizontal, 17)
                .auraCard()

            Button(action: onSync) {
                Text(String(localized: "Sync now"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AuraPalette.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(AuraPalette.accent))
            }
            .buttonStyle(.plain)
        }
    }

    private var batteryCard: some View {
        VStack(spacing: 20) {
            AuraBatteryRing(fraction: reading.batteryFraction,
                            percentText: "\(reading.batteryPercent)",
                            caption: reading.remaining)
            Text(reading.chargingNote)
                .font(.system(size: 14))
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(AuraPalette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .auraCard(cornerRadius: 26)
    }
}

// MARK: - Reading

struct AuraBandReading {
    struct Row: Identifiable {
        let id: String
        let key: String
        let value: String
    }

    let batteryPercent: Int
    let remaining: String
    let chargingNote: String
    let lastSync: String
    let buffered: String
    let rows: [Row]

    var batteryFraction: Double { Double(batteryPercent) / 100 }

    static let prototype = AuraBandReading(
        batteryPercent: 62,
        remaining: String(localized: "about 2 days left"),
        chargingNote: String(localized: "Charging takes about 90 minutes. Wear it while you charge — the band keeps recording."),
        lastSync: String(localized: "4 minutes ago"),
        buffered: String(localized: "2 days buffered"),
        rows: [
            Row(id: "worn", key: String(localized: "Worn since"), value: String(localized: "6 days straight")),
            Row(id: "mode", key: String(localized: "Battery mode"), value: String(localized: "Standard")),
            Row(id: "strap", key: String(localized: "Strap"), value: String(localized: "Graphite knit")),
            Row(id: "firmware", key: String(localized: "Firmware"), value: String(localized: "Up to date")),
        ]
    )
}
#endif
