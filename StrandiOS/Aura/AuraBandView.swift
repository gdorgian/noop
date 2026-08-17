#if os(iOS)
import SwiftUI
import StrandAnalytics
import StrandDesign

// MARK: - Aura Band
//
// The strap's own screen. It answers "is it working and how long have I got" first, and everything else
// after — which is the opposite order to most device screens and the right one for a band you are
// wearing rather than configuring.

struct AuraBandView: View {
    private let reading: AuraBandReading?
    /// Opens the app's real device manager (pair / switch straps), which Aura does not reimplement.
    let onManageDevices: () -> Void
    let onSync: () -> Void

    init(
        reading: AuraBandReading? = nil,
        onManageDevices: @escaping () -> Void,
        onSync: @escaping () -> Void
    ) {
        self.reading = reading
        self.onManageDevices = onManageDevices
        self.onSync = onSync
    }

    var body: some View {
        if let reading {
            AuraBandContent(reading: reading, onManageDevices: onManageDevices, onSync: onSync)
        } else {
            AuraLiveBandContent(onManageDevices: onManageDevices, onSync: onSync)
        }
    }
}

/// LiveState publishes the HR stream around once per second. Keeping that observation on the Band screen
/// itself prevents those updates invalidating the shell, Today, and every chart while preserving a live
/// device readout whenever this screen is actually open.
private struct AuraLiveBandContent: View {
    @EnvironmentObject private var live: LiveState
    let onManageDevices: () -> Void
    let onSync: () -> Void

    var body: some View {
        AuraBandContent(
            reading: .live(live),
            onManageDevices: onManageDevices,
            onSync: onSync
        )
    }
}

private struct AuraBandContent: View {
    let reading: AuraBandReading
    let onManageDevices: () -> Void
    let onSync: () -> Void

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            batteryCard

            HStack(spacing: 8) {
                AuraIconTile(symbol: "arrow.triangle.2.circlepath", tint: AuraPalette.accent,
                             tag: reading.syncTag,
                             title: String(localized: "Last sync"),
                             detail: reading.lastSync)
                AuraIconTile(symbol: "cpu", tint: AuraPalette.rest,
                             tag: reading.historyTag,
                             title: String(localized: "History range"),
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
                Text(reading.isSyncing ? String(localized: "Syncing history…")
                                      : String(localized: "Sync now"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(reading.canSync ? AuraPalette.onAccent : AuraPalette.textQuiet)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(reading.canSync ? AuraPalette.accent : AuraPalette.controlFill))
            }
            .buttonStyle(.plain)
            .disabled(!reading.canSync)
        }
    }

    private var batteryCard: some View {
        VStack(spacing: 20) {
            AuraBatteryRing(fraction: reading.batteryFraction,
                            percentText: reading.batteryPercent.map(String.init) ?? "—",
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

    let batteryPercent: Int?
    let remaining: String
    let chargingNote: String
    let syncTag: String
    let lastSync: String
    let historyTag: String
    let buffered: String
    let rows: [Row]
    let canSync: Bool
    let isSyncing: Bool

    var batteryFraction: Double { Double(batteryPercent ?? 0) / 100 }

    @MainActor
    static func live(_ live: LiveState, now: TimeInterval = Date().timeIntervalSince1970) -> AuraBandReading {
        let battery = live.connected ? live.batteryPct.map { Int($0.rounded()) } : nil
        let remaining: String
        if live.charging == true {
            remaining = String(localized: "charging now")
        } else if let estimate = live.batteryEstimate {
            remaining = String(localized: "\(BatteryEstimator.label(hours: estimate.remainingHours)) left")
        } else if battery != nil {
            remaining = String(localized: "learning your battery life")
        } else {
            remaining = String(localized: "connect to read battery")
        }

        let chargingNote: String
        if live.charging == true {
            chargingNote = String(localized: "Live readings and recording continue while the battery pack charges.")
        } else if live.connected {
            chargingNote = String(localized: "NOOP keeps recording and syncs history in the background.")
        } else {
            chargingNote = String(localized: "Reconnect your band to update battery and history.")
        }

        let syncTag: String
        let lastSync: String
        if live.backfilling {
            syncTag = String(localized: "Syncing")
            lastSync = String(localized: "\(live.syncChunksThisSession) chunks pulled")
        } else if live.lastSyncError != nil {
            syncTag = String(localized: "Attention")
            lastSync = String(localized: "Sync needs retry")
        } else if let timestamp = live.lastSyncedAt {
            syncTag = live.connected ? String(localized: "Live") : String(localized: "Saved")
            lastSync = relativeAgo(timestamp, now: now)
        } else {
            syncTag = live.connected ? String(localized: "Live") : String(localized: "Offline")
            lastSync = String(localized: "Not synced yet")
        }

        let range = historyRange(live.strapRange)
        let variant = live.whoop5Variant.flatMap { $0 == "—" ? nil : $0 }
        let secureLink: String
        if live.encryptedBond {
            secureLink = String(localized: "Encrypted")
        } else if live.connected {
            secureLink = String(localized: "Live HR only")
        } else {
            secureLink = String(localized: "Not connected")
        }

        return AuraBandReading(
            batteryPercent: battery,
            remaining: remaining,
            chargingNote: chargingNote,
            syncTag: syncTag,
            lastSync: lastSync,
            historyTag: range == nil ? String(localized: "Waiting") : String(localized: "Recorded"),
            buffered: range ?? String(localized: "Waiting for band"),
            rows: [
                Row(id: "worn", key: String(localized: "On wrist"),
                    value: live.connected ? (live.worn ? String(localized: "Yes") : String(localized: "No")) : "—"),
                Row(id: "secure", key: String(localized: "Secure link"), value: secureLink),
                Row(id: "hardware", key: String(localized: "Hardware"),
                    value: variant.map { "WHOOP \($0)" }
                        ?? (live.connected ? String(localized: "Identifying…") : String(localized: "Waiting for band"))),
                Row(id: "firmware", key: String(localized: "Firmware"),
                    value: live.strapFirmware ?? String(localized: "Waiting for band")),
            ],
            canSync: live.connected && live.bonded && !live.backfilling,
            isSyncing: live.backfilling
        )
    }

    private static func historyRange(_ range: LiveState.StrapRange?) -> String? {
        guard let range, let oldest = range.oldestUnix, range.newestUnix > oldest else { return nil }
        let seconds = range.newestUnix - oldest
        if seconds < 3_600 { return String(localized: "\(max(1, seconds / 60)) min available") }
        if seconds < 86_400 { return String(localized: "\(seconds / 3_600) h available") }
        let days = Double(seconds) / 86_400
        return String(localized: "\(days.formatted(.number.precision(.fractionLength(1)))) days available")
    }

    static let prototype = AuraBandReading(
        batteryPercent: 62,
        remaining: String(localized: "about 2 days left"),
        chargingNote: String(localized: "Charging takes about 90 minutes. Wear it while you charge — the band keeps recording."),
        syncTag: String(localized: "Live"),
        lastSync: String(localized: "4 minutes ago"),
        historyTag: String(localized: "Recorded"),
        buffered: String(localized: "2 days buffered"),
        rows: [
            Row(id: "worn", key: String(localized: "Worn since"), value: String(localized: "6 days straight")),
            Row(id: "mode", key: String(localized: "Battery mode"), value: String(localized: "Standard")),
            Row(id: "strap", key: String(localized: "Strap"), value: String(localized: "Graphite knit")),
            Row(id: "firmware", key: String(localized: "Firmware"), value: String(localized: "Up to date")),
        ],
        canSync: true,
        isSyncing: false
    )
}
#endif
