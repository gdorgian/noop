#if os(iOS)
import SwiftUI
import PhotosUI
import UIKit
import StrandDesign

// MARK: - Aura detail navigation

enum AuraRoute: Hashable {
    case metric(String)
    case editProfile
    case notifications
    case units
    case export
    case more
    case tracking
    case privacy
    case settings
    case manageStraps
    case comingSoon(AuraUpcomingFeature)
    /// Body Age, Fitness Age and the VO₂max behind them. Reached from Trends, not the tab bar.
    case age

    #if DEBUG
    /// Direct-launch seam for simulator visual checks of routes that normally require a tap.
    static var debugLaunchRoute: AuraRoute? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--aura-route"),
              arguments.indices.contains(flag + 1) else { return nil }
        switch arguments[flag + 1] {
        case "heart-rate": return .metric("hr")
        case "variability": return .metric("hrv")
        case "breathing": return .metric("resp")
        case "sleep": return .metric("sleep")
        case "edit-profile": return .editProfile
        case "notifications": return .notifications
        case "units": return .units
        case "export": return .export
        case "more": return .more
        case "tracking": return .tracking
        case "privacy": return .privacy
        case "settings": return .settings
        case "manage-straps": return .manageStraps
        case "daytime-charge": return .comingSoon(.daytimeCharge)
        case "notification-mirroring": return .comingSoon(.notificationMirroring)
        case "aura-widgets": return .comingSoon(.widgets)
        case "goals-labs": return .comingSoon(.goalsAndLabs)
        case "svea-memory": return .comingSoon(.sveaMemory)
        case "body-clock": return .comingSoon(.bodyClock)
        case "age": return .age
        default: return nil
        }
    }
    #endif
}

/// Destinations present in the approved Aura information architecture whose underlying capability is not
/// implemented yet. Keeping their copy here prevents a prototype number or promise from leaking into a
/// placeholder screen.
enum AuraUpcomingFeature: String, Hashable, Identifiable, CaseIterable {
    case daytimeCharge
    case notificationMirroring
    case widgets
    case goalsAndLabs
    case sveaMemory
    case bodyClock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daytimeCharge: return String(localized: "Daytime Charge")
        case .notificationMirroring: return String(localized: "Phone notification mirroring")
        case .widgets: return String(localized: "Aura widgets")
        case .goalsAndLabs: return String(localized: "Goal journeys and lab interpretation")
        case .sveaMemory: return String(localized: "Svea memory review")
        case .bodyClock: return String(localized: "Body clock")
        }
    }

    var symbol: String {
        switch self {
        case .daytimeCharge: return "battery.75percent"
        case .notificationMirroring: return "bell.and.waves.left.and.right"
        case .widgets: return "rectangle.3.group"
        case .goalsAndLabs: return "target"
        case .sveaMemory: return "brain.head.profile"
        case .bodyClock: return "clock.arrow.circlepath"
        }
    }

    var summary: String {
        switch self {
        case .daytimeCharge:
            return String(localized: "A daytime Charge model is planned. It will not replace morning Charge until its data, validation and missing-data rules are defined.")
        case .notificationMirroring:
            return String(localized: "A supported iOS and strap-firmware path is still being investigated. No phone-notification mirroring is active in this build.")
        case .widgets:
            return String(localized: "New Aura layouts for Charge and last night, backed only by the most recent completed sync.")
        case .goalsAndLabs:
            return String(localized: "New goal journeys, OCR-confidence review and evidence-backed lab visuals. The existing local Lab Book remains available in More.")
        case .sveaMemory:
            return String(localized: "A redesigned purpose-by-purpose view of coach consent and memory. Existing Coach controls remain available in More.")
        case .bodyClock:
            return String(localized: "A 24-hour view built from recorded sleep timing once its baseline and missing-data rules are final.")
        }
    }
}

struct AuraComingSoonView: View {
    let feature: AuraUpcomingFeature

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: feature.symbol)
                    .font(.system(size: 25, weight: .regular))
                    .foregroundStyle(AuraPalette.accent)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(AuraPalette.accent.opacity(0.12)))

                Text(String(localized: "Coming soon"))
                    .font(.system(size: 24, weight: .regular, design: .rounded))
                    .foregroundStyle(AuraPalette.textPrimary)

                Text(feature.summary)
                    .font(.system(size: 14))
                    .lineSpacing(3)
                    .foregroundStyle(AuraPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .auraCard(surface: AuraCardSurface.coaching(accent: AuraPalette.accent))

            AuraNoteBanner(
                text: String(localized: "This Aura feature is not active in this build. Existing underlying data and tools remain available where noted; this screen shows no substitute or preview value."),
                tint: AuraPalette.rest
            )
        }
    }
}

/// Full-screen detail chrome shared by every route that hangs off Aura. It deliberately keeps Aura's
/// canvas and spacing while providing a conventional 44-point back target and an explicit page title.
struct AuraDetailScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    let onBack: () -> Void
    @ViewBuilder let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        onBack: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.content = content()
    }

    var body: some View {
        ZStack {
            AuraPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AuraPalette.cardGap) {
                    Button(action: onBack) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text(String(localized: "Back"))
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(AuraPalette.accent)
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(title)
                            .font(.system(size: 30, weight: .regular, design: .rounded))
                            .foregroundStyle(AuraPalette.textPrimary)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 13.5))
                                .lineSpacing(2)
                                .foregroundStyle(AuraPalette.textQuiet)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.bottom, 10)

                    content
                    Color.clear.frame(height: 28)
                }
                .padding(.horizontal, AuraPalette.screenPadding)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Shared Aura controls

struct AuraProfilePhoto: View {
    @EnvironmentObject private var profile: ProfileStore
    let size: CGFloat

    var body: some View {
        ProfileAvatarView(
            imageData: profile.avatarImageData,
            size: size,
            fallbackTint: AuraPalette.textSecondary
        )
        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
    }
}

private struct AuraActionButton: View {
    let title: String
    let symbol: String
    var tint: Color = AuraPalette.accent
    var destructive = false
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(disabled ? AuraPalette.textDim : (destructive ? Color(hex: "#F18A79") : tint))
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AuraPalette.controlFill)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AuraPalette.cardBorder, lineWidth: 0.5))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

// MARK: - Metric detail

struct AuraMetricDetailView: View {
    let signal: AuraTodayReading.Signal
    @State private var selectedPoint: Int?

    init(signal: AuraTodayReading.Signal) {
        self.signal = signal
        _selectedPoint = State(initialValue: nil)
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            hero
            trendCard
            HStack(spacing: 8) {
                AuraStatTile(label: String(localized: "Recent average"), value: average, unit: signal.unit,
                             valueTint: signal.tint)
                AuraStatTile(label: String(localized: "Recent range"), value: range, unit: signal.unit)
            }
            AuraNoteBanner(text: explanation, tint: signal.tint)
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            Image(systemName: signal.systemImage)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(signal.tint)
                .frame(width: 42, height: 42)
                .background(Circle().fill(signal.tint.opacity(0.14)))
            if signal.id == "hr" {
                AuraLiveHeartRateHero(fallback: signal.value, unit: signal.unit)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(signal.value)
                        .font(.system(size: 52, weight: .ultraLight, design: .rounded).monospacedDigit())
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(signal.unit)
                        .font(.system(size: 15))
                        .foregroundStyle(AuraPalette.textQuiet)
                }
                Text(heroCaption)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AuraPalette.textQuiet)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .auraCard(cornerRadius: 26)
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            AuraCardHeader(title: trendTitle, note: String(localized: "Tap or drag"))
            if signal.series.isEmpty {
                Text(String(localized: "No readings in this period yet."))
                    .font(.system(size: 13.5))
                    .foregroundStyle(AuraPalette.textQuiet)
                    .frame(maxWidth: .infinity, minHeight: 140, alignment: .center)
            } else {
                AuraTrendChart(
                    values: signal.series,
                    labels: labels,
                    selected: selectedIndex,
                    window: chartWindow,
                    normalRange: nil
                ) { selectedPoint = $0 }
                HStack {
                    Text(labels.first ?? "")
                    Spacer()
                    Text(labels.last ?? "")
                }
                .font(.system(size: 10.5))
                .foregroundStyle(AuraPalette.textDim)
            }
        }
        .padding(18)
        .auraCard()
    }

    private var labels: [String] {
        signal.labels.count == signal.series.count
            ? signal.labels
            : signal.series.indices.map { String(localized: "Reading \($0 + 1)") }
    }

    private var selectedIndex: Int {
        guard let selectedPoint, signal.series.indices.contains(selectedPoint) else {
            return max(signal.series.count - 1, 0)
        }
        return selectedPoint
    }

    private var chartWindow: ClosedRange<Double> {
        guard let lo = signal.series.min(), let hi = signal.series.max() else { return 0...100 }
        let pad = max((hi - lo) * 0.2, signal.id == "resp" ? 0.5 : 1)
        return (lo - pad)...(hi + pad)
    }

    private var average: String {
        guard !signal.series.isEmpty else { return "—" }
        let value = signal.series.reduce(0, +) / Double(signal.series.count)
        return signal.id == "resp" || signal.id == "sleep"
            ? String(format: "%.1f", value)
            : String(format: "%.0f", value)
    }

    private var range: String {
        guard let lo = signal.series.min(), let hi = signal.series.max() else { return "—" }
        let f = signal.id == "resp" || signal.id == "sleep" ? "%.1f" : "%.0f"
        return "\(String(format: f, lo))–\(String(format: f, hi))"
    }

    private var heroCaption: String {
        switch signal.id {
        case "hr": return String(localized: "Heart rate")
        case "hrv": return String(localized: "Latest valid nightly reading")
        case "resp": return String(localized: "Latest valid nightly estimate")
        case "sleep": return String(localized: "Main sleep from your latest night")
        default: return String(localized: "Latest reading")
        }
    }

    private var trendTitle: String {
        signal.id == "hr" ? String(localized: "Resting heart rate · recent nights")
                          : String(localized: "Recent readings")
    }

    private var explanation: String {
        switch signal.id {
        case "hr":
            return String(localized: "When the strap is connected, the large number is measured live heart rate. Otherwise it shows the latest valid nightly resting heart rate. The chart uses one resting-heart-rate value per valid night.")
        case "hrv":
            return String(localized: "Variability is Noop Aura's nightly HRV estimate. Compare it with your own baseline and direction, not another person's number.")
        case "resp":
            return String(localized: "Breathing is estimated from respiratory sinus arrhythmia in clean R–R data. Noop Aura leaves it blank when beat integrity is not good enough instead of inventing a rate.")
        case "sleep":
            return String(localized: "This is asleep time, not simply time in bed. Open Rest for the stage timeline, sleep window and debt ledger.")
        default:
            return String(localized: "This view uses your locally stored Noop Aura history.")
        }
    }
}

private struct AuraLiveHeartRateHero: View {
    @EnvironmentObject private var model: AppModel
    let fallback: String
    let unit: String

    private var liveBPM: Int? {
        model.live.connected ? (model.bpm ?? model.live.heartRate) : nil
    }

    private var caption: String {
        if liveBPM != nil { return String(localized: "Live from your connected strap") }
        if model.live.connected {
            return fallback == "—"
                ? String(localized: "Waiting for the first live heart-rate sample")
                : String(localized: "Waiting for a live sample · latest nightly resting heart rate shown")
        }
        return fallback == "—"
            ? String(localized: "Strap disconnected · no nightly resting heart rate yet")
            : String(localized: "Strap disconnected · latest nightly resting heart rate shown")
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(liveBPM.map(String.init) ?? fallback)
                    .font(.system(size: 52, weight: .ultraLight, design: .rounded).monospacedDigit())
                    .foregroundStyle(AuraPalette.textPrimary)
                Text(unit)
                    .font(.system(size: 15))
                    .foregroundStyle(AuraPalette.textQuiet)
            }
            Text(caption)
                .font(.system(size: 12.5))
                .foregroundStyle(AuraPalette.textQuiet)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Profile editor

struct AuraProfileEditorView: View {
    @EnvironmentObject private var profile: ProfileStore
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        let hasAvatar = profile.hasAvatar
        VStack(spacing: AuraPalette.cardGap) {
            VStack(spacing: 16) {
                AuraProfilePhoto(size: 104)
                HStack(spacing: 8) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(hasAvatar ? String(localized: "Change photo") : String(localized: "Choose photo"),
                              systemImage: "photo")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AuraPalette.accent)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 15).fill(AuraPalette.controlFill))
                    }
                    if hasAvatar {
                        Button { profile.clearAvatar() } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color(hex: "#F18A79"))
                                .frame(width: 48, height: 48)
                                .background(RoundedRectangle(cornerRadius: 15).fill(AuraPalette.controlFill))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Remove photo"))
                    }
                }
                Text(String(localized: "Your photo is stored locally by Noop Aura. It is not included in Noop Aura backups or sent to Coach providers."))
                    .font(.system(size: 12))
                    .foregroundStyle(AuraPalette.textQuiet)
            }
            .padding(18)
            .auraCard()

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Display name")).auraOverline()
                TextField(String(localized: "Your name"), text: $profile.name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .font(.system(size: 17))
                    .foregroundStyle(AuraPalette.textPrimary)
                    .tint(AuraPalette.accent)
                    .padding(.horizontal, 15)
                    .frame(minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AuraPalette.controlFill))
                Text(String(localized: "Used only for your profile. Your health calculations do not depend on it."))
                    .font(.system(size: 12))
                    .foregroundStyle(AuraPalette.textQuiet)
            }
            .padding(18)
            .auraCard()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                await MainActor.run {
                    if let data { profile.setAvatar(data) }
                    photoItem = nil
                }
            }
        }
    }
}

// MARK: - Notifications

struct AuraNotificationsView: View {
    enum Sheet: String, Identifiable { case alarms, automations; var id: String { rawValue } }
    @AppStorage(UnitPrefs.liveActivityKey) private var liveActivity = true
    @State private var sheet: Sheet?
    @Environment(\.openURL) private var openURL
    let onOpenMirroring: () -> Void

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $liveActivity) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Live heart rate"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AuraPalette.textPrimary)
                        Text(String(localized: "Dynamic Island and Lock Screen while your strap is connected"))
                            .font(.system(size: 11.5))
                            .foregroundStyle(AuraPalette.textQuiet)
                    }
                }
                .toggleStyle(.switch)
                .tint(AuraPalette.accent)
            }
            .padding(18)
            .auraCard()

            VStack(spacing: 0) {
                AuraListRow(key: String(localized: "Phone notification mirroring"),
                            value: String(localized: "Coming soon"),
                            subtitle: String(localized: "iOS and strap-firmware feasibility under review"),
                            showsDivider: true,
                            action: onOpenMirroring)
                AuraListRow(key: String(localized: "Wind-down & alarms"),
                            subtitle: String(localized: "Sleep schedule and evening reminder"),
                            showsDivider: true) { sheet = .alarms }
                AuraListRow(key: String(localized: "Automation alerts"),
                            subtitle: String(localized: "Movement, battery and strap haptics"),
                            showsDivider: true) { sheet = .automations }
                AuraListRow(key: String(localized: "iOS notification permission"),
                            subtitle: String(localized: "Open this app's system settings"),
                            showsDivider: false) {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
            }
            .padding(.horizontal, 17)
            .auraCard()
        }
        .sheet(item: $sheet) { destination in
            NavigationStack {
                Group {
                    switch destination {
                    case .alarms: SmartAlarmView()
                    case .automations: AutomationsView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { sheet = nil }
                    }
                }
            }
        }
    }
}

// MARK: - Units

struct AuraUnitsView: View {
    @AppStorage(UnitPrefs.systemKey) private var systemRaw = UnitSystem.metric.rawValue
    @AppStorage(UnitPrefs.temperatureKey) private var temperatureRaw = ""
    @AppStorage(UnitPrefs.effortScaleKey) private var effortRaw = EffortScale.hundred.rawValue

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            pickerCard(title: String(localized: "Distance & weight")) {
                Picker("Distance and weight", selection: $systemRaw) {
                    Text("Metric").tag(UnitSystem.metric.rawValue)
                    Text("Imperial").tag(UnitSystem.imperial.rawValue)
                }
                .pickerStyle(.segmented)
            }
            pickerCard(title: String(localized: "Temperature")) {
                Picker("Temperature", selection: $temperatureRaw) {
                    Text("Automatic").tag("")
                    Text("°C").tag(TemperatureUnit.celsius.rawValue)
                    Text("°F").tag(TemperatureUnit.fahrenheit.rawValue)
                }
                .pickerStyle(.segmented)
            }
            pickerCard(title: String(localized: "Effort scale")) {
                Picker("Effort scale", selection: $effortRaw) {
                    Text("0–100").tag(EffortScale.hundred.rawValue)
                    Text("WHOOP 0–21").tag(EffortScale.whoop.rawValue)
                }
                .pickerStyle(.segmented)
            }
            AuraNoteBanner(
                text: String(localized: "These are display choices only. Noop Aura keeps the stored measurements unchanged."),
                tint: AuraPalette.rest
            )
        }
    }

    private func pickerCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title).auraOverline()
            content().tint(AuraPalette.accent)
        }
        .padding(18)
        .auraCard()
    }
}

// MARK: - Export and data destinations

struct AuraExportView: View {
    enum Sheet: String, Identifiable { case health, backup, sources, shortcuts; var id: String { rawValue } }
    @EnvironmentObject private var health: HealthKitBridge
    @State private var sheet: Sheet?

    private var healthSubtitle: String {
        switch health.auth {
        case .authorized:
            return String(localized: "Native Apple Health bridge · permissions set in Health")
        case .denied:
            return String(localized: "Permission not granted · review Apple Health")
        case .unknown:
            return String(localized: "Enable Apple Health to allow native sync")
        case .entitlementMissing:
            return String(localized: "Native access unavailable in this signing build")
        case .unavailable:
            return String(localized: "Apple Health is unavailable on this device")
        }
    }

    private var healthDestination: Sheet {
        switch health.auth {
        case .entitlementMissing, .unavailable: return .shortcuts
        default: return .health
        }
    }

    private var healthNote: String {
        switch health.auth {
        case .authorized:
            return String(localized: "This build supports native Apple Health. Noop Aura attempts its supported Health records, and iOS decides which writes succeed from your permissions; Shortcuts Export remains optional.")
        case .denied:
            return String(localized: "Noop Aura can write supported data after you grant Apple Health permission. Nothing is written while access is denied.")
        case .unknown:
            return String(localized: "Apple Health has not been enabled. Noop Aura writes nothing there unless you grant permission.")
        case .entitlementMissing:
            return String(localized: "This signing build cannot use native HealthKit. Shortcuts Export can send heart rate, HRV and steps after you enable and run it.")
        case .unavailable:
            return String(localized: "Native Apple Health is unavailable on this device. Shortcuts Export is available where the Shortcuts and Health apps are supported.")
        }
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            VStack(spacing: 0) {
                AuraListRow(key: String(localized: "Apple Health"),
                            subtitle: healthSubtitle,
                            showsDivider: true) { sheet = healthDestination }
                AuraListRow(key: String(localized: "Backup & Sync"),
                            subtitle: String(localized: "Biometric database backup, restore and folder sync"),
                            showsDivider: true) { sheet = .backup }
                AuraListRow(key: String(localized: "Import & data sources"),
                            subtitle: String(localized: "WHOOP, Mi Band, Apple Health and other exports"),
                            showsDivider: true) { sheet = .sources }
                AuraListRow(key: String(localized: "Shortcuts Export"),
                            subtitle: String(localized: "Fallback for builds without native HealthKit"),
                            showsDivider: false) { sheet = .shortcuts }
            }
            .padding(.horizontal, 17)
            .auraCard()

            AuraNoteBanner(
                text: healthNote,
                tint: AuraPalette.accent
            )
        }
        .sheet(item: $sheet) { destination in
            NavigationStack {
                Group {
                    switch destination {
                    case .health: AppleHealthView()
                    case .backup: BackupSyncView()
                    case .sources: DataSourcesView()
                    case .shortcuts: ShortcutExportSettingsView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { sheet = nil } }
                }
            }
        }
    }
}

// MARK: - Tracking and privacy

struct AuraTrackingView: View {
    @EnvironmentObject private var health: HealthKitBridge
    @State private var showLimitations = false

    private var appleHealthCard: (title: String, rows: [(String, String, String)]) {
        switch health.auth {
        case .authorized:
            return (
                String(localized: "Supported by native Apple Health"),
                [
                    (String(localized: "Heart rate, resting HR and HRV"), String(localized: "Supported"), "heart.text.square.fill"),
                    (String(localized: "Sleep stages and workouts"), String(localized: "Supported"), "bed.double.fill"),
                    (String(localized: "Breathing when integrity passes"), String(localized: "Conditional"), "checkmark.shield.fill"),
                ])
        case .unknown, .denied:
            return (
                String(localized: "Can write to Apple Health"),
                [
                    (String(localized: "Heart rate, resting HR and HRV"), String(localized: "With permission"), "heart.text.square.fill"),
                    (String(localized: "Sleep stages and workouts"), String(localized: "With permission"), "bed.double.fill"),
                    (String(localized: "Breathing when integrity passes"), String(localized: "Conditional"), "checkmark.shield.fill"),
                ])
        case .entitlementMissing:
            return (
                String(localized: "Available through Shortcuts Export"),
                [
                    (String(localized: "Heart rate and HRV"), String(localized: "15-minute windows"), "heart.text.square.fill"),
                    (String(localized: "Steps"), String(localized: "15-minute windows"), "figure.walk"),
                    (String(localized: "Sleep, workouts and breathing"), String(localized: "Not exported"), "xmark.shield"),
                ])
        case .unavailable:
            return (
                String(localized: "Apple Health unavailable"),
                [
                    (String(localized: "Native Apple Health sync"), String(localized: "Unavailable"), "heart.text.square.fill"),
                    (String(localized: "Shortcuts Export"), String(localized: "Check device support"), "square.and.arrow.up"),
                ])
        }
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            trackingCard(
                title: String(localized: "Read from WHOOP 5.0"),
                rows: [
                    (String(localized: "Live heart rate"), String(localized: "Live"), "heart.fill"),
                    (String(localized: "R–R intervals"), String(localized: "Live"), "waveform.path.ecg"),
                    (String(localized: "Motion, battery and skin temperature"), String(localized: "Recorded"), "sensor.tag.radiowave.forward"),
                ]
            )
            trackingCard(
                title: String(localized: "Computed on iPhone"),
                rows: [
                    (String(localized: "Charge, Effort and Rest"), String(localized: "Personal"), "figure.mind.and.body"),
                    (String(localized: "Sleep stages and nightly HRV"), String(localized: "Estimated"), "moon.stars.fill"),
                    (String(localized: "Breathing from clean R–R data"), String(localized: "Estimated"), "lungs.fill"),
                ]
            )
            trackingCard(title: appleHealthCard.title, rows: appleHealthCard.rows)
            AuraActionButton(title: String(localized: "Open Noop Aura limitations"),
                             symbol: "list.bullet.rectangle") { showLimitations = true }
        }
        .sheet(isPresented: $showLimitations) {
            NavigationStack {
                NoopLimitationsView()
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showLimitations = false } } }
            }
        }
    }

    private func trackingCard(title: String, rows: [(String, String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).auraOverline()
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 11) {
                    Image(systemName: row.2)
                        .foregroundStyle(AuraPalette.accent)
                        .frame(width: 21)
                    Text(row.0)
                        .font(.system(size: 13.5))
                        .foregroundStyle(AuraPalette.textPrimary)
                    Spacer(minLength: 8)
                    Text(row.1)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(AuraPalette.textQuiet)
                }
                .frame(minHeight: 42)
                if index < rows.count - 1 { Rectangle().fill(AuraPalette.cardBorder).frame(height: 0.5) }
            }
        }
        .padding(18)
        .auraCard()
    }
}

struct AuraPrivacyView: View {
    @Environment(\.openURL) private var openURL
    @State private var showHealth = false

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            privacyCard(symbol: "iphone", title: String(localized: "On this iPhone"),
                        text: String(localized: "WHOOP history, profile details, your photo and computed scores are stored locally by default. Data leaves Noop Aura only through destinations you enable, such as exports, backups, Apple Health or a Coach provider; the photo is not included in Noop Aura backups or Coach requests."))
            privacyCard(symbol: "heart.text.square", title: String(localized: "Apple Health"),
                        text: String(localized: "Apple Health controls access by data type. Noop Aura reads and writes through HealthKit only after you enable the connection, and iOS applies your permissions."))
            privacyCard(symbol: "icloud.slash", title: String(localized: "No Noop Aura cloud"),
                        text: String(localized: "Noop Aura has no account server. A backup reaches iCloud, Drive or Dropbox only when you choose a folder managed by that service."))
            privacyCard(symbol: "bubble.left.and.text.bubble.right", title: String(localized: "Coach providers"),
                        text: String(localized: "If you configure the Coach, messages and the data categories you consent to can be sent to your selected provider. Opt-in proactive summaries may contact that provider in the background. Local endpoints are also supported."))
            AuraActionButton(title: String(localized: "Review Apple Health"), symbol: "heart.fill") { showHealth = true }
            AuraActionButton(title: String(localized: "Open iOS app settings"), symbol: "gearshape") {
                openURL(URL(string: UIApplication.openSettingsURLString)!)
            }
        }
        .sheet(isPresented: $showHealth) {
            NavigationStack {
                AppleHealthView()
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showHealth = false } } }
            }
        }
    }

    private func privacyCard(symbol: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16))
                .foregroundStyle(AuraPalette.accent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(AuraPalette.accent.opacity(0.13)))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(AuraPalette.textPrimary)
                Text(text).font(.system(size: 12.5)).lineSpacing(2).foregroundStyle(AuraPalette.textQuiet)
            }
        }
        .padding(18)
        .auraCard()
    }
}

// MARK: - Aura settings and tools indexes

struct AuraSettingsIndexView: View {
    let onOpenNotifications: () -> Void
    let onOpenUnits: () -> Void
    let onOpenExport: () -> Void
    let onOpenTracking: () -> Void
    let onOpenPrivacy: () -> Void
    let onOpenWidgets: () -> Void
    let onOpenAdvanced: () -> Void

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            VStack(spacing: 0) {
                AuraListRow(key: String(localized: "Notifications"), subtitle: String(localized: "Dynamic Island, reminders and alerts"), showsDivider: true, action: onOpenNotifications)
                AuraListRow(key: String(localized: "Aura widgets"), value: String(localized: "Coming soon"), subtitle: String(localized: "New Charge and last-night layouts"), showsDivider: true, action: onOpenWidgets)
                AuraListRow(key: String(localized: "Units"), subtitle: String(localized: "Metric, temperature and Effort scale"), showsDivider: true, action: onOpenUnits)
                AuraListRow(key: String(localized: "Export data"), subtitle: String(localized: "Apple Health, backup and imports"), showsDivider: true, action: onOpenExport)
                AuraListRow(key: String(localized: "What Noop Aura tracks"), subtitle: String(localized: "Direct signals, estimates and Health output"), showsDivider: true, action: onOpenTracking)
                AuraListRow(key: String(localized: "Privacy"), subtitle: String(localized: "Storage and system permissions"), showsDivider: false, action: onOpenPrivacy)
            }
            .padding(.horizontal, 17)
            .auraCard()
            AuraActionButton(title: String(localized: "Advanced Noop Aura settings"), symbol: "slider.horizontal.3", tint: AuraPalette.textSecondary, action: onOpenAdvanced)
        }
    }
}

struct AuraMoreView: View {
    let onOpenAllTools: () -> Void

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            VStack(spacing: 0) {
                AuraListRow(key: String(localized: "Live & workouts"), value: String(localized: "Body"), showsDivider: true)
                AuraListRow(key: String(localized: "Coach, insights & journal"), value: String(localized: "Guidance"), showsDivider: true)
                AuraListRow(key: String(localized: "Health, Mi Band & data sources"), value: String(localized: "Data"), showsDivider: true)
                AuraListRow(key: String(localized: "Lab Book, Test Centre & experiments"), value: String(localized: "Advanced"), showsDivider: false)
            }
            .padding(.horizontal, 17)
            .auraCard()
            AuraActionButton(title: String(localized: "Open all Noop Aura tools"), symbol: "square.grid.2x2", action: onOpenAllTools)
            AuraNoteBanner(text: String(localized: "These tools still use the original screens. The Aura index keeps every capability reachable while those deeper surfaces are redesigned one by one."), tint: AuraPalette.accent)
        }
    }
}

// MARK: - WHOOP 5 strap management

struct AuraManageStrapsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState
    let onOpenDeviceManager: () -> Void
    @State private var copied = false

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            VStack(alignment: .leading, spacing: 14) {
                AuraCardHeader(title: String(localized: "WHOOP 5.0 / MG"),
                               note: live.connected ? String(localized: "Connected") : String(localized: "Offline"),
                               noteTint: live.connected ? AuraPalette.accent : AuraPalette.textQuiet,
                               symbol: "sensor.tag.radiowave.forward",
                               symbolTint: AuraPalette.accent)
                AuraListRow(key: String(localized: "Secure link"), value: live.encryptedBond ? String(localized: "Encrypted") : "—", showsDivider: true)
                AuraListRow(key: String(localized: "Firmware"), value: live.strapFirmware ?? "—", showsDivider: true)
                AuraListRow(
                    key: String(localized: "Battery"),
                    value: live.connected ? (live.batteryPct.map { "\(Int($0.rounded()))%" } ?? "—") : "—",
                    showsDivider: false)
            }
            .padding(18)
            .auraCard()

            VStack(spacing: 8) {
                AuraActionButton(title: String(localized: "Re-scan for WHOOP 5"), symbol: "arrow.clockwise") {
                    model.scan(model: .whoop5mg)
                }
                AuraActionButton(title: String(localized: "Buzz strap"), symbol: "wave.3.right", disabled: !live.connected || !live.bonded) {
                    model.buzzStrapOnce()
                }
                AuraActionButton(title: String(localized: "Disconnect"), symbol: "xmark.circle", destructive: true,
                                 disabled: !live.connected && !live.bonded) {
                    model.disconnect()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(String(localized: "Strap log")).auraOverline()
                HStack(spacing: 8) {
                    AuraActionButton(title: copied ? String(localized: "Copied") : String(localized: "Copy"), symbol: "doc.on.doc") {
                        PlatformPasteboard.copy(live.exportableLogText())
                        copied = true
                    }
                    AuraActionButton(title: String(localized: "Save…"), symbol: "square.and.arrow.up") {
                        Task {
                            let extra = await DebugDataDiagnostics.dynamicLines(repo: model.repo)
                            FileExport.exportText(
                                live.exportableLogText(extraHeaderLines: extra),
                                suggestedName: FileExport.timestampedName("noop-strap-log", ext: "txt")
                            )
                        }
                    }
                }
                Text(String(localized: "Share this log when a sync or protocol reading looks wrong."))
                    .font(.system(size: 12))
                    .foregroundStyle(AuraPalette.textQuiet)
            }
            .padding(18)
            .auraCard()

            AuraActionButton(title: String(localized: "Pair, switch or forget a strap"), symbol: "link.badge.plus", action: onOpenDeviceManager)
        }
    }
}
#endif
