import Foundation
import SwiftUI
import UIKit
import UserNotifications
import PhotosUI
import StrandAnalytics
import StrandDesign
import WhoopStore

// MARK: - Act 5 · You and the plumbing

struct NoopAct5Screens: View {
    @ObservedObject var navigation: NoopNavigation
    /// The production shell's measured hub record. Nil only in the seeded Debug shell.
    var you: NoopYouRecord? = nil
    var battery: Int? = nil
    /// The production shell's history list; read only when `you` is set.
    var history: NoopHistoryRecord? = nil
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState
    @EnvironmentObject private var coach: AICoachEngine
    @EnvironmentObject private var profile: ProfileStore
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    /// The same gate Energy uses: until the wearer confirms them, the profile's starting values are
    /// examples and are not printed as theirs.
    @AppStorage("noop.energy.profileConfirmed") private var profileConfirmed = false
    @EnvironmentObject private var behavior: BehaviorStore

    // The app's real settings, bound in the production shell. Defaults match the classic Settings
    // screen's, so an unset key reads here exactly as it does everywhere else in the app.
    @AppStorage(UnitPrefs.temperatureKey) private var temperatureRaw = ""
    @AppStorage(UnitPrefs.effortScaleKey) private var effortScaleRaw = ""
    @AppStorage(QuietMotionPrefs.enabledKey) private var quietMotionOn = false
    @AppStorage(UnitPrefs.liveActivityKey) private var liveActivityOn = true
    @AppStorage(PuffinExperiment.powerSavingKey) private var powerSavingOn = false
    @AppStorage(PuffinExperiment.powerSavingBatteryPctKey) private var powerSavingPct = 20
    @AppStorage(PuffinExperiment.pauseHrvDisabledKey) private var pauseHrvDisabled = false
    @AppStorage(PuffinExperiment.autoDetectWorkoutsKey) private var autoDetectOn = false
    @AppStorage(PuffinExperiment.journalReminderKey) private var journalReminderOn = true
    @AppStorage("workoutKeepScreenOn") private var keepScreenOn = false
    @AppStorage(UnitPrefs.liftLiveActivityKey) private var liftActivityOn = true
    @AppStorage("notif.quietHoursEnabled") private var quietHoursOn = false
    @AppStorage("inactivity.enabled") private var inactivityOn = false
    @AppStorage(PuffinExperiment.experimentalSleepV2Key) private var sleepV2On = true
    @AppStorage(PuffinExperiment.motionAwareWakeKey) private var motionAwareWakeOn = false
    @AppStorage(PuffinExperiment.keepRealtimeForDataKey) private var continuousHrvOn = false
    @AppStorage(PuffinExperiment.continuousHrvOvernightOnlyKey) private var hrvOvernightOnly = true
    @AppStorage(PuffinExperiment.spo2CandidateDisplayKey) private var spo2EstimateOn = false
    @AppStorage(PuffinFrameRecorder.enabledKey) private var frameRecorderOn = false

    @AppStorage(PuffinExperiment.deepDataKey) private var deepDataEnabled = false
    @AppStorage(PuffinExperiment.broadcastHrKey) private var broadcastHrEnabled = false
    @AppStorage(PuffinExperiment.ecgRawDataKey) private var ecgRawDataEnabled = false
    @AppStorage(SleepNeedPrefs.key) private var sleepNeedUserMinutes = 0
    @State private var choosingSleepNeed = false

    @SceneStorage("noop.act5.history-filter") private var historyFilter = "All"
    @State private var openZone: Int?
    @State private var hasPhoto = false
    @State private var photoItem: PhotosPickerItem?
    @State private var confirmingProfile = false
    @State private var dailyLogOn = ScheduledDebugExport.isEnabled
    @EnvironmentObject private var health: HealthKitBridge
    @State private var sex = "Male"
    @State private var birthDay = 12
    @State private var birthMonth = 1
    @State private var birthYear = 1997
    @State private var height = 178
    @State private var weight = 74.0
    @State private var waist = 0
    @State private var maximumHeartRate = 186
    @State private var stepScale = 1.0

    @State private var connected = true
    @State private var syncStage = 0
    @State private var healthSyncStage = 0
    @State private var buzz = "Normal"
    @State private var enabled: Set<String> = [
        "Continuous pulse", "Temperature", "Blood oxygen", "Stay connected in the background",
        "Apple Health", "Bedtime nudge", "Session offer", "Battery alerts", "Off-wrist reminder", "Sync reminder", "Journal reminder",
        "Day-cycle sky", "Sky behind cards", "Pause the HRV stream when low", "Sleep staging V2",
        "Overnight only", "Messages", "Phone calls", "Calendar", "WhatsApp", "Reminders",
        "Only when the phone is locked", "Follow iPhone Focus", "Hold them during quiet hours",
        "Quiet hours", "Live heart rate in the Dynamic Island", "Illness early warning",
        "Buzz if I go over"
    ]
    @State private var lastLogAction: String?
    @State private var pinged = false
    @State private var notificationBuzz = "Two short"
    @State private var healthAccessFixed = false
    @State private var ceilingMode = "Profile zone"
    @State private var ceilingZone = "Zone 4"
    @State private var ceilingBPM = 162

    @State private var sparePresent = true
    @State private var activeDevice = "mg"
    @State private var spareName = "WHOOP 4.0"
    @State private var renameDraft = ""
    @State private var deviceNotice: String?

    @State private var preferences: [String: String] = [
        "Units": "Metric", "Temperature": "°C", "Effort": "0–100", "Appearance": "Dark",
        "Chart colours": "Titanium", "Sleep chart": "Hypnogram", "Card surface": "Frosted",
        "App icon": "Aura", "Power saving at": "20%", "Double tap": "Sleep mark",
        "Language": "English", "Svea’s manner": "Plain"
    ]
    @State private var baselinesRestarting = false
    @State var showRhythm = false
    @State var showHevy = false
    @State private var settingsGlowID: String?
    /// The not-yet option whose explanation is open.
    @State private var pendingOption: NoopPendingOption?
    @State private var settingsEntered = false
    @State private var confirmingSettingsReset = false
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    /// iOS notification permission, read when Notifications opens and again on return from iOS Settings.
    @State private var notificationAuth: UNAuthorizationStatus?
    @State private var actionNotice: String?
    @State private var labExportBusy = false
    @State private var showPhasePicker = false
    @State private var showTestCentre = false
    /// One request to the Aura release page, only when the wearer taps Check for updates.
    @StateObject private var updates = UpdateChecker()
    @State private var showReleaseNotes = false
    @State private var selectedAppIcon = NoopAppIconChoice.current

    @State private var selectedShift: String?
    @State private var paired = false
    @State private var labFlagToClear: String?
    @StateObject var youLayout = NoopPageLayout(page: "you", catalog: NoopAct5Screens.youSections)
    @State var youEditing = NoopPageEditing()

    var body: some View {
        Group {
            switch navigation.route {
            case .record: recordScreen
            case .zones: NoopZonesScreen(navigation: navigation, zones: model.personalZones)
            case .history: historyScreen
            case .strap: strapScreen
            case .notifs: notificationsScreen
            case .devices: devicesScreen
            case .apple: appleHealthScreen
            case .data, .importHistory, .reading, .imported, .rejected, .backup:
                NoopDataScreen(navigation: navigation)
            case .settings: settingsScreen
            case .settingsToday, .settingsSleep, .settingsFitness, .settingsScores, .settingsYou, .settingsStrap,
                 .settingsAlerts, .settingsSvea, .settingsData, .settingsLook, .settingsLater, .settingsAbout:
                if let page = NoopSettingsPage(route: navigation.route) { settingsPageScreen(page) }
            case .widgets: widgetsScreen
            case .lab: labScreen
            case .diagnostics: diagnosticsScreen
            case .automations: automationsScreen
            case .onboard: onboardingScreen
            case .pair: if measured { NoopLivePairScreen(navigation: navigation) } else { pairingScreen }
            case .position: positionScreen
            case .howItWorks, .limitations, .siri, .shortcutExport, .storage, .digest, .report, .fused, .hydration:
                NoopUtilityScreens(navigation: navigation)
            default: youScreen
            }
        }
        .sheet(isPresented: $showRhythm) { NoopDailyRhythmScreen() }
        .sheet(isPresented: $showHevy) { NoopHevyScreen() }
        .sheet(item: $pendingOption) { option in
            pendingSheet(option).noopFloatingSheet(height: 380)
        }
        .sheet(isPresented: $showReleaseNotes) {
            WhatsNewView(presentation: .bell) {
                showReleaseNotes = false
            }
            .noopSheet()
        }
        .alert("Clear the stored strap flag?", isPresented: Binding(
            get: { labFlagToClear != nil },
            set: { if !$0 { labFlagToClear = nil } }
        )) {
            Button("Clear on strap", role: .destructive) {
                if let flag = labFlagToClear { clearStoredLabFlag(flag) }
                labFlagToClear = nil
            }
            Button("Leave it stored", role: .cancel) { labFlagToClear = nil }
        } message: {
            Text("Turning the switch off only stops Noop sending it. Clear the value already stored on the strap as well?")
        }
        .confirmationDialog("Mark an experiment phase", isPresented: $showPhasePicker, titleVisibility: .visible) {
            ForEach(PuffinOpticalExperimentPhase.allCases, id: \.self) { phase in
                Button(phase.displayName) {
                    actionNotice = model.ble.markWhoop5OpticalPhase(phase)
                        ? "\(phase.displayName) marked in the local capture file."
                        : "Nothing was marked: turn on Record protocol frames first, so there is a capture file to mark."
                }
            }
        }
        .sheet(isPresented: $showTestCentre) {
            NavigationStack { TestCentreView() }
        }
        .alert("Noop", isPresented: Binding(
            get: { actionNotice != nil },
            set: { if !$0 { actionNotice = nil } }
        )) {
            Button("Done") { actionNotice = nil }
        } message: {
            Text(actionNotice ?? "")
        }
    }
}

// MARK: Shared Act 5 vocabulary

private extension NoopAct5Screens {
    static var blush: Color { Color(hex: 0xE08A9B) }
    static var blushLight: Color { Color(hex: 0xF6D3DA) }
    static var blushDark: Color { Color(hex: 0x2A0E14) }
    static var blushLabel: Color { Color(hex: 0xC08E98) }
    static var green: Color { Color(hex: 0x2ECC80) }
    static var lavender: Color { Color(hex: 0x8B99D6) }
    static var warm: Color { Color(hex: 0xF2B45C) }

    var imperial: Bool { preferences["Units"] == "Imperial" }
    var heightDisplay: String {
        guard imperial else { return "\(height) cm" }
        let totalInches = Int((Double(height) / 2.54).rounded())
        return "\(totalInches / 12)′ \(totalInches % 12)″"
    }
    var weightDisplay: String {
        imperial ? "\(Int((weight * 2.20462).rounded())) lb" : String(format: "%.1f kg", weight)
    }
    var waistDisplay: String {
        guard waist > 0 else { return "Not set" }
        return imperial ? "\(Int((Double(waist) / 2.54).rounded()))″" : "\(waist) cm"
    }
    var activeStrapName: String { activeDevice == "w4" ? spareName : "WHOOP 5.0 / MG" }
    var activeStrapBattery: Int { activeDevice == "w4" ? 61 : 52 }

    var monthName: String {
        let names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
        return names[max(0, min(11, birthMonth - 1))]
    }

    /// The production shell. Every switch and choice then reads and writes the app's real setting,
    /// and one with no feature behind it is drawn in the designed "Later" state instead of as a switch.
    var measured: Bool { you != nil }

    func isEnabled(_ key: String) -> Bool {
        if measured { return liveToggle(key)?.wrappedValue ?? false }
        return enabled.contains(key)
    }

    func flip(_ key: String) {
        if measured {
            guard let binding = liveToggle(key) else { return }
            binding.wrappedValue.toggle()
            toggleSideEffect(key)
            return
        }
        if enabled.contains(key) { enabled.remove(key) } else { enabled.insert(key) }
    }

    /// True in production for a switch with no real setting behind it.
    func isLater(_ key: String) -> Bool { measured && liveToggle(key) == nil }

    func liveToggle(_ key: String) -> Binding<Bool>? {
        switch key {
        case "Reduce motion in Noop": $quietMotionOn
        case "Live heart rate in the Dynamic Island": $liveActivityOn
        case "Battery alerts": $behavior.batteryAlerts
        case "Off-wrist reminder": $behavior.wearAlerts
        case "Sync reminder": $behavior.syncReminder
        case "Your night is in": noticeBinding(.morning)
        case "Bedtime nudge": noticeBinding(.bedtime)
        case "A new best": noticeBinding(.best)
        case "Weekly read": noticeBinding(.weekly)
        case "Backup reminder": noticeBinding(.backup)
        case "Power saving": $powerSavingOn
        // Stored as "pause disabled"; the switch asks the positive question.
        case "Pause the HRV stream when low": Binding(get: { !pauseHrvDisabled }, set: { pauseHrvDisabled = !$0 })
        case "Offer a workout it spotted": $autoDetectOn
        case "Journal reminder": $journalReminderOn
        case "Keep the screen on in a workout": $keepScreenOn
        case "Lift on the Lock Screen": $liftActivityOn
        case "Quiet hours": $quietHoursOn
        case "Move reminder": $inactivityOn
        case "Stress check-ins": $behavior.stressCheckIn
        case "Illness early warning": $behavior.illnessWatch
        case "Buzz if I go over": $behavior.zoneCoaching
        case "Sleep staging V2": $sleepV2On
        case "Motion-aware wake": $motionAwareWakeOn
        case "Continuous HRV capture": $continuousHrvOn
        case "Overnight only": $hrvOvernightOnly
        case "SpO₂ strap estimate": $spo2EstimateOn
        case "Record protocol frames": $frameRecorderOn
        default: nil
        }
    }

    /// One of Aura's own notifications (`AuraNotices`): the switch saves, asks for permission when turned
    /// on, and re-plans what is pending.
    func noticeBinding(_ kind: AuraNotices.Kind) -> Binding<Bool> {
        Binding(get: { AuraNotices.isOn(kind) }, set: { on in
            AuraNotices.set(kind, on)
            Task { await AuraNotices.refresh(repo: model.repo) }
        })
    }

    /// The same follow-ups the classic Settings screen runs when these change.
    func toggleSideEffect(_ key: String) {
        switch key {
        case "Continuous HRV capture": model.ble.setKeepRealtimeForData(continuousHrvOn)
        case "Overnight only": model.ble.setKeepRealtimeForData(PuffinExperiment.keepRealtimeForDataEnabled)
        case "SpO₂ strap estimate": Task { await model.intelligence.analyzeRecent(); await model.repo.refresh() }
        case "Illness early warning": if behavior.illnessWatch { IllnessNotifier.requestAuthorization() }
        case "Sync reminder":
            if behavior.syncReminder { SyncReminder.requestAuthorization() }
            model.rearmSyncReminder()
        default: break
        }
    }

    /// The stored choice for a segmented row, or nil when production has nothing behind it.
    func liveChoice(_ title: String) -> Binding<String>? {
        switch title {
        case "Units":
            Binding(get: { UnitSystem(rawValue: unitSystemRaw) == .imperial ? "Imperial" : "Metric" },
                    set: { unitSystemRaw = ($0 == "Imperial" ? UnitSystem.imperial : .metric).rawValue })
        case "Temperature":
            Binding(get: {
                UnitPrefs.resolveTemperature(system: UnitSystem(rawValue: unitSystemRaw) ?? .metric,
                                             override: temperatureRaw) == .fahrenheit ? "°F" : "°C"
            }, set: { temperatureRaw = ($0 == "°F" ? TemperatureUnit.fahrenheit : .celsius).rawValue })
        case "Effort":
            Binding(get: { UnitPrefs.resolveEffortScale(effortScaleRaw) == .whoop ? "0–21" : "0–100" },
                    set: { effortScaleRaw = ($0 == "0–21" ? EffortScale.whoop : .hundred).rawValue })
        case "Power saving at":
            Binding(get: { "\(powerSavingPct)%" },
                    set: { powerSavingPct = Int($0.dropLast()) ?? powerSavingPct })
        case "Double tap":
            Binding(get: {
                switch behavior.doubleTapAction {
                case .sleepMark: "Sleep mark"
                case .none: "Nothing"
                default: ""
                }
            }, set: { behavior.doubleTapAction = $0 == "Sleep mark" ? .sleepMark : .none })
        // Dark is the only designed appearance and English the only shipped language.
        case "Appearance": .constant("Dark")
        case "Language": .constant("English")
        default: nil
        }
    }

    /// Choices a real setting cannot hold, drawn disabled in production.
    func unsupportedChoices(_ title: String) -> Set<String> {
        guard measured else { return [] }
        switch title {
        case "Double tap": return ["Log water"]
        default: return []
        }
    }

    func pageTitle(_ title: String, copy: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(NoopHTMLFont.outfit(NoopType.title2))
                .tracking(-0.6)
                .foregroundStyle(NoopHTMLColor.ink)
            if !copy.isEmpty {
                Text(copy)
                    .font(NoopHTMLFont.sans(NoopType.footnote))
                    .tracking(-0.15)
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(4)
            }
        }
    }

    func dividedCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        NoopHTMLCard(radius: 22, padding: 0) {
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 16)
        }
    }

    func act5BackHeader(_ label: String, action: @escaping () -> Void) -> some View {
        NoopBackHeader(label: label, action: action)
            // HTML gives the header 18 px horizontal padding while page content uses 20 px.
            .padding(.horizontal, -2)
            // The header is outside the HTML content stack; cancel the shared stack's extra gap.
            .padding(.bottom, -10)
    }

    func copyRow(_ title: String, detail: String?, symbol: String? = nil, tint: Color = NoopHTMLColor.blue, value: String? = nil, action: (() -> Void)? = nil) -> some View {
        Button { action?() } label: {
            HStack(spacing: 13) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: 21)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                    if let detail {
                        Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                    }
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                }
                if action != nil { NoopChevron() }
            }
            .padding(.vertical, 13)
            .frame(minHeight: 58)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    func canonicalLinkRow(
        _ title: String,
        detail: String,
        glyph: NoopCanonicalGlyphName,
        tint: Color,
        value: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: glyph, size: 19, color: tint)
                    .frame(width: 21)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(detail)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineSpacing(2)
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
                NoopChevron()
            }
            .padding(.vertical, 13)
            .frame(minHeight: 58)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    func toggleRow(_ title: String, detail: String, tint: Color = NoopHTMLColor.blue, gate: String? = nil, persistent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: gate == nil ? 0 : 8) {
            HStack(spacing: 13) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                    Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                }
                Spacer(minLength: 8)
                if isLater(title) {
                    NoopLaterChip()
                } else {
                NoopA5TintToggle(isOn: isEnabled(title), tint: tint) {
                    if persistent, isEnabled(title) {
                        labFlagToClear = title
                    } else {
                        flip(title)
                    }
                }
                }
            }
            .padding(.vertical, 13)
            if let gate {
                Text(gate)
                    .font(NoopHTMLFont.sans(NoopType.eyebrow))
                    .foregroundStyle(Color(hex: 0x8B92AE))
                    .lineSpacing(3)
                    .padding(.bottom, 13)
            }
        }
    }

    func segmentRow(
        _ title: String,
        detail: String,
        choices: [String],
        tint: Color = Self.blush,
        disabledChoices: Set<String> = []
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title).font(NoopHTMLFont.sans(NoopType.footnote))
                Spacer()
                Text(detail).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x7F8A85)).multilineTextAlignment(.trailing)
            }
            HStack(spacing: 4) {
                ForEach(choices, id: \.self) { choice in
                    let disabled = disabledChoices.contains(choice) || unsupportedChoices(title).contains(choice)
                    let live = measured ? liveChoice(title) : nil
                    let selected = !disabled && (title == "Svea’s manner"
                        ? navigation.coachVoice.rawValue == choice
                        : (live?.wrappedValue ?? preferences[title]) == choice)
                    Button {
                        guard !disabled else { return }
                        if title == "Svea’s manner", let voice = NoopCoachVoice(rawValue: choice) {
                            navigation.coachVoice = voice
                            preferences[title] = choice
                            if voice == .off {
                                UserDefaults.standard.set("Never", forKey: "noop.html.svea-proactive")
                                UserDefaults.standard.set(false, forKey: SveaProactiveBackgroundTask.enabledKey)
                                coach.proactiveLevel = .off
                                SveaProactiveBackgroundTask.updateSchedule(enabled: false)
                            }
                        } else if let live {
                            live.wrappedValue = choice
                        } else {
                            preferences[title] = choice
                        }
                    } label: {
                        Text(choice)
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? (tint == Self.blush ? Self.blushLight : NoopHTMLColor.ink) : NoopHTMLColor.copy)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 36)
                            .background(selected ? tint.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? tint.opacity(0.42) : .clear, lineWidth: 0.5))
                    }
                    .buttonStyle(NoopPlainHitStyle())
                    .disabled(disabled)
                    .opacity(disabled ? 0.34 : 1)
                }
            }
            .padding(4)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(.vertical, 13)
    }
}

// MARK: You

private extension NoopAct5Screens {
    var youScreen: some View {
        NoopScreen(topInset: 52) {
            VStack(alignment: .leading, spacing: 0) {
                // You is the person (23 Oct 2026); everything about the app is one tap away in Settings.
                HStack(spacing: 8) {
                    Spacer()
                    NoopBatteryChip(percent: you == nil ? 52 : battery) { navigation.push(.strap) }
                    Button { navigation.settingsQuery = ""; navigation.push(.settings) } label: {
                        NoopIconDiscShape(size: .small) {
                            Image(systemName: "gearshape").font(.system(size: NoopControlSize.small.icon, weight: .medium))
                        }
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .accessibilityLabel("Settings")
                }
                .padding(.bottom, -30)
                .zIndex(1)
                NoopEditableSections(layout: youLayout, editing: $youEditing, spacing: 0) { id in youSection(id) }
            }
            .background(alignment: .top) {
                NoopPageBackdrop(theme: .you)
                    .frame(width: UIScreen.main.bounds.width)
                    .offset(y: -110)
            }
        }
        .noopEditBar($youEditing, layout: youLayout) { navigation.push(.settingsYou) }
    }

    /// You's sections in their default order; each carries the space above it.
    static let youSections: [NoopPageSection] = [
        NoopPageSection(id: "portrait", title: "Your clock", detail: "Your name and your usual sleep window"),
        NoopPageSection(id: "portrait-sky", title: "Header · Sky", detail: "Your day as sky on a 24-hour dial", onByDefault: false),
        NoopPageSection(id: "portrait-ring", title: "Header · Portrait", detail: "You inside a ring that fills as your need is learned", onByDefault: false),
        NoopPageSection(id: "body", title: "Your body", detail: "Your record and your zones"),
        NoopPageSection(id: "journey", title: "Your journey", detail: "Your goal, everything you logged and bloodwork")
    ]

    @ViewBuilder
    func youSection(_ id: String) -> some View {
        switch id {
        case "portrait":
            VStack(spacing: 2) {
                if let you {
                    NoopBodyClock(onsetHour: you.usualOnsetHour, wakeHour: you.usualWakeHour,
                                  showsNow: true,
                                  initials: NoopYouRecord.initials(profile.displayName),
                                  photo: profile.avatarImage)
                    if let name = profile.displayName {
                        Text(name)
                            .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light))
                            .tracking(-0.8)
                    }
                    // The prototype's line goes on to claim how tightly the need has held; no
                    // template exists for that, so only the window and the need are stated.
                    if let onset = you.usualOnsetHour, let wake = you.usualWakeHour {
                        Text("Asleep \(NoopYouRecord.clock(onset)) \u{2192} \(NoopYouRecord.clock(wake)) \u{00B7} a \(NoopRestRecord.duration(you.needMin)) need")
                            .font(NoopHTMLFont.sans(NoopType.caption))
                            .foregroundStyle(Color(hex: 0x8B958F))
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                            .frame(maxWidth: 300)
                    }
                } else {
                NoopBodyClock()
                Text("Gabriel")
                    .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light))
                    .tracking(-0.8)
                Text("Asleep 23:20 → 06:32 · a 7h 12m need, held to within nine minutes for 221 nights")
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(Color(hex: 0x8B958F))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 300)
                }
            }
        case "portrait-sky", "portrait-ring":
            if let you {
                Group {
                    if id == "portrait-sky" {
                        NoopYouSky(onsetHour: you.usualOnsetHour, wakeHour: you.usualWakeHour)
                    } else {
                        NoopYouPortrait(initials: NoopYouRecord.initials(profile.displayName), photo: profile.avatarImage,
                                        needMin: you.needMin, needNights: you.needNights)
                    }
                }
                .frame(width: 300, height: 300)
                .frame(maxWidth: .infinity)
            }
        case "body":
            VStack(alignment: .leading, spacing: 9) {
                youSectionLabel("Your body")
                Button { navigation.push(.record) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 8) {
                            NoopSectionLabel("Your record", color: Color(hex: 0xC08E98))
                            if you == nil {
                            HStack(spacing: 10) {
                                recordFact("29", "years")
                                recordFact(heightDisplay, "")
                                recordFact(weightDisplay, "")
                                recordFact(sex.lowercased(), "")
                            }
                            } else if profileConfirmed {
                            HStack(spacing: 10) {
                                recordFact("\(profile.age)", "years")
                                recordFact(liveHeightDisplay, "")
                                recordFact(liveWeightDisplay, "")
                                recordFact(liveSexDisplay, "")
                            }
                            }
                        }
                        Spacer()
                        NoopChevron(color: Color(hex: 0xC08E98))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(Self.blush.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Self.blush.opacity(0.22), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                dividedCard {
                    copyRow("Your zones", detail: "five bands for your effort", symbol: "chart.bar", tint: Self.blush, value: "5") { navigation.push(.zones) }
                    Divider().overlay(NoopHTMLColor.border)
                    copyRow("Daily rhythm", detail: "the shape of your days, from your strap", symbol: "sun.and.horizon", tint: Self.blush) { showRhythm = true }
                }
            }
            .padding(.top, 18)
        case "journey":
            VStack(alignment: .leading, spacing: 9) {
                youSectionLabel("Your journey")
                dividedCard {
                    VStack(spacing: 0) {
                        copyRow("Your journey", detail: you == nil ? "half marathon, 26 October · 46% recorded" : nil, symbol: "sparkles", tint: Self.blush) { navigation.push(.goal) }
                        Divider().overlay(NoopHTMLColor.border)
                        copyRow("Everything you logged", detail: "sessions, sleeps, coffees", symbol: "waveform.path.ecg", tint: Self.blush, value: you == nil ? "142" : nil) { navigation.push(.history) }
                        Divider().overlay(NoopHTMLColor.border)
                        copyRow("Bloodwork", detail: "your lab results, each with its own date", symbol: "drop", tint: NoopHTMLColor.warm) { navigation.push(.labs) }
                    }
                }

                Text("Noop is told six things about your body and works the rest out.")
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(4)
                    .padding(.horizontal, 2)
            }
            .padding(.top, 17)
        default:
            EmptyView()
        }
    }

    var bodyReferenceCards: some View {
        VStack(alignment: .leading, spacing: 9) {
                    NoopSectionLabel("The three numbers everything runs on")
                        .padding(.horizontal, 2)
                        .padding(.top, 8)

                    if let you {
                        // Values are the wearer's; the explanatory copy is the example person's
                        // (221 nights, a hill in June) and has no template, so it is left out.
                        // A planning target, not a measured need (owner decision, 24 Sep): never tagged "learned".
                        // Tapping it lets the wearer set their own, since the estimate never goes below 8 h.
                        let userSet = SleepNeedPrefs.userMinutes() != nil
                        coreCard("Your sleep need", value: NoopRestRecord.duration(you.needMin),
                                 tag: userSet ? "set by you" : nil,
                                 copy: userSet ? nil : "Tap to set your own if your schedule can't fit this.") {
                            choosingSleepNeed = true
                        }
                        .confirmationDialog("Your sleep need", isPresented: $choosingSleepNeed, titleVisibility: .visible) {
                            ForEach(SleepNeedPrefs.choices, id: \.self) { minutes in
                                Button(NoopRestRecord.duration(Double(minutes))) { setSleepNeed(minutes) }
                            }
                            Button("Use the estimate") { setSleepNeed(0) }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Sleep debt and Rest measure against this.")
                        }
                        if let onset = you.usualOnsetHour {
                            coreCard("Your bedtime hour", value: NoopYouRecord.clock(onset), tag: "learned", copy: nil)
                        }
                        // hrMax falls back to an age formula; an unconfirmed age is an example, so the
                        // maximum is printed only once the age is the wearer's or they entered one.
                        coreCard("Your zones", value: NoopZoneSource.current(profile).trusted
                                    ? "5 zones \u{00B7} max \(profile.hrMax)" : "5 zones",
                                 tag: NoopZoneSource.current(profile).tag, copy: nil) {
                            navigation.push(.zones)
                        }
                    } else {
                    coreCard("Your sleep need", value: "7h 12m", tag: "learned", copy: "Worked out from 221 nights of your own sleep, not from a recommendation for adults in general. It moves slowly and tells you when it does.")
                    coreCard("Your bedtime hour", value: "23:20", tag: "learned", copy: "Learned from 221 nights. Everything the app says about regularity is measured against this hour, not against a clock you set.")
                    coreCard("Your zones", value: "5 zones · max \(maximumHeartRate)", tag: "measured", copy: "From a maximum Noop actually saw on a hill in June and a resting rate of 58. Tap to see what each zone is for.") {
                        navigation.push(.zones)
                    }
                    }

        }
    }

    func youSectionLabel(_ title: String) -> some View {
        NoopSectionLabel(title, color: Self.blushLabel)
            .padding(.horizontal, 2)
            .padding(.bottom, 4)
    }

    func recordFact(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value).font(NoopHTMLFont.outfit(NoopType.body)).foregroundStyle(Self.blushLight).monospacedDigit()
            if !label.isEmpty { Text(label).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x8B958F)) }
        }
        .lineLimit(1)
    }

    // MARK: You, measured

    private var liveImperial: Bool { UnitSystem(rawValue: unitSystemRaw) == .imperial }
    private var liveHeightDisplay: String {
        let cm = Int(profile.heightCm.rounded())
        guard liveImperial else { return "\(cm) cm" }
        let inches = Int((profile.heightCm / 2.54).rounded())
        return "\(inches / 12)\u{2032} \(inches % 12)\u{2033}"
    }
    private var liveWeightDisplay: String {
        liveImperial ? "\(Int((profile.weightKg * 2.20462).rounded())) lb" : String(format: "%.1f kg", profile.weightKg)
    }
    private var liveSexDisplay: String {
        switch profile.sex { case "female": "female"; case "male": "male"; default: "other" }
    }
    /// The active strap's model, from the device registry. Nil when none is paired.
    private var liveStrapDetail: String? {
        guard let registry = model.deviceRegistry,
              let active = registry.devices.first(where: { $0.id == registry.activeDeviceId }) else { return nil }
        return active.displayName
    }

    /// Store the wearer's sleep need (0 = back to the estimate) and re-score recent nights against it.
    /// The screens reload because the shell keys their loads on this setting.
    func setSleepNeed(_ minutes: Int) {
        sleepNeedUserMinutes = minutes
        Task { await model.intelligence.analyzeRecent(); await model.repo.refresh() }
    }

    func coreCard(_ title: String, value: String, tag: String?, copy: String?, action: (() -> Void)? = nil) -> some View {
        Button { action?() } label: {
            NoopHTMLCard(radius: 20, padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                            Text(value).font(NoopHTMLFont.outfit(NoopType.title2, weight: .light)).tracking(-0.8).monospacedDigit()
                        }
                        Spacer()
                        if let tag {
                            NoopPill(text: tag, color: tag == "learned" ? Self.blushLight : Color(hex: 0xC9D0EE))
                        }
                    }
                    if let copy {
                        Text(copy).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
                    }
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopBodyClock: View {
    private static let blush = Color(hex: 0xE08A9B)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Local hours on the 24-hour dial (00 at the top). The defaults are the prototype person's; the
    /// production caller passes the wearer's usual window, or nil to draw no arc.
    var onsetHour: Double? = 23.333
    var wakeHour: Double? = 6.533
    /// Production places the now-marker at the real time; the prototype keeps its drawn position.
    var showsNow = false
    var initials: String? = "G"
    var photo: Image? = nil

    private static let markRadius: CGFloat = 94.5

    private func point(_ hour: Double) -> CGSize {
        let angle = hour / 24 * 2 * .pi
        return CGSize(width: sin(angle) * Self.markRadius, height: -cos(angle) * Self.markRadius)
    }

    private var nowHour: Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
    }

    private func inSleep(_ hour: Int) -> Bool {
        guard let onset = onsetHour, let wake = wakeHour else { return false }
        let h = Double(hour)
        return onset <= wake ? (h >= onset && h <= wake) : (h >= onset || h <= wake)
    }

    var body: some View {
        NoopAnimatedTimeline(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion) { timeline in
            let heroPhase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 9) / 9
            let heroWave = (1 - cos(heroPhase * 2 * .pi)) / 2
            let nowPhase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3.4) / 3.4
            let nowWave = (1 + cos(nowPhase * 2 * .pi)) / 2

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Self.blush.opacity(0.24), location: 0),
                                .init(color: Self.blush.opacity(0), location: 0.62),
                                .init(color: Self.blush.opacity(0), location: 1)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 143
                        )
                    )
                    .frame(width: 286, height: 286)
                    .blur(radius: 18)
                    .opacity(reduceMotion ? 0.83 : 0.66 + heroWave * 0.34)

                Circle()
                    .stroke(Color.white.opacity(0.055), lineWidth: 17.5)
                    .frame(width: 189, height: 189)

                Circle()
                    .trim(from: 0, to: 0.5)
                    .stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 17.5, lineCap: .butt))
                    .frame(width: 189, height: 189)

                if onsetHour != nil && wakeHour != nil {
                sleepArc
                    .stroke(Self.blush.opacity(0.9), style: StrokeStyle(lineWidth: 15.4, lineCap: .round))
                    .frame(width: 189, height: 189)
                    .blur(radius: 7)
                    .opacity(0.75)

                sleepArc
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color(hex: 0x8B99D6), location: 0),
                                .init(color: Self.blush, location: 0.55),
                                .init(color: Color(hex: 0xF2C4CE), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 15.4, lineCap: .round)
                    )
                    .frame(width: 189, height: 189)
                }

                ForEach(0..<24, id: \.self) { hour in
                    let major = hour % 6 == 0
                    let inSleep = showsNow ? self.inSleep(hour) : hour <= 6
                    Capsule()
                        .fill(major ? Color.white.opacity(0.5) : inSleep ? Self.blush.opacity(0.3) : Color.white.opacity(0.14))
                        .frame(width: major ? 1.6 : 1, height: major ? 6.2 : 3.1)
                        .offset(y: -82.2)
                        .rotationEffect(.degrees(Double(hour) * 15))
                }

                clockLabel("00", x: 0, y: -122)
                clockLabel("06", x: 122, y: 0)
                clockLabel("12", x: 0, y: 122)
                clockLabel("18", x: -122, y: 0)

                Circle()
                    .fill(Color.white)
                    .frame(width: 7, height: 7)
                    .shadow(color: .white.opacity(0.9), radius: 6)
                    .opacity(reduceMotion ? 1 : 0.35 + nowWave * 0.65)
                    .offset(showsNow ? point(nowHour) : CGSize(width: -54.2, height: -77.4))
                if let wake = wakeHour {
                Circle()
                    .fill(NoopHTMLColor.canvas)
                    .overlay(Circle().stroke(Color(hex: 0xF2C4CE), lineWidth: 2))
                    .frame(width: 10.7, height: 10.7)
                    .offset(showsNow ? point(wake) : CGSize(width: 93.5, height: 13.2))
                }
                if let onset = onsetHour {
                Circle()
                    .fill(Color(hex: 0x8B99D6))
                    .frame(width: 7, height: 7)
                    .offset(showsNow ? point(onset) : CGSize(width: -16.4, height: -93.1))
                }

                Circle()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: Color(hex: 0x4A3239), location: 0),
                                .init(color: Color(hex: 0x1B1D1C), location: 0.72),
                                .init(color: Color(hex: 0x1B1D1C), location: 1)
                            ],
                            center: UnitPoint(x: 0.38, y: 0.32),
                            startRadius: 0,
                            endRadius: 78
                        )
                    )
                    .frame(width: 112, height: 112)
                    .overlay(Circle().stroke(Self.blush.opacity(0.4), lineWidth: 0.5))
                    .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1).padding(1))
                    .shadow(color: Self.blush.opacity(0.24), radius: 17)
                if let photo {
                    photo.resizable().scaledToFill()
                        .frame(width: 112, height: 112)
                        .clipShape(Circle())
                } else if let initials {
                    Text(initials)
                        .font(NoopHTMLFont.outfit(42, weight: .light))
                        .tracking(-1.25)
                        .foregroundStyle(Color(hex: 0xF6D3DA))
                } else {
                    // No photo and no name: the spec's fallback is the brand mark, never an empty disc.
                    BrandMark(size: 44)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        // The pulsing glow and its blur are repainted every frame; on the GPU, not the CPU, where they
        // cost up to a fifth of the main thread (profiled 25 Oct 2026). The padding keeps the group
        // from clipping the glow, which spills past the frame.
        .padding(.vertical, 50)
        .drawingGroup()
        .padding(.vertical, -50)
    }

    private var sleepArc: some Shape {
        let onset = onsetHour ?? 0, wake = wakeHour ?? 0
        let span = (wake - onset + 24).truncatingRemainder(dividingBy: 24)
        return Circle()
            .trim(from: 0, to: span / 24)
            .rotation(.degrees(-90 + onset * 15))
    }

    private func clockLabel(_ value: String, x: CGFloat, y: CGFloat) -> some View {
        Text(value)
            .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(Color(hex: 0x5A635F))
            .offset(x: x, y: y)
    }
}

// MARK: Your record

private extension NoopAct5Screens {
    var recordScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                act5BackHeader("You") { navigation.back(or: .you) }
                pageTitle("Your record", copy: "Six facts and two calibrations. These set your zones, your calorie estimate and your body age — nothing else in the app asks you anything.")
                    .padding(.bottom, 6)

                if measured {
                    liveRecordBody
                } else {

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(spacing: 14) {
                            Group {
                                if hasPhoto {
                                    Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(Self.blushLight)
                                } else {
                                    Text("G").font(NoopHTMLFont.outfit(NoopType.title1, weight: .light)).foregroundStyle(Self.blushLight)
                                }
                            }
                            .frame(width: 68, height: 68)
                            .background(
                                RadialGradient(
                                    stops: [
                                        .init(color: Color(hex: 0x4A3239), location: 0),
                                        .init(color: Color(hex: 0x1B1D1C), location: 0.72),
                                        .init(color: Color(hex: 0x1B1D1C), location: 1)
                                    ],
                                    center: UnitPoint(x: 0.38, y: 0.32),
                                    startRadius: 0,
                                    endRadius: 48
                                ),
                                in: Circle()
                            )
                            .overlay(Circle().stroke(Self.blush.opacity(0.4), lineWidth: 0.5))

                            VStack(spacing: 7) {
                                Button(hasPhoto ? "Change photo" : "Choose photo") { hasPhoto = true }
                                    .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                                    .foregroundStyle(Self.blushLight)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(Self.blush.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
                                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Self.blush.opacity(0.3), lineWidth: 0.5))
                                    .buttonStyle(NoopHTMLPressStyle())
                                if hasPhoto {
                                    Button("Remove photo") { hasPhoto = false }
                                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).frame(height: 32)
                                }
                            }
                        }
                        Text("Optional. It stays on this phone and is never uploaded — Noop has no account to upload it to.")
                            .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    }
                    .padding(.vertical, 3.5)
                }

                dividedCard {
                    VStack(spacing: 0) {
                        dateOfBirthRow
                        Divider().overlay(NoopHTMLColor.border)
                        HStack(spacing: 13) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sex").font(NoopHTMLFont.sans(NoopType.footnote))
                                Text("used in the calorie and VO₂max models")
                                    .font(NoopHTMLFont.sans(NoopType.eyebrow))
                                    .foregroundStyle(Color(hex: 0x7F8A85))
                                    // Wraps as in the design rather than shrinking into "VO₂ma…".
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 4)
                            compactSexControl
                        }
                        .frame(minHeight: 66)
                        .padding(.vertical, 13)
                        Divider().overlay(NoopHTMLColor.border)
                        stepperRow("Height", detail: imperial ? "stepped in whole inches" : "stepped in centimetres", value: heightDisplay, minus: { height = max(120, height - (imperial ? 3 : 1)) }, plus: { height = min(230, height + (imperial ? 3 : 1)) })
                        Divider().overlay(NoopHTMLColor.border)
                        stepperRow("Weight", detail: imperial ? "stepped in pounds" : "stepped in half kilos", value: weightDisplay, minus: { weight = max(30, weight - (imperial ? 0.45 : 0.5)) }, plus: { weight = min(250, weight + (imperial ? 0.45 : 0.5)) })
                        Divider().overlay(NoopHTMLColor.border)
                        stepperRow("Waist", detail: "optional — adds a VO₂max estimate, nothing else", value: waistDisplay, minus: { waist = max(0, waist - (imperial ? 3 : 1)) }, plus: { waist = waist == 0 ? 80 : min(160, waist + (imperial ? 3 : 1)) })
                        Divider().overlay(NoopHTMLColor.border)
                        stepperRow("Maximum heart rate", detail: maximumHeartRate == 186 ? "seen on the climb out of the valley, 14 June" : "manual override", value: "\(maximumHeartRate) bpm", minus: { maximumHeartRate = max(100, maximumHeartRate - 1) }, plus: { maximumHeartRate = min(220, maximumHeartRate + 1) })
                        Divider().overlay(NoopHTMLColor.border)
                        copyRow("Your zones", detail: "five bands, derived from the two anchors above", value: "5 zones") { navigation.push(.zones) }
                            .frame(height: 92)
                        Divider().overlay(NoopHTMLColor.border)
                        stepperRow("Step calibration", detail: "counter ticks per step — leave at 1.0 unless steps run high", value: String(format: "%.1f", stepScale), minus: { stepScale = max(0.5, stepScale - 0.1) }, plus: { stepScale = min(3, stepScale + 0.1) })
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("Why the waist is optional").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    Text("It adds an estimated VO₂max. It does not sharpen your body age — that model cancels the body term out — so Noop will not nag you for it.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0xC9BEC0)).lineSpacing(4)
                }
                .padding(16)
                .background(Self.blush.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Self.blush.opacity(0.2), lineWidth: 0.5))
                }
                bodyReferenceCards
            }
        }
        .sheet(isPresented: $confirmingProfile) {
            NoopEnergyProfileConfirmation(profile: profile) {
                profileConfirmed = true
                confirmingProfile = false
                Task { await WidgetSnapshot.publish(from: model) }
            }
            .noopSheet()
        }
        .onChangeCompat(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) { profile.setAvatar(data) }
                photoItem = nil
            }
        }
    }

    // MARK: Your record, measured

    /// The same rows over the wearer's stored profile. Until the starting example values are
    /// confirmed they print as "—" and any tap opens the one-time confirmation; after that each
    /// stepper writes the profile directly.
    @ViewBuilder
    var liveRecordBody: some View {
        NoopHTMLCard(radius: 22, padding: 16) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 14) {
                    Group {
                        if let photo = profile.avatarImage {
                            photo.resizable().scaledToFill()
                        } else if let initials = NoopYouRecord.initials(profile.displayName) {
                            Text(initials).font(NoopHTMLFont.outfit(NoopType.title1, weight: .light)).foregroundStyle(Self.blushLight)
                        } else {
                            BrandMark(size: 30)
                        }
                    }
                    .frame(width: 68, height: 68)
                    .clipShape(Circle())
                    .background(Color(hex: 0x1B1D1C), in: Circle())
                    .overlay(Circle().stroke(Self.blush.opacity(0.4), lineWidth: 0.5))

                    VStack(spacing: 7) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text(profile.hasAvatar ? "Change photo" : "Choose photo")
                                .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                                .foregroundStyle(Self.blushLight)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 40)
                                .background(Self.blush.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
                                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Self.blush.opacity(0.3), lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        if profile.hasAvatar {
                            Button("Remove photo") { profile.clearAvatar() }
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).frame(height: 32)
                        }
                    }
                }
                Divider().overlay(NoopHTMLColor.border)
                HStack(spacing: 12) {
                    Text("Name").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                    TextField("What Today greets you by", text: $profile.name)
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                }
                .frame(minHeight: 36)
                Text("Optional, like the photo. Both stay on this phone and are never uploaded — Noop has no account to upload them to.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
            }
            .padding(.vertical, 3.5)
        }

        dividedCard {
            VStack(spacing: 0) {
                liveDateOfBirthRow
                Divider().overlay(NoopHTMLColor.border)
                HStack(spacing: 13) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sex").font(NoopHTMLFont.sans(NoopType.footnote))
                        Text("used in the calorie and VO₂max models")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x7F8A85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    liveSexControl
                }
                .frame(minHeight: 66)
                .padding(.vertical, 13)
                Divider().overlay(NoopHTMLColor.border)
                stepperRow("Height", detail: liveImperial ? "stepped in whole inches" : "stepped in centimetres",
                           value: profileConfirmed ? liveHeightDisplay : "\u{2014}",
                           minus: { editProfile { profile.heightCm = max(120, profile.heightCm - (liveImperial ? 2.54 : 1)) } },
                           plus: { editProfile { profile.heightCm = min(230, profile.heightCm + (liveImperial ? 2.54 : 1)) } })
                Divider().overlay(NoopHTMLColor.border)
                stepperRow("Weight", detail: liveImperial ? "stepped in pounds" : "stepped in half kilos",
                           value: profileConfirmed ? liveWeightDisplay : "\u{2014}",
                           minus: { editProfile { profile.weightKg = max(30, profile.weightKg - (liveImperial ? 0.45359 : 0.5)) } },
                           plus: { editProfile { profile.weightKg = min(250, profile.weightKg + (liveImperial ? 0.45359 : 0.5)) } })
                Divider().overlay(NoopHTMLColor.border)
                stepperRow("Waist", detail: "optional — adds a VO₂max estimate, nothing else",
                           value: profile.waistCm > 0
                                ? (liveImperial ? "\(Int((profile.waistCm / 2.54).rounded()))\u{2033}" : "\(Int(profile.waistCm.rounded())) cm")
                                : "Not set",
                           minus: { profile.waistCm = profile.waistCm <= 60 ? 0 : profile.waistCm - (liveImperial ? 2.54 : 1) },
                           plus: { profile.waistCm = profile.waistCm == 0 ? 80 : min(160, profile.waistCm + (liveImperial ? 2.54 : 1)) })
                Divider().overlay(NoopHTMLColor.border)
                // No observed maximum is stored, so the row speaks only of an override the wearer set.
                stepperRow("Maximum heart rate",
                           detail: profile.hrMaxOverride > 0 ? (profile.hrMaxSource == "measured" ? "held for 30 seconds, measured on you" : "manual override") : "",
                           value: profile.hrMaxOverride > 0 || profileConfirmed ? "\(profile.hrMax) bpm" : "\u{2014}",
                           minus: { profile.setManualMax(max(100, profile.hrMax - 1)) },
                           plus: { profile.setManualMax(min(230, profile.hrMax + 1)) })
                Divider().overlay(NoopHTMLColor.border)
                copyRow("Your zones", detail: "five bands, derived from the two anchors above", value: "5 zones") { navigation.push(.zones) }
                    .frame(height: 92)
                Divider().overlay(NoopHTMLColor.border)
                stepperRow("Step calibration", detail: "counter ticks per step — leave at 1.0 unless steps run high",
                           value: String(format: "%.1f", profile.stepTicksPerStep),
                           minus: { profile.stepTicksPerStep = max(0.5, profile.stepTicksPerStep - 0.1) },
                           plus: { profile.stepTicksPerStep = min(3, profile.stepTicksPerStep + 0.1) })
            }
        }

        VStack(alignment: .leading, spacing: 9) {
            Text("Why the waist is optional").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
            Text("It adds an estimated VO₂max. It does not sharpen your body age — that model cancels the body term out — so Noop will not nag you for it.")
                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0xC9BEC0)).lineSpacing(4)
        }
        .padding(16)
        .background(Self.blush.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Self.blush.opacity(0.2), lineWidth: 0.5))
    }

    /// Edits to the four confirmed facts go through the confirmation first, once.
    func editProfile(_ change: () -> Void) {
        guard profileConfirmed else { confirmingProfile = true; return }
        change()
    }

    var liveDateOfBirthRow: some View {
        let calendar = Calendar(identifier: .gregorian)
        let parts = calendar.dateComponents([.day, .month, .year], from: profile.dateOfBirth)
        let day = parts.day ?? 1, month = parts.month ?? 1, year = parts.year ?? 1990
        let monthLabel = DateFormatter().monthSymbols[max(0, min(11, month - 1))]
        func set(_ d: Int, _ m: Int, _ y: Int) {
            editProfile {
                var c = DateComponents(); c.year = y; c.month = m
                let days = calendar.range(of: .day, in: .month, for: calendar.date(from: c) ?? Date())?.count ?? 28
                c.day = min(d, days)
                if let date = calendar.date(from: c) { profile.dateOfBirth = date }
            }
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Date of birth").font(NoopHTMLFont.sans(NoopType.footnote))
                Spacer()
                Text(profileConfirmed ? "\(day) \(monthLabel) \(String(year)) \u{00B7} \(profile.age) years" : "\u{2014}")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Self.blushLight)
            }
            HStack(spacing: 7) {
                compactStepper(value: profileConfirmed ? "\(day)" : "\u{2014}", label: "day",
                               minus: { set(day == 1 ? 31 : day - 1, month, year) }, plus: { set(day == 31 ? 1 : day + 1, month, year) })
                compactStepper(value: profileConfirmed ? String(monthLabel.prefix(3)) : "\u{2014}", label: "month",
                               minus: { set(day, month == 1 ? 12 : month - 1, year) }, plus: { set(day, month == 12 ? 1 : month + 1, year) })
                compactStepper(value: profileConfirmed ? "\(year)" : "\u{2014}", label: "year",
                               minus: { set(day, month, max(1930, year - 1)) }, plus: { set(day, month, min(2012, year + 1)) })
            }
            Text("Your age is derived from this, so it advances on its own. Nothing else in the app asks for it.")
                .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(2)
        }
        .padding(.vertical, 11.5)
    }

    var liveSexControl: some View {
        HStack(spacing: 3) {
            ForEach([("Male", "male"), ("Female", "female"), ("Other", "nonbinary")], id: \.0) { label, value in
                let selected = profileConfirmed && profile.sex == value
                Button { editProfile { profile.sex = value } } label: {
                    Text(label)
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: selected ? .semibold : .regular))
                        .lineLimit(1).minimumScaleFactor(0.85).fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(selected ? Self.blushLight : NoopHTMLColor.copy)
                        .padding(.horizontal, 9).frame(minHeight: 36)
                        .background(selected ? Self.blush.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? Self.blush.opacity(0.42) : .clear, lineWidth: 0.5))
                }
                .buttonStyle(NoopPlainHitStyle())
            }
        }
        .padding(3)
        .fixedSize()
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    var dateOfBirthRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Date of birth").font(NoopHTMLFont.sans(NoopType.footnote))
                Spacer()
                Text("\(birthDay) \(monthName) \(String(birthYear)) · 29 years")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Self.blushLight)
            }
            HStack(spacing: 7) {
                compactStepper(value: "\(birthDay)", label: "day", minus: { birthDay = birthDay == 1 ? 31 : birthDay - 1 }, plus: { birthDay = birthDay == 31 ? 1 : birthDay + 1 })
                compactStepper(value: String(monthName.prefix(3)), label: "month", minus: { birthMonth = birthMonth == 1 ? 12 : birthMonth - 1 }, plus: { birthMonth = birthMonth == 12 ? 1 : birthMonth + 1 })
                compactStepper(value: "\(birthYear)", label: "year", minus: { birthYear = max(1930, birthYear - 1) }, plus: { birthYear = min(2012, birthYear + 1) })
            }
            Text("Your age is derived from this, so it advances on its own. Nothing else in the app asks for it.")
                .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(2)
        }
        .padding(.vertical, 11.5)
    }

    var compactSexControl: some View {
        HStack(spacing: 3) {
            ForEach(["Male", "Female", "Other"], id: \.self) { choice in
                let selected = sex == choice
                Button { sex = choice } label: {
                    Text(choice)
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(selected ? Self.blushLight : NoopHTMLColor.copy)
                        .padding(.horizontal, 9)
                        .frame(minHeight: 32)
                        .background(selected ? Self.blush.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? Self.blush.opacity(0.42) : .clear, lineWidth: 0.5))
                }
                .buttonStyle(NoopPlainHitStyle())
            }
        }
        .padding(3)
        .fixedSize()
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    func compactStepper(value: String, label: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            Button(action: minus) { Image(systemName: "minus").font(.system(size: 9, weight: .semibold)).frame(width: 32, height: 32).noopHitTarget() }
                .buttonStyle(NoopA5CompactStepStyle())
            VStack(spacing: 1) {
                // The HTML's nowrap value may run a few points into the gap; truncating turned the
                // year into "19…" on every phone width.
                Text(value).font(NoopHTMLFont.outfit(NoopType.body)).monospacedDigit().lineLimit(1).fixedSize()
                Text(label.uppercased()).font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(0.7).foregroundStyle(Color(hex: 0x7F8A85))
                    .lineLimit(1).fixedSize()
            }
            .frame(maxWidth: .infinity)
            Button(action: plus) { Image(systemName: "plus").font(.system(size: 9, weight: .semibold)).frame(width: 32, height: 32).noopHitTarget() }
                .buttonStyle(NoopA5CompactStepStyle())
        }
        .foregroundStyle(NoopHTMLColor.inkSoft)
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
    }

    func stepperRow(_ title: String, detail: String, value: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(NoopType.footnote))
                Text(detail).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
            }
            Spacer(minLength: 4)
            Text(value).font(NoopHTMLFont.outfit(NoopType.body)).monospacedDigit().multilineTextAlignment(.trailing)
            HStack(spacing: 4) {
                Button(action: minus) { Image(systemName: "minus") }
                Button(action: plus) { Image(systemName: "plus") }
            }
            .font(.system(size: 10, weight: .semibold))
            .buttonStyle(NoopA5StepButtonStyle())
        }
        .frame(minHeight: 66)
        .padding(.vertical, 13)
    }
}

private struct NoopA5StepButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .foregroundStyle(NoopHTMLColor.inkSoft)
            .frame(width: 32, height: 32).noopHitTarget()
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.11), lineWidth: 0.5))
    }
}

// MARK: Zones

private extension NoopAct5Screens {
    var zonesScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                act5BackHeader("Your record") { navigation.back(or: .record) }
                pageTitle("Your zones", copy: measured ? "" : "Built from two numbers Noop has actually seen on you, not from your age.")
                    .padding(.bottom, 3)

                HStack(spacing: 9) {
                    if measured {
                        // No maximum is observed anywhere in the app, so "Measured maximum" cannot be
                        // claimed. The maximum the zones are built on is shown, named for where it came
                        // from; the resting anchor is measured.
                        let source = NoopZoneSource.current(profile)
                        anchorCard(value: source.trusted ? "\(profile.hrMax)" : "\u{2014}", title: source.maximumTitle,
                                   copy: source.tag ?? "")
                        if let resting = liveRestingAnchor {
                            anchorCard(value: "\(resting)", title: "Resting rate", copy: "Overnight average across the last fourteen nights, updated every morning.")
                        }
                    } else {
                    anchorCard(value: "\(maximumHeartRate)", title: "Measured maximum", copy: "Seen on the climb out of the valley, 14 June. Not estimated from your age.")
                    anchorCard(value: "58", title: "Resting rate", copy: "Overnight average across the last fourteen nights, updated every morning.")
                    }
                }

                VStack(spacing: 9) {
                    ForEach(Array((measured ? liveZones : Self.zones).enumerated()), id: \.offset) { index, zone in
                        Button { withAnimation(.easeOut(duration: 0.18)) { openZone = openZone == index ? nil : index } } label: {
                            VStack(alignment: .leading, spacing: 11) {
                                HStack(spacing: 11) {
                                    RoundedRectangle(cornerRadius: 4).fill(zone.color).frame(width: 10, height: 26)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(zone.name).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                        Text(zone.percent).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                                    }
                                    Spacer()
                                    Text(zone.range).font(NoopHTMLFont.outfit(NoopType.body)).foregroundStyle(NoopHTMLColor.inkSoft).monospacedDigit()
                                }
                                if openZone == index {
                                    if !zone.use.isEmpty {
                                    Text(zone.use).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
                                    }
                                    HStack(spacing: 10) {
                                        Text("Lower edge").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
                                        NoopProgressBar(progress: zone.progress, color: zone.color, height: 4)
                                        Text(zone.lower).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft)
                                    }
                                    Text("Nudging an edge only changes what the app calls it. Your history is not renumbered.")
                                        .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                                }
                            }
                            .padding(16)
                            .background(openZone == index ? NoopHTMLColor.blue.opacity(0.07) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(openZone == index ? NoopHTMLColor.blue.opacity(0.28) : NoopHTMLColor.border, lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }

                if !measured {
                VStack(alignment: .leading, spacing: 9) {
                    Text("These update themselves").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    Text("When your resting pulse or your measured maximum moves, the edges move with them and you get one line about it in Trends. There is no annual retest to remember.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0xB7C3C9)).lineSpacing(4)
                }
                .padding(16)
                .background(NoopHTMLColor.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.blue.opacity(0.2), lineWidth: 0.5))
                }
            }
        }
    }

    func anchorCard(value: String, title: String, copy: String) -> some View {
        NoopHTMLCard(radius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(NoopHTMLFont.outfit(NoopType.title2, weight: .light)).tracking(-0.8)
                    Text("bpm").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.muted)
                }
                Text(title).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft)
                if !copy.isEmpty {
                    Text(copy).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                }
            }
        }
    }

    /// The profile's own five zones, named by number. The design's "use" lines describe its own
    /// bands, which do not line up with these, so none is printed.
    var liveZones: [NoopA5Zone] {
        let set = profile.hrZoneSet
        return Self.zones.enumerated().compactMap { index, template in
            guard set.zones.indices.contains(index) else { return nil }
            let z = set.zones[index]
            let lo = Int(z.lower.rounded()), hi = Int(z.upper.rounded())
            // An age formula over an unconfirmed example age is not the wearer's zone.
            let trusted = NoopZoneSource.current(profile).trusted
            return NoopA5Zone(name: NoopZoneSource.name(index + 1), range: trusted ? "\(lo)\u{2013}\(hi)" : "\u{2014}",
                              percent: "\(Int((z.lowerPct * 100).rounded()))\u{2013}\(Int((z.upper / set.maxHR * 100).rounded()))% of your maximum",
                              lower: trusted ? "\(lo) bpm" : "\u{2014}", progress: z.lowerPct, color: template.color,
                              // The "use" lines describe the design's bands, not the app's zones.
                              use: "")
        }
    }

    /// Mean resting heart rate over the last fourteen recorded nights.
    var liveRestingAnchor: Int? {
        let values = model.repo.days.suffix(14).compactMap(\.restingHr)
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }

    static let zones: [NoopA5Zone] = [
        .init(name: "Resting", range: "40–62", percent: "22–33% of your maximum", lower: "40 bpm", progress: 0.22, color: Color(hex: 0x3E6C86), use: "Sitting, sleeping, standing in a queue. Nothing to train here — it is the floor the other four are measured from."),
        .init(name: "Easy", range: "62–96", percent: "33–52% of your maximum", lower: "62 bpm", progress: 0.33, color: Color(hex: 0x4FB8E8), use: "Walking, gentle riding, most of a long day. The zone that built almost all of your capacity this year."),
        .init(name: "Steady", range: "96–128", percent: "52–69% of your maximum", lower: "96 bpm", progress: 0.52, color: NoopHTMLColor.blue, use: "Conversation pace with effort behind it. Where the recommended sessions live and where the hours should go."),
        .init(name: "Hard", range: "128–152", percent: "69–82% of your maximum", lower: "128 bpm", progress: 0.69, color: Self.warm, use: "Hills, the last ten minutes, an interval you can hold for a few minutes. Costs a day of recovery."),
        .init(name: "All out", range: "152–186", percent: "82–100% of your maximum", lower: "152 bpm", progress: 0.82, color: NoopHTMLColor.amber, use: "A minute at a time, no more. Nine of these in six months is about right for you.")
    ]
}

private struct NoopA5Zone {
    let name: String
    let range: String
    let percent: String
    let lower: String
    let progress: Double
    let color: Color
    let use: String
}

// MARK: Everything logged

private extension NoopAct5Screens {
    var historyScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                act5BackHeader("You") { navigation.back(or: .you) }
                pageTitle("Everything you logged", copy: "Sessions, sleeps and every coffee, in one list. This is where the + button's taps end up.")
                    .padding(.bottom, 6)

                HStack(spacing: 6) {
                    ForEach(["All", "Sessions", "Sleep", "Logs"], id: \.self) { filter in
                        Button { historyFilter = filter } label: {
                            Text(filter)
                                .font(NoopHTMLFont.sans(NoopType.caption, weight: .medium))
                                .foregroundStyle(historyFilter == filter ? Self.blushLight : NoopHTMLColor.copy)
                                .padding(.horizontal, 13)
                                .frame(minHeight: 40)
                                .background(historyFilter == filter ? Self.blush.opacity(0.18) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(historyFilter == filter ? Self.blush.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 0.5))
                        }
                        .buttonStyle(NoopPlainHitStyle())
                    }
                }

                HStack(spacing: 9) {
                    if measured, let h = history {
                        historyMetricTile("\(h.monthSessions)", label: "sessions in \(h.monthName)")
                        historyMetricTile(NoopRestRecord.duration(Double(h.monthMovingMin)), label: "moving")
                        historyMetricTile("\(h.monthLoad)", label: "load")
                    } else {
                    historyMetricTile("12", label: "sessions in August")
                    historyMetricTile("8h 40m", label: "moving")
                    historyMetricTile("302", label: "load")
                    }
                }

                Button {
                    navigation.push(.across)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Every session, in aggregate")
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("A window rather than a list — how much you rode, walked and lifted in it.")
                                .font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(NoopHTMLColor.border, lineWidth: 0.5)
                    )
                }
                .buttonStyle(NoopPlainHitStyle())

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(filteredHistory) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(day.day).font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                                Spacer()
                                Text(day.summary).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                            }
                            .padding(.horizontal, 2)
                            dividedCard {
                                VStack(spacing: 0) {
                                    ForEach(Array(day.items.enumerated()), id: \.offset) { index, item in
                                        historyRow(item)
                                        if index < day.items.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }

                Text("Grouped by day, newest first. Sleeps sit in the same list as sessions because they are the same kind of fact about your week.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
            }
        }
    }

    /// Change 4. A session row with an identity opens its record; a sleep row opens the night.
    /// Everything else is inert, and only rows that navigate carry a chevron.
    @ViewBuilder
    func historyRow(_ item: NoopA5HistoryItem) -> some View {
        let glyphTint: Color = item.kind == .log
            ? Color(hex: 0x7F8A85)
            : item.kind == .sleep ? Self.lavender : NoopHTMLColor.blue
        Button {
            if item.kind == .sleep {
                if let date = item.date, !NoopContentPolicy.allowsPrototypeContent {
                    // Release has no "why" engine: open the night itself on Rest, which reads it in full.
                    let back = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: date),
                                                               to: Calendar.current.startOfDay(for: Date())).day ?? 0
                    navigation.selectedRestDay = max(0, back)
                    navigation.reset(to: .rest)
                } else {
                    navigation.push(.why)
                }
            } else if let workout = item.workout {
                navigation.detailSession = NoopSessionDetailSelection(
                    workout: workout,
                    headerLine: item.sessionHeaderLine,
                    durationLabel: item.sessionDurationLabel,
                    load: item.sessionLoad
                )
                navigation.historyWorkout = workout
                navigation.push(.detail)
            }
        } label: {
            HStack(spacing: 12) {
                NoopCanonicalGlyph(name: item.symbol, size: 18, color: glyphTint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: item.kind == .log ? .regular : .semibold))
                        .foregroundStyle(item.kind == .log ? NoopHTMLColor.inkSoft : NoopHTMLColor.ink)
                    Text(item.detail)
                        .font(NoopHTMLFont.sans(NoopType.eyebrow))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                }
                Spacer()
                Text(item.value)
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                if item.opensSomething {
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.chevronDim)
                }
            }
            .frame(minHeight: 55)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!item.opensSomething)
    }

    /// The measured list in the prototype's row shapes. Session rows keep no workout identity yet, so
    /// they carry no chevron until the session record screen is wired.
    var liveHistoryDays: [NoopA5HistoryDay] {
        (history?.days ?? []).map { day in
            NoopA5HistoryDay(day: day.label, summary: "", items: day.entries.map { e in
                switch e.kind {
                case .session:
                    NoopA5HistoryItem(kind: .session, name: e.name, detail: e.detail, value: e.value,
                                      symbol: Self.glyph(forSport: e.sport))
                case .sleep:
                    NoopA5HistoryItem(kind: .sleep, name: e.name, detail: e.detail, value: e.value, symbol: .bed,
                                      date: e.date)
                case .log:
                    NoopA5HistoryItem(kind: .log, name: e.name, detail: e.detail, value: e.value, symbol: .check)
                }
            })
        }
    }

    static func glyph(forSport sport: String?) -> NoopCanonicalGlyphName {
        let s = (sport ?? "").lowercased()
        if s.contains("cycl") || s.contains("bike") || s.contains("ride") { return .bike }
        if s.contains("walk") || s.contains("hik") { return .walk }
        if s.contains("strength") || s.contains("weight") || s.contains("lift") { return .weight }
        if s.contains("swim") { return .wave }
        return .bolt
    }

    var filteredHistory: [NoopA5HistoryDay] {
        (measured ? liveHistoryDays : Self.history).compactMap { day in
            let items = day.items.filter { item in
                historyFilter == "All" ||
                    (historyFilter == "Sessions" && item.kind == .session) ||
                    (historyFilter == "Sleep" && item.kind == .sleep) ||
                    (historyFilter == "Logs" && item.kind == .log)
            }
            guard !items.isEmpty else { return nil }
            let sessions = items.filter { $0.kind == .session }.count
            let sleeps = items.filter { $0.kind == .sleep }.count
            let logs = items.filter { $0.kind == .log }.count
            var parts: [String] = []
            if sessions > 0 { parts.append("\(sessions) session\(sessions == 1 ? "" : "s")") }
            if sleeps > 0 { parts.append(sleeps == 1 ? "sleep" : "\(sleeps) sleeps") }
            if logs > 0 { parts.append("\(logs) log\(logs == 1 ? "" : "s")") }
            return NoopA5HistoryDay(day: day.day, summary: parts.joined(separator: " · "), items: items)
        }
    }

    func historyMetricTile(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(NoopHTMLFont.outfit(NoopType.title3, weight: .light))
                .tracking(-0.6)
                .monospacedDigit()
            Text(label)
                .font(NoopHTMLFont.sans(NoopType.eyebrow))
                .foregroundStyle(Color(hex: 0x7F8A85))
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .frame(maxWidth: .infinity, minHeight: 79, maxHeight: 79, alignment: .topLeading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    static let history: [NoopA5HistoryDay] = [
        .init(day: "Today", summary: "", items: [
            .init(
                kind: .session,
                name: "Steady ride",
                detail: "17:04 · 42 min · avg 126 bpm",
                value: "load 48",
                symbol: .bike,
                workout: .steadyRide,
                sessionHeaderLine: "Today, 17:04 · 42 min · 14.8 km",
                sessionDurationLabel: "42:10",
                sessionLoad: 48
            ),
            .init(kind: .log, name: "Coffee", detail: "07:20", value: "", symbol: .cup),
            .init(kind: .log, name: "Water", detail: "09:40 · 11:15", value: "×2", symbol: .drop),
            .init(kind: .log, name: "Meal", detail: "12:05", value: "", symbol: .plate)
        ]),
        .init(day: "Yesterday", summary: "", items: [
            .init(kind: .sleep, name: "Slept 7h 12m", detail: "23:18 → 06:41 · 7 min over your need", value: "", symbol: .bed),
            .init(kind: .log, name: "Coffee", detail: "07:15 · 13:40", value: "×2", symbol: .cup),
            .init(kind: .log, name: "Alcohol", detail: "20:30 · one glass", value: "", symbol: .drop)
        ]),
        .init(day: "Monday 18 August", summary: "", items: [
            .init(
                kind: .session,
                name: "6 × 1 min hard",
                detail: "18:10 · 22 min · max 174 bpm",
                value: "load 86",
                symbol: .bolt,
                workout: .intervals,
                sessionHeaderLine: "Monday 18 August, 18:10 · 22 min · 7.1 km",
                sessionDurationLabel: "22:08",
                sessionLoad: 86
            ),
            .init(kind: .sleep, name: "Slept 6h 48m", detail: "23:52 → 06:40 · 24 min under", value: "", symbol: .bed),
            .init(kind: .log, name: "Nap", detail: "15:10 · 26 min", value: "", symbol: .bed)
        ]),
        .init(day: "Sunday 17 August", summary: "", items: [
            .init(
                kind: .session,
                name: "Long walk",
                detail: "10:20 · 68 min",
                value: "load 22",
                symbol: .walk,
                workout: .longWalk,
                sessionHeaderLine: "Sunday 17 August, 10:20 · 68 min",
                sessionDurationLabel: "68:00",
                sessionLoad: 22
            ),
            .init(kind: .session, name: "Strength, lower body", detail: "17:40 · 35 min", value: "load 62", symbol: .weight),
            .init(kind: .sleep, name: "Slept 7h 26m", detail: "23:05 → 06:31", value: "", symbol: .bed)
        ])
    ]
}

private enum NoopA5HistoryKind: Equatable { case session, sleep, log }

private struct NoopA5HistoryItem {
    let kind: NoopA5HistoryKind
    let name: String
    let detail: String
    let value: String
    let symbol: NoopCanonicalGlyphName
    /// Change 4. Written when the session is logged. A row without one has no record to open, keeps
    /// no chevron, and does nothing — the honest state for anything logged before this existed.
    /// Sleep rows carry no workout and open the night instead.
    var workout: NoopWorkout? = nil
    var sessionHeaderLine: String? = nil
    var sessionDurationLabel: String? = nil
    var sessionLoad: Int? = nil
    /// When the night ended, so a sleep row can open that night on Rest.
    var date: Date? = nil

    var opensSomething: Bool { kind == .sleep || workout != nil }
}

private struct NoopA5HistoryDay: Identifiable {
    let id = UUID()
    let day: String
    let summary: String
    let items: [NoopA5HistoryItem]
}

// MARK: Your strap

private extension NoopAct5Screens {
    @ViewBuilder
    var strapScreen: some View {
        if measured { liveStrapScreen } else { prototypeStrapScreen }
    }

    // MARK: Your strap, measured

    /// The strap screen over the live connection, the battery estimator, the Health bridge and the
    /// real strap-log export. Controls with no feature behind them are drawn "Later".
    var liveStrapScreen: some View {
        let connected = live.connected
        let report = health.lastWritebackReport
        let wroteKinds = report?.entries.filter { $0.count > 0 }.count ?? 0
        let relative = RelativeDateTimeFormatter()
        return NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("You") { navigation.back(or: .you) }
                pageTitle("Your strap", copy: liveStrapDetail ?? "No strap paired")

                NoopHTMLCard(radius: 24, padding: 18) {
                    VStack(spacing: 16) {
                        HStack(spacing: 18) {
                            NoopStrapBatteryRing(percent: battery, connected: connected,
                                                 daysLeft: live.batteryEstimate.map { BatteryEstimator.label(hours: $0.remainingHours) })
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(connected ? Self.green : NoopHTMLColor.faint)
                                        .frame(width: 8, height: 8)
                                        .shadow(color: connected ? Self.green.opacity(0.7) : .clear, radius: 5)
                                    Text(connected ? "Connected and reading" : "Disconnected")
                                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                }
                                strapFact("Secure link", connected && live.encryptedBond ? "Encrypted" : "\u{2014}")
                                strapFact("On wrist", connected ? (live.worn ? "Yes" : "No") : "\u{2014}")
                            }
                        }
                        NoopStrapSyncButton(connected: connected,
                                            sync: { model.ble.syncNow() },
                                            reconnect: { model.ble.connectFromSystem() })
                    }
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(spacing: 11) {
                            NoopCanonicalGlyph(name: .heart, size: 20, color: Self.green).frame(width: 21)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Health").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                Text(health.auth != .authorized ? "not connected"
                                     : report.map { "wrote \(wroteKinds) kinds \u{00B7} \(relative.localizedString(for: $0.completedAt, relativeTo: Date()))" }
                                        ?? "connected")
                                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            Spacer()
                            NoopHTMLToggle(isOn: health.auth == .authorized, color: Self.green) {
                                if health.auth != .authorized { Task { await health.requestAuthorization() } }
                            }
                        }
                        NoopFlowLayout(spacing: 6) {
                            ForEach(["Sleep", "Workouts", "Heart rate", "HRV", "Respiration", "Body temp"], id: \.self) { kind in
                                Text(kind)
                                    .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .medium))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 27)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                            }
                        }
                        let authorized = health.auth == .authorized
                        Button {
                            guard authorized, !health.syncing else { return }
                            Task { _ = await health.sync() }
                        } label: {
                            Text(!authorized ? "Turn on Apple Health to sync" : "Sync Apple Health now")
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(authorized ? Color(hex: 0x8FE3B4) : NoopHTMLColor.faint)
                                .frame(maxWidth: .infinity).frame(minHeight: 46)
                                .background(authorized ? Self.green.opacity(0.13) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(authorized ? Self.green.opacity(0.36) : Color.white.opacity(0.08), lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .disabled(!authorized)
                        Text("Noop writes to Health and never reads your Health history back in — the only exception is your phone's step count, which fills days the strap could not estimate.")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                        Button { navigation.push(.apple) } label: {
                            HStack(spacing: 12) {
                                Text("What crossed, and what did not")
                                    .font(NoopHTMLFont.sans(NoopType.footnote))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                Spacer(minLength: 8)
                                NoopChevron()
                            }
                            .padding(.top, 13)
                            .overlay(alignment: .top) {
                                Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
                            }
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }

                dividedCard {
                    VStack(spacing: 0) {
                        toggleRow("Continuous pulse", detail: "Off means pulse only during sessions and sleep. Saves about a day and a half.")
                        Divider().overlay(NoopHTMLColor.border)
                        toggleRow("Temperature", detail: "Off costs you the skin-temperature vital and the early warning it gives. Saves about six hours.")
                        Divider().overlay(NoopHTMLColor.border)
                        toggleRow("Blood oxygen", detail: "Overnight only. Costs about four hours a week.")
                        Divider().overlay(NoopHTMLColor.border)
                        toggleRow("Stay connected in the background", detail: "Off and Noop only reads when you open it — you lose live heart rate and the nightly backfill runs late.")
                    }
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            Text("Buzz strength").font(NoopHTMLFont.sans(NoopType.footnote))
                            Spacer()
                            NoopLaterChip()
                        }
                        Button {
                            guard connected else { return }
                            model.ble.buzzStrapOnce()
                            pinged = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { pinged = false }
                        } label: {
                            Text(pinged ? "Buzzing now — follow the sound" : "Buzz the strap to find it")
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(pinged ? NoopHTMLColor.blueLight : NoopHTMLColor.inkSoft)
                                .frame(maxWidth: .infinity).frame(minHeight: 46)
                                .background(pinged ? NoopHTMLColor.blue.opacity(0.18) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(pinged ? NoopHTMLColor.blue.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .disabled(!connected)
                        .opacity(connected ? 1 : 0.38)
                    }
                }

                Button { navigation.push(.notifs) } label: {
                    HStack(spacing: 13) {
                        NoopCanonicalGlyph(name: .bell, size: 19, color: Self.blush)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Buzz for phone notifications")
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("designed · not built yet")
                                .font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                        }
                        Spacer(minLength: 8)
                        NoopChevron()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("Strap log")
                        HStack(spacing: 8) {
                            logButton("Copy", symbol: "doc.on.doc", done: lastLogAction == "Copied") {
                                if let url = ScheduledDebugExport.runNow(),
                                   let text = try? String(contentsOf: url, encoding: .utf8) {
                                    UIPasteboard.general.string = text
                                    lastLogAction = "Copied"
                                }
                            }
                            logButton("Save…", symbol: "square.and.arrow.up", done: lastLogAction == "Saved") {
                                if let url = ScheduledDebugExport.runNow() {
                                    FileExport.exportFile(at: url)
                                    lastLogAction = "Saved"
                                }
                            }
                        }
                        Divider().overlay(NoopHTMLColor.border)
                        HStack(spacing: 13) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Save one copy a day").font(NoopHTMLFont.sans(NoopType.footnote))
                                Text("A timestamped file at 22:00, on this phone. Off by default.")
                                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                            }
                            Spacer()
                            NoopHTMLToggle(isOn: dailyLogOn) {
                                dailyLogOn.toggle()
                                if dailyLogOn { ScheduledDebugExport.setTimeMinutes(22 * 60) }
                                ScheduledDebugExport.setEnabled(dailyLogOn)
                            }
                        }
                        Text("Send this log when a sync or a reading looks wrong. It is the one thing that makes a bug report answerable.")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    }
                }

                NoopHTMLRow(title: "Manage straps",
                            detail: pairedStrapCount == 1 ? "one band paired" : "\(pairedStrapCount) bands paired",
                            symbol: "link", value: nil) {
                    navigation.push(.devices)
                }

                Button {
                    if connected { model.ble.disconnect() } else { model.ble.connectFromSystem() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: connected ? "xmark.circle" : "arrow.triangle.2.circlepath")
                        Text(connected ? "Disconnect this strap" : "Reconnect")
                    }
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    .foregroundStyle(connected ? Color(hex: 0xF3A472) : NoopHTMLColor.blueLight)
                    .frame(maxWidth: .infinity).frame(minHeight: 50)
                    .background((connected ? NoopHTMLColor.amber : NoopHTMLColor.blue).opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke((connected ? NoopHTMLColor.amber : NoopHTMLColor.blue).opacity(0.26), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                Text("Every switch here says what it costs you in battery, because that is the only reason anyone turns one off.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
            }
        }
    }

    var pairedStrapCount: Int { model.deviceRegistry?.devices.count ?? 0 }

    var prototypeStrapScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("You") { navigation.back(or: .you) }
                pageTitle("Your strap", copy: "\(activeStrapName) · left wrist")

                NoopHTMLCard(radius: 24, padding: 18) {
                    VStack(spacing: 16) {
                        HStack(spacing: 18) {
                            NoopStrapBatteryRing(percent: activeStrapBattery)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(connected ? Self.green : NoopHTMLColor.faint)
                                        .frame(width: 8, height: 8)
                                        .shadow(color: connected ? Self.green.opacity(0.7) : .clear, radius: 5)
                                    Text(connected ? "Connected and reading" : "Disconnected")
                                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                }
                                strapFact("Secure link", connected ? "Encrypted" : "—")
                                strapFact("On wrist", connected ? "Yes, worn since 06:38" : "No")
                            }
                        }
                        Button {
                            guard connected else { connected = true; return }
                            syncStage = min(2, syncStage + 1)
                        } label: {
                            HStack(spacing: 9) {
                                Image(systemName: syncStage == 2 ? "checkmark" : "arrow.triangle.2.circlepath")
                                Text(syncStage == 0 ? "Sync now" : syncStage == 1 ? "Syncing — 3 nights buffered" : "Up to date, just now")
                            }
                            .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                            .foregroundStyle(syncStage == 0 ? NoopHTMLColor.blueInk : syncStage == 2 ? Color(hex: 0x8FE3B4) : NoopHTMLColor.blueLight)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 52)
                            .background(syncStage == 0 ? NoopHTMLColor.blue : syncStage == 2 ? Self.green.opacity(0.12) : NoopHTMLColor.blue.opacity(0.16), in: RoundedRectangle(cornerRadius: 17))
                            .overlay(RoundedRectangle(cornerRadius: 17).stroke(syncStage == 0 ? .clear : syncStage == 2 ? Self.green.opacity(0.36) : NoopHTMLColor.blue.opacity(0.4), lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(spacing: 11) {
                            NoopCanonicalGlyph(name: .heart, size: 20, color: Self.green).frame(width: 21)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apple Health").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                Text(isEnabled("Apple Health") ? (healthSyncStage > 0 ? "wrote 6 kinds · just now" : "wrote 6 kinds · 2 hours ago") : "not connected")
                                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            Spacer()
                            NoopHTMLToggle(isOn: isEnabled("Apple Health"), color: Self.green) { flip("Apple Health") }
                        }
                        NoopFlowLayout(spacing: 6) {
                            ForEach(["Sleep", "Workouts", "Heart rate", "HRV", "Respiration", "Body temp"], id: \.self) { kind in
                                Text(kind)
                                    .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .medium))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                                    .padding(.horizontal, 10)
                                    .frame(minHeight: 27)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                            }
                        }
                        Button {
                            guard isEnabled("Apple Health") else { return }
                            healthSyncStage = min(2, healthSyncStage + 1)
                        } label: {
                            Text(!isEnabled("Apple Health") ? "Turn on Apple Health to sync" : healthSyncStage == 0 ? "Sync Apple Health now" : "Written — 6 kinds, 221 nights")
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(isEnabled("Apple Health") ? Color(hex: 0x8FE3B4) : NoopHTMLColor.faint)
                                .frame(maxWidth: .infinity).frame(minHeight: 46)
                                .background(isEnabled("Apple Health") ? Self.green.opacity(healthSyncStage == 0 ? 0.13 : 0.2) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(isEnabled("Apple Health") ? Self.green.opacity(0.36) : Color.white.opacity(0.08), lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .disabled(!isEnabled("Apple Health"))
                        Text("Noop writes to Health and never reads your Health history back in — the only exception is your phone's step count, which fills days the strap could not estimate.")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                        Button { navigation.push(.apple) } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("What crossed, and what did not")
                                        .font(NoopHTMLFont.sans(NoopType.footnote))
                                        .foregroundStyle(NoopHTMLColor.ink)
                                    Text(healthAccessFixed
                                         ? "Six kinds out, steps in. Everything is crossing."
                                         : "One kind is being refused — variability has never reached Health")
                                        .font(NoopHTMLFont.sans(NoopType.caption))
                                        .foregroundStyle(healthAccessFixed ? Color(hex: 0x7F8A85) : Color(hex: 0xC8934B))
                                        .lineSpacing(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 8)
                                NoopChevron()
                            }
                            .padding(.top, 13)
                            .overlay(alignment: .top) {
                                Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
                            }
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }

                dividedCard {
                    VStack(spacing: 0) {
                        toggleRow("Continuous pulse", detail: "Off means pulse only during sessions and sleep. Saves about a day and a half.")
                        Divider().overlay(NoopHTMLColor.border)
                        toggleRow("Temperature", detail: "Off costs you the skin-temperature vital and the early warning it gives. Saves about six hours.")
                        Divider().overlay(NoopHTMLColor.border)
                        toggleRow("Blood oxygen", detail: "Overnight only. Costs about four hours a week.")
                        Divider().overlay(NoopHTMLColor.border)
                        toggleRow("Stay connected in the background", detail: "Off and Noop only reads when you open it — you lose live heart rate and the nightly backfill runs late.")
                    }
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            Text("Buzz strength").font(NoopHTMLFont.sans(NoopType.footnote))
                            Spacer()
                            Text(buzz == "Light" ? "easy to miss on a cold wrist" : buzz == "Normal" ? "enough to notice, not to startle" : "you will not miss it")
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                        }
                        NoopSegmentedControl(items: ["Light", "Normal", "Firm"], selection: buzz) { buzz = $0 }
                        Button {
                            pinged = true
                        } label: {
                            Text(pinged ? "Buzzing now — follow the sound" : "Buzz the strap to find it")
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(pinged ? NoopHTMLColor.blueLight : NoopHTMLColor.inkSoft)
                                .frame(maxWidth: .infinity).frame(minHeight: 46)
                                .background(pinged ? NoopHTMLColor.blue.opacity(0.18) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(pinged ? NoopHTMLColor.blue.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }

                Button { navigation.push(.notifs) } label: {
                    HStack(spacing: 13) {
                        NoopCanonicalGlyph(name: .bell, size: 19, color: Self.blush)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Buzz for phone notifications")
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("designed · not built yet")
                                .font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                        }
                        Spacer(minLength: 8)
                        NoopChevron()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("Strap log")
                        HStack(spacing: 8) {
                            logButton("Copy", symbol: "doc.on.doc", done: lastLogAction == "Copied") { lastLogAction = "Copied" }
                            logButton("Save…", symbol: "square.and.arrow.up", done: lastLogAction == "Saved") { lastLogAction = "Saved" }
                        }
                        Divider().overlay(NoopHTMLColor.border)
                        HStack(spacing: 13) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Save one copy a day").font(NoopHTMLFont.sans(NoopType.footnote))
                                Text("A timestamped file at 22:00, on this phone. Off by default.")
                                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                            }
                            Spacer()
                            NoopHTMLToggle(isOn: isEnabled("Save one copy a day")) { flip("Save one copy a day") }
                        }
                        Text("Send this log when a sync or a reading looks wrong. It is the one thing that makes a bug report answerable.")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    }
                }

                NoopHTMLRow(title: "Manage straps", detail: sparePresent ? "two bands paired · one connected" : "one band paired", symbol: "link", value: nil) {
                    navigation.push(.devices)
                }

                Button {
                    connected.toggle()
                    if connected { activeDevice = "mg" }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: connected ? "xmark.circle" : "arrow.triangle.2.circlepath")
                        Text(connected ? "Disconnect this strap" : "Reconnect")
                    }
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    .foregroundStyle(connected ? Color(hex: 0xF3A472) : NoopHTMLColor.blueLight)
                    .frame(maxWidth: .infinity).frame(minHeight: 50)
                    .background((connected ? NoopHTMLColor.amber : NoopHTMLColor.blue).opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke((connected ? NoopHTMLColor.amber : NoopHTMLColor.blue).opacity(0.26), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                Text("Every switch here says what it costs you in battery, because that is the only reason anyone turns one off.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
            }
        }
    }

    func strapFact(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
            Spacer()
            Text(value).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.inkSoft).multilineTextAlignment(.trailing)
        }
    }

    func logButton(_ label: String, symbol: String, done: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(done ? (label == "Copy" ? "Copied" : "Saved") : label, systemImage: done ? "checkmark" : symbol)
                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                .foregroundStyle(done ? Color(hex: 0x8FE3B4) : NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity).frame(minHeight: 46)
                .background(done ? Self.green.opacity(0.12) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(done ? Self.green.opacity(0.34) : Color.white.opacity(0.11), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

// MARK: Buzz for notifications

private extension NoopAct5Screens {
    var notificationsScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("Your strap") { navigation.back(or: .strap) }
                pageTitle(
                    "Buzz for notifications",
                    copy: "Your phone decides what arrives. You decide what is worth your wrist."
                )

                VStack(alignment: .leading, spacing: 13) {
                    HStack(spacing: 13) {
                        NoopCanonicalGlyph(name: .bell, size: 22, color: NoopHTMLColor.muted)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Mirroring is not built yet")
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("iOS only hands notifications to a paired accessory over ANCS, and the strap does not consume it today. Everything below is the decided design, held here so you can see what it will ask for — no permission is requested and nothing is saved.")
                                .font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .lineSpacing(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Text("Later")
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(NoopHTMLColor.muted)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 15))
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                }
                .padding(16)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 13) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mirror phone notifications")
                                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.ink)
                            Text("Not available. Noop still buzzes for its own things — bedtime, sessions, battery.")
                                .font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .lineSpacing(3)
                        }
                        Spacer(minLength: 8)
                        laterChip
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))

                    VStack(alignment: .leading, spacing: 8) {
                        NoopSectionLabel("Which ones reach your wrist")
                            .padding(.horizontal, 4)
                        dividedCard {
                            ForEach(Array(notificationApps.enumerated()), id: \.offset) { index, item in
                                notificationToggleRow(item.0, detail: item.1)
                                if index < notificationApps.count - 1 {
                                    Divider().overlay(NoopHTMLColor.border)
                                }
                            }
                        }
                        Text("Nothing in this list reaches your wrist while mirroring is unbuilt. The defaults are the intent: chat and calls through, feeds and newsletters not.")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .lineSpacing(3)
                            .padding(.horizontal, 4)
                    }

                    NoopHTMLCard(radius: 22, padding: 16) {
                        VStack(alignment: .leading, spacing: 11) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("How it buzzes").font(NoopHTMLFont.sans(NoopType.footnote))
                                Spacer()
                                Text(notificationBuzz == "One buzz" ? "easy to miss, easy to live with" : notificationBuzz == "Long" ? "hard to miss, harder to ignore" : "the one people keep")
                                    .font(NoopHTMLFont.sans(NoopType.caption))
                                    .foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            NoopSegmentedControl(items: ["One buzz", "Two short", "Long"], selection: notificationBuzz) {
                                notificationBuzz = $0
                            }
                            Text("Feel it on the strap")
                                .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
                        }
                    }

                    dividedCard {
                        ForEach(Array(notificationConditions.enumerated()), id: \.offset) { index, item in
                            notificationToggleRow(item.0, detail: item.1)
                            if index < notificationConditions.count - 1 {
                                Divider().overlay(NoopHTMLColor.border)
                            }
                        }
                    }

                    Text("When this is built, Noop will never read what a notification says — only which app sent it, so it knows whether to buzz. Nothing on this page is stored or synced today.")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4)
                        .padding(.horizontal, 2)
                }
                .opacity(0.38)
                .allowsHitTesting(false)
            }
        }
    }

    var laterChip: some View {
        Text("LATER")
            .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(NoopHTMLColor.muted)
            .padding(.horizontal, 10)
            .frame(minHeight: 24)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
    }

    var notificationApps: [(String, String)] {
        [
            ("Messages", "Anyone who can already reach you. A group thread counts once."),
            ("Phone calls", "Incoming only, and only while it is still ringing."),
            ("Calendar", "The ten-minute warning, not the invitation."),
            ("WhatsApp", "Direct messages and mentions. Not every group line."),
            ("Mail", "Noisy by nature. Off is the honest default."),
            ("Slack", "Held outside your active hours whatever you pick here."),
            ("Reminders", "The ones with a time on them."),
            ("Everything else", "One buzz for any other app your phone already allows.")
        ]
    }

    var notificationConditions: [(String, String)] {
        [
            ("Only when the phone is locked", "If you are already looking at the screen, your wrist adds nothing."),
            ("Follow iPhone Focus", "Sleep, Work and Do Not Disturb all apply here first."),
            ("Hold them during quiet hours", "Nothing between your bedtime anchor and your usual wake."),
            ("Repeat once after two minutes", "One more buzz if you have not picked the phone up.")
        ]
    }

    func notificationToggleRow(_ title: String, detail: String) -> some View {
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NoopHTMLFont.sans(NoopType.footnote))
                    .foregroundStyle(NoopHTMLColor.ink)
                Text(detail)
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .lineSpacing(3)
            }
            Spacer(minLength: 8)
            NoopA5TintToggle(isOn: isEnabled(title), tint: Self.blush) { }
        }
        .padding(.vertical, 13)
    }
}

// MARK: Apple Health

private extension NoopAct5Screens {
    @ViewBuilder var appleHealthScreen: some View {
        if measured { liveAppleHealthScreen } else { prototypeAppleHealthScreen }
    }

    /// Apple Health over the bridge's own last write-back: one row per group it wrote, the count it
    /// wrote and whether iOS let every kind in the group through. The HTML's per-kind lifetime totals,
    /// the step-source chart and the "Health holds these" list have no source in the bridge.
    var liveAppleHealthScreen: some View {
        let report = health.lastWritebackReport
        let refused = report?.entries.filter { $0.authorizedTypes < $0.totalTypes } ?? []
        return NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                act5BackHeader("Your strap") { navigation.back(or: .strap) }
                pageTitle("Apple Health", copy: "")

                VStack(alignment: .leading, spacing: 5) {
                    Text("An imported score never becomes your score")
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueLight)
                    Text("Another app\u{2019}s readiness or sleep score is kept under its own name and is never shown as Charge, Effort or Rest. Noop recomputes its own from the raw pulse, variability and sleep it can see.")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0xB7C3C9))
                        .lineSpacing(3)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 14)
                .background(NoopHTMLColor.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.blue.opacity(0.20), lineWidth: 0.5))

                if let report, !report.entries.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            NoopSectionLabel("Every kind, and what happened to it")
                            Spacer()
                            Text(refused.isEmpty ? "all crossing" : "\(refused.count) needs you")
                                .font(NoopHTMLFont.sans(NoopType.eyebrow))
                                .foregroundStyle(NoopHTMLColor.faint)
                        }
                        .padding(.horizontal, 2)
                        dividedCard {
                            ForEach(Array(report.entries.enumerated()), id: \.offset) { index, entry in
                                let blocked = entry.authorizedTypes < entry.totalTypes
                                appleKindRow(AppleKind(title: entry.id,
                                                       value: blocked ? "refused" : entry.count.formatted(),
                                                       copy: "", state: blocked ? -1 : entry.count > 0 ? 1 : 0),
                                             openHealth: true)
                                if index < report.entries.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                            }
                        }
                        Text("iOS never tells an app that a read was refused \u{2014} a denied kind and a kind with no data look identical from in here. That is why this page counts what was written rather than claiming everything worked.")
                            .font(NoopHTMLFont.sans(NoopType.caption))
                            .foregroundStyle(NoopHTMLColor.faint)
                            .lineSpacing(4)
                            .padding(.horizontal, 2)
                    }
                }

                Button { navigation.enter(.importHistory, from: .data) } label: {
                    HStack(spacing: 13) {
                        NoopCanonicalGlyph(name: .upload, size: 19, color: NoopHTMLColor.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bring history in").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                            Text("the one-time import \u{2014} a Health export, or any of the other eleven formats")
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
                        }
                        Spacer(minLength: 8)
                        NoopChevron()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())
                .padding(.bottom, 22)
            }
        }
        .task {
            // The report lives for the session; the page is where someone looks for it, so write once.
            guard health.auth == .authorized, health.lastWritebackReport == nil, !health.syncing else { return }
            _ = await health.sync()
        }
    }

    var prototypeAppleHealthScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                act5BackHeader("Your strap") { navigation.back(or: .strap) }
                pageTitle(
                    "Apple Health",
                    copy: "A two-way bridge — six kinds out, one in — and the only place to look when a kind stops crossing."
                )

                HStack(spacing: 10) {
                    appleSummaryTile(
                        eyebrow: "Noop writes",
                        value: healthAccessFixed ? "Six kinds" : "Five of six",
                        copy: healthAccessFixed
                            ? "sleep, workouts, pulse, resting pulse, variability and respiration"
                            : "one is being refused, and it is the one the night is built on"
                    )
                    appleSummaryTile(
                        eyebrow: "Noop takes",
                        value: "One",
                        copy: "steps, and only on days the strap could not estimate them"
                    )
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("An imported score never becomes your score")
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueLight)
                    Text("Another app’s readiness or sleep score is kept under its own name and is never shown as Charge, Effort or Rest. Noop recomputes its own from the raw pulse, variability and sleep it can see.")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0xB7C3C9))
                        .lineSpacing(3)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 14)
                .background(NoopHTMLColor.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.blue.opacity(0.20), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        NoopSectionLabel("Every kind, and what happened to it")
                        Spacer()
                        Text(healthAccessFixed ? "all crossing" : "1 needs you")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow))
                            .foregroundStyle(NoopHTMLColor.faint)
                    }
                    .padding(.horizontal, 2)

                    dividedCard {
                        ForEach(Array(appleKinds.enumerated()), id: \.offset) { index, item in
                            appleKindRow(item)
                            if index < appleKinds.count - 1 {
                                Divider().overlay(NoopHTMLColor.border)
                            }
                        }
                    }

                    Text("iOS never tells an app that a read was refused — a denied kind and a kind with no data look identical from in here. That is why this page counts what was written rather than claiming everything worked.")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4)
                        .padding(.horizontal, 2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    NoopSectionLabel("Where your steps came from")
                        .padding(.horizontal, 2)
                    NoopHTMLCard(radius: 22, padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .bottom, spacing: 3) {
                                ForEach(Array(appleStepBars.enumerated()), id: \.offset) { index, value in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill([2, 7, 11].contains(index) ? Color(hex: 0x5B7C8D) : NoopHTMLColor.blue)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: value / 13.1 * 60)
                                }
                            }
                            .frame(height: 60, alignment: .bottom)
                            HStack(spacing: 14) {
                                appleLegend("the strap", color: NoopHTMLColor.blue)
                                appleLegend("your phone, through Health", color: Color(hex: 0x5B7C8D))
                            }
                            Text("Three of the last fourteen days came from the phone — days the strap was off your wrist or charging. Nothing else on this page fills a gap that way.")
                                .font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(Color(hex: 0x8B958F))
                                .lineSpacing(3)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    NoopSectionLabel("Health holds these, Noop does not use them")
                        .padding(.horizontal, 2)
                    dividedCard {
                        ForEach(Array(appleUnused.enumerated()), id: \.offset) { index, item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.0).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.inkSoft)
                                    Text(item.2).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
                                }
                                Spacer(minLength: 8)
                                Text(item.1).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x8B958F)).monospacedDigit()
                            }
                            .padding(.vertical, 13)
                            if index < appleUnused.count - 1 { Divider().overlay(NoopHTMLColor.border) }
                        }
                    }
                    Text("To bring any of this in as history rather than as a live feed, hand the Health export to Bring history in — it reads the same file and tells you what it wrote.")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4)
                        .padding(.horizontal, 2)
                }

                Button { navigation.enter(.importHistory, from: .data) } label: {
                    HStack(spacing: 13) {
                        NoopCanonicalGlyph(name: .upload, size: 19, color: NoopHTMLColor.blue)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bring history in").font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                            Text("the one-time import — a Health export, or any of the other eleven formats")
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
                        }
                        Spacer(minLength: 8)
                        NoopChevron()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())
                .padding(.bottom, 22)
            }
        }
    }

    struct AppleKind {
        let title: String
        let value: String
        let copy: String
        let state: Int
    }

    var appleKinds: [AppleKind] {
        [
            AppleKind(title: "Sleep", value: "221 nights", copy: "Written after each night is sorted. Last at 07:14 today.", state: 1),
            AppleKind(title: "Workouts", value: "148 sessions", copy: "Written when a session ends. Last yesterday, 18:22.", state: 1),
            AppleKind(title: "Heart rate", value: "62,410 samples", copy: "Every sample the strap took, at the strap’s own rate.", state: 1),
            AppleKind(title: "Resting heart rate", value: "221 days", copy: "One figure a day, from the night rather than from the morning.", state: 1),
            healthAccessFixed
                ? AppleKind(title: "Heart rate variability", value: "221 nights", copy: "Allowed. Written with the night it belongs to.", state: 1)
                : AppleKind(title: "Heart rate variability", value: "refused", copy: "iOS is refusing this one, so 221 nights of variability have never reached Health. Nothing is lost in Noop — it is only missing on the other side.", state: -1),
            AppleKind(title: "Respiratory rate", value: "219 nights", copy: "Two nights had too little clean signal to write anything.", state: 1),
            AppleKind(title: "Body temperature", value: "not asked", copy: "Noop asks for a kind the first time it has something to write. It has not needed this one yet.", state: 0)
        ]
    }

    var appleStepBars: [CGFloat] { [8.4, 11.2, 6.1, 9.8, 12.4, 7.2, 10.1, 5.4, 11.9, 9.2, 13.1, 8.8, 10.6, 11.4] }

    var appleUnused: [(String, String, String)] {
        [
            ("VO₂ max", "48.2", "from your watch — Noop works its own out from your sessions and shows that one instead"),
            ("Weight", "74.2 kg", "from a scale app. Your record holds 74.0, and Your record is what Noop uses."),
            ("Body fat", "17.4%", "nothing in Noop reads this yet"),
            ("Lean mass", "61.3 kg", "nothing in Noop reads this yet")
        ]
    }

    func appleSummaryTile(eyebrow: String, value: String, copy: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            NoopSectionLabel(eyebrow)
            Text(value)
                .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light))
                .tracking(-0.78)
                .foregroundStyle(NoopHTMLColor.ink)
            Text(copy)
                .font(NoopHTMLFont.sans(NoopType.caption))
                .foregroundStyle(Color(hex: 0x7F8A85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 15)
        .padding(.horizontal, 15)
        .padding(.bottom, 13)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    func appleKindRow(_ item: AppleKind, openHealth: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(item.state < 0 ? NoopHTMLColor.warm : item.state == 0 ? Color.white.opacity(0.16) : Self.green)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(item.title).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.ink)
                    Spacer(minLength: 8)
                    Text(item.value)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(item.state < 0 ? NoopHTMLColor.warm : Color(hex: 0x8B958F))
                        .monospacedDigit()
                }
                if !item.copy.isEmpty {
                Text(item.copy)
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(item.state < 0 ? Color(hex: 0xC8934B) : Color(hex: 0x7F8A85))
                    .lineSpacing(3)
                }
                if item.state < 0 {
                    Button {
                        if openHealth, let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        } else {
                            healthAccessFixed = true
                        }
                    } label: {
                        Text("Open Health → Noop")
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.warm)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(NoopHTMLColor.warm.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(NoopHTMLColor.warm.opacity(0.34), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 13)
    }

    func appleLegend(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(title).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x7F8A85))
        }
    }
}

// MARK: Automations

private extension NoopAct5Screens {
    var automationsScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("Settings") { navigation.back(or: .settings) }
                pageTitle(
                    "Automations",
                    copy: "What the strap reports and what Noop does about it. Each row says what it costs you — a buzz or an interruption — and the footnote says where each one runs."
                )

                automationGroup("The strap as a button", note: "the phone may stay locked") {
                    segmentRow("Double tap", detail: "two firm taps on the face, any time", choices: ["Sleep mark", "Log water", "Nothing"])
                    Divider().overlay(NoopHTMLColor.border)
                    automationSegment("When it comes off", detail: "the moment the skin contact breaks", choices: ["Nothing", "Lock the phone", "Run a Shortcut"])
                    Divider().overlay(NoopHTMLColor.border)
                    automationSegment("When it goes back on", detail: "and it knows loose from off", choices: ["Nothing", "Run a Shortcut"])
                    // iOS cannot lock the phone for an app, and the design has no field to name the
                    // Shortcut, so in production both rows are Later rather than choices that do nothing.
                }

                automationGroup("Quietly, in the background", note: "each one costs a buzz you did not ask for") {
                    toggleRow("Move reminder", detail: "Buzzes the strap after 45 minutes still, inside your active hours only. Never during a session, never after your anchor.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Stress check-ins", detail: "A passive haptic when stress holds high for twenty minutes. Off by default, because most people find it lands at the worst moment.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Illness early warning", detail: "Watches four signals against your own 28-day normal and says what it ruled out first. It appears in the charge ledger, priced like any other drain — it never takes over the screen.", tint: Self.blush)
                }

                automationGroup("A ceiling, and a nudge", note: "") {
                    VStack(alignment: .leading, spacing: 0) {
                        toggleRow("Buzz if I go over", detail: "One buzz when you cross it, then nothing until you have been under for a full minute.", tint: Self.blush)
                        if isEnabled("Buzz if I go over") {
                            Divider().overlay(NoopHTMLColor.border)
                            VStack(alignment: .leading, spacing: 11) {
                                automationBareSegment(["Profile zone", "Fixed bpm"], selection: shownCeilingMode) { setCeilingMode($0) }
                                if shownCeilingMode == "Profile zone" {
                                    automationBareSegment(["Zone 3", "Zone 4", "Zone 5"], selection: shownCeilingZone) { setCeilingZone($0) }
                                } else {
                                    HStack(spacing: 18) {
                                        Spacer()
                                        automationStepButton(plus: false) { setCeilingBPM(shownCeilingBPM - 2) }
                                        Text("\(shownCeilingBPM) bpm")
                                            .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light))
                                            .tracking(-0.9)
                                            .monospacedDigit()
                                            .frame(minWidth: 104)
                                        automationStepButton(plus: true) { setCeilingBPM(shownCeilingBPM + 2) }
                                        Spacer()
                                    }
                                }
                                if let armsAt = resolvedCeilingBPMShown {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("ARMS AT \(armsAt) BPM")
                                        .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                                        .tracking(1)
                                        .foregroundStyle(Self.blushLight)
                                    Text(shownCeilingMode == "Profile zone"
                                         ? "\(shownCeilingZone) starts at \(armsAt) bpm on your record. It arms with that number, and it moves if your maximum does."
                                         : "It arms with exactly this number, whatever your zones do later.")
                                        .font(NoopHTMLFont.sans(NoopType.caption))
                                        .foregroundStyle(Color(hex: 0xC9BEC0))
                                        .lineSpacing(3)
                                }
                                .padding(.horizontal, 13)
                                .padding(.vertical, 11)
                                .background(Self.blush.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Self.blush.opacity(0.20), lineWidth: 0.5))
                                }
                            }
                            .padding(.vertical, 13)
                        }
                        Divider().overlay(NoopHTMLColor.border)
                        toggleRow("Target-zone coach", detail: "While a session runs: one tap means you are in the zone, two means push, three means ease off. It is the only thing in Noop that buzzes more than once.", tint: Self.blush)
                    }
                }

                Text("Everything here runs through Noop rather than on the strap: the strap reports, the app decides, and the app buzzes it back. Each one needs Noop running; background delivery is best effort because iOS may suspend it. Nothing on this page claims strap-firmware support.")
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .lineSpacing(4)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 20)
            }
        }
    }

    // Production reads and writes the ceiling `AppModel` arms from; the prototype keeps its own state.
    var shownCeilingMode: String {
        guard measured else { return ceilingMode }
        return behavior.hrCeilingThresholdMode == .bpm ? "Fixed bpm" : "Profile zone"
    }
    func setCeilingMode(_ value: String) {
        guard measured else { ceilingMode = value; return }
        behavior.hrCeilingThresholdMode = value == "Fixed bpm" ? .bpm : .zone
    }
    /// The zone it arms at is the one above the highest allowed zone.
    var shownCeilingZone: String {
        guard measured else { return ceilingZone }
        return "Zone \(min(max(behavior.hrCeilingAllowedZone, 1), 4) + 1)"
    }
    func setCeilingZone(_ value: String) {
        guard measured else { ceilingZone = value; return }
        behavior.hrCeilingAllowedZone = (Int(value.dropFirst(5)) ?? 5) - 1
    }
    var shownCeilingBPM: Int { measured ? behavior.hrCeilingBPM : ceilingBPM }
    func setCeilingBPM(_ value: Int) {
        let clamped = min(200, max(120, value))
        if measured { behavior.hrCeilingBPM = clamped } else { ceilingBPM = clamped }
    }
    /// Where it arms: the lower edge of the chosen zone on the wearer's own zones (nil until those are
    /// the wearer's), or the fixed number.
    var resolvedCeilingBPMShown: Int? {
        guard measured else { return resolvedCeilingBPM }
        if behavior.hrCeilingThresholdMode == .bpm { return behavior.hrCeilingBPM }
        guard profileConfirmed || profile.hrMaxOverride > 0 || profile.hasCustomHRZones else { return nil }
        let zones = profile.hrZoneSet.zones
        let index = min(max(behavior.hrCeilingAllowedZone, 1), 4)
        return zones.indices.contains(index) ? Int(zones[index].lower.rounded()) : nil
    }

    var resolvedCeilingBPM: Int {
        guard ceilingMode == "Profile zone" else { return ceilingBPM }
        switch ceilingZone {
        case "Zone 3": return 148
        case "Zone 5": return 176
        default: return 162
        }
    }

    func automationGroup<Content: View>(_ title: String, note: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                NoopSectionLabel(title)
                Spacer(minLength: 8)
                if !note.isEmpty {
                    Text(note)
                        .font(NoopHTMLFont.sans(NoopType.eyebrow))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(.horizontal, 2)
            dividedCard { content() }
        }
    }

    func automationSegment(_ title: String, detail: String, choices: [String]) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title).font(NoopHTMLFont.sans(NoopType.footnote))
                Spacer()
                if measured {
                    NoopLaterChip()
                } else {
                    Text(detail).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x7F8A85))
                }
            }
            if !measured {
                automationBareSegment(choices, selection: preferences[title] ?? choices[0]) { preferences[title] = $0 }
            }
        }
        .padding(.vertical, 13)
    }

    func automationBareSegment(_ choices: [String], selection: String, action: @escaping (String) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach(choices, id: \.self) { choice in
                Button { action(choice) } label: {
                    Text(choice)
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: choice == selection ? .semibold : .regular))
                        .foregroundStyle(choice == selection ? Self.blushLight : NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .background(choice == selection ? Self.blush.opacity(0.20) : .clear, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(choice == selection ? Self.blush.opacity(0.42) : .clear, lineWidth: 0.5))
                }
                .buttonStyle(NoopPlainHitStyle())
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14))
    }

    func automationStepButton(plus: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Capsule().fill(NoopHTMLColor.inkSoft).frame(width: 11, height: 1.6)
                if plus { Capsule().fill(NoopHTMLColor.inkSoft).frame(width: 1.6, height: 11) }
            }
            .frame(width: 32, height: 32).noopHitTarget()
            .background(Color.white.opacity(0.06), in: Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.10), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopStrapBatteryRing: View {
    let percent: Int?
    var connected = true
    var daysLeft: String? = "~6.2 days"

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 9)
            Circle()
                .trim(from: 0, to: Double(percent ?? 0) / 100)
                .stroke(NoopHTMLColor.blue, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                if let percent {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(percent)").font(NoopHTMLFont.outfit(38, weight: .ultraLight)).tracking(-1.5).foregroundStyle(NoopHTMLColor.blue)
                        Text("%").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x8B958F))
                    }
                } else {
                    // A linked strap answers the battery read late while it sends its history; say that
                    // rather than draw "—%" beside a days-left figure, which reads as a broken gauge.
                    Text(connected ? "Checking" : "\u{2014}")
                        .font(connected ? NoopHTMLFont.sans(NoopType.footnote, weight: .medium) : NoopHTMLFont.outfit(38, weight: .ultraLight))
                        .foregroundStyle(Color(hex: 0x8B958F))
                }
                if percent != nil, let daysLeft {
                    Text(daysLeft).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x7F8A85))
                }
            }
        }
        .frame(width: 118, height: 118)
    }
}

// MARK: Manage straps

private extension NoopAct5Screens {
    @ViewBuilder
    var devicesScreen: some View {
        if measured { liveDevicesScreen } else { prototypeDevicesScreen }
    }

    // MARK: Manage straps, measured

    var liveDevices: [PairedDevice] {
        (model.deviceRegistry?.devices ?? []).filter { $0.status != .archived && $0.sourceKind == .liveBLE }
    }

    var liveDevicesScreen: some View {
        let registry = model.deviceRegistry
        let relative = RelativeDateTimeFormatter()
        return NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                act5BackHeader("Your strap") { navigation.back(or: .strap) }
                pageTitle("Manage straps", copy: "Noop can hold several bands and remembers each one's nights. Only one is connected at a time.")
                    .padding(.bottom, 5)

                VStack(spacing: 10) {
                    ForEach(liveDevices, id: \.id) { device in
                        let isActive = device.id == registry?.activeDeviceId
                        let connectedHere = isActive && live.connected
                        let meta = connectedHere
                            ? [battery.map { "\($0)%" }, live.encryptedBond ? "encrypted" : nil].compactMap { $0 }.joined(separator: " \u{00B7} ")
                            : "last seen \(relative.localizedString(for: Date(timeIntervalSince1970: TimeInterval(device.lastSeenAt)), relativeTo: Date()))"
                        liveDeviceCard(device, meta: meta, active: connectedHere, isActive: isActive)
                    }
                }

                if let deviceNotice {
                    Text(deviceNotice)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0x8FE3B4))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Self.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Self.green.opacity(0.25), lineWidth: 0.5))
                }

                Button { navigation.push(.pair) } label: {
                    Label("Pair a new strap", systemImage: "plus")
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueInk)
                        .frame(maxWidth: .infinity).frame(minHeight: 54)
                        .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 18))
                        .shadow(color: NoopHTMLColor.blue.opacity(0.26), radius: 12, y: 8)
                }
                .buttonStyle(NoopHTMLPressStyle())

                Button { model.ble.scanForWhoops() } label: {
                    Label("Re-scan for straps", systemImage: "arrow.triangle.2.circlepath")
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .frame(maxWidth: .infinity).frame(minHeight: 50)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.11), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                Text("Forgetting a strap removes the pairing, not the nights. Its history stays in your record and stays in your export.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
            }
        }
    }

    func liveDeviceCard(_ device: PairedDevice, meta: String, active: Bool, isActive: Bool) -> some View {
        let isWhoop4 = device.model.contains("4.0")
        return NoopHTMLCard(radius: 22, padding: 16, tint: active ? NoopHTMLColor.blue : nil) {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 12) {
                    NoopCanonicalGlyph(name: .watch, size: 22, color: active ? NoopHTMLColor.blue : Color(hex: 0x7F8A85))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(device.displayName).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        if !meta.isEmpty {
                            Text(meta).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                        }
                    }
                    Spacer()
                    NoopPill(text: active ? "Connected" : "Paired", color: active ? NoopHTMLColor.blueLight : NoopHTMLColor.copy)
                }
                HStack(spacing: 7) {
                    Button {
                        if active {
                            model.ble.disconnect()
                            deviceNotice = "\(device.displayName) is disconnected. Its pairing and history remain."
                        } else {
                            model.deviceRegistry?.setActive(device.id)
                            model.ble.connectFromSystem()
                            deviceNotice = "\(device.displayName) is now the connected strap."
                        }
                    } label: {
                        Text(active ? "Disconnect" : "Switch to this")
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            .foregroundStyle(active ? NoopHTMLColor.inkSoft : NoopHTMLColor.blueLight)
                            .frame(maxWidth: .infinity).frame(minHeight: 44)
                            .background(active ? Color.white.opacity(0.05) : NoopHTMLColor.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? Color.white.opacity(0.11) : NoopHTMLColor.blue.opacity(0.34), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Button {
                        // Archive, never `forget`: the registry's forget deletes the recorded nights,
                        // and the design promises the pairing goes while the history stays.
                        if isActive { model.ble.forgetDevice(device.peripheralId) }
                        model.deviceRegistry?.archive(device.id)
                        deviceNotice = "Pairing forgotten. Its history remains in your record and export."
                    } label: {
                        Text("Forget")
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xF3A472))
                            .padding(.horizontal, 18).frame(minHeight: 44)
                            .background(NoopHTMLColor.amber.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NoopHTMLColor.amber.opacity(0.26), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }
                if isWhoop4 && active {
                    HStack(spacing: 9) {
                        TextField("a name for this band", text: $renameDraft)
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .padding(.horizontal, 13).frame(height: 40)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                        Button("Rename") {
                            let value = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !value.isEmpty else { return }
                            model.ble.renameStrap(value)
                            model.deviceRegistry?.rename(device.id, to: value)
                            renameDraft = ""
                            deviceNotice = "Renamed to \(value). The strap is rebooting to apply it."
                        }
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueLight)
                        .padding(.horizontal, 15).frame(height: 40)
                        .background(NoopHTMLColor.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(NoopHTMLColor.blue.opacity(0.34), lineWidth: 0.5))
                    }
                    Text("A 4.0 can be renamed over Bluetooth — useful for a second-hand band still carrying its old owner's name. The strap reboots to apply it.")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                }
            }
        }
    }

    var prototypeDevicesScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                act5BackHeader("Your strap") { navigation.back(or: .strap) }
                pageTitle("Manage straps", copy: "Noop can hold several bands and remembers each one's nights. Only one is connected at a time.")
                    .padding(.bottom, 5)

                VStack(spacing: 10) {
                    deviceCard(
                        id: "mg",
                        name: "WHOOP 5.0 / MG",
                        meta: activeDevice == "mg" && connected ? "52% · encrypted" : "last seen 2 minutes ago",
                        renamable: false
                    )

                    if sparePresent {
                        deviceCard(
                            id: "w4",
                            name: spareName,
                            meta: "spare · last seen 11 June · 221 nights on record",
                            renamable: true
                        )
                    }
                }

                if let deviceNotice {
                    Text(deviceNotice)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0x8FE3B4))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Self.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Self.green.opacity(0.25), lineWidth: 0.5))
                }

                Button { paired = false; navigation.push(.pair) } label: {
                    Label("Pair a new strap", systemImage: "plus")
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueInk)
                        .frame(maxWidth: .infinity).frame(minHeight: 54)
                        .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 18))
                        .shadow(color: NoopHTMLColor.blue.opacity(0.26), radius: 12, y: 8)
                }
                .buttonStyle(NoopHTMLPressStyle())

                Button {
                    deviceNotice = "Search complete · \(sparePresent ? "two straps found" : "one strap found")"
                } label: {
                    Label("Re-scan for straps", systemImage: "arrow.triangle.2.circlepath")
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .frame(maxWidth: .infinity).frame(minHeight: 50)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.11), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                Text("Forgetting a strap removes the pairing, not the nights. Its history stays in your record and stays in your export.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
            }
        }
    }

    func deviceCard(id: String, name: String, meta: String, renamable: Bool) -> some View {
        let active = activeDevice == id && connected
        return NoopHTMLCard(radius: 22, padding: 16, tint: active ? NoopHTMLColor.blue : nil) {
            VStack(alignment: .leading, spacing: renamable ? 10.3 : 15) {
                HStack(spacing: 12) {
                    NoopCanonicalGlyph(
                        name: .watch,
                        size: 22,
                        color: active ? NoopHTMLColor.blue : Color(hex: 0x7F8A85)
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(name).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        Text(meta).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                    }
                    Spacer()
                    NoopPill(text: active ? "Connected" : "Paired", color: active ? NoopHTMLColor.blueLight : NoopHTMLColor.copy)
                }

                HStack(spacing: 7) {
                    Button {
                        if active {
                            connected = false
                            deviceNotice = "\(name) is disconnected. Its pairing and history remain."
                        } else {
                            activeDevice = id
                            connected = true
                            deviceNotice = "\(name) is now the connected strap."
                        }
                    } label: {
                        Text(active ? "Disconnect" : "Switch to this")
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            .foregroundStyle(active ? NoopHTMLColor.inkSoft : NoopHTMLColor.blueLight)
                            .frame(maxWidth: .infinity).frame(minHeight: 44)
                            .background(active ? Color.white.opacity(0.05) : NoopHTMLColor.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(active ? Color.white.opacity(0.11) : NoopHTMLColor.blue.opacity(0.34), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Button {
                        if id == "w4" {
                            if activeDevice == "w4" { activeDevice = "mg"; connected = true }
                            sparePresent = false
                            deviceNotice = "Pairing forgotten. Its 221 nights remain in your record and export."
                        } else if activeDevice == "mg", sparePresent {
                            deviceNotice = "Switch to the spare strap before forgetting this one. Its history will remain."
                        } else {
                            deviceNotice = "Pairing forgotten. Its history remains in your record and export."
                        }
                    } label: {
                        Text("Forget")
                            .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xF3A472))
                            .padding(.horizontal, 18).frame(minHeight: 44)
                            .background(NoopHTMLColor.amber.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(NoopHTMLColor.amber.opacity(0.26), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }

                if renamable {
                    HStack(spacing: 9) {
                        TextField("a name for this band", text: $renameDraft)
                            .font(.system(size: 12.5, design: .monospaced))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .padding(.horizontal, 13).frame(height: 40)
                            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
                        Button("Rename") {
                            let value = renameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !value.isEmpty else { return }
                            spareName = value
                            renameDraft = ""
                            deviceNotice = "Renamed to \(value). The strap is rebooting to apply it."
                        }
                        .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueLight)
                        .padding(.horizontal, 15).frame(height: 40)
                        .background(NoopHTMLColor.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(NoopHTMLColor.blue.opacity(0.34), lineWidth: 0.5))
                    }
                    Text("A 4.0 can be renamed over Bluetooth — useful for a second-hand band still carrying its old owner's name. The strap reboots to apply it.")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                }
            }
        }
    }
}

// MARK: Data and permissions

private extension NoopAct5Screens {
    func bullet(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle().fill(NoopHTMLColor.blue).frame(width: 7, height: 7).padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(NoopType.footnote))
                Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
            }
        }
    }

    func place(_ title: String, _ detail: String, glyph: NoopCanonicalGlyphName) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NoopCanonicalGlyph(name: glyph, size: 19, color: NoopHTMLColor.blue).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(NoopHTMLFont.sans(NoopType.footnote))
                Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
            }
        }
    }
}

// MARK: Settings

private extension NoopAct5Screens {
    /// Visual fixture: `--noop-route settings-strap --noop-settings-focus strap-broadcast` arrives as a
    /// search result would, scrolled to the row and glowing it.
    var settingsFixtureFocus: String? {
        #if DEBUG
        guard let index = CommandLine.arguments.firstIndex(of: "--noop-settings-focus"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
        #else
        nil
        #endif
    }

    var settingsInitialScrollID: String? {
        #if DEBUG
        CommandLine.arguments.contains("--noop-settings-icons") ? "settings-app-icon" : nil
        #else
        nil
        #endif
    }

    var settingsZoneDetail: String {
        guard measured else { return "five bands from two measured anchors" }
        switch NoopZoneSource.current(profile) {
        case .custom: return "five bands set by you"
        case .manualMax: return "five bands from the maximum you set"
        case .estimated: return "five bands from an estimated maximum"
        case .unconfirmed: return "five bands; confirm your profile to calculate the limits"
        }
    }

    var settingsScreen: some View {
        let query = navigation.settingsQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("You") { navigation.back(or: .you) }
                pageTitle("Settings", copy: "How Noop behaves, page by page. Your body and records live on You.")
                    .padding(.bottom, 5)

                settingsSearchField

                // Settings by page (26 Oct 2026): the strap card, then the pages you see, then Noop
                // itself, then the rest. Every row lives on exactly one page; search reaches all of them.
                if query.isEmpty {
                    settingsStrapCard
                        .padding(.top, 4)
                        .transition(.opacity)

                    ForEach(NoopSettingsPage.Block.allCases, id: \.self) { block in
                        VStack(alignment: .leading, spacing: 8) {
                            NoopSectionLabel(block.rawValue).padding(.horizontal, 2).padding(.top, 8)
                            dividedCard {
                                let pages = NoopSettingsPage.allCases.filter { $0.block == block }
                                ForEach(Array(pages.enumerated()), id: \.element) { index, page in
                                    if index > 0 { Divider().overlay(NoopHTMLColor.border) }
                                    settingsHubRow(page)
                                }
                            }
                        }
                        .transition(.opacity)
                    }

                    settingsVersionFooter
                        .padding(.top, 6)
                        .transition(.opacity)
                } else {
                    settingsSearchResults
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.24), value: query.isEmpty)
        }
        .onAppear {
            // Back on the hub, a search result has done its job.
            navigation.settingsFocus = nil
            navigation.settingsFocusGlowed = false
            #if DEBUG
            // Visual fixture: `--noop-route settings --noop-settings-query battery` opens on results.
            if let index = CommandLine.arguments.firstIndex(of: "--noop-settings-query"),
               CommandLine.arguments.indices.contains(index + 1), navigation.settingsQuery.isEmpty {
                navigation.settingsQuery = CommandLine.arguments[index + 1]
            }
            #endif
        }
    }

    var settingsSearchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(NoopHTMLColor.faint)
            TextField("Search every setting", text: $navigation.settingsQuery)
                .font(NoopHTMLFont.sans(NoopType.footnote))
                .foregroundStyle(NoopHTMLColor.inkSoft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !navigation.settingsQuery.isEmpty {
                Button {
                    withAnimation(.smooth(duration: 0.24)) { navigation.settingsQuery = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .frame(width: 28, height: 44)
                }
                .buttonStyle(NoopPlainHitStyle())
                .accessibilityLabel("Clear search")
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, navigation.settingsQuery.isEmpty ? 14 : 6)
        .frame(height: 44)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.09), lineWidth: 0.5))
        .animation(.smooth(duration: 0.2), value: navigation.settingsQuery.isEmpty)
    }

    /// The strap at the top of Settings, the way an account sits at the top of the iPhone's own:
    /// what it is, whether it is reading, how much battery it has. It opens the Strap page.
    var settingsStrapCard: some View {
        let name = measured ? liveStrapDetail : activeStrapName
        let isConnected = measured ? live.connected : connected
        let percent = measured ? battery : activeStrapBattery
        let daysLeft = measured
            ? live.batteryEstimate.map { BatteryEstimator.label(hours: $0.remainingHours) }
            : "about 3 days left"
        let ringColor = (percent ?? 100) <= 20 ? Self.warm : Self.green
        let status: String = name == nil
            ? "Pair one and Noop starts reading"
            : ([isConnected ? "Connected" : "Not connected"]
                + [percent.map { "\($0)%" }, daysLeft].compactMap { $0 }).joined(separator: " · ")
        return Button {
            navigation.settingsFocus = nil
            navigation.push(.settingsStrap)
        } label: {
            NoopHTMLCard(radius: 24, padding: 16) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.08), lineWidth: 3.5)
                        Circle()
                            .trim(from: 0, to: CGFloat(min(100, max(0, percent ?? 0))) / 100)
                            .stroke(isConnected ? ringColor : NoopHTMLColor.faint,
                                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: name == nil ? "plus" : "applewatch")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(NoopHTMLColor.ink)
                    }
                    .frame(width: 50, height: 50)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(name ?? "No strap paired")
                            .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.ink)
                            .lineLimit(1)
                        HStack(spacing: 7) {
                            Circle()
                                .fill(isConnected && name != nil ? Self.green : NoopHTMLColor.faint)
                                .frame(width: 7, height: 7)
                                .shadow(color: isConnected && name != nil ? Self.green.opacity(0.7) : .clear, radius: 4)
                            Text(status)
                                .font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(NoopHTMLColor.copy)
                                .lineLimit(1)
                        }
                        Text("Battery, capture and automations")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow))
                            .foregroundStyle(Color(hex: 0x7F8A85))
                    }
                    Spacer(minLength: 6)
                    NoopChevron()
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Strap settings. \(name ?? "No strap paired"). \(status)")
    }

    func settingsTile(_ page: NoopSettingsPage, size: CGFloat = 30) -> some View {
        Image(systemName: page.symbol)
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(page.tint)
            .frame(width: size, height: size)
            .background(page.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).stroke(page.tint.opacity(0.26), lineWidth: 0.5))
            .accessibilityHidden(true)
    }

    func settingsHubRow(_ page: NoopSettingsPage) -> some View {
        Button {
            navigation.settingsFocus = nil
            navigation.push(page.route)
        } label: {
            HStack(spacing: 13) {
                settingsTile(page)
                VStack(alignment: .leading, spacing: 2) {
                    Text(page.title)
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(settingsSummary(page))
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                NoopChevron()
            }
            .padding(.vertical, 11)
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    /// The live line under each hub row: what the page is set to now, so most visits need no tap.
    func settingsSummary(_ page: NoopSettingsPage) -> String {
        switch page {
        case .today:
            return (isEnabled("Journal reminder") ? "journal strip on" : "journal strip off") + " · hydration"
        case .sleep:
            return (isEnabled("Sleep staging V2") ? "V2 staging" : "V1 staging")
                + (isEnabled("Motion-aware wake") ? " · wake refinement on" : "") + " · smart alarm"
        case .fitness:
            return (isEnabled("Offer a workout it spotted") ? "spotted workouts offered" : "spotted workouts not offered")
                + (isEnabled("Keep the screen on in a workout") ? " · screen stays on" : "")
        case .scores:
            return "Effort shown \(settingsChoice("Effort") ?? "0–100") · baselines"
        case .you:
            return "your record, your zones, what Noop won’t ask"
        case .strap:
            return isEnabled("Power saving") ? "power saving at \(settingsChoice("Power saving at") ?? "20%")" : "power saving off"
        case .alerts:
            let on = Self.settingsAlertTitles.filter(isEnabled).count
            return "\(on) of \(Self.settingsAlertTitles.count) on" + (isEnabled("Quiet hours") ? " · quiet hours" : "")
        case .svea:
            return navigation.coachVoice == .off ? "Svea is off" : "\(navigation.coachVoice.rawValue.lowercased()) manner · provider, reading, memory"
        case .data:
            guard measured else { return "Apple Health, backup, Hevy and Shortcuts" }
            return (health.auth == .authorized ? "Apple Health connected" : "Apple Health not connected") + " · backup · Hevy"
        case .look:
            return [settingsChoice("Units") ?? "Metric", settingsChoice("Temperature") ?? "°C"].joined(separator: " · ")
                + (isEnabled("Reduce motion in Noop") ? " · motion reduced" : "")
        case .lab:
            return "readings in progress, probes that touch the strap"
        case .diagnostics:
            return "strap log, raw data, bug-report files"
        case .later:
            let deciding = NoopPendingOption.all.filter { $0.status == .deciding }.count
            return "\(NoopPendingOption.all.count - deciding) coming later · \(deciding) being decided"
        case .about:
            if case let .available(version, _, _) = updates.state { return "\(version) is out · tap to see" }
            return "version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") · what’s new, how it works, credits"
        }
    }

    static let settingsAlertTitles = [
        "Battery alerts", "Off-wrist reminder", "Sync reminder", "Your night is in",
        "Bedtime nudge", "A new best", "Weekly read", "Backup reminder"
    ]

    /// A segmented choice's current value, measured or prototype, without its Binding.
    func settingsChoice(_ title: String) -> String? {
        (measured ? liveChoice(title)?.wrappedValue : nil) ?? preferences[title]
    }

    var settingsVersionFooter: some View {
        Text("Noop Aura \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")) · everything on this phone")
            .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
    }

    // MARK: Settings pages

    func settingsPageScreen(_ page: NoopSettingsPage) -> some View {
        let focus = navigation.settingsFocus ?? settingsFixtureFocus
        return NoopScreen(topInset: 56, initialScrollID: focus ?? (page == .look ? settingsInitialScrollID : nil)) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("Settings") { navigation.back(or: .settings) }
                VStack(alignment: .leading, spacing: 14) {
                    settingsTile(page, size: 44)
                        .scaleEffect(settingsEntered ? 1 : 0.62)
                        .opacity(settingsEntered ? 1 : 0)
                    pageTitle(page.title, copy: page.blurb)
                        .offset(y: settingsEntered ? 0 : 7)
                        .opacity(settingsEntered ? 1 : 0)
                }
                .padding(.bottom, 5)

                ForEach(settingsSections(page)) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        if let title = section.title {
                            NoopSectionLabel(title).padding(.horizontal, 2).padding(.top, 8)
                        }
                        if let note = section.note {
                            Text(note)
                                .font(NoopHTMLFont.sans(NoopType.caption))
                                .foregroundStyle(Color(hex: 0x7F8A85))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 2)
                                .padding(.bottom, 2)
                        }
                        dividedCard {
                            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                                if index > 0 { Divider().overlay(NoopHTMLColor.border) }
                                item.row()
                                    .id(item.id)
                                    .overlay(alignment: .topLeading) {
                                        // Changed from how Noop starts: a small dot in the card's margin,
                                        // level with the row's title.
                                        if settingsChanged(item.title) {
                                            Circle().fill(page.tint).frame(width: 5, height: 5)
                                                .offset(x: -10.5, y: 19)
                                                .transition(.scale.combined(with: .opacity))
                                                .accessibilityHidden(true)
                                        }
                                    }
                                    .animation(.smooth(duration: 0.25), value: settingsChanged(item.title))
                                    .background {
                                        // A search result's row glows once on arrival, then settles.
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(page.tint.opacity(settingsGlowID == item.id ? 0.14 : 0))
                                            .padding(.horizontal, -9)
                                            .padding(.vertical, 3)
                                    }
                            }
                        }
                    }
                    .padding(.top, section.title == nil ? 3 : 0)
                }

                if page == .about { settingsVersionFooter.padding(.top, 6) }

                settingsResetFooter(page)
            }
        }
        // A selection tick for every switch or choice that actually changes on this page.
        .sensoryFeedback(.selection, trigger: settingsSignature(page))
        .task {
            if page == .alerts { await readNotificationAuth() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard page == .alerts else { return }
            Task { await readNotificationAuth() }
        }
        .onAppear {
            if systemReduceMotion || quietMotionOn {
                settingsEntered = true
            } else {
                withAnimation(.spring(response: 0.46, dampingFraction: 0.78).delay(0.05)) { settingsEntered = true }
            }
            #if DEBUG
            // Visual fixture: `--noop-settings-pending <id>` opens that option's explanation.
            if let index = CommandLine.arguments.firstIndex(of: "--noop-settings-pending"),
               CommandLine.arguments.indices.contains(index + 1) {
                pendingOption = NoopPendingOption.all.first { $0.id == CommandLine.arguments[index + 1] }
            }
            #endif
            guard let focus, !navigation.settingsFocusGlowed else { return }
            navigation.settingsFocusGlowed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.3)) { settingsGlowID = focus }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                    withAnimation(.easeInOut(duration: 0.9)) { settingsGlowID = nil }
                }
            }
        }
    }

    func toggleItem(_ tint: Color, _ id: String, _ title: String, _ detail: String, keywords: String = "") -> NoopSettingsItem {
        NoopSettingsItem(id: id, title: title, detail: detail, keywords: keywords) {
            AnyView(toggleRow(title, detail: detail, tint: tint))
        }
    }

    /// A switch that came out of the Lab keeps the Lab's row: its badge, its gate and its strap write.
    func labItem(_ tint: Color, _ id: String, _ title: String, _ detail: String, badge: String? = nil, gate: String? = nil,
                 keywords: String = "") -> NoopSettingsItem {
        NoopSettingsItem(id: id, title: title, detail: detail, keywords: keywords) {
            AnyView(labToggle(title, detail: detail, badge: badge, gate: gate, tint: tint))
        }
    }

    func linkItem(_ tint: Color, _ id: String, _ title: String, _ detail: String, symbol: String,
                  keywords: String = "", action: @escaping () -> Void) -> NoopSettingsItem {
        NoopSettingsItem(id: id, title: title, detail: detail, keywords: keywords) {
            AnyView(copyRow(title, detail: detail, symbol: symbol, tint: tint, action: action))
        }
    }

    func glyphItem(_ tint: Color, _ id: String, _ title: String, _ detail: String, glyph: NoopCanonicalGlyphName, value: String? = nil,
                   keywords: String = "", action: @escaping () -> Void) -> NoopSettingsItem {
        NoopSettingsItem(id: id, title: title, detail: detail, keywords: keywords) {
            AnyView(canonicalLinkRow(title, detail: detail, glyph: glyph, tint: tint, value: value, action: action))
        }
    }

    func segmentItem(_ tint: Color, _ id: String, _ title: String, _ detail: String, choices: [String],
                     disabled: Set<String> = [], keywords: String = "") -> NoopSettingsItem {
        NoopSettingsItem(id: id, title: title, detail: detail, keywords: keywords) {
            AnyView(segmentRow(title, detail: detail, choices: choices, tint: tint, disabledChoices: disabled))
        }
    }

    func soonItem(_ id: String, _ title: String, _ detail: String, glyph: NoopCanonicalGlyphName, keywords: String = "") -> NoopSettingsItem {
        NoopSettingsItem(id: id, title: title, detail: detail, keywords: keywords) {
            AnyView(soonRow(title, detail: detail, glyph: glyph))
        }
    }

    /// Every page's rows, in order. The page draws them, the hub reads their state and search
    /// indexes them, so the three can never disagree about what exists or where it lives.
    func settingsSections(_ page: NoopSettingsPage) -> [NoopSettingsSection] {
        if page == .later {
            // On the way: every pending option, grouped under the page it will live on.
            return NoopSettingsPage.allCases.compactMap { home in
                let options = NoopPendingOption.all.filter { $0.page == home }
                guard !options.isEmpty else { return nil }
                return NoopSettingsSection(title: home.title, items: options.map { pendingItem($0) })
            }
        }
        let pending = NoopPendingOption.all.filter { $0.page == page }
        guard !pending.isEmpty else { return settingsBaseSections(page) }
        return settingsBaseSections(page) + [NoopSettingsSection(title: "Not in Aura yet", items: pending.map { pendingItem($0) })]
    }

    func pendingItem(_ option: NoopPendingOption) -> NoopSettingsItem {
        NoopSettingsItem(id: option.id, title: option.title, detail: option.does,
                         keywords: "later planned deciding coming " + option.why,
                         focusable: option.page != .lab) {
            AnyView(pendingRow(option))
        }
    }

    /// A dimmed row for an option Aura does not have yet. A tap explains it rather than doing nothing.
    func pendingRow(_ option: NoopPendingOption) -> some View {
        Button { pendingOption = option } label: {
            HStack(spacing: 13) {
                Image(systemName: option.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: 0x5E6864))
                    .frame(width: 21)
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(Color(hex: 0x9AA39F))
                    Text(option.does)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0x6E7874))
                        .lineSpacing(2)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        // Same size in every row; the sheet carries the whole sentence.
                        .minimumScaleFactor(1)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                pendingChip(option.status)
            }
            .padding(.vertical, 13)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityLabel("\(option.title), \(option.status.label.lowercased()). \(option.does)")
        .accessibilityHint("Explains why it is not in Aura yet")
    }

    func pendingChip(_ status: NoopPendingOption.Status) -> some View {
        let deciding = status == .deciding
        return Text(status.label)
            .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
            .tracking(0.95)
            .textCase(.uppercase)
            .foregroundStyle(deciding ? Color(hex: 0xE9C68F) : Color(hex: 0x7F8A85))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background((deciding ? Self.warm.opacity(0.10) : Color.white.opacity(0.05)), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(deciding ? Self.warm.opacity(0.26) : Color.white.opacity(0.09), lineWidth: 0.5))
    }

    func pendingSheet(_ option: NoopPendingOption) -> some View {
        let fromIndex = navigation.route == .settingsLater
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: option.symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(option.page.tint)
                    .frame(width: 44, height: 44)
                    .background(option.page.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 5) {
                    pendingChip(option.status)
                    Text(option.page.title)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                }
                Spacer()
            }
            Text(option.title)
                .font(NoopHTMLFont.outfit(NoopType.title3))
                .foregroundStyle(NoopHTMLColor.ink)
            VStack(alignment: .leading, spacing: 14) {
                pendingFact("What it does", option.does)
                pendingFact(option.status == .later ? "Why not yet" : "Why it is undecided", option.why)
            }
            if fromIndex {
                Button {
                    let target = option
                    pendingOption = nil
                    navigation.settingsFocus = target.page == .lab ? nil : target.id
                    navigation.settingsFocusGlowed = false
                    navigation.push(target.page.route)
                } label: {
                    Text("See it on \(option.page.title)")
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 48)
                        .background(option.page.tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(option.page.tint.opacity(0.36), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 26)
    }

    func pendingFact(_ label: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            NoopSectionLabel(label)
            Text(text)
                .font(NoopHTMLFont.sans(NoopType.footnote))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// How a fresh install starts, for every switch a page can reset. Rows not listed here (links,
    /// the app icon, Svea's manner, anything that writes to the strap beyond Broadcast) are never
    /// marked changed and never reset.
    static let settingsToggleDefaults: [String: Bool] = [
        "Journal reminder": true,
        "Sleep staging V2": true, "Motion-aware wake": false,
        "Keep the screen on in a workout": false, "Offer a workout it spotted": false, "Lift on the Lock Screen": true,
        "Live heart rate in the Dynamic Island": true,
        "Power saving": false, "Pause the HRV stream when low": true,
        "Continuous HRV capture": false, "Overnight only": true, "Broadcast heart rate": false,
        "Quiet hours": false, "Battery alerts": true, "Off-wrist reminder": false, "Sync reminder": true,
        "Your night is in": true, "Bedtime nudge": false, "A new best": false, "Weekly read": false,
        "Backup reminder": true,
        "Reduce motion in Noop": false
    ]

    /// True when a row's stored value is not what a fresh install has. Production only: the seeded
    /// prototype has no stored settings to compare.
    func settingsChanged(_ title: String) -> Bool {
        guard measured else { return false }
        if let start = Self.settingsToggleDefaults[title] { return labControlIsOn(title) != start }
        switch title {
        case "Units": return settingsChoice("Units") != (NoopDefaults.regionUnitSystem == .imperial ? "Imperial" : "Metric")
        case "Temperature":
            return settingsChoice("Temperature") != (settingsChoice("Units") == "Imperial" ? "°F" : "°C")
        case "Effort": return settingsChoice("Effort") == "0–21"
        case "Power saving at": return powerSavingPct != 20
        default: return false
        }
    }

    /// Put one row back the way a fresh install has it, through the same path a tap takes, so every
    /// side effect (a notice re-planned, the HRV stream re-armed, the strap told) runs as it would.
    func settingsReset(_ title: String) {
        if let start = Self.settingsToggleDefaults[title] {
            guard labControlIsOn(title) != start else { return }
            if title == "Broadcast heart rate" { toggleLabControl(title) } else { flip(title) }
            return
        }
        switch title {
        // Removed, not written: an untouched setting follows the iPhone's region again.
        case "Units": UserDefaults.standard.removeObject(forKey: UnitPrefs.systemKey)
        case "Temperature": temperatureRaw = ""
        case "Effort": effortScaleRaw = ""
        case "Power saving at": powerSavingPct = 20
        default: break
        }
    }

    func settingsChangedTitles(_ page: NoopSettingsPage) -> [String] {
        settingsBaseSections(page).flatMap(\.items).map(\.title).filter(settingsChanged)
    }

    func settingsSignature(_ page: NoopSettingsPage) -> String {
        settingsBaseSections(page).flatMap(\.items).map { item in
            (labControlIsOn(item.title) ? "1" : "0") + (settingsChoice(item.title) ?? "")
        }.joined(separator: "|")
    }

    @ViewBuilder
    func settingsResetFooter(_ page: NoopSettingsPage) -> some View {
        let changed = settingsChangedTitles(page)
        if !changed.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button { confirmingSettingsReset = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 13, weight: .semibold))
                        Text("Reset \(page.title) to how Noop starts")
                            .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    }
                    .foregroundStyle(page.tint)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(page.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(page.tint.opacity(0.24), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())
                HStack(spacing: 7) {
                    Circle().fill(page.tint).frame(width: 5, height: 5)
                    Text(changed.count == 1 ? "One setting here is changed from how Noop starts. Your data stays as it is."
                         : "\(changed.count) settings here are changed from how Noop starts. Your data stays as it is.")
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 2)
            }
            .padding(.top, 14)
            .transition(.opacity)
            .confirmationDialog("Reset \(page.title)?", isPresented: $confirmingSettingsReset, titleVisibility: .visible) {
                Button(changed.count == 1 ? "Reset 1 setting" : "Reset \(changed.count) settings", role: .destructive) {
                    withAnimation(.smooth(duration: 0.3)) { changed.forEach(settingsReset) }
                    NoopHaptics.play(.save)
                }
                Button("Keep them", role: .cancel) {}
            } message: {
                Text(changed.joined(separator: ", "))
            }
        }
    }

    func settingsBaseSections(_ page: NoopSettingsPage) -> [NoopSettingsSection] {
        // Every control on a page wears the page's colour, the same one as its tile on the hub.
        let tint = page.tint
        switch page {
        case .today:
            return [NoopSettingsSection(items: [
                toggleItem(tint, "today-journal", "Journal reminder", "The seven-day strip on Today. Off removes it entirely.",
                           keywords: "journal strip log behaviour today"),
                glyphItem(tint, "today-hydration", "Hydration", "a water log with a goal that follows your sex and the day’s effort",
                          glyph: .drop, keywords: "water drink cups tracker") { navigation.push(.hydration) }
            ])]

        case .sleep:
            return [
                NoopSettingsSection(title: "Reading the night", items: [
                    labItem(tint, "sleep-staging", "Sleep staging V2", "A cardiorespiratory recipe that recovers deep and REM better on nights the old stager flattened to light. On by default after a 44-person benchmark.",
                            badge: "default on", keywords: "stages deep rem light hypnogram v1 recipe"),
                    labItem(tint, "sleep-wake", "Motion-aware wake", "Re-reads scored wake as light sleep when your posture was stable and there were no steps. A no-op on a sparse night.",
                            keywords: "wake refinement posture steps awake")
                ]),
                NoopSettingsSection(title: "Alerts", items: [
                    alertsLinkItem(tint, "sleep-alerts", "Sleep alerts", titles: ["Your night is in", "Bedtime nudge"], focus: "alerts-night")
                ]),
                NoopSettingsSection(title: "Waking", items: [
                    linkItem(tint, "sleep-alarm", "Smart alarm", "a buzz in light sleep, inside the window you set", symbol: "alarm",
                             keywords: "alarm wake window wake-up") { navigation.push(.alarm) }
                ])
            ]

        case .fitness:
            return [NoopSettingsSection(items: [
                NoopSettingsItem(id: "fitness-animations", title: "Exercise animations",
                                 detail: "Download exercise media from GitHub when viewed. Cached media works offline.",
                                 keywords: "media videos gifs download") {
                    AnyView(NoopExerciseAnimationToggle().padding(14))
                },
                toggleItem(tint, "fitness-screen-on", "Keep the screen on in a workout", "Holds the screen awake while a manual recording runs.",
                           keywords: "awake display lock"),
                toggleItem(tint, "fitness-lift-activity", "Lift on the Lock Screen", "Your current set and the rest timer on the Lock Screen and in the Dynamic Island while you lift.",
                           keywords: "live activity dynamic island rest timer lifting"),
                toggleItem(tint, "fitness-spotted", "Offer a workout it spotted", "Sees a probable session in your heart rate and offers to save it. It never creates one for you.",
                           keywords: "auto detect workouts sessions detection")
            ])]

        case .scores:
            return [NoopSettingsSection(items: [
                segmentItem(tint, "scores-effort", "Effort", "display only — Effort is stored 0–100", choices: ["0–100", "0–21"],
                            keywords: "strain scale 21 effort scale"),
                NoopSettingsItem(id: "scores-recalibrate", title: "Recalibrate your baselines",
                                 detail: "Restart the four-night build-up if a bad week — being ill, a flight — set it wrong.",
                                 keywords: "baselines recovery charge hrv resting pulse respiration skin temperature restart reset") {
                    AnyView(recalibrateBaselinesRow)
                }
            ]),
            NoopSettingsSection(title: "Alerts", items: [
                alertsLinkItem(tint, "scores-alerts", "Progress alerts", titles: ["A new best", "Weekly read"], focus: "alerts-best")
            ])]

        case .you:
            return [NoopSettingsSection(items: [
                linkItem(tint, "you-record", "Your record", "date of birth, sex, height, weight and waist", symbol: "person.text.rectangle",
                         keywords: "profile photo birth sex height weight waist maximum") { navigation.enter(.record, from: .you) },
                linkItem(tint, "you-zones", "Your zones", settingsZoneDetail, symbol: "heart",
                         keywords: "heart rate training bands maximum") { navigation.enter(.zones, from: .record) },
                linkItem(tint, "you-position", "What Noop will not ask you", "no weight goal, no step target, no score", symbol: "nosign",
                         keywords: "goals targets philosophy") { navigation.push(.position) }
            ])]

        case .strap:
            return [
                NoopSettingsSection(items: [
                    linkItem(tint, "strap-device", "Your strap", "connection, battery, sensors and sync", symbol: "applewatch",
                             keywords: "connection battery sensors sync now") { navigation.push(.strap) },
                    linkItem(tint, "strap-manage", "Manage straps", "pair, switch or forget a strap", symbol: "arrow.left.arrow.right",
                             keywords: "pair switch forget rename band devices") { navigation.enter(.devices, from: .strap) },
                    linkItem(tint, "strap-automations", "Automations", "what the strap does on its own, and what a tap on it does", symbol: "sparkles",
                             keywords: "double tap move reminder stress check-ins illness zone buzz") { navigation.push(.automations) },
                    toggleItem(tint, "strap-island", "Live heart rate in the Dynamic Island", "Also puts it on the Lock Screen while a session runs.",
                               keywords: "live activity lock screen bpm")
                ]),
                NoopSettingsSection(title: "Alerts", items: [
                    alertsLinkItem(tint, "strap-alerts", "Strap alerts", titles: ["Battery alerts", "Off-wrist reminder", "Sync reminder"], focus: "alerts-battery")
                ]),
                NoopSettingsSection(title: "Battery", items: [
                    toggleItem(tint, "strap-power-saving", "Power saving", "Syncs every 45 minutes instead of 15 once the strap is low and discharging. Never while charging.",
                               keywords: "battery low sync 45 minutes"),
                    segmentItem(tint, "strap-power-at", "Power saving at", "the strap battery that starts it", choices: ["10%", "20%", "30%"],
                                keywords: "battery threshold percent"),
                    toggleItem(tint, "strap-pause-hrv", "Pause the HRV stream when low", "Releases the always-on stream too. Costs overnight variability detail on that night only.",
                               keywords: "battery hrv stream")
                ]),
                NoopSettingsSection(title: "Capture", items: [
                    labItem(tint, "strap-continuous-hrv", "Continuous HRV capture", "Holds the dense beat-to-beat stream armed so overnight variability has more to work with. Costs roughly a day of battery.",
                            keywords: "hrv beat-to-beat stream variability"),
                    labItem(tint, "strap-hrv-overnight", "Overnight only", "Arms that stream inside quiet hours instead of around the clock. Most of the benefit, a fraction of the cost.",
                            gate: "Follows Continuous HRV capture — with the switch above off, this does nothing.",
                            keywords: "hrv night stream"),
                    labItem(tint, "strap-broadcast", "Broadcast heart rate", "Makes the strap advertise its pulse as a standard sensor, so a bike computer or a gym machine can read it.",
                            badge: "writes to strap", keywords: "bluetooth sensor bike gym machine ant")
                ])
            ]

        case .alerts:
            return [
                NoopSettingsSection(items: [
                    NoopSettingsItem(id: "alerts-permission", title: "Notification permission",
                                     detail: "whether iOS lets Noop’s notices through at all",
                                     keywords: "allow permission ios banners sounds denied blocked") {
                        AnyView(notificationPermissionRow(tint: tint))
                    },
                    toggleItem(tint, "alerts-quiet", "Quiet hours", "Nothing buzzes between your anchor and your usual wake, whatever else is on.",
                               keywords: "do not disturb silence night buzz")
                ]),
                NoopSettingsSection(title: "Strap", items: [
                    toggleItem(tint, "alerts-battery", "Battery alerts", "One notice at 15% and one when it finishes charging. Never twice for the same crossing.",
                               keywords: "charging low battery"),
                    toggleItem(tint, "alerts-off-wrist", "Off-wrist reminder", "One notice when the strap has been off your wrist for ten minutes. Not while it charges.",
                               keywords: "wear wrist"),
                    toggleItem(tint, "alerts-sync", "Sync reminder", "A silent notice when the strap hasn’t synced for three hours, usually because Noop was swiped away. Every sync pushes it back.",
                               keywords: "not synced swiped away")
                ]),
                NoopSettingsSection(title: "Sleep", items: [
                    toggleItem(tint, "alerts-night", "Your night is in", "Once last night is scored, its sleep and Charge. Not when Noop is already open.",
                               keywords: "morning sleep charge scored"),
                    toggleItem(tint, "alerts-bedtime", "Bedtime nudge", "Thirty minutes before the bedtime that gets you your own sleep need before your usual wake. Learned per weekday after fourteen nights.",
                               keywords: "wind down bedtime reminder")
                ]),
                NoopSettingsSection(title: "Progress", items: [
                    toggleItem(tint, "alerts-best", "A new best", "When last night beat three months on HRV, resting pulse or Charge. Never more than one a day.",
                               keywords: "record hrv resting personal best"),
                    toggleItem(tint, "alerts-weekly", "Weekly read", "Sunday at seven: sleep, Charge and sessions against the week before. Off by default.",
                               keywords: "week summary sunday digest")
                ]),
                NoopSettingsSection(title: "Data", items: [
                    toggleItem(tint, "alerts-backup", "Backup reminder", "Your record lives only on this phone. A quiet reminder when the last backup is a month old.",
                               keywords: "backup month")
                ]),
                // The strap's own buzzes are what the strap does, so they stay in Automations. Listed here
                // because "why did my wrist buzz" is a notifications question too.
                NoopSettingsSection(title: "On your wrist", items: [
                    linkItem(tint, "alerts-wrist", "Strap buzzes",
                             "\(Self.settingsWristTitles.filter(isEnabled).count) on · move reminder, stress check-ins, illness warning and the zone buzz, set in Automations",
                             symbol: "applewatch.radiowaves.left.and.right",
                             keywords: "buzz haptic wrist move reminder stress illness zone ceiling") { navigation.push(.automations) }
                ])
            ]

        case .svea:
            return [NoopSettingsSection(items: [
                linkItem(tint, "svea-provider", "Provider and key", "which model answers, with your own key", symbol: "key",
                         keywords: "model anthropic openai api key coach ai") { navigation.push(.setup) },
                linkItem(tint, "svea-consent", "What she may read", "purpose by purpose, revocable", symbol: "shield",
                         keywords: "consent privacy permissions") { navigation.push(.consent) },
                linkItem(tint, "svea-memory", "Memory", "what she keeps between conversations", symbol: "sparkles",
                         keywords: "remember forget conversations") { navigation.push(.memory) },
                segmentItem(tint, "svea-manner", "Svea’s manner", "plain writes a paragraph, quiet writes a line", choices: ["Plain", "Quiet", "Direct", "Off"],
                            keywords: "tone voice style off coach")
            ])]

        case .data:
            return [
                NoopSettingsSection(title: "Your data", items: [
                    linkItem(tint, "data-permissions", "Data and permissions", "what is kept, what leaves, and importing history", symbol: "lock.shield",
                             keywords: "privacy recorded delete import history") { navigation.push(.data) },
                    linkItem(tint, "data-backup", "Backup and restore", "one file you keep, restored the same way", symbol: "externaldrive",
                             keywords: "back up restore file noopbak export") { navigation.enter(.backup, from: .data) },
                    alertsLinkItem(tint, "data-alerts", "Backup reminder", titles: ["Backup reminder"], focus: "alerts-backup")
                ]),
                NoopSettingsSection(title: "Apple", items: [
                    linkItem(tint, "data-health", "Apple Health", "what Noop writes and reads", symbol: "heart",
                             keywords: "healthkit sync write read") { navigation.enter(.apple, from: .strap) },
                    glyphItem(tint, "data-siri", "Siri and Shortcuts", "Sync, Buzz, Mark a moment and Ask Svea, hands-free", glyph: .spark,
                              keywords: "voice app intents automation") { navigation.push(.siri) },
                    glyphItem(tint, "data-shortcut-export", "Shortcuts export", "the HealthKit-free path, for a sideloaded build", glyph: .upload,
                              keywords: "healthkit-free sideloaded drop file") { navigation.push(.shortcutExport) }
                ]),
                NoopSettingsSection(title: "Connected apps", items: [
                    linkItem(tint, "data-hevy", "Hevy", HevySync.shared.hasKey ? "connected · workouts, routines and body in step" : "bring your Hevy workouts, routines and body in",
                             symbol: "dumbbell", keywords: "lifting workouts routines api key sync") { showHevy = true }
                ])
            ]

        case .look:
            return [NoopSettingsSection(items: [
                segmentItem(tint, "look-units", "Units", "stored in SI either way", choices: ["Metric", "Imperial"],
                            keywords: "metric imperial kilograms pounds miles kilometres"),
                segmentItem(tint, "look-temperature", "Temperature", "independent of the rest", choices: ["°C", "°F"],
                            keywords: "celsius fahrenheit"),
                toggleItem(tint, "look-motion", "Reduce motion in Noop", "Poses every looping graphic still without needing the system switch.",
                           keywords: "animation accessibility still"),
                linkItem(tint, "look-widgets", "Widgets", "\(widgetFamilyCountWord) families, and what each one answers", symbol: "square.grid.2x2",
                         keywords: "home screen lock screen") { navigation.push(.widgets) },
                NoopSettingsItem(id: "settings-app-icon", title: "App icon", detail: selectedAppIcon.detail,
                                 keywords: "icon home screen navy aura") {
                    AnyView(appIconPickerRow)
                }
            ])]

        case .lab:
            return [NoopSettingsSection(items: [
                NoopSettingsItem(id: "lab", title: "The Lab", detail: "readings still being worked out, and probes that touch the strap",
                                 keywords: "experiments spo2 oxygen estimate r22 deep data ecg raw protocol frames record test centre",
                                 focusable: false) { AnyView(EmptyView()) }
            ])]

        case .diagnostics:
            return [NoopSettingsSection(items: [
                NoopSettingsItem(id: "diagnostics", title: "Diagnostics", detail: "strap log, raw data and the files a bug report needs",
                                 keywords: "strap log raw sensor data export zip experiment phase environment bug report",
                                 focusable: false) { AnyView(EmptyView()) }
            ])]

        case .later:
            return []

        case .about:
            return [
                NoopSettingsSection(items: [
                    NoopSettingsItem(id: "about-updates", title: "Check for updates", detail: updateDetail,
                                     keywords: "version release new update") {
                        AnyView(actionRow("Check for updates", detail: updateDetail, symbol: "arrow.triangle.2.circlepath", tint: NoopHTMLColor.blue) {
                            if case let .available(_, url, _) = updates.state {
                                UIApplication.shared.open(url)
                            } else {
                                updates.check(currentVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")
                            }
                        })
                    },
                    glyphItem(tint, "about-whats-new", "What’s new", "this version, and every one before it", glyph: .file, value: currentChangelogDisplayVersion,
                              keywords: "release notes changelog") { showReleaseNotes = true },
                    glyphItem(tint, "about-how", "How Noop works", "how sleep is sorted, how the scores build, where the numbers come from", glyph: .globe,
                              keywords: "scoring explained method") { navigation.push(.howItWorks) },
                    glyphItem(tint, "about-limitations", "Strap limitations", "4.0 against 5.0 against MG — what each band can read", glyph: .watch,
                              keywords: "4.0 5.0 mg capabilities what works") { navigation.push(.limitations) }
                ]),
                NoopSettingsSection(title: "Built on", items: [
                    NoopSettingsItem(id: "about-credits", title: "Built on NOOP",
                                     detail: "Noop Aura is a fork of NOOP by ryanbr, which reads WHOOP straps directly over Bluetooth.",
                                     keywords: "credits ryanbr upstream open source licence polyform my-whoop goose thanks") {
                        AnyView(settingsCreditsRow)
                    }
                ])
            ]
        }
    }

    static let settingsWristTitles = ["Move reminder", "Stress check-ins", "Illness early warning", "Buzz if I go over"]

    /// A page's own notices live on Notifications; the page shows how many are on and opens them there,
    /// scrolled to the first and glowing it, so a switch is never in two places.
    func alertsLinkItem(_ tint: Color, _ id: String, _ title: String, titles: [String], focus: String) -> NoopSettingsItem {
        let on = titles.filter(isEnabled).count
        let detail = titles.count == 1 ? (on == 1 ? "on" : "off") + " · in Notifications" : "\(on) of \(titles.count) on · in Notifications"
        return NoopSettingsItem(id: id, title: title, detail: detail, keywords: "notifications alerts", focusable: true) {
            AnyView(copyRow(title, detail: detail, symbol: "bell.badge", tint: tint) {
                navigation.settingsFocus = focus
                navigation.settingsFocusGlowed = false
                navigation.push(.settingsAlerts)
            })
        }
    }

    /// iOS's own permission, stated plainly at the top of Notifications: every switch below is moot
    /// without it, and a denied one can only be fixed in iOS Settings.
    func notificationPermissionRow(tint: Color) -> some View {
        let status = notificationAuth
        let allowed = status == .authorized || status == .provisional || status == .ephemeral
        let denied = status == .denied
        let title = status == nil ? "Checking with iOS…" : allowed ? "Allowed on this iPhone" : denied ? "Turned off in iOS Settings" : "Not allowed yet"
        let detail = allowed ? "Banners and sounds come through for every switch that is on."
            : denied ? "Nothing below can reach you until notifications are back on for Noop."
            : "Noop asks once, the first time a notice has something to say. You can allow it now instead."
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                ZStack {
                    Circle().fill((allowed ? Self.green : denied ? Self.warm : NoopHTMLColor.faint).opacity(0.16))
                    Image(systemName: allowed ? "checkmark" : denied ? "bell.slash.fill" : "bell.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(allowed ? Self.green : denied ? Self.warm : NoopHTMLColor.copy)
                }
                .frame(width: 30, height: 30)
                .animation(.smooth(duration: 0.3), value: allowed)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                    Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if status == .notDetermined || denied {
                Button {
                    if denied {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                    } else {
                        Task {
                            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                            await readNotificationAuth()
                            await AuraNotices.refresh(repo: model.repo)
                        }
                    }
                } label: {
                    Text(denied ? "Open iOS Settings" : "Allow notifications")
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(tint.opacity(0.2), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(tint.opacity(0.4), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())
                .transition(.opacity)
            }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .contain)
    }

    func readNotificationAuth() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        withAnimation(.smooth(duration: 0.3)) { notificationAuth = status }
    }

    var recalibrateBaselinesRow: some View {
        actionRow(
            baselinesRestarting ? "Baselines restarting from tonight" : "Recalibrate your baselines",
            detail: baselinesRestarting
                ? "HRV, resting pulse, respiration and skin temperature all rebuild over about four nights. Your history stays where it is."
                : "Restart the four-night build-up if a bad week — being ill, a flight — set it wrong.",
            symbol: "gauge.with.dots.needle.50percent",
            tint: baselinesRestarting ? Self.green : NoopSettingsPage.scores.tint,
            titleColor: baselinesRestarting ? Color(hex: 0x8FE3B4) : NoopHTMLColor.ink
        ) {
            // Production runs the real re-anchor the classic screen uses: no day is deleted,
            // only the day the four baselines re-learn from moves, then a rescore.
            if measured && !baselinesRestarting {
                Baselines.recalibrateRecoveryBaselines()
                Task { await model.intelligence.analyzeRecent(); await model.repo.refresh() }
                baselinesRestarting = true
            } else if !measured {
                baselinesRestarting.toggle()
            }
        }
    }

    /// Credit where Noop comes from, as the classic About did: the upstream app and the two protocol
    /// projects it stands on.
    var settingsCreditsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Noop Aura is a fork of NOOP by ryanbr, which reads WHOOP straps directly over Bluetooth: no WHOOP app, no cloud. Every reading here starts with that work.")
                .font(NoopHTMLFont.sans(NoopType.caption))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 7) {
                settingsCreditLine("ryanbr/noop", note: "the app Aura is built on")
                settingsCreditLine("johnmiddleton12/my-whoop", note: "WHOOP 4.0 protocol")
                settingsCreditLine("b-nnett/goose", note: "WHOOP 5.0 protocol")
            }
            Link(destination: URL(string: "https://github.com/ryanbr/noop")!) {
                HStack(spacing: 6) {
                    Text("NOOP on GitHub").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                    Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(NoopHTMLColor.blueLight)
                .frame(minHeight: 32)
            }
            .accessibilityLabel("Open NOOP on GitHub")
        }
        .padding(.vertical, 14)
    }

    func settingsCreditLine(_ repo: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(repo)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(NoopHTMLColor.ink)
            Text("· \(note)")
                .font(NoopHTMLFont.sans(NoopType.caption))
                .foregroundStyle(Color(hex: 0x7F8A85))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Settings search

    var settingsIndex: [NoopSettingsHit] {
        // On the way only repeats what each page already lists.
        NoopSettingsPage.allCases.filter { $0 != .later }.flatMap { page in
            settingsSections(page).flatMap { section in
                section.items.map { NoopSettingsHit(page: page, section: section.title, item: $0) }
            }
        }
    }

    var settingsSearchResults: some View {
        let hits = settingsIndex.filter {
            settingsSearchMatches([$0.item.title, $0.item.detail, $0.item.keywords, $0.page.title, $0.section ?? ""].joined(separator: " "))
        }
        let pages = NoopSettingsPage.allCases.filter { page in hits.contains { $0.page == page } }
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(pages) { page in
                VStack(alignment: .leading, spacing: 8) {
                    NoopSectionLabel(page.title).padding(.horizontal, 2).padding(.top, 4)
                    dividedCard {
                        let rows = hits.filter { $0.page == page }
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, hit in
                            if index > 0 { Divider().overlay(NoopHTMLColor.border) }
                            settingsResultRow(hit)
                        }
                    }
                }
            }
            settingsDestinationResults(hasSettingHits: !hits.isEmpty)
        }
    }

    func settingsResultRow(_ hit: NoopSettingsHit) -> some View {
        Button {
            navigation.settingsFocus = hit.item.focusable ? hit.item.id : nil
            navigation.settingsFocusGlowed = false
            navigation.push(hit.page.route)
        } label: {
            HStack(spacing: 13) {
                settingsTile(hit.page, size: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.item.title)
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(([hit.page.title] + [hit.section].compactMap { $0 }).joined(separator: " › "))
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                NoopChevron()
            }
            .padding(.vertical, 11)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    // Search aliases preserve discoverability for screens that are not settings at all.
    var movedSettingsDestinations: [(title: String, home: String, aliases: String, route: NoopRoute, parent: NoopRoute)] {
        [
            ("Biomarkers", "Trends", "bloodwork blood tests lab results markers", .labs, .trends),
            ("Import a file", "Data and permissions · Bring your history in", "nutrition calories macros csv history import", .importHistory, .data),
            ("Your data, fused", "Data and permissions", "source winner merged", .fused, .data),
            ("Storage", "Data and permissions", "phone space database", .storage, .data),
            ("Weekly digest", "Trends", "week summary", .digest, .trends),
            ("Trends report", "Trends", "pdf export window report", .report, .trends)
        ]
    }

    func settingsSearchMatches(_ text: String) -> Bool {
        let words = navigation.settingsQuery.lowercased().split(whereSeparator: { $0.isWhitespace })
        return words.allSatisfy { text.localizedCaseInsensitiveContains(String($0)) }
    }

    func settingsDestinationResults(hasSettingHits: Bool) -> some View {
        let results = movedSettingsDestinations.filter {
            settingsSearchMatches($0.title + " " + $0.home + " " + $0.aliases)
        }
        return VStack(alignment: .leading, spacing: 8) {
            if !results.isEmpty {
                NoopSectionLabel("Elsewhere in Noop").padding(.horizontal, 2).padding(.top, 4)
                dividedCard {
                    VStack(spacing: 0) {
                        ForEach(results.indices, id: \.self) { index in
                            let result = results[index]
                            if index > 0 { Divider().overlay(NoopHTMLColor.border) }
                            copyRow(result.title, detail: result.home, tint: Self.blush) {
                                navigation.enter(result.route, from: result.parent)
                            }
                        }
                    }
                }
            } else if !hasSettingHits {
                Text("Nothing matches “\(navigation.settingsQuery.trimmingCharacters(in: .whitespaces))”. Try battery, sleep, units or backup.")
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 2)
            }
        }
    }

    var updateDetail: String {
        switch updates.state {
        case .idle: "one request to the release page, when you ask for it"
        case .checking: "asking the release page…"
        case .upToDate(let version): "you have the newest, \(version)"
        case .available(let version, _, _): "\(version) is out — tap to open the release"
        case .failed: "the release page did not answer; try again later"
        }
    }

    var currentChangelogDisplayVersion: String {
        let raw = AppChangelog.currentVersion
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.last == "0" else { return raw }
        return parts.dropLast().joined(separator: ".")
    }

    func soonRow(_ title: String, detail: String, glyph: NoopCanonicalGlyphName) -> some View {
        HStack(spacing: 13) {
            NoopCanonicalGlyph(name: glyph, size: 19, color: Color(hex: 0x4E5854))
                .frame(width: 21)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(NoopHTMLFont.sans(NoopType.footnote))
                    .foregroundStyle(Color(hex: 0x8B958F))
                Text(detail)
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Text("Later")
                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                .tracking(0.95)
                .textCase(.uppercase)
                .foregroundStyle(Color(hex: 0x7F8A85))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5))
        }
        .padding(.vertical, 14)
    }

    var appIconPickerRow: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                NoopCanonicalGlyph(name: .grid, size: 19, color: NoopHTMLColor.blueLight)
                    .frame(width: 21)
                VStack(alignment: .leading, spacing: 2) {
                    Text("App icon")
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(selectedAppIcon.detail)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 9), count: 3),
                spacing: 9
            ) {
                ForEach(NoopAppIconChoice.allCases) { choice in
                    let selected = choice == selectedAppIcon
                    Button {
                        selectAppIcon(choice)
                    } label: {
                        VStack(spacing: 8) {
                            NoopAppIconArtwork(choice: choice)
                                .frame(width: 46, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 10.3, style: .continuous))
                                .shadow(color: .black.opacity(0.34), radius: 6.5, y: 2.3)
                            Text(choice.rawValue)
                                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                                .foregroundStyle(selected ? Color(hex: 0x9FE2FB) : Color(hex: 0x8B958F))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                        .padding(.top, 9)
                        .padding(.bottom, 8)
                        .background(
                            selected ? NoopHTMLColor.blue.opacity(0.10) : Color.white.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    selected ? NoopHTMLColor.blue.opacity(0.50) : Color.white.opacity(0.08),
                                    lineWidth: 0.5
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .accessibilityLabel("Use the \(choice.rawValue) app icon")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }

            Text("iOS shows its own alert when the icon changes, and the new one can take a moment to appear on the Home Screen. Nothing else about the app changes.")
                .font(NoopHTMLFont.sans(NoopType.eyebrow))
                .foregroundStyle(Color(hex: 0x7F8A85))
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 16)
        .onAppear {
            selectedAppIcon = NoopAppIconChoice.current
        }
    }

    func selectAppIcon(_ choice: NoopAppIconChoice) {
        guard choice != selectedAppIcon else { return }
        guard UIApplication.shared.supportsAlternateIcons else {
            actionNotice = "This iPhone does not allow alternate app icons. The current icon remains selected."
            return
        }

        UIApplication.shared.setAlternateIconName(choice.alternateIconName) { error in
            DispatchQueue.main.async {
                if let error {
                    actionNotice = "The icon did not change. iOS said: \(error.localizedDescription)"
                } else {
                    selectedAppIcon = choice
                    preferences["App icon"] = choice.rawValue
                }
            }
        }
    }

    func actionRow(_ title: String, detail: String, symbol: String, tint: Color, titleColor: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(tint).frame(width: 21)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(titleColor ?? (tint == NoopHTMLColor.blue ? NoopHTMLColor.blueLight : tint))
                    Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                }
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

}

// MARK: Widgets

private extension NoopAct5Screens {
    var widgetFamilyCountWord: String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: NoopWidgetFamilyRegistry.count)) ?? String(NoopWidgetFamilyRegistry.count)
    }

    var widgetsScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                act5BackHeader("Settings", action: navigation.back)
                pageTitle(
                    "Widgets",
                    copy: measured
                        ? "\(widgetFamilyCountWord.capitalized) families."
                        : "\(widgetFamilyCountWord.capitalized) families. The three below are drawn in full; the rest are named underneath, and each one answers a single question without opening the app."
                )

                // The three drawn widgets carry the example person's figures; production lists the
                // families without them rather than show numbers that are not the wearer's.
                if !measured {

                widgetSurface(colors: [Color(hex: 0x14384A), Color(hex: 0x0C1A24), NoopHTMLColor.canvas], minHeight: 242) {
                    NoopSectionLabel("Home Screen · small", color: Color.white.opacity(0.5))
                    HStack(alignment: .top, spacing: 13) {
                        VStack(alignment: .leading) {
                            HStack(spacing: 6) { Circle().fill(NoopHTMLColor.blue).frame(width: 7, height: 7); NoopSectionLabel("Charge", color: Color(hex: 0x8B958F)) }
                                .offset(y: 1)
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text("56").font(NoopHTMLFont.outfit200(44)).tracking(-1.3)
                                Text("of 92").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            // Flip-checked against the 402×874 HTML: Swift's one flexible spacer
                            // seats this group six points too high while the header and footer land.
                            .offset(y: 6)
                            VStack(alignment: .leading, spacing: 8) {
                                widgetChargeTrack
                                Text("Plenty left").font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.inkSoft)
                            }
                            .offset(y: 1)
                        }
                        .frame(width: 146, height: 146, alignment: .leading)
                        .padding(15)
                        .background(NoopHTMLColor.canvas.opacity(0.74), in: RoundedRectangle(cornerRadius: 26))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.45), radius: 15, y: 12)
                        Text("How much of the day have I got left? The bar carries the day’s spend, the pale stretch behind it is what you woke with.")
                            .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color.white.opacity(0.62)).lineSpacing(4)
                    }
                }

                widgetSurface(colors: [Color(hex: 0x1E2340), Color(hex: 0x111421), NoopHTMLColor.canvas], minHeight: 291) {
                    NoopSectionLabel("Home Screen · medium", color: Color.white.opacity(0.5))
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 0) {
                            NoopSectionLabel("Last night", color: Self.lavender)
                                .offset(y: 1)
                            Spacer()
                            VStack(alignment: .leading, spacing: 3) {
                                Text("7h 12m").font(NoopHTMLFont.outfit(NoopType.title1, weight: .ultraLight))
                                Text("7m over your need")
                                    .font(NoopHTMLFont.sans(NoopType.eyebrow))
                                    .foregroundStyle(Color(hex: 0x8B958F))
                                    .offset(y: -5)
                            }
                            .offset(y: -2)
                            Spacer()
                            // `text-wrap: pretty` deliberately makes this two lines in the HTML.
                            Text("Deep came early. Nothing\nto fix.")
                                .font(NoopHTMLFont.sans(NoopType.eyebrow))
                                .foregroundStyle(NoopHTMLColor.inkSoft)
                                .lineSpacing(2)
                                .offset(y: -4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Divider().overlay(Color.white.opacity(0.07))
                        VStack(alignment: .leading) {
                            HStack(alignment: .bottom, spacing: 7) {
                                ForEach(
                                    Array([
                                        ("Deep", 40.0, 1.0),
                                        ("Light", 62.0, 0.6),
                                        ("REM", 34.0, 0.82),
                                        ("Awake", 9.0, 0.26)
                                    ].enumerated()),
                                    id: \.offset
                                ) { entry in
                                    let stage = entry.element
                                    VStack(spacing: 5) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Self.lavender.opacity(stage.2))
                                            .frame(height: stage.1)
                                        Text(stage.0)
                                            .font(NoopHTMLFont.sans(NoopType.eyebrow))
                                            .tracking(0.35)
                                            .foregroundStyle(NoopHTMLColor.muted)
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            // CSS gives this track 62 px, but Instrument Sans' native line box is
                            // four points taller than the browser's. A 66 pt track preserves the
                            // same intentional upward overflow and lands every bar on the HTML pixels.
                            .frame(height: 66, alignment: .bottom)
                            .padding(.leading, 12)
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text("56").font(NoopHTMLFont.outfit(NoopType.title2, weight: .light)).foregroundStyle(NoopHTMLColor.blueLight)
                                NoopSectionLabel("charge", color: Color(hex: 0x7F8A85))
                            }
                            .padding(.leading, 12)
                        }
                        .frame(width: 104)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 151)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                    .background(NoopHTMLColor.canvas.opacity(0.74), in: RoundedRectangle(cornerRadius: 26))
                    .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.45), radius: 15, y: 12)
                    Text("What did the night actually give me? Duration against your own need, the four stages, and the charge it left you on.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color.white.opacity(0.62)).lineSpacing(4)
                }

                widgetSurface(colors: [Color(hex: 0x232323), Color(hex: 0x141414), NoopHTMLColor.canvas]) {
                    NoopSectionLabel("Lock Screen · circular and inline", color: Color.white.opacity(0.5))
                    HStack(spacing: 20) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.16), lineWidth: 6)
                            Circle().trim(from: 0, to: 0.56).stroke(NoopHTMLColor.blueLight, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                            VStack(spacing: 0) { Text("56").font(NoopHTMLFont.outfit(NoopType.title3, weight: .light)); NoopSectionLabel("chg", color: Color.white.opacity(0.6)) }
                        }.frame(width: 74, height: 74)
                        VStack(alignment: .leading, spacing: 9) {
                            Text("9:41").font(NoopHTMLFont.outfit200(34))
                            HStack(spacing: 7) { Circle().fill(NoopHTMLColor.blueLight).frame(width: 6, height: 6).shadow(color: NoopHTMLColor.blueLight.opacity(0.7), radius: 4); Text("Charge 56 · slept 7h 12m").font(NoopHTMLFont.sans(NoopType.caption)) }
                        }
                    }.padding(.vertical, 6)
                    Text("A glance without unlocking. The ring is the same gauge as the orb, and the inline line replaces the one thing people check the app for.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color.white.opacity(0.62)).lineSpacing(4)
                }

                }

                VStack(spacing: 0) {
                    ForEach(Array(NoopWidgetFamilyRegistry.families.enumerated()), id: \.element.id) { index, family in
                        if index > 0 {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(family.title)
                                    .font(NoopHTMLFont.sans(NoopType.footnote))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                Text(family.detail)
                                    .font(NoopHTMLFont.sans(NoopType.caption))
                                    .foregroundStyle(Color(hex: 0x7F8A85))
                                    .lineSpacing(2.7)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 8)
                            if family.isNew {
                                Text("new")
                                    .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                                    .tracking(0.9)
                                    .textCase(.uppercase)
                                    .foregroundStyle(NoopHTMLColor.blueLight)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(NoopHTMLColor.blue.opacity(0.4), lineWidth: 0.5)
                                    )
                            }
                        }
                        .padding(.vertical, 12)
                        .frame(minHeight: 56)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 26))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                )

                Text("Long-press your Home Screen, tap the +, and search Noop. Every one of them reads the last sync — none of them wakes the strap on its own, and none of them shows a figure the app itself would withhold.")
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                    .lineSpacing(4)
                    .padding(.horizontal, 2)
            }
        }
    }

    func widgetSurface<Content: View>(colors: [Color], minHeight: CGFloat? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 13) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: minHeight, alignment: .topLeading)
            .background {
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.clear)
                    .overlay {
                        NoopCSSLinearGradient(
                            stops: [
                                .init(color: colors[0], location: 0),
                                .init(color: colors[1], location: 0.6),
                                .init(color: colors[2], location: 1)
                            ],
                            degrees: 168
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                    }
            }
            .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
    }

    var widgetChargeTrack: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    Color(hex: 0x9FE2FB, alpha: 0.24).frame(width: proxy.size.width * 0.92)
                    Color.white.opacity(0.08)
                }
                RoundedRectangle(cornerRadius: 3)
                    .fill(NoopHTMLColor.blueLight)
                    .frame(width: proxy.size.width * 0.56)
            }
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(height: 6)
    }
}

// MARK: The Lab

private extension NoopAct5Screens {
    var r22WriteReady: Bool {
        live.connected && live.encryptedBond && live.worn
    }

    var ecgWriteReady: Bool {
        live.connected && live.encryptedBond && live.whoop5Variant == "MG"
    }

    func labControlIsOn(_ title: String) -> Bool {
        switch title {
        case "Broadcast heart rate": broadcastHrEnabled
        case "R22 deep data": deepDataEnabled
        case "ECG raw data": ecgRawDataEnabled
        default: isEnabled(title)
        }
    }

    func labGateCopy(_ title: String, fallback: String) -> String {
        switch title {
        case "R22 deep data":
            if !live.connected || !live.encryptedBond {
                return "Needs the full encrypted bond — close the official app and pair to Noop first."
            }
            if !live.worn {
                return "Put the strap on first. The deeper stream is only available while it is worn."
            }
            return "Full encrypted bond ready. Noop can write the sixteen flags now."
        case "ECG raw data":
            if !live.connected || !live.encryptedBond {
                return "Needs the full encrypted bond — close the official app and pair to Noop first."
            }
            if live.whoop5Variant != "MG" {
                return "Waiting for your strap to identify itself as an MG. Only an MG has the electrodes, so Noop will not write this to anything else."
            }
            return "Attested MG and full encrypted bond ready. Noop will write the key and read it back."
        default:
            return fallback
        }
    }

    func toggleLabControl(_ title: String) {
        switch title {
        case "Broadcast heart rate":
            let newValue = !broadcastHrEnabled
            broadcastHrEnabled = newValue
            model.ble.setBroadcastHr(newValue)

        case "R22 deep data":
            if deepDataEnabled {
                // The app-side opt-in stops immediately. Clearing the value that may already be on the
                // strap remains a separate, explicit hardware write in the confirmation below.
                deepDataEnabled = false
                labFlagToClear = title
            } else if r22WriteReady {
                deepDataEnabled = true
                model.ble.enableWhoop5DeepData()
            } else {
                actionNotice = labGateCopy(title, fallback: "")
            }

        case "ECG raw data":
            if ecgRawDataEnabled {
                // Match R22: Noop is off before the user decides whether the persistent strap value
                // should also be cleared.
                ecgRawDataEnabled = false
                labFlagToClear = title
            } else if ecgWriteReady {
                ecgRawDataEnabled = true
                model.ble.setEcgRawDataGate(true)
            } else {
                actionNotice = labGateCopy(title, fallback: "")
            }

        default:
            flip(title)
        }
    }

    func clearStoredLabFlag(_ title: String) {
        switch title {
        case "R22 deep data":
            guard live.connected, live.encryptedBond else {
                actionNotice = "Reconnect with the full encrypted bond, then turn R22 on and off again to clear the stored flags. Noop is already off."
                return
            }
            model.ble.disableWhoop5DeepData()
        case "ECG raw data":
            guard ecgWriteReady else {
                actionNotice = "Reconnect the attested MG with the full encrypted bond, then turn ECG raw data on and off again to clear the stored key. Noop is already off."
                return
            }
            // BLEManager's ECG allowlist currently requires the experiment opt-in in both directions.
            // Keep the visible and lasting preference off, granting it only for this synchronous,
            // user-confirmed off write. Its scheduled read-back is admitted by the in-flight report.
            UserDefaults.standard.set(true, forKey: PuffinExperiment.ecgRawDataKey)
            model.ble.setEcgRawDataGate(false)
            UserDefaults.standard.set(false, forKey: PuffinExperiment.ecgRawDataKey)
        default:
            break
        }
    }

    /// The bug-report exports, out of the Lab (23 Oct 2026): they are tools, not experiments.
    var diagnosticsScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("Settings", action: navigation.back)
                pageTitle("Diagnostics", copy: "The exports that make a problem answerable. All local, all plain files; nothing leaves the phone unless you send it.")
                    .padding(.bottom, 8)
                labGroup("Exports", blurb: "Send the zip with a note of what went wrong and roughly when.") {
                    labAction("Copy the strap log", detail: "the connection and protocol trace, as text", symbol: "doc.on.doc")
                    Divider().overlay(NoopHTMLColor.border)
                    labAction("Export raw sensor data", detail: "the decoded per-sample streams for the last 24 hours, as CSV", symbol: "arrow.down.to.line")
                    Divider().overlay(NoopHTMLColor.border)
                    labAction("Export raw and log together", detail: "one zip, for when the two need reading side by side", symbol: "archivebox")
                    Divider().overlay(NoopHTMLColor.border)
                    labAction("Mark an experiment phase", detail: "timestamps the local capture file — sends nothing to the strap", symbol: "clock")
                    Divider().overlay(NoopHTMLColor.border)
                    labAction("This phone’s environment", detail: "model, iOS build, data protection, background refresh, certificate expiry", symbol: "doc.text")
                    Divider().overlay(NoopHTMLColor.border)
                    labAction("Test Centre", detail: "run a reading against a known input and see where it disagrees", symbol: "flask")
                }

            }
        }
    }

    var labScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("Settings", action: navigation.back)
                pageTitle("The Lab", copy: "Readings still being worked out, and probes that touch the strap. Every switch here says what it can and cannot reach. Bug-report exports are in Settings → Diagnostics.")
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 9) {
                    Text("Read this once").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold)).foregroundStyle(Color(hex: 0xF6DCB4))
                    Text("Two of these write a persistent flag to the strap itself. They are marked. Turning such a switch off stops Noop sending it — it does not undo what the strap already stored, so Noop offers to clear it instead of pretending.")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0xC9BFA9)).lineSpacing(4)
                }
                .padding(.vertical, 1)
                .padding(.bottom, 2)
                .padding(16)
                .background(Self.warm.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Self.warm.opacity(0.24), lineWidth: 0.5))

                labGroup("Readings still being worked out", blurb: "These change what a number says. Sleep staging, wake refinement and HRV capture have settled and moved to Settings › Sleep and Settings › Strap.") {
                    labToggle("SpO₂ strap estimate", detail: "Shows the strap’s own unverified nightly oxygen mean where no calibrated figure exists. Display only — writes nothing.")
                }

                labGroup("Probes that touch the strap", blurb: "Each of these sends something to the hardware. Two write a flag that survives a reboot, so turning the switch off offers to clear it rather than leaving it set.") {
                    labToggle("R22 deep data", detail: "Writes sixteen feature flags that unlock the denser frame set. Noop reads every one back and reports what the strap actually stored.", badge: "writes to strap", gate: "Needs the full encrypted bond — close the official app and pair to Noop first.", persistent: true)
                    Divider().overlay(NoopHTMLColor.border)
                    labToggle("ECG raw data", detail: "Stores the raw-ECG config key on an attested MG. One tap writes it, then Noop reads it back rather than trusting the write.", badge: "writes to strap", gate: "Waiting for your strap to identify itself as an MG. Only an MG has the electrodes, so Noop will not write this to anything else.", persistent: true)
                    Divider().overlay(NoopHTMLColor.border)
                    labToggle("Record protocol frames", detail: "Captures raw frames to a file for working out what an undocumented packet means. Local, and large.")
                }

                labGroup("Not in Aura yet", blurb: "Lab readouts the classic Noop screens have. Tap one to see why it is not here.") {
                    let options = NoopPendingOption.all.filter { $0.page == .lab }
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        if index > 0 { Divider().overlay(NoopHTMLColor.border) }
                        pendingRow(option)
                    }
                }

                Text("If a probe here changes a reading you care about, it belongs in Settings and not in the Lab. Say so and it will move.")
                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2).padding(.top, 4)
            }
        }
    }

    func labGroup<Content: View>(_ title: String, blurb: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NoopSectionLabel(title).padding(.horizontal, 2).padding(.top, 9)
            Text(blurb)
                .font(NoopHTMLFont.sans(NoopType.caption))
                .foregroundStyle(NoopHTMLColor.faint)
                .lineSpacing(4)
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            dividedCard { content() }
        }
    }

    func labToggle(_ title: String, detail: String, badge: String? = nil, gate: String? = nil, persistent: Bool = false, tint: Color = Self.lavender) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 13) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(title).font(NoopHTMLFont.sans(NoopType.footnote))
                        if let badge {
                            Text(badge.uppercased())
                                .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(badge == "writes to strap" ? Color(hex: 0xF6DCB4) : Color(hex: 0xC9D0EE))
                                .padding(.horizontal, 7).frame(minHeight: 21)
                                .background((badge == "writes to strap" ? Self.warm : Self.lavender).opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NoopA5TintToggle(isOn: labControlIsOn(title), tint: tint) {
                    toggleLabControl(title)
                }
            }
            if let gate {
                Text(labGateCopy(title, fallback: gate)).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(Color(hex: 0x8B92AE)).lineSpacing(3)
            }
            if title == "R22 deep data", let report = live.r22DisableReport {
                Text(report).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
            }
            if title == "ECG raw data", let report = live.ecgRawDataGate {
                Text(report.summary).font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
            }
        }
        .padding(.vertical, 14)
    }

    /// The Lab's diagnostic actions, wired to the same exports the classic Settings and Live screens use.
    /// They used to show "… is ready." and do nothing (tester, 23 Oct).
    func runLabAction(_ title: String) {
        switch title {
        case "Copy the strap log":
            PlatformPasteboard.copy(live.exportableLogText())
            actionNotice = "Strap log copied. Paste it into a message or a note."
        case "Export raw sensor data", "Export raw and log together":
            guard !labExportBusy else { return }
            labExportBusy = true
            let withLog = title == "Export raw and log together"
            Task { @MainActor in
                defer { labExportBusy = false }
                guard let store = await model.repo.storeHandle() else {
                    actionNotice = "Export failed: the local store could not be opened."
                    return
                }
                do {
                    let url = try await store.exportRawCSV(deviceId: model.repo.deviceId,
                                                           since: Date().timeIntervalSince1970 - 24 * 60 * 60)
                    if withLog {
                        let extra = await DebugDataDiagnostics.dynamicLines(repo: model.repo)
                        await FileExport.exportPair(file: url, fileSuggestedName: url.lastPathComponent,
                                                    text: live.exportableLogText(extraHeaderLines: extra),
                                                    textSuggestedName: FileExport.timestampedName("noop-strap-log", ext: "txt"))
                    } else {
                        FileExport.exportFile(at: url)
                    }
                } catch {
                    actionNotice = "Export failed: \(error.localizedDescription)"
                }
            }
        case "Mark an experiment phase":
            showPhasePicker = true
        case "This phone’s environment":
            FileExport.exportText(IOSDiagnostics.capture().summaryLines().joined(separator: "\n"),
                                  suggestedName: FileExport.timestampedName("noop-environment", ext: "txt"))
        case "Test Centre":
            showTestCentre = true
        default:
            break
        }
    }

    func labAction(_ title: String, detail: String, symbol: String) -> some View {
        Button { runLabAction(title) } label: {
            HStack(spacing: 13) {
                Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(NoopHTMLColor.blue).frame(width: 21)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.blueLight)
                    Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                }
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

struct NoopA5TintToggle: View {
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(isOn ? tint : Color.white.opacity(0.09))
                .frame(width: 46, height: 28)
                .overlay(
                    Capsule().strokeBorder(
                        Color.white.opacity(isOn ? 0.14 : 0.16),
                        lineWidth: 0.5
                    )
                )
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(NoopHTMLColor.ink)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
                        .overlay(Circle().strokeBorder(.black.opacity(0.10), lineWidth: 0.5))
                        .padding(2)
                }
                .animation(.timingCurve(0.34, 1.25, 0.64, 1, duration: 0.24), value: isOn)
        }
        .buttonStyle(NoopPlainHitStyle())
    }
}

// MARK: Onboarding schedule

private extension NoopAct5Screens {
    var onboardingScreen: some View {
        GeometryReader { proxy in
            let canvasWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            let canvasHeight = min(proxy.size.height, UIScreen.main.bounds.height)
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        HStack(spacing: 5) {
                            Capsule().fill(Self.blush).frame(width: 7, height: 7)
                            Capsule().fill(Self.blush).frame(width: 22, height: 7)
                            Capsule().fill(Color.white.opacity(0.14)).frame(width: 7, height: 7)
                            Capsule().fill(Color.white.opacity(0.14)).frame(width: 7, height: 7)
                        }
                        Spacer()
                        Text("Step 2 of 4").font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                    }

                    Spacer(minLength: 24)

                    VStack(alignment: .leading, spacing: 25) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("When do you usually sleep?")
                                .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light)).tracking(-0.9).lineSpacing(1)
                            Text("This is the only question that changes the whole app. Everything else Noop works out by watching for a week.")
                                .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                        }

                        VStack(spacing: 9) {
                            shiftOption("At night, mostly", detail: "A normal bedtime that lands in the evening. Today means midnight to midnight.")
                            shiftOption("Rotating shifts", detail: "It changes week to week. Noop will anchor your day to your sleep instead of the clock.")
                            shiftOption("Permanent nights", detail: "You sleep in daylight. Every screen in the app will be written for that, not translated into it.")
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            Text("What Noop will not ask you").font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                            Text(NoopPositionCopy.inlineSentence)
                                .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x939C97)).lineSpacing(4.5)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 17)
                        .background(Self.lavender.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Self.lavender.opacity(0.2), lineWidth: 0.5))
                    }

                    Spacer(minLength: 24)

                    VStack(spacing: 8) {
                        Button {
                            guard selectedShift != nil else { return }
                            navigation.push(.pair)
                        } label: {
                            Text(selectedShift == nil ? "Pick one to continue" : "Continue")
                                .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                .foregroundStyle(selectedShift == nil ? NoopHTMLColor.muted : Self.blushDark)
                                .frame(maxWidth: .infinity).frame(minHeight: 56)
                                .background(selectedShift == nil ? Color.white.opacity(0.07) : Self.blush, in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedShift == nil ? Color.white.opacity(0.1) : .clear, lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .disabled(selectedShift == nil)

                        Button("I would rather not say") {
                            selectedShift = nil
                            navigation.push(.pair)
                        }
                        .font(NoopHTMLFont.sans(NoopType.footnote))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .frame(minHeight: 42)
                    }
                }
                .frame(width: max(0, canvasWidth - 44))
                .frame(minHeight: max(0, canvasHeight - 84))
                .padding(.horizontal, 22)
                .padding(.top, 56)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: UIScreen.main.bounds.width)
        .background(Color.clear)
    }

    func shiftOption(_ title: String, detail: String) -> some View {
        let selected = selectedShift == title
        return Button { selectedShift = title } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(selected ? Self.blush : .clear)
                    .frame(width: 20, height: 20)
                    .overlay(Circle().stroke(selected ? Self.blush : Color.white.opacity(0.22), lineWidth: 1.5))
                    .overlay(Circle().stroke(NoopHTMLColor.canvas, lineWidth: selected ? 4 : 0))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                    Text(detail).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 17)
            .background(selected ? Self.blush.opacity(0.1) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(selected ? Self.blush.opacity(0.4) : NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

// MARK: Pairing

private extension NoopAct5Screens {
    var pairingScreen: some View {
        GeometryReader { proxy in
            let canvasWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            let canvasHeight = min(proxy.size.height, UIScreen.main.bounds.height)
            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        NoopBackButton(action: navigation.back)
                        Spacer()
                        NoopSectionLabel(paired ? "Paired" : "Looking")
                        Spacer()
                        Color.clear.frame(width: NoopCloseButton.side, height: NoopCloseButton.side)
                    }

                    Spacer(minLength: 24)

                    VStack(spacing: 24) {
                        NoopA5PairPulse(paired: paired)

                        VStack(spacing: 9) {
                            Text(paired ? "That is everything." : "Hold the button until it blinks.")
                                .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light)).tracking(-0.8).multilineTextAlignment(.center)
                            Text(paired
                                 ? "Three nights were buffered on the strap and they are importing now. Noop will watch for a week before it tells you anything — the first read arrives next Sunday."
                                 : "Noop found one strap nearby. Nothing is connected until you tap Connect, and pairing does not send anything anywhere.")
                                .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy).multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 290)
                        }

                        HStack(spacing: 13) {
                            NoopCanonicalGlyph(name: .watch, size: 20, color: NoopHTMLColor.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WHOOP 5.0 / MG").font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                Text(paired ? "connected · 52% · importing 3 nights" : "signal strong · 52% battery")
                                    .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            Spacer()
                            NoopPill(text: paired ? "Connected" : "Found", color: paired ? NoopHTMLColor.blueLight : NoopHTMLColor.copy)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .frame(width: max(0, canvasWidth - 10))
                        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.border, lineWidth: 0.5))
                    }

                    Spacer(minLength: 24)

                    VStack(spacing: 8) {
                        Button {
                            if paired { navigation.back() } else { paired = true; activeDevice = "mg"; connected = true }
                        } label: {
                            Text(paired ? "Back to your straps" : "Connect")
                                .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.blueInk)
                                .frame(maxWidth: .infinity).frame(minHeight: 58)
                                .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 19))
                                .shadow(color: NoopHTMLColor.blue.opacity(0.28), radius: 13, y: 8)
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        Text(paired
                             ? "You can wear it loosely. Noop would rather have an imperfect night than none."
                             : "If nothing appears, the strap is asleep — put it on the charger for a moment.")
                            .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint).multilineTextAlignment(.center).lineSpacing(3)
                    }
                }
                .frame(width: max(0, canvasWidth - 44))
                .frame(minHeight: max(0, canvasHeight - 84))
                .padding(.horizontal, 22)
                .padding(.top, 56)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: UIScreen.main.bounds.width)
        .background(Color.clear)
    }
}

private struct NoopA5PairPulse: View {
    let paired: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animationStart = Date()

    var body: some View {
        NoopAnimatedTimeline(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion || paired) { timeline in
            ZStack {
                if !paired {
                    pulseRing(at: timeline.date.timeIntervalSinceReferenceDate, delay: 0)
                    pulseRing(at: timeline.date.timeIntervalSinceReferenceDate, delay: 1.2)
                }
                Circle()
                    .fill(paired ? NoopHTMLColor.blue.opacity(0.18) : Color.white.opacity(0.06))
                    .frame(width: 92, height: 92)
                    .overlay(Circle().stroke(paired ? NoopHTMLColor.blue.opacity(0.5) : Color.white.opacity(0.12), lineWidth: 0.5))
                NoopCanonicalGlyph(name: .watch, size: 38, color: paired ? NoopHTMLColor.blue : NoopHTMLColor.copy)
            }
        }
        .frame(width: 150, height: 150)
    }

    private func pulseRing(at time: TimeInterval, delay: TimeInterval) -> some View {
        let duration = 2.4
        let elapsed = time - animationStart.timeIntervalSinceReferenceDate
        let delayed = elapsed - delay
        let phase = delayed < 0 ? 0 : delayed.truncatingRemainder(dividingBy: duration) / duration
        let travel = min(1, phase / 0.7)
        let eased = cssEaseOut(travel)
        let waiting = delayed < 0
        let scale = CGFloat(reduceMotion ? 1 : waiting ? 1 : 0.7 + 0.8 * eased)
        let opacity = reduceMotion ? 0.28 : waiting ? 1 : phase < 0.7 ? 0.55 * (1 - eased) : 0

        return Circle()
            .stroke(NoopHTMLColor.blue.opacity(0.45), lineWidth: 1)
            .frame(width: 150, height: 150)
            .scaleEffect(scale)
            .opacity(opacity)
    }

    /// CSS `ease-out` is cubic-bezier(0, 0, .58, 1). Solve x(t), then return y(t), so the
    /// expanding pairing rings share the HTML's timing instead of a faster cubic shortcut.
    private func cssEaseOut(_ x: Double) -> Double {
        var lower = 0.0
        var upper = 1.0
        for _ in 0..<14 {
            let t = (lower + upper) / 2
            let oneMinusT = 1 - t
            let curveX = 3 * oneMinusT * t * t * 0.58 + t * t * t
            if curveX < x { lower = t } else { upper = t }
        }
        let t = (lower + upper) / 2
        return 3 * (1 - t) * t * t + t * t * t
    }
}

private extension NoopAct5Screens {
    var positionScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 0) {
                NoopBackHeader(label: "You") { navigation.back(or: .you) }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What Noop will not ask you")
                            .font(NoopHTMLFont.outfit(NoopType.title2))
                            .tracking(-0.625)
                            .foregroundStyle(NoopHTMLColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(NoopPositionCopy.lead)
                            .font(NoopHTMLFont.sans(NoopType.footnote))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(NoopPositionCopy.denials.enumerated()), id: \.offset) { index, denial in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(denial.title)
                                    .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                Text(denial.reason)
                                    .font(NoopHTMLFont.sans(NoopType.caption))
                                    .foregroundStyle(NoopHTMLColor.copy)
                                    .lineSpacing(4.2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 15)
                            if index < NoopPositionCopy.denials.count - 1 {
                                Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 22).fill(NoopHTMLColor.card))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))

                    // The counterweight, so the screen is not five refusals and nothing else.
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NoopPositionCopy.asksTitle)
                            .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.ink)
                        Text(NoopPositionCopy.asks)
                            .font(NoopHTMLFont.sans(NoopType.caption))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .lineSpacing(4.2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 22).fill(Self.blush.opacity(0.07)))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Self.blush.opacity(0.20), lineWidth: 0.5))

                    Text(NoopPositionCopy.foot)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 2)
                }
            }
        }
    }
}


/// The HTML's `stepBtnSm`: 26 pt, radius 9, white 7% with a hairline.
private struct NoopA5CompactStepStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .foregroundStyle(Color(hex: 0xC6CEC9))
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.11), lineWidth: 0.5))
    }
}

// MARK: - Pair a strap, measured

/// The designed `pair` screen on the real Bluetooth scan. It replaces the classic Add-device wizard in
/// Release: pick the band's family, see what is advertising nearby, tap one, Connect. Nothing connects
/// until Connect, and the registry entry is the same one the classic wizard wrote (`registerDevice`).
struct NoopLivePairScreen: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var glance: NoopLiveGlance
    @State private var family: WhoopModel = .whoop5mg
    @State private var picked: (uuid: String, name: String, rssi: Int)?
    @State private var registered = false
    @State private var found: [(uuid: String, name: String, rssi: Int)] = []

    var body: some View {
        NoopScreen(bottomInset: 40, topInset: 56) {
            VStack(spacing: 22) {
                HStack {
                    NoopBackButton { leave() }
                    Spacer()
                    Text(registered ? "PAIRED" : "LOOKING")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow, weight: .semibold)).tracking(1.5)
                        .foregroundStyle(Color(hex: 0x7F8A85))
                    Spacer()
                    Color.clear.frame(width: NoopCloseButton.side, height: NoopCloseButton.side)
                }

                HStack(spacing: 6) {
                    ForEach(WhoopModel.allCases) { option in
                        Button {
                            guard option != family else { return }
                            family = option
                            picked = nil
                            model.presentWhoopScan(model: option)
                        } label: {
                            Text(option.displayName)
                                .font(NoopHTMLFont.sans(NoopType.caption, weight: .semibold))
                                .foregroundStyle(option == family ? NoopHTMLColor.blueInk : NoopHTMLColor.inkSoft)
                                .frame(maxWidth: .infinity).frame(minHeight: 40)
                                .background(option == family ? NoopHTMLColor.blue : Color.white.opacity(0.05),
                                            in: RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .disabled(registered)
                    }
                }

                NoopA5PairPulse(paired: registered)

                VStack(spacing: 9) {
                    Text(registered ? "That is everything." : "Hold the button until it blinks.")
                        .font(NoopHTMLFont.outfit(NoopType.title2, weight: .light)).tracking(-0.8).multilineTextAlignment(.center)
                    Text(registered
                         ? "Noop is connecting and will import what the strap has buffered. It watches for a week before it tells you anything."
                         : found.isEmpty
                            ? "Looking for a \(family.displayName) nearby. Nothing is connected until you tap Connect, and pairing does not send anything anywhere."
                            : "Noop found \(found.count == 1 ? "one strap" : "\(found.count) straps") nearby. Nothing is connected until you tap Connect, and pairing does not send anything anywhere.")
                        .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                        .multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 300)
                }

                VStack(spacing: 8) {
                    ForEach(found, id: \.uuid) { strap in
                        let selected = picked?.uuid == strap.uuid
                        Button { picked = strap } label: {
                            HStack(spacing: 13) {
                                NoopCanonicalGlyph(name: .watch, size: 20, color: NoopHTMLColor.blue)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(strap.name.isEmpty ? family.displayName : strap.name)
                                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                                    Text(Self.signal(strap.rssi))
                                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(Color(hex: 0x7F8A85))
                                }
                                Spacer()
                                NoopPill(text: registered && selected ? "Connected" : selected ? "Chosen" : "Found",
                                         color: selected ? NoopHTMLColor.blueLight : NoopHTMLColor.copy)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 15)
                            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 22))
                            .overlay(RoundedRectangle(cornerRadius: 22)
                                .stroke(selected ? NoopHTMLColor.blue.opacity(0.5) : NoopHTMLColor.border, lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .disabled(registered)
                    }
                }

                VStack(spacing: 8) {
                    Button { registered ? leave() : connect() } label: {
                        Text(registered ? "Back to your straps" : "Connect")
                            .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                            .foregroundStyle(canConnect || registered ? NoopHTMLColor.blueInk : NoopHTMLColor.muted)
                            .frame(maxWidth: .infinity).frame(minHeight: 58)
                            .background(canConnect || registered ? NoopHTMLColor.blue : Color.white.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 19))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                    .disabled(!canConnect && !registered)
                    Text(registered
                         ? "You can wear it loosely. Noop would rather have an imperfect night than none."
                         : "If nothing appears, the strap is asleep — put it on the charger for a moment.")
                        .font(NoopHTMLFont.sans(NoopType.eyebrow)).foregroundStyle(NoopHTMLColor.faint)
                        .multilineTextAlignment(.center).lineSpacing(3)
                }
            }
        }
        .onAppear { model.presentWhoopScan(model: family) }
        .onDisappear { if !registered { model.stopWhoopScan() } }
        // The scan publishes as straps advertise; the list follows it, strongest first.
        .onReceive(model.ble.$discoveredWhoops) { found = $0.sorted { $0.rssi > $1.rssi } }
    }

    private var canConnect: Bool { picked != nil }

    private static func signal(_ rssi: Int) -> String {
        rssi >= -60 ? "signal strong" : rssi >= -75 ? "signal fair" : "signal weak — bring it closer"
    }

    private func connect() {
        guard let picked else { return }
        model.stopWhoopScan()
        let modelLabel = family == .whoop4 ? "4.0" : "5.0 MG"
        let now = Int(Date().timeIntervalSince1970)
        model.registerDevice(PairedDevice(
            id: "whoop-\(picked.uuid)", brand: "WHOOP", model: modelLabel,
            nickname: picked.name.isEmpty ? nil : picked.name,
            peripheralId: picked.uuid, sourceKind: .liveBLE,
            capabilities: WhoopLiveCapabilities.metrics(forModel: modelLabel),
            status: .paired, addedAt: now, lastSeenAt: now), makeActive: true)
        registered = true
    }

    private func leave() {
        if !registered { model.stopWhoopScan() }
        navigation.back(or: .devices)
    }
}

/// The strap screen's sync control. "Sync now" used to fire and show nothing; it now follows the offload
/// it started: starting, syncing (with the time it has run), then synced or failed, and at rest it says
/// when the strap last synced. A tap the strap ignores because it is already caught up reads "Up to date".
struct NoopStrapSyncButton: View {
    let connected: Bool
    let sync: () -> Void
    let reconnect: () -> Void

    @EnvironmentObject private var live: LiveState
    @State private var requestedAt: Date?
    @State private var sawSyncing = false
    @State private var outcome: Outcome?

    enum Outcome: Equatable { case synced, upToDate, failed(String) }
    private enum Phase { case idle, starting, syncing, done(Outcome) }

    private static let green = Color(hex: 0x8FE3B4)

    private var phase: Phase {
        if live.backfilling { return .syncing }
        if requestedAt != nil { return .starting }
        if let outcome { return .done(outcome) }
        return .idle
    }

    var body: some View {
        VStack(spacing: 8) {
            Button {
                guard connected else { reconnect(); return }
                guard !live.backfilling, requestedAt == nil else { return }
                outcome = nil
                sawSyncing = false
                requestedAt = Date()
                sync()
            } label: {
                HStack(spacing: 9) {
                    icon
                    Text(title).contentTransition(.opacity)
                }
                .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(fill, in: RoundedRectangle(cornerRadius: 17))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(stroke, lineWidth: 0.5))
            }
            .buttonStyle(NoopHTMLPressStyle())
            .animation(.easeInOut(duration: 0.25), value: title)

            TimelineView(.periodic(from: .now, by: 30)) { _ in
                Text(caption)
                    .font(NoopHTMLFont.sans(NoopType.caption))
                    .foregroundStyle(captionColor)
                    .frame(maxWidth: .infinity)
            }
        }
        .onChange(of: live.backfilling) { _, now in
            if now {
                sawSyncing = true
                requestedAt = nil
            } else if sawSyncing {
                sawSyncing = false
                finish(live.lastSyncError.map(Outcome.failed) ?? .synced)
            }
        }
        .task(id: requestedAt) {
            // The strap ignores a tap when it is already caught up or another sync just ran: no offload
            // starts. Give it a few seconds to begin before saying so.
            guard requestedAt != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            guard requestedAt != nil, !live.backfilling else { return }
            requestedAt = nil
            finish(.upToDate)
        }
        .task(id: outcome) {
            guard outcome != nil else { return }
            try? await Task.sleep(for: .seconds(8))
            outcome = nil
        }
    }

    private func finish(_ o: Outcome) {
        outcome = o
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred({
            if case .failed = o { return .error } else { return .success }
        }())
        #endif
    }

    private var title: String {
        guard connected else { return "Reconnect" }
        switch phase {
        case .idle: return "Sync now"
        case .starting: return "Starting sync…"
        case .syncing: return "Syncing…"
        case .done(.synced): return "Synced"
        case .done(.upToDate): return "Already up to date"
        case .done(.failed): return "Sync didn't finish"
        }
    }

    @ViewBuilder private var icon: some View {
        switch connected ? phase : .idle {
        case .starting, .syncing:
            ProgressView().controlSize(.small).tint(NoopHTMLColor.blueLight)
        case .done(.failed):
            Image(systemName: "exclamationmark.triangle.fill")
        case .done:
            Image(systemName: "checkmark")
        case .idle:
            Image(systemName: "arrow.triangle.2.circlepath")
        }
    }

    private var tone: Int {   // 0 primary, 1 working, 2 good, 3 bad
        guard connected else { return 0 }
        switch phase {
        case .idle: return 0
        case .starting, .syncing: return 1
        case .done(.failed): return 3
        case .done: return 2
        }
    }

    private var ink: Color {
        [NoopHTMLColor.blueInk, NoopHTMLColor.blueLight, Self.green, Color(hex: 0xFF9A8A)][tone]
    }
    private var fill: Color {
        [NoopHTMLColor.blue, NoopHTMLColor.blue.opacity(0.16), Self.green.opacity(0.12), Color(hex: 0xFF6B57).opacity(0.12)][tone]
    }
    private var stroke: Color {
        [.clear, NoopHTMLColor.blue.opacity(0.4), Self.green.opacity(0.36), Color(hex: 0xFF6B57).opacity(0.4)][tone]
    }

    private var caption: String {
        if case .done(.failed(let why)) = phase, connected { return why }
        if live.backfilling { return "Pulling stored history from the strap. Keep it close." }
        guard let ts = live.lastSyncedAt else { return connected ? "Not synced yet" : "Strap not connected" }
        let when = Date(timeIntervalSince1970: ts)
        if Date().timeIntervalSince(when) < 60 { return "Last synced just now" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return "Last synced \(f.localizedString(for: when, relativeTo: Date()))"
    }

    private var captionColor: Color {
        if case .done(.failed) = phase, connected { return Color(hex: 0xFF9A8A) }
        return NoopHTMLColor.faint
    }
}

// MARK: - Settings pages

extension NoopAct5Screens {
    /// You's catalog, for the new-look choice (the list itself sits in a private extension).
    static var youCatalog: [NoopPageSection] { youSections }
}


/// One page of Settings (26 Oct 2026). The hub lists the pages in three blocks under the strap card;
/// each opens its own route. The Lab and Diagnostics keep the screens they already had.
enum NoopSettingsPage: String, CaseIterable, Identifiable {
    case today, sleep, fitness, scores, you, strap, alerts, svea, data, look, lab, diagnostics, later, about

    var id: String { rawValue }

    enum Block: String, CaseIterable {
        case pages = "Your pages"
        case noop = "Noop"
        case more = "More"
    }

    /// Nil for the Strap page, which the hub's strap card opens.
    var block: Block? {
        switch self {
        case .today, .sleep, .fitness, .scores, .you: .pages
        case .alerts, .svea, .data, .look: .noop
        case .lab, .diagnostics, .later, .about: .more
        case .strap: nil
        }
    }

    var route: NoopRoute {
        switch self {
        case .today: .settingsToday
        case .sleep: .settingsSleep
        case .fitness: .settingsFitness
        case .scores: .settingsScores
        case .you: .settingsYou
        case .strap: .settingsStrap
        case .alerts: .settingsAlerts
        case .svea: .settingsSvea
        case .data: .settingsData
        case .look: .settingsLook
        case .lab: .lab
        case .diagnostics: .diagnostics
        case .later: .settingsLater
        case .about: .settingsAbout
        }
    }

    init?(route: NoopRoute) {
        guard let page = Self.allCases.first(where: { $0.route == route }) else { return nil }
        self = page
    }

    var title: String {
        switch self {
        case .today: "Today"
        case .sleep: "Sleep"
        case .fitness: "Fitness"
        case .scores: "Trends and scores"
        case .you: "You"
        case .strap: "Strap"
        case .alerts: "Notifications"
        case .svea: "Svea"
        case .data: "Data and connections"
        case .look: "Look and feel"
        case .lab: "The Lab"
        case .diagnostics: "Diagnostics"
        case .later: "On the way"
        case .about: "About"
        }
    }

    var blurb: String {
        switch self {
        case .today: "What sits on Today besides your numbers: the journal strip and the trackers that add their own cards."
        case .sleep: "How a night is read and how you are woken."
        case .fitness: "The workout screen, and what Noop does when it sees a session you did not start."
        case .scores: "Charge, Effort and the baselines they are measured against."
        case .you: "Your record, your zones, and what Noop leaves out on purpose."
        case .strap: "The strap itself, its battery, and what it captures."
        case .alerts: "Every notice Noop can send, and the hours it stays quiet."
        case .svea: "Who answers, what she may read, and how she talks."
        case .data: "Where your record goes, where it comes from, and the file that keeps it safe."
        case .look: "Units, motion, widgets and the icon."
        case .lab: "Readings still being worked out, and probes that touch the strap."
        case .diagnostics: "The strap log, raw data and the files a bug report needs."
        case .later: "What the classic Noop screens have that Aura does not show yet. Each one also sits, dimmed, on the page it will live on. Tap one to see why it is not here."
        case .about: "This version, how Noop works, and the work it is built on."
        }
    }

    var symbol: String {
        switch self {
        case .today: "sun.max.fill"
        case .sleep: "moon.fill"
        case .fitness: "figure.run"
        case .scores: "chart.line.uptrend.xyaxis"
        case .you: "person.fill"
        case .strap: "applewatch"
        case .alerts: "bell.badge.fill"
        case .svea: "sparkles"
        case .data: "externaldrive.fill"
        case .look: "paintbrush.fill"
        case .lab: "flask.fill"
        case .diagnostics: "stethoscope"
        case .later: "hourglass"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .today: Color(hex: 0xF2B45C)
        case .sleep: Color(hex: 0x8B99D6)
        case .fitness: Color(hex: 0x2ECC80)
        case .scores: NoopHTMLColor.blue
        case .you: Color(hex: 0xE08A9B)
        case .strap: NoopHTMLColor.blue
        case .alerts: Color(hex: 0xFF8A7A)
        case .svea: Color(hex: 0xB79CF0)
        case .data: Color(hex: 0x5CC8C2)
        case .look: Color(hex: 0xB5D86A)
        case .lab: Color(hex: 0x8B99D6)
        case .diagnostics: Color(hex: 0x8B958F)
        case .later: Color(hex: 0x8B958F)
        case .about: Color(hex: 0x9FE2FB)
        }
    }
}

/// One row of a Settings page: what search and the hub need to know about it, and how to draw it.
struct NoopSettingsItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let keywords: String
    /// False for an entry that stands for a whole screen (the Lab, Diagnostics): search opens the
    /// screen without trying to scroll to a row it does not have.
    let focusable: Bool
    let row: () -> AnyView

    init(id: String, title: String, detail: String, keywords: String = "", focusable: Bool = true,
         row: @escaping () -> AnyView) {
        self.id = id
        self.title = title
        self.detail = detail
        self.keywords = keywords
        self.focusable = focusable
        self.row = row
    }
}

struct NoopSettingsSection: Identifiable {
    var title: String? = nil
    var note: String? = nil
    let items: [NoopSettingsItem]

    var id: String { title ?? items.first?.id ?? "" }
}

struct NoopSettingsHit: Identifiable {
    let page: NoopSettingsPage
    let section: String?
    let item: NoopSettingsItem

    var id: String { item.id }
}

/// An option the classic NOOP has that Aura does not show yet (26 Oct 2026). Each sits dimmed on the page
/// it will live on, says what it does and why it is not here, and all of them are listed on On the way.
/// Nothing here reads or writes a setting.
struct NoopPendingOption: Identifiable {
    enum Status {
        /// Will be ported: the work is known.
        case later
        /// Might not fit Aura's design; undecided whether it comes back.
        case deciding

        var label: String { self == .later ? "Later" : "Deciding" }
    }

    let id: String
    let page: NoopSettingsPage
    let status: Status
    let title: String
    let symbol: String
    let does: String
    let why: String

    static let all: [NoopPendingOption] = [
        // Today
        .init(id: "pending-key-metric-grid", page: .today, status: .deciding, title: "Key-metric grid", symbol: "square.grid.3x2",
              does: "Choose how many columns the classic key-metric tiles use, and how many days each tile averages.",
              why: "Aura lays Today out by editing the page instead of by a grid of tiles. Whether a grid comes back is still open."),
        .init(id: "pending-liquid-today", page: .today, status: .deciding, title: "Liquid Today", symbol: "drop",
              does: "The classic prototype Today, with the three scores drawn as living liquid under a time-of-day sky.",
              why: "Aura’s Today replaced it. It may return as a look for Today, or stay retired."),
        // Sleep
        .init(id: "pending-day-starts", page: .sleep, status: .later, title: "When the day starts", symbol: "sunrise",
              does: "Start each day at your main sleep instead of at midnight, so a late night counts toward the day it belongs to.",
              why: "Every Aura page that counts a day has to follow the same choice. It comes once they all can."),
        .init(id: "pending-hrv-window", page: .sleep, status: .later, title: "HRV window", symbol: "waveform.path.ecg",
              does: "Read your nightly HRV over the whole night, or over deep sleep only.",
              why: "The classic setting changes one number; in Aura, Charge, Trends and the night all read HRV and need to agree."),
        .init(id: "pending-sleep-chart", page: .sleep, status: .later, title: "Sleep chart", symbol: "chart.bar.xaxis",
              does: "The hypnogram drawn as rows or as a ribbon instead.",
              why: "Designed, not built yet."),
        // Fitness
        .init(id: "pending-session-haptics", page: .fitness, status: .later, title: "Session buzzes", symbol: "hand.tap",
              does: "Turn off the strap’s buzzes during a workout, a breathing session or the interval timer, each on its own.",
              why: "Each Aura session screen buzzes through its own path, and the switches need wiring into every one."),
        .init(id: "pending-live-sessions", page: .fitness, status: .deciding, title: "Live Sessions", symbol: "shield.lefthalf.filled",
              does: "A one-tap guarded workout: the strap watches your heart rate against a band set by today’s Charge and only buzzes to correct course.",
              why: "Aura’s session screens already cover most of it. Whether the guard returns as its own mode is open."),
        // Trends and scores
        .init(id: "pending-chart-colours", page: .scores, status: .later, title: "Chart colours", symbol: "paintpalette",
              does: "A second palette for the data, leaving the rest of the app alone.",
              why: "Designed, not built yet."),
        .init(id: "pending-trend-style", page: .scores, status: .later, title: "Trend chart style", symbol: "chart.bar",
              does: "Draw trend charts as lines or as bars.",
              why: "Aura’s trend charts are drawn one way for now. The second style comes with the chart pass."),
        .init(id: "pending-exponential-effort", page: .scores, status: .deciding, title: "Exponential effort", symbol: "function",
              does: "Weights hard minutes more heavily, the way a training-load model does, instead of a straight line.",
              why: "It changes every Effort score you have, so it needs a benchmark before it can be offered."),
        // Strap
        .init(id: "pending-phone-buzz", page: .strap, status: .later, title: "Buzz for phone notifications", symbol: "bell",
              does: "Choose which iPhone apps buzz your strap, and how.",
              why: "The screen is drawn. The path that carries an iPhone notification to the strap is not wired in Aura yet."),
        .init(id: "pending-wrist-shortcuts", page: .strap, status: .later, title: "Shortcuts on and off the wrist", symbol: "arrow.triangle.branch",
              does: "Run a Shortcut when the strap comes off (set a Focus, pause media) and another when it goes back on.",
              why: "It works in the classic app. Aura still needs a way to pick the Shortcut."),
        .init(id: "pending-hourly-sync", page: .strap, status: .later, title: "Hourly sync at any charge", symbol: "clock.arrow.circlepath",
              does: "Stretches the strap’s history sync to once an hour whatever its battery, not only when low. Nothing is lost: the strap keeps it until it is read.",
              why: "A part of Power saving that needs testing against Aura’s background sync."),
        .init(id: "pending-sync-awake", page: .strap, status: .later, title: "Keep the screen on while syncing", symbol: "iphone",
              does: "Holds the iPhone awake while the strap sends a long history, so the sync is not cut off.",
              why: "Needs testing against Aura’s background sync first."),
        .init(id: "pending-sync-activity", page: .strap, status: .later, title: "Sync on the Lock Screen", symbol: "rectangle.badge.checkmark",
              does: "A long sync’s progress as a Live Activity.",
              why: "Comes with the Lock Screen pass."),
        .init(id: "pending-oura-hr", page: .strap, status: .later, title: "Oura ring all-day heart rate", symbol: "circle.circle",
              does: "Oura ring only. Keeps the ring measuring heart rate through the day, standing it down only for your night.",
              why: "Oura works in the classic app. Aura’s strap pages are WHOOP-first for now."),
        // Notifications
        .init(id: "pending-predictive-battery", page: .alerts, status: .later, title: "Recharge tonight", symbol: "battery.25",
              does: "An early heads-up when the strap has about a day of estimated runtime left, at most once per discharge.",
              why: "The estimate already runs. The notice needs testing on a real discharge first."),
        .init(id: "pending-effort-target", page: .alerts, status: .later, title: "Effort target reached", symbol: "flame",
              does: "Once a day, when today’s Effort reaches the low end of what your Charge allows.",
              why: "Aura names that range differently. The wording and the number need to agree first."),
        .init(id: "pending-session-offer", page: .alerts, status: .later, title: "Session offer", symbol: "figure.run",
              does: "One notification a day, in the morning, with today’s recommendation.",
              why: "Aura does not recommend a session yet. The notice comes with the recommendation."),
        // Svea
        .init(id: "pending-svea-button", page: .svea, status: .deciding, title: "Floating Svea button", symbol: "bubble.left",
              does: "A button you can drag to any corner that opens Svea from every screen.",
              why: "Aura opens Svea from the centre of the tab bar. A second door may only add clutter."),
        .init(id: "pending-svea-today", page: .svea, status: .deciding, title: "Svea on Today", symbol: "person.crop.circle",
              does: "Her avatar as a card on Today, with the morning suggestion.",
              why: "Today is now edited by its own page. She may come back as a section there instead."),
        // Data and connections
        .init(id: "pending-mi-band", page: .data, status: .later, title: "Mi Band import", symbol: "figure.walk.motion",
              does: "Bring in history from a Xiaomi Mi Band through Mi Fitness.",
              why: "The import works in the classic app. Aura’s import screen lists WHOOP files and Apple Health first."),
        // Look and feel
        .init(id: "pending-distance-units", page: .look, status: .later, title: "Distance apart from units", symbol: "ruler",
              does: "Set exercise distance and pace apart from body measurements: kilograms with miles, say.",
              why: "Aura’s units are one switch today. The split comes with the workout pages."),
        .init(id: "pending-skin-temp", page: .look, status: .later, title: "Skin temperature as a change", symbol: "thermometer.medium",
              does: "Show skin temperature as degrees, or as the change from your own normal.",
              why: "Every page that shows it needs to follow the same choice."),
        .init(id: "pending-clock", page: .look, status: .later, title: "Clock", symbol: "clock",
              does: "12- or 24-hour times inside Noop, whatever the iPhone itself uses.",
              why: "Aura follows the iPhone for now."),
        .init(id: "pending-appearance", page: .look, status: .later, title: "Appearance", symbol: "circle.lefthalf.filled",
              does: "Light, dark, or follow the iPhone.",
              why: "Dark only in this build. Light is drawn but not coloured yet."),
        .init(id: "pending-language", page: .look, status: .later, title: "Language", symbol: "globe",
              does: "Noop in your own language.",
              why: "English only in this build. The strings are written but not translated."),
        .init(id: "pending-day-sky", page: .look, status: .later, title: "Day-cycle sky", symbol: "sun.haze",
              does: "A backdrop that moves with the hour.",
              why: "Designed, not built yet."),
        .init(id: "pending-card-surface", page: .look, status: .deciding, title: "Card surface", symbol: "square.on.square",
              does: "Frosted or clear cards, so the backdrop shows through.",
              why: "Clear cards trade legibility for the look. Whether that is worth it is open."),
        .init(id: "pending-accent", page: .look, status: .deciding, title: "Accent colour", symbol: "paintbrush.pointed",
              does: "One colour of your choice for the app’s controls.",
              why: "Aura’s colours mean something page by page. A single accent may fight that."),
        .init(id: "pending-background", page: .look, status: .deciding, title: "Your own background", symbol: "photo",
              does: "A photo of your own behind the pages.",
              why: "It would sit under Aura’s own canvas. Open whether the two can share a page."),
        .init(id: "pending-apple-colours", page: .look, status: .deciding, title: "Apple Health colours", symbol: "heart.circle",
              does: "Swap Noop’s palette for the colours Apple Health uses.",
              why: "Aura has its own palette. Open whether a second one is worth keeping in step."),
        .init(id: "pending-tab-bar", page: .look, status: .deciding, title: "Hide the tab bar while scrolling", symbol: "dock.rectangle",
              does: "The tab bar slides away as you scroll down and back as you scroll up.",
              why: "Aura’s tab bar floats over the page. Open whether hiding it helps or only moves things."),
        // The Lab
        .init(id: "pending-beat-rhythm", page: .lab, status: .later, title: "Beat Rhythm", symbol: "waveform.path",
              does: "An experimental view of beat-to-beat regularity. It needs reading and ticking a page first: no alarms, no red, no condition names.",
              why: "The consent page and the view need Aura’s design before it can be offered."),
        .init(id: "pending-hrv-readiness", page: .lab, status: .later, title: "HRV readiness tiers", symbol: "gauge.with.needle",
              does: "A read-only tier from the Plews and Altini method, beside Charge. It changes nothing else.",
              why: "Rough and early. It comes with the Lab’s readouts."),
        .init(id: "pending-ppg-interpolation", page: .lab, status: .later, title: "Finer heart rate from the optical signal", symbol: "point.topleft.down.to.point.bottomright.curvepath",
              does: "Removes a step of up to about 8 bpm when Noop fills seconds the strap never reported. It never replaces a stored reading.",
              why: "A research variant. It comes with the Lab’s readouts."),
        .init(id: "pending-polar-log", page: .lab, status: .later, title: "Polar debug log", symbol: "doc.text",
              does: "Writes a detailed log of a Polar sensor’s connection for a bug report.",
              why: "Polar works in the classic app. It comes with Aura’s support for other sensors."),
        // About
        .init(id: "pending-auto-updates", page: .about, status: .later, title: "Check automatically", symbol: "arrow.triangle.2.circlepath",
              does: "A quiet check for a new version once a day, and a notice when one is out.",
              why: "Aura only asks the release page when you tap. An automatic check comes with the notice for it.")
    ]
}
