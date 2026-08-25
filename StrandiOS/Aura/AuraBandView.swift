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
    let onSyncHealth: () -> Void

    init(
        reading: AuraBandReading? = nil,
        onManageDevices: @escaping () -> Void,
        onSync: @escaping () -> Void,
        onSyncHealth: @escaping () -> Void
    ) {
        self.reading = reading
        self.onManageDevices = onManageDevices
        self.onSync = onSync
        self.onSyncHealth = onSyncHealth
    }

    var body: some View {
        if let reading {
            AuraBandContent(reading: reading, onManageDevices: onManageDevices,
                            onSync: onSync, onSyncHealth: onSyncHealth)
        } else {
            AuraLiveBandContent(onManageDevices: onManageDevices, onSync: onSync,
                                onSyncHealth: onSyncHealth)
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
    let onSyncHealth: () -> Void

    var body: some View {
        AuraBandContent(
            reading: .live(live),
            onManageDevices: onManageDevices,
            onSync: onSync,
            onSyncHealth: onSyncHealth
        )
    }
}

private struct AuraBandContent: View {
    let reading: AuraBandReading
    let onManageDevices: () -> Void
    let onSync: () -> Void
    let onSyncHealth: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Your strap"))
                    .font(AuraFont.display(25, weight: .regular))
                    .tracking(-0.62)
                    .foregroundStyle(AuraPalette.textPrimary)
                Text(hardwareSubtitle)
                    .font(AuraFont.ui(13.5))
                    .foregroundStyle(AuraPalette.textTertiary)
            }

            strapCard
            healthCard
            unavailableControls
            supportRows

            Text(String(localized: "Only live device values and actions supported by this build are enabled. Unsupported firmware controls stay visibly unavailable."))
                .font(AuraFont.ui(11.5))
                .lineSpacing(4)
                .foregroundStyle(AuraPalette.textDim)
                .padding(.horizontal, 2)
        }
    }

    private var hardwareSubtitle: String {
        reading.rows.first(where: { $0.id == "hardware" })?.value
            ?? String(localized: "Waiting for band")
    }

    private var strapCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 18) {
                AuraCompactBatteryRing(
                    percent: reading.batteryPercent,
                    caption: reading.remaining
                )
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(reading.isConnected ? Color(hex: "#2ECC80") : AuraPalette.textDim)
                            .frame(width: 8, height: 8)
                            .shadow(color: reading.isConnected ? Color(hex: "#2ECC80").opacity(0.7) : .clear, radius: 5)
                        Text(reading.isConnected
                             ? String(localized: "Connected and reading")
                             : String(localized: "Disconnected"))
                            .font(AuraFont.ui(14, weight: .semibold))
                            .foregroundStyle(AuraPalette.textPrimary)
                    }
                    ForEach(reading.rows.filter { $0.id != "hardware" }.prefix(3)) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(row.key)
                                .font(AuraFont.ui(11.5))
                                .foregroundStyle(AuraPalette.textQuiet)
                            Spacer(minLength: 3)
                            Text(row.value)
                                .font(AuraFont.ui(11.5))
                                .foregroundStyle(AuraPalette.textSecondary)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: onSync) {
                HStack(spacing: 9) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                    Text(reading.isSyncing ? String(localized: "Syncing history…")
                                          : String(localized: "Sync now"))
                        .font(AuraFont.ui(15, weight: .semibold))
                }
                .foregroundStyle(reading.canSync ? AuraPalette.onAccent : AuraPalette.textQuiet)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(reading.canSync ? AuraPalette.accent : AuraPalette.controlFill))
            }
            .buttonStyle(.plain)
            .disabled(!reading.canSync)
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
        .padding(.bottom, 18)
        .auraCard(cornerRadius: 24)
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 11) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#E08A9B"))
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Apple Health"))
                        .font(AuraFont.ui(13.5, weight: .semibold))
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(String(localized: "Reads and writes only categories you authorize in iOS"))
                        .font(AuraFont.ui(11.5))
                        .foregroundStyle(AuraPalette.textQuiet)
                }
            }
            AuraHealthSyncButton(action: onSyncHealth)
            Text(String(localized: "Sleep, workouts, heart signals, respiration, oxygen, temperature, steps, energy, fitness, body measurements, and journal signals can be read or written where the app supports them and you grant access."))
                .font(AuraFont.ui(11))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textDim)
        }
        .padding(16)
        .auraCard()
    }

    private var unavailableControls: some View {
        VStack(spacing: 0) {
            unavailableRow("sensor.tag.radiowave.forward", String(localized: "Sensor controls"),
                           String(localized: "No supported firmware control path in this build"))
            unavailableRow("waveform", String(localized: "Buzz strength"),
                           String(localized: "One-shot find buzz is available in Manage straps"))
            unavailableRow("bell.and.waves.left.and.right", String(localized: "Phone notification mirroring"),
                           String(localized: "Coming soon"), divider: false)
        }
        .padding(.horizontal, 16)
        .auraCard()
    }

    private var supportRows: some View {
        VStack(spacing: 0) {
            AuraListRow(
                key: String(localized: "Strap log"),
                subtitle: String(localized: "Copy or save a timestamped diagnostic log"),
                showsDivider: true,
                action: onManageDevices
            )
            AuraListRow(
                key: String(localized: "Manage straps"),
                subtitle: String(localized: "Find, pair, switch, disconnect, or forget a band"),
                showsDivider: false,
                action: onManageDevices
            )
        }
        .padding(.horizontal, 16)
        .auraCard()
    }

    private func unavailableRow(
        _ symbol: String,
        _ title: String,
        _ subtitle: String,
        divider: Bool = true
    ) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(AuraPalette.textQuiet)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AuraFont.ui(13.5)).foregroundStyle(AuraPalette.textPrimary)
                Text(subtitle).font(AuraFont.ui(11.5)).foregroundStyle(AuraPalette.textQuiet)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(localized: "Coming soon"))
                .font(AuraFont.ui(10.5, weight: .semibold))
                .foregroundStyle(AuraPalette.textFaint)
        }
        .frame(minHeight: 66)
        .overlay(alignment: .bottom) {
            if divider { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5).padding(.leading, 35) }
        }
    }
}

private struct AuraCompactBatteryRing: View {
    let percent: Int?
    let caption: String

    private var tint: Color {
        guard let percent else { return AuraPalette.textQuiet }
        if percent <= 10 { return Color(hex: "#F0742C") }
        if percent <= 20 { return Color(hex: "#F2B45C") }
        return AuraPalette.accent
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 9)
            if let percent {
                Circle()
                    .trim(from: 0, to: Double(min(max(percent, 0), 100)) / 100)
                    .stroke(tint, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: tint.opacity(0.35), radius: 5)
            }
            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(percent.map(String.init) ?? "—")
                        .font(AuraFont.display(38, weight: .thin))
                        .tracking(-1.5)
                        .foregroundStyle(tint)
                        .monospacedDigit()
                    if percent != nil {
                        Text(verbatim: "%").font(AuraFont.ui(12)).foregroundStyle(AuraPalette.textLabel)
                    }
                }
                Text(caption)
                    .font(AuraFont.ui(9.5))
                    .foregroundStyle(AuraPalette.textQuiet)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 10)
        }
        .frame(width: 118, height: 118)
    }
}

/// HealthKit publishes only when authorization or a sync changes, so keeping it in this small leaf
/// avoids making the live Band screen own a second observable object.
private struct AuraHealthSyncButton: View {
    @EnvironmentObject private var health: HealthKitBridge
    let action: () -> Void

    private var unavailable: Bool {
        health.auth == .unavailable || health.auth == .entitlementMissing
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(health.syncing ? String(localized: "Syncing Apple Health…")
                                    : String(localized: "Sync Apple Health"))
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(unavailable ? AuraPalette.textQuiet : AuraPalette.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(AuraPalette.controlFill)
                    .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .strokeBorder(AuraPalette.cardBorder, lineWidth: 0.5))
            )
        }
        .buttonStyle(.plain)
        .disabled(unavailable || health.syncing)
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
    let isConnected: Bool
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
            chargingNote = String(localized: "Noop Aura keeps recording and syncs history in the background.")
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
            isConnected: live.connected,
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

    #if DEBUG
    static let prototype = AuraBandReading(
        batteryPercent: 62,
        isConnected: true,
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
    #endif
}
#endif
