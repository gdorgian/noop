import Foundation
import SwiftUI
import UIKit

// MARK: - Act 5 · You and the plumbing

struct NoopAct5Screens: View {
    @ObservedObject var navigation: NoopNavigation
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState
    @EnvironmentObject private var coach: AICoachEngine

    @AppStorage(PuffinExperiment.deepDataKey) private var deepDataEnabled = false
    @AppStorage(PuffinExperiment.broadcastHrKey) private var broadcastHrEnabled = false
    @AppStorage(PuffinExperiment.ecgRawDataKey) private var ecgRawDataEnabled = false

    @State private var historyFilter = "All"
    @State private var openZone: Int?
    @State private var hasPhoto = false
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
        "Apple Health", "Bedtime nudge", "Session offer", "Battery alerts", "Journal reminder",
        "Day-cycle sky", "Sky behind cards", "Pause the HRV stream when low", "Sleep staging V2",
        "Overnight only"
    ]
    @State private var lastLogAction: String?
    @State private var pinged = false

    @State private var sparePresent = true
    @State private var activeDevice = "mg"
    @State private var spareName = "WHOOP 4.0"
    @State private var renameDraft = ""
    @State private var deviceNotice: String?

    @State private var preferences: [String: String] = [
        "Units": "Metric", "Temperature": "°C", "Effort": "0–100", "Appearance": "Dark",
        "Chart colours": "Titanium", "Sleep chart": "Hypnogram", "Card surface": "Frosted",
        "App icon": "Titanium", "Power saving at": "20%", "Double tap": "Sleep mark",
        "Svea’s voice": "Plain"
    ]
    @State private var baselinesRestarting = false
    @State private var settingsSearch = ""
    @State private var actionNotice: String?

    @State private var selectedShift: String?
    @State private var paired = false
    @State private var labFlagToClear: String?

    var body: some View {
        Group {
            switch navigation.route {
            case .record: recordScreen
            case .zones: zonesScreen
            case .history: historyScreen
            case .strap: strapScreen
            case .devices: devicesScreen
            case .data: dataScreen
            case .settings: settingsScreen
            case .widgets: widgetsScreen
            case .lab: labScreen
            case .onboard: onboardingScreen
            case .pair: pairingScreen
            default: youScreen
            }
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

    func isEnabled(_ key: String) -> Bool { enabled.contains(key) }

    func flip(_ key: String) {
        if enabled.contains(key) { enabled.remove(key) } else { enabled.insert(key) }
    }

    func pageTitle(_ title: String, copy: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(NoopHTMLFont.outfit(25))
                .tracking(-0.6)
                .foregroundStyle(NoopHTMLColor.ink)
            Text(copy)
                .font(NoopHTMLFont.sans(13.5))
                .tracking(-0.15)
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(4)
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

    func copyRow(_ title: String, detail: String, symbol: String? = nil, tint: Color = NoopHTMLColor.blue, value: String? = nil, action: (() -> Void)? = nil) -> some View {
        Button { action?() } label: {
            HStack(spacing: 13) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(tint)
                        .frame(width: 21)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy)
                }
                if action != nil { NoopChevron() }
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
                    Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.ink)
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                }
                Spacer(minLength: 8)
                NoopA5TintToggle(isOn: isEnabled(title), tint: tint) {
                    if persistent, isEnabled(title) {
                        labFlagToClear = title
                    } else {
                        flip(title)
                    }
                }
            }
            .padding(.vertical, 13)
            if let gate {
                Text(gate)
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(Color(hex: 0x8B92AE))
                    .lineSpacing(3)
                    .padding(.bottom, 13)
            }
        }
    }

    func segmentRow(_ title: String, detail: String, choices: [String], tint: Color = Self.blush) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title).font(NoopHTMLFont.sans(13.5))
                Spacer()
                Text(detail).font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x7F8A85)).multilineTextAlignment(.trailing)
            }
            HStack(spacing: 4) {
                ForEach(choices, id: \.self) { choice in
                    let selected = title == "Svea’s voice"
                        ? navigation.coachVoice.rawValue == choice
                        : preferences[title] == choice
                    Button {
                        if title == "Svea’s voice", let voice = NoopCoachVoice(rawValue: choice) {
                            navigation.coachVoice = voice
                            preferences[title] = choice
                            if voice == .off {
                                UserDefaults.standard.set("Never", forKey: "noop.html.svea-proactive")
                                UserDefaults.standard.set(false, forKey: SveaProactiveBackgroundTask.enabledKey)
                                coach.proactiveLevel = .off
                                SveaProactiveBackgroundTask.updateSchedule(enabled: false)
                            }
                        } else {
                            preferences[title] = choice
                        }
                    } label: {
                        Text(choice)
                            .font(NoopHTMLFont.sans(11.5, weight: selected ? .semibold : .regular))
                            .foregroundStyle(selected ? Self.blushLight : NoopHTMLColor.copy)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(selected ? tint.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? tint.opacity(0.42) : .clear, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
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
                VStack(spacing: 2) {
                    NoopBodyClock()
                    Text("Gabriel")
                        .font(NoopHTMLFont.outfit(27, weight: .light))
                        .tracking(-0.8)
                    Text("Asleep 23:20 → 06:32 · a 7h 12m need, held to within nine minutes for 221 nights")
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(Color(hex: 0x8B958F))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 300)
                }

                VStack(alignment: .leading, spacing: 9) {
                    Button { navigation.push(.record) } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                NoopSectionLabel("Your record", color: Color(hex: 0xC08E98))
                                HStack(spacing: 10) {
                                    recordFact("29", "years")
                                    recordFact(heightDisplay, "")
                                    recordFact(weightDisplay, "")
                                    recordFact(sex.lowercased(), "")
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

                    NoopSectionLabel("The three numbers everything runs on")
                        .padding(.horizontal, 2)
                        .padding(.top, 8)

                    coreCard("Your sleep need", value: "7h 12m", tag: "learned", copy: "Worked out from 221 nights of your own sleep, not from a recommendation for adults in general. It moves slowly and tells you when it does.")
                    coreCard("Your bedtime hour", value: "23:20", tag: "learned", copy: "Learned from 221 nights. Everything the app says about regularity is measured against this hour, not against a clock you set.")
                    coreCard("Your zones", value: "5 zones · max \(maximumHeartRate)", tag: "measured", copy: "From a maximum Noop actually saw on a hill in June and a resting rate of 58. Tap to see what each zone is for.") {
                        navigation.push(.zones)
                    }

                    dividedCard {
                        VStack(spacing: 0) {
                            copyRow("Your journey", detail: "half marathon, 26 October · 46% recorded", symbol: "sparkles", tint: Self.blush) { navigation.push(.goal) }
                            Divider().overlay(NoopHTMLColor.border)
                            copyRow("Biomarkers", detail: "your own bloodwork, dated and kept here", symbol: "drop", tint: Self.blush, value: "7") { navigation.push(.labs) }
                            Divider().overlay(NoopHTMLColor.border)
                            copyRow("Your strap", detail: "WHOOP 5.0 / MG · synced 2 min ago", symbol: "applewatch", value: "52%") { navigation.push(.strap) }
                            Divider().overlay(NoopHTMLColor.border)
                            copyRow("Everything you logged", detail: "sessions, sleeps, coffees", symbol: "waveform.path.ecg", tint: Self.blush, value: "142") { navigation.push(.history) }
                            Divider().overlay(NoopHTMLColor.border)
                            copyRow("Data and permissions", detail: "what is kept, and what leaves", symbol: "shield", tint: Self.blush) { navigation.push(.data) }
                            Divider().overlay(NoopHTMLColor.border)
                            copyRow("Settings", detail: "every switch Noop has, in eleven groups", symbol: "ruler", tint: Self.blush) { navigation.push(.settings) }
                        }
                    }

                    Text("Noop is told six things about your body and works the rest out. There is no weight goal, no step target and no daily score, because none of them would change what it says to you.")
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4)
                        .padding(.horizontal, 2)
                }
                .padding(.top, 18)
            }
        }
    }

    func recordFact(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value).font(NoopHTMLFont.outfit(17)).foregroundStyle(Self.blushLight).monospacedDigit()
            if !label.isEmpty { Text(label).font(NoopHTMLFont.sans(10.5)).foregroundStyle(Color(hex: 0x8B958F)) }
        }
    }

    func coreCard(_ title: String, value: String, tag: String, copy: String, action: (() -> Void)? = nil) -> some View {
        Button { action?() } label: {
            NoopHTMLCard(radius: 20, padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy)
                            Text(value).font(NoopHTMLFont.outfit(27, weight: .light)).tracking(-0.8).monospacedDigit()
                        }
                        Spacer()
                        NoopPill(text: tag, color: tag == "learned" ? Self.blushLight : Color(hex: 0xC9D0EE))
                    }
                    Text(copy).font(NoopHTMLFont.sans(12)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
                }
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopBodyClock: View {
    private static let blush = Color(hex: 0xE08A9B)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion)) { timeline in
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

                ForEach(0..<24, id: \.self) { hour in
                    let major = hour % 6 == 0
                    let inSleep = hour <= 6
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
                    .offset(x: -54.2, y: -77.4)
                Circle()
                    .fill(NoopHTMLColor.canvas)
                    .overlay(Circle().stroke(Color(hex: 0xF2C4CE), lineWidth: 2))
                    .frame(width: 10.7, height: 10.7)
                    .offset(x: 93.5, y: 13.2)
                Circle()
                    .fill(Color(hex: 0x8B99D6))
                    .frame(width: 7, height: 7)
                    .offset(x: -16.4, y: -93.1)

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
                Text("G")
                    .font(NoopHTMLFont.outfit(42, weight: .light))
                    .tracking(-1.25)
                    .foregroundStyle(Color(hex: 0xF6D3DA))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250)
    }

    private var sleepArc: some Shape {
        Circle()
            .trim(from: 0, to: (6.533 + 24 - 23.333) / 24)
            .rotation(.degrees(-90 + 23.333 * 15))
    }

    private func clockLabel(_ value: String, x: CGFloat, y: CGFloat) -> some View {
        Text(value)
            .font(NoopHTMLFont.sans(9, weight: .semibold))
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
                act5BackHeader("You") { navigation.reset(to: .you) }
                pageTitle("Your record", copy: "Six facts and two calibrations. These set your zones, your calorie estimate and your body age — nothing else in the app asks you anything.")
                    .padding(.bottom, 6)

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack(spacing: 14) {
                            Group {
                                if hasPhoto {
                                    Image(systemName: "person.crop.circle.fill").resizable().scaledToFit().foregroundStyle(Self.blushLight)
                                } else {
                                    Text("G").font(NoopHTMLFont.outfit(31, weight: .light)).foregroundStyle(Self.blushLight)
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
                                    .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                                    .foregroundStyle(Self.blushLight)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 40)
                                    .background(Self.blush.opacity(0.11), in: RoundedRectangle(cornerRadius: 13))
                                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Self.blush.opacity(0.3), lineWidth: 0.5))
                                    .buttonStyle(NoopHTMLPressStyle())
                                if hasPhoto {
                                    Button("Remove photo") { hasPhoto = false }
                                        .font(NoopHTMLFont.sans(12)).foregroundStyle(Color(hex: 0x7F8A85)).frame(height: 32)
                                }
                            }
                        }
                        Text("Optional. It stays on this phone and is never uploaded — Noop has no account to upload it to.")
                            .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                    }
                    .padding(.vertical, 3.5)
                }

                dividedCard {
                    VStack(spacing: 0) {
                        dateOfBirthRow
                        Divider().overlay(NoopHTMLColor.border)
                        HStack(spacing: 13) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Sex").font(NoopHTMLFont.sans(13.5))
                                Text("used in the calorie and VO₂max models")
                                    .font(NoopHTMLFont.sans(11))
                                    .foregroundStyle(Color(hex: 0x7F8A85))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
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
                    Text("Why the waist is optional").font(NoopHTMLFont.sans(13.5, weight: .semibold))
                    Text("It adds an estimated VO₂max. It does not sharpen your body age — that model cancels the body term out — so Noop will not nag you for it.")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(Color(hex: 0xC9BEC0)).lineSpacing(4)
                }
                .padding(16)
                .background(Self.blush.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Self.blush.opacity(0.2), lineWidth: 0.5))
            }
        }
    }

    var dateOfBirthRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Date of birth").font(NoopHTMLFont.sans(13.5))
                Spacer()
                Text("\(birthDay) \(monthName) \(birthYear) · 29 years")
                    .font(NoopHTMLFont.sans(12)).foregroundStyle(Self.blushLight)
            }
            HStack(spacing: 7) {
                compactStepper(value: "\(birthDay)", label: "day", minus: { birthDay = birthDay == 1 ? 31 : birthDay - 1 }, plus: { birthDay = birthDay == 31 ? 1 : birthDay + 1 })
                compactStepper(value: String(monthName.prefix(3)), label: "month", minus: { birthMonth = birthMonth == 1 ? 12 : birthMonth - 1 }, plus: { birthMonth = birthMonth == 12 ? 1 : birthMonth + 1 })
                compactStepper(value: "\(birthYear)", label: "year", minus: { birthYear = max(1930, birthYear - 1) }, plus: { birthYear = min(2012, birthYear + 1) })
            }
            Text("Your age is derived from this, so it advances on its own. Nothing else in the app asks for it.")
                .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(2)
        }
        .padding(.vertical, 11.5)
    }

    var compactSexControl: some View {
        HStack(spacing: 3) {
            ForEach(["Male", "Female", "Other"], id: \.self) { choice in
                let selected = sex == choice
                Button { sex = choice } label: {
                    Text(choice)
                        .font(NoopHTMLFont.sans(11.5, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: true, vertical: false)
                        .foregroundStyle(selected ? Self.blushLight : NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(selected ? Self.blush.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 11))
                        .overlay(RoundedRectangle(cornerRadius: 11).stroke(selected ? Self.blush.opacity(0.42) : .clear, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .frame(width: 114)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    func compactStepper(value: String, label: String, minus: @escaping () -> Void, plus: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            Button(action: minus) { Image(systemName: "minus").font(.system(size: 9, weight: .semibold)).frame(width: 26, height: 26) }
            VStack(spacing: 1) {
                Text(value).font(NoopHTMLFont.outfit(15)).lineLimit(1)
                Text(label.uppercased()).font(NoopHTMLFont.sans(8.5, weight: .semibold)).tracking(0.7).foregroundStyle(Color(hex: 0x7F8A85))
            }
            .frame(maxWidth: .infinity)
            Button(action: plus) { Image(systemName: "plus").font(.system(size: 9, weight: .semibold)).frame(width: 26, height: 26) }
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
                Text(title).font(NoopHTMLFont.sans(13.5))
                Text(detail).font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
            }
            Spacer(minLength: 4)
            Text(value).font(NoopHTMLFont.outfit(17)).monospacedDigit().multilineTextAlignment(.trailing)
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
            .foregroundStyle(NoopHTMLColor.inkSoft)
            .frame(width: 30, height: 30)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.07), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.11), lineWidth: 0.5))
    }
}

// MARK: Zones

private extension NoopAct5Screens {
    var zonesScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                act5BackHeader("Your record") { navigation.reset(to: .record) }
                pageTitle("Your zones", copy: "Built from two numbers Noop has actually seen on you, not from your age.")
                    .padding(.bottom, 3)

                HStack(spacing: 9) {
                    anchorCard(value: "\(maximumHeartRate)", title: "Measured maximum", copy: "Seen on the climb out of the valley, 14 June. Not estimated from your age.")
                    anchorCard(value: "58", title: "Resting rate", copy: "Overnight average across the last fourteen nights, updated every morning.")
                }

                VStack(spacing: 9) {
                    ForEach(Array(Self.zones.enumerated()), id: \.offset) { index, zone in
                        Button { withAnimation(.easeOut(duration: 0.18)) { openZone = openZone == index ? nil : index } } label: {
                            VStack(alignment: .leading, spacing: 11) {
                                HStack(spacing: 11) {
                                    RoundedRectangle(cornerRadius: 4).fill(zone.color).frame(width: 10, height: 26)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(zone.name).font(NoopHTMLFont.sans(14, weight: .semibold))
                                        Text(zone.percent).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                                    }
                                    Spacer()
                                    Text(zone.range).font(NoopHTMLFont.outfit(16)).foregroundStyle(NoopHTMLColor.inkSoft).monospacedDigit()
                                }
                                if openZone == index {
                                    Text(zone.use).font(NoopHTMLFont.sans(12.5)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(3)
                                    HStack(spacing: 10) {
                                        Text("Lower edge").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.muted)
                                        NoopProgressBar(progress: zone.progress, color: zone.color, height: 4)
                                        Text(zone.lower).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.inkSoft)
                                    }
                                    Text("Nudging an edge only changes what the app calls it. Your history is not renumbered.")
                                        .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
                                }
                            }
                            .padding(16)
                            .background(openZone == index ? NoopHTMLColor.blue.opacity(0.07) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(openZone == index ? NoopHTMLColor.blue.opacity(0.28) : NoopHTMLColor.border, lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("These update themselves").font(NoopHTMLFont.sans(13.5, weight: .semibold))
                    Text("When your resting pulse or your measured maximum moves, the edges move with them and you get one line about it in Trends. There is no annual retest to remember.")
                        .font(NoopHTMLFont.sans(12.5)).foregroundStyle(Color(hex: 0xB7C3C9)).lineSpacing(4)
                }
                .padding(16)
                .background(NoopHTMLColor.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(NoopHTMLColor.blue.opacity(0.2), lineWidth: 0.5))
            }
        }
    }

    func anchorCard(value: String, title: String, copy: String) -> some View {
        NoopHTMLCard(radius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value).font(NoopHTMLFont.outfit(27, weight: .light)).tracking(-0.8)
                    Text("bpm").font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.muted)
                }
                Text(title).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.inkSoft)
                Text(copy).font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
            }
        }
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
                act5BackHeader("You") { navigation.reset(to: .you) }
                pageTitle("Everything you logged", copy: "Sessions, sleeps and every coffee, in one list. This is where the + button's taps end up.")
                    .padding(.bottom, 6)

                HStack(spacing: 6) {
                    ForEach(["All", "Sessions", "Sleep", "Logs"], id: \.self) { filter in
                        Button { historyFilter = filter } label: {
                            Text(filter)
                                .font(NoopHTMLFont.sans(12, weight: .medium))
                                .foregroundStyle(historyFilter == filter ? Self.blushLight : NoopHTMLColor.copy)
                                .padding(.horizontal, 13)
                                .frame(height: 37)
                                .background(historyFilter == filter ? Self.blush.opacity(0.18) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(historyFilter == filter ? Self.blush.opacity(0.4) : Color.white.opacity(0.07), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 9) {
                    historyMetricTile("12", label: "sessions in August")
                    historyMetricTile("8h 40m", label: "moving")
                    historyMetricTile("302", label: "load")
                }

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(filteredHistory) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(day.day).font(NoopHTMLFont.sans(12, weight: .semibold)).foregroundStyle(NoopHTMLColor.inkSoft)
                                Spacer()
                                Text(day.summary).font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint)
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
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
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
                navigation.push(.why)
            } else if let workout = item.workout {
                navigation.historyWorkout = workout
                navigation.push(.detail)
            }
        } label: {
            HStack(spacing: 12) {
                NoopCanonicalGlyph(name: item.symbol, size: 18, color: glyphTint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(NoopHTMLFont.sans(13.5, weight: item.kind == .log ? .regular : .semibold))
                        .foregroundStyle(item.kind == .log ? NoopHTMLColor.inkSoft : NoopHTMLColor.ink)
                    Text(item.detail)
                        .font(NoopHTMLFont.sans(11))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                }
                Spacer()
                Text(item.value)
                    .font(NoopHTMLFont.sans(11.5))
                    .foregroundStyle(Color(hex: 0x7F8A85))
                if item.opensSomething {
                    NoopFixedChevron(direction: .right, color: NoopHTMLColor.faint)
                }
            }
            .frame(minHeight: 55)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!item.opensSomething)
    }

    var filteredHistory: [NoopA5HistoryDay] {
        Self.history.compactMap { day in
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
                .font(NoopHTMLFont.outfit(21, weight: .light))
                .tracking(-0.6)
                .monospacedDigit()
            Text(label)
                .font(NoopHTMLFont.sans(10.5))
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
            .init(kind: .session, name: "Steady ride", detail: "17:04 · 42 min · avg 126 bpm", value: "load 48", symbol: .bike, workout: .steadyRide),
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
            .init(kind: .session, name: "6 × 1 min hard", detail: "18:10 · 22 min · max 174 bpm", value: "load 86", symbol: .bolt, workout: .intervals),
            .init(kind: .sleep, name: "Slept 6h 48m", detail: "23:52 → 06:40 · 24 min under", value: "", symbol: .bed),
            .init(kind: .log, name: "Nap", detail: "15:10 · 26 min", value: "", symbol: .bed)
        ]),
        .init(day: "Sunday 17 August", summary: "", items: [
            .init(kind: .session, name: "Long walk", detail: "10:20 · 68 min", value: "load 22", symbol: .walk, workout: .longWalk),
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
    var strapScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("You") { navigation.reset(to: .you) }
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
                                        .font(NoopHTMLFont.sans(14, weight: .semibold))
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
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(syncStage == 0 ? NoopHTMLColor.blueInk : syncStage == 2 ? Color(hex: 0x8FE3B4) : NoopHTMLColor.blueLight)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
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
                                Text("Apple Health").font(NoopHTMLFont.sans(13.5, weight: .semibold))
                                Text(isEnabled("Apple Health") ? (healthSyncStage > 0 ? "wrote 6 kinds · just now" : "wrote 6 kinds · 2 hours ago") : "not connected")
                                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            Spacer()
                            NoopHTMLToggle(isOn: isEnabled("Apple Health"), color: Self.green) { flip("Apple Health") }
                        }
                        NoopFlowLayout(spacing: 6) {
                            ForEach(["Sleep", "Workouts", "Heart rate", "HRV", "Respiration", "Body temp"], id: \.self) { kind in
                                Text(kind)
                                    .font(NoopHTMLFont.sans(10.5, weight: .medium))
                                    .foregroundStyle(NoopHTMLColor.inkSoft)
                                    .padding(.horizontal, 10)
                                    .frame(height: 27)
                                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
                            }
                        }
                        Button {
                            guard isEnabled("Apple Health") else { return }
                            healthSyncStage = min(2, healthSyncStage + 1)
                        } label: {
                            Text(!isEnabled("Apple Health") ? "Turn on Apple Health to sync" : healthSyncStage == 0 ? "Sync Apple Health now" : "Written — 6 kinds, 221 nights")
                                .font(NoopHTMLFont.sans(13, weight: .semibold))
                                .foregroundStyle(isEnabled("Apple Health") ? Color(hex: 0x8FE3B4) : NoopHTMLColor.faint)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(isEnabled("Apple Health") ? Self.green.opacity(healthSyncStage == 0 ? 0.13 : 0.2) : Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(isEnabled("Apple Health") ? Self.green.opacity(0.36) : Color.white.opacity(0.08), lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .disabled(!isEnabled("Apple Health"))
                        Text("Noop writes to Health and never reads your Health history back in — the only exception is your phone's step count, which fills days the strap could not estimate.")
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
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
                            Text("Buzz strength").font(NoopHTMLFont.sans(13.5))
                            Spacer()
                            Text(buzz == "Light" ? "easy to miss on a cold wrist" : buzz == "Normal" ? "enough to notice, not to startle" : "you will not miss it")
                                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                        }
                        NoopSegmentedControl(items: ["Light", "Normal", "Firm"], selection: buzz) { buzz = $0 }
                        Button {
                            pinged = true
                        } label: {
                            Text(pinged ? "Buzzing now — follow the sound" : "Buzz the strap to find it")
                                .font(NoopHTMLFont.sans(13, weight: .semibold))
                                .foregroundStyle(pinged ? NoopHTMLColor.blueLight : NoopHTMLColor.inkSoft)
                                .frame(maxWidth: .infinity).frame(height: 46)
                                .background(pinged ? NoopHTMLColor.blue.opacity(0.18) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                                .overlay(RoundedRectangle(cornerRadius: 15).stroke(pinged ? NoopHTMLColor.blue.opacity(0.45) : Color.white.opacity(0.12), lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                    }
                }

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
                                Text("Save one copy a day").font(NoopHTMLFont.sans(13))
                                Text("A timestamped file at 22:00, on this phone. Off by default.")
                                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                            }
                            Spacer()
                            NoopHTMLToggle(isOn: isEnabled("Save one copy a day")) { flip("Save one copy a day") }
                        }
                        Text("Send this log when a sync or a reading looks wrong. It is the one thing that makes a bug report answerable.")
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
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
                    .font(NoopHTMLFont.sans(13, weight: .semibold))
                    .foregroundStyle(connected ? Color(hex: 0xF3A472) : NoopHTMLColor.blueLight)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background((connected ? NoopHTMLColor.amber : NoopHTMLColor.blue).opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke((connected ? NoopHTMLColor.amber : NoopHTMLColor.blue).opacity(0.26), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                Text("Every switch here says what it costs you in battery, because that is the only reason anyone turns one off.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
            }
        }
    }

    func strapFact(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
            Spacer()
            Text(value).font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.inkSoft).multilineTextAlignment(.trailing)
        }
    }

    func logButton(_ label: String, symbol: String, done: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(done ? (label == "Copy" ? "Copied" : "Saved") : label, systemImage: done ? "checkmark" : symbol)
                .font(NoopHTMLFont.sans(13, weight: .semibold))
                .foregroundStyle(done ? Color(hex: 0x8FE3B4) : NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(done ? Self.green.opacity(0.12) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(done ? Self.green.opacity(0.34) : Color.white.opacity(0.11), lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopStrapBatteryRing: View {
    let percent: Int

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 9)
            Circle()
                .trim(from: 0, to: Double(percent) / 100)
                .stroke(NoopHTMLColor.blue, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(percent)").font(NoopHTMLFont.outfit(38, weight: .ultraLight)).tracking(-1.5).foregroundStyle(NoopHTMLColor.blue)
                    Text("%").font(NoopHTMLFont.sans(12)).foregroundStyle(Color(hex: 0x8B958F))
                }
                Text("~6.2 days").font(NoopHTMLFont.sans(10)).foregroundStyle(Color(hex: 0x7F8A85))
            }
        }
        .frame(width: 118, height: 118)
    }
}

// MARK: Manage straps

private extension NoopAct5Screens {
    var devicesScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                act5BackHeader("Your strap") { navigation.reset(to: .strap) }
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
                        .font(NoopHTMLFont.sans(11.5))
                        .foregroundStyle(Color(hex: 0x8FE3B4))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Self.green.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Self.green.opacity(0.25), lineWidth: 0.5))
                }

                Button { paired = false; navigation.push(.pair) } label: {
                    Label("Pair a new strap", systemImage: "plus")
                        .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueInk)
                        .frame(maxWidth: .infinity).frame(height: 54)
                        .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 18))
                        .shadow(color: NoopHTMLColor.blue.opacity(0.26), radius: 12, y: 8)
                }
                .buttonStyle(NoopHTMLPressStyle())

                Button {
                    deviceNotice = "Search complete · \(sparePresent ? "two straps found" : "one strap found")"
                } label: {
                    Label("Re-scan for straps", systemImage: "arrow.triangle.2.circlepath")
                        .font(NoopHTMLFont.sans(13, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.11), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                Text("Forgetting a strap removes the pairing, not the nights. Its history stays in your record and stays in your export.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
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
                        Text(name).font(NoopHTMLFont.sans(14.5, weight: .semibold))
                        Text(meta).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
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
                            .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                            .foregroundStyle(active ? NoopHTMLColor.inkSoft : NoopHTMLColor.blueLight)
                            .frame(maxWidth: .infinity).frame(height: 44)
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
                            .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xF3A472))
                            .padding(.horizontal, 18).frame(height: 44)
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
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.blueLight)
                        .padding(.horizontal, 15).frame(height: 40)
                        .background(NoopHTMLColor.blue.opacity(0.14), in: RoundedRectangle(cornerRadius: 13))
                        .overlay(RoundedRectangle(cornerRadius: 13).stroke(NoopHTMLColor.blue.opacity(0.34), lineWidth: 0.5))
                    }
                    Text("A 4.0 can be renamed over Bluetooth — useful for a second-hand band still carrying its old owner's name. The strap reboots to apply it.")
                        .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
                }
            }
        }
    }
}

// MARK: Data and permissions

private extension NoopAct5Screens {
    var dataScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 13) {
                act5BackHeader("You") { navigation.reset(to: .you) }
                pageTitle("Data and permissions", copy: "What is collected, where it sits, and how to take it with you.")
                    .lineLimit(1)
                    .minimumScaleFactor(0.92)
                    .padding(.bottom, 5)

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("What the strap records")
                        bullet("Pulse, and the gap between beats", "Continuously while worn. This is where sleep stages, stress and recovery all come from.")
                        bullet("Movement", "To tell sleep from lying still, and to auto-pause a session.")
                        bullet("Skin temperature and blood oxygen", "Overnight, as deviations from your own normal rather than absolute figures.")
                        bullet("What you log", "Coffee, drinks, meals, naps, intimacy. Only what you tap.")
                    }
                    .padding(.vertical, 3)
                }

                NoopHTMLCard(radius: 22, padding: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoopSectionLabel("Where it lives")
                        place("On your phone", "Everything raw: every beat, every night, the whole 221. It never has to leave to be useful.", glyph: .watch)
                        place("On Noop’s servers", "Nothing. There is no account and no server — a restore comes from your own backup file.", glyph: .cloud)
                    }
                    .padding(.vertical, 3)
                }

                dividedCard {
                    VStack(spacing: 0) {
                        toggleRow("Apple Health", detail: "writes sleep, workouts and vitals", tint: NoopHTMLColor.blue)
                        Divider().overlay(NoopHTMLColor.border)
                        toggleRow("Strava", detail: "would write sessions only", tint: NoopHTMLColor.blue)
                        Divider().overlay(NoopHTMLColor.border)
                        toggleRow("Google Fit", detail: "not connected", tint: NoopHTMLColor.blue)
                    }
                }

                VStack(spacing: 8) {
                    Button {
                        actionNotice = "Your export is ready: every beat, night, session and log across 221 nights."
                    } label: {
                        Label("Export everything, 221 nights", systemImage: "arrow.down.to.line")
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.white.opacity(0.14), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())

                    Button { navigation.show(.destructiveConfirmation("your account and data")) } label: {
                        Label("Delete my account and data", systemImage: "trash")
                            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                            .foregroundStyle(Color(hex: 0xF3A472))
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(NoopHTMLColor.amber.opacity(0.1), in: RoundedRectangle(cornerRadius: 17))
                            .overlay(RoundedRectangle(cornerRadius: 17).stroke(NoopHTMLColor.amber.opacity(0.3), lineWidth: 0.5))
                    }
                    .buttonStyle(NoopHTMLPressStyle())
                }

                Text("Nothing here is sold, and there is no advertising identifier in the app. Deleting takes effect immediately and the export is a plain file you can read yourself.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
            }
        }
    }

    func bullet(_ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle().fill(NoopHTMLColor.blue).frame(width: 7, height: 7).padding(.top, 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(13))
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
            }
        }
    }

    func place(_ title: String, _ detail: String, glyph: NoopCanonicalGlyphName) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NoopCanonicalGlyph(name: glyph, size: 19, color: NoopHTMLColor.blue).frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(NoopHTMLFont.sans(13))
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
            }
        }
    }
}

// MARK: Settings

private extension NoopAct5Screens {
    var settingsScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("You") { navigation.reset(to: .you) }
                pageTitle("Settings", copy: "Eleven groups, every switch written with what it costs you. The sharp edges live in the Lab at the foot.")
                    .padding(.bottom, 5)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.faint)
                    TextField("Search every setting", text: $settingsSearch)
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.09), lineWidth: 0.5))

                settingsGroup("You") {
                    copyRow("Your record", detail: "photo, birth, sex, height, weight, waist, maximum", symbol: "person", tint: Self.blush) { navigation.push(.record) }
                    Divider().overlay(NoopHTMLColor.border)
                    copyRow("Your zones", detail: "five bands from two measured anchors", symbol: "chart.bar", tint: Self.blush, value: "5") { navigation.push(.zones) }
                    Divider().overlay(NoopHTMLColor.border)
                    actionRow(
                        baselinesRestarting ? "Baselines restarting from tonight" : "Recalibrate your baselines",
                        detail: baselinesRestarting
                            ? "HRV, resting pulse, respiration and skin temperature all rebuild over about four nights. Your history stays where it is."
                            : "Restart the four-night build-up if a bad week — being ill, a flight — set it wrong.",
                        symbol: "gauge.with.dots.needle.50percent",
                        tint: baselinesRestarting ? Self.green : Self.blush
                    ) { baselinesRestarting.toggle() }
                }
                .padding(.top, 3)

                settingsGroup("Units") {
                    segmentRow("Units", detail: "stored in SI either way", choices: ["Metric", "Imperial"])
                    Divider().overlay(NoopHTMLColor.border)
                    segmentRow("Temperature", detail: "independent of the rest", choices: ["°C", "°F"])
                    Divider().overlay(NoopHTMLColor.border)
                    segmentRow("Effort", detail: "display only — Effort is stored 0–100", choices: ["0–100", "0–21"])
                }

                settingsGroup("Appearance") {
                    copyRow("Widgets", detail: "three, and what each one answers", symbol: "square.grid.2x2", tint: Self.blush, value: "3") { navigation.push(.widgets) }
                    Divider().overlay(NoopHTMLColor.border)
                    segmentRow("Appearance", detail: "dark suits a bedside app", choices: ["Dark", "Light", "System"])
                    Divider().overlay(NoopHTMLColor.border)
                    segmentRow("Chart colours", detail: "Classic recolours the data, not the chrome", choices: ["Titanium", "Classic"])
                    Divider().overlay(NoopHTMLColor.border)
                    segmentRow("Sleep chart", detail: "how the stages are drawn", choices: ["Hypnogram", "Rows", "Ribbon"])
                    Divider().overlay(NoopHTMLColor.border)
                    segmentRow("Card surface", detail: "lets the sky show through", choices: ["Solid", "Frosted", "Clear"])
                    Divider().overlay(NoopHTMLColor.border)
                    segmentRow("App icon", detail: "on your home screen", choices: ["Titanium", "Blued"])
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Day-cycle sky", detail: "The backdrop moves with the hour. Off gives you a plain dark canvas.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Sky behind cards", detail: "Extends that sky under the whole scroll, so transparent cards reveal it.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Reduce motion in Noop", detail: "Poses every looping graphic still without needing the system switch.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    valueRow("Language", detail: "this build is English only", value: "English")
                }

                settingsGroup("Your strap") {
                    copyRow("Your strap", detail: "battery, sensors, sync, log and Apple Health", symbol: "applewatch", tint: Self.blush, value: "52%") { navigation.push(.strap) }
                    Divider().overlay(NoopHTMLColor.border)
                    copyRow("Manage straps", detail: "pair, switch, forget or rename a band", symbol: "link", tint: Self.blush, value: sparePresent ? "2" : "1") { navigation.push(.devices) }
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Live heart rate in the Dynamic Island", detail: "Also puts it on the Lock Screen while a session runs.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Battery alerts", detail: "One notice at 15% and one when it finishes charging. Never twice for the same crossing.", tint: Self.blush)
                }

                settingsGroup("Power saving") {
                    toggleRow("Power saving", detail: "Syncs every 45 minutes instead of 15 once the strap is low and discharging. Never while charging.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    segmentRow("Power saving at", detail: "the strap battery that starts it", choices: ["10%", "20%", "30%"])
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Pause the HRV stream when low", detail: "Releases the always-on stream too. Costs overnight variability detail on that night only.", tint: Self.blush)
                }

                settingsGroup("Features") {
                    toggleRow("Hydration", detail: "A local water log with a daily goal that follows your sex and the day’s effort.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Offer a workout it spotted", detail: "Sees a probable session in your heart rate and offers to save it. It never creates one for you.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Journal reminder", detail: "The seven-day strip on Today. Off removes it entirely.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Keep the screen on in a workout", detail: "Holds the screen awake while a manual recording runs.", tint: Self.blush)
                }

                settingsGroup("What may interrupt you") {
                    toggleRow("Bedtime nudge", detail: "One buzz thirty minutes before your anchor, and nothing after it.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Session offer", detail: "One notification a day, in the morning, with today’s recommendation.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Weekly read", detail: "Sunday evening summary. Off by default because most weeks do not need one.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Quiet hours", detail: "Nothing buzzes between your anchor and your usual wake, whatever else is on.", tint: Self.blush)
                }

                settingsGroup("Automations") {
                    toggleRow("Move reminder", detail: "Buzzes the strap after 45 minutes still, inside your active hours only.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Stress check-ins", detail: "A passive haptic when stress holds high. Off by default.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Illness notice", detail: "An on-device estimate from temperature and respiration. Not a diagnosis, and it says so.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    toggleRow("Rhythm", detail: "Needs reading and ticking a page first. No alarms, no red, no condition names.", tint: Self.blush)
                    Divider().overlay(NoopHTMLColor.border)
                    segmentRow("Double tap", detail: "what a double tap on the strap does", choices: ["Sleep mark", "Log water", "Nothing"])
                }

                settingsGroup("Svea") {
                    copyRow("Provider and key", detail: "Anthropic · your key · 5 of 7 grants", symbol: "key", tint: Self.blush) { navigation.push(.setup) }
                    Divider().overlay(NoopHTMLColor.border)
                    copyRow("What she may read", detail: "purpose by purpose, revocable", symbol: "shield", tint: Self.blush) { navigation.push(.consent) }
                    Divider().overlay(NoopHTMLColor.border)
                    copyRow("Memory", detail: "what she keeps between conversations", symbol: "sparkles", tint: Self.blush) { navigation.push(.memory) }
                    Divider().overlay(NoopHTMLColor.border)
                    segmentRow("Svea’s voice", detail: "plain writes a paragraph, quiet writes a line", choices: ["Plain", "Quiet", "Direct", "Off"])
                }

                settingsGroup("Backup and data") {
                    actionRow("Back up to a file", detail: "one .noopbak with every night, session and log — yours to keep", symbol: "arrow.down.to.line", tint: NoopHTMLColor.blue) {
                        actionNotice = "Backup prepared. The .noopbak file contains every night, session and log."
                    }
                    Divider().overlay(NoopHTMLColor.border)
                    actionRow("Restore from a file", detail: "imports straight back in; nothing is merged silently", symbol: "arrow.up.to.line", tint: NoopHTMLColor.blue) {
                        actionNotice = "Choose a .noopbak file. No existing entry will be merged silently."
                    }
                    Divider().overlay(NoopHTMLColor.border)
                    copyRow("Data and permissions", detail: "what is recorded, what leaves, and how to delete it", symbol: "shield", tint: Self.blush) { navigation.push(.data) }
                }

                settingsGroup("About") {
                    actionRow("How Noop works", detail: "how sleep is sorted, how the scores build, where the numbers come from", symbol: "globe", tint: NoopHTMLColor.blue) {
                        actionNotice = "Noop sorts sleep and builds every estimate locally from your own baselines."
                    }
                    Divider().overlay(NoopHTMLColor.border)
                    actionRow("What’s new", detail: "the changelog, in plain words", symbol: "doc.text", tint: NoopHTMLColor.blue) {
                        actionNotice = "You are using Noop 5.2.0."
                    }
                    Divider().overlay(NoopHTMLColor.border)
                    actionRow("Check for updates", detail: "one request to the release page, when you ask for it", symbol: "arrow.triangle.2.circlepath", tint: NoopHTMLColor.blue) {
                        actionNotice = "No update check has left this phone in the prototype."
                    }
                    Divider().overlay(NoopHTMLColor.border)
                    actionRow("Set up Apple Watch", detail: "what it is good at, and where it is lighter than the strap", symbol: "applewatch", tint: NoopHTMLColor.blue) {
                        actionNotice = "Apple Watch setup is ready to continue."
                    }
                }

                Button { navigation.push(.lab) } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "flask").font(.system(size: 21, weight: .medium)).foregroundStyle(Self.lavender)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("The Lab").font(NoopHTMLFont.sans(14, weight: .semibold))
                            Text("Experimental readings, protocol probes and every diagnostic. Nothing in here is needed to use Noop.")
                                .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0xA9B0CE)).lineSpacing(2)
                        }
                        Spacer()
                        NoopChevron(color: Self.lavender)
                    }
                    .padding(16)
                    .background(Self.lavender.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Self.lavender.opacity(0.24), lineWidth: 0.5))
                }
                .buttonStyle(NoopHTMLPressStyle())

                Text("Noop 5.2.0 · WHOOP 5.0 / MG · everything on this phone")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
            }
        }
    }

    func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NoopSectionLabel(title).padding(.horizontal, 2).padding(.top, 8)
            dividedCard { content() }
        }
    }

    func actionRow(_ title: String, detail: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(tint).frame(width: 21)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(tint == NoopHTMLColor.blue ? NoopHTMLColor.blueLight : tint)
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                }
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }

    func valueRow(_ title: String, detail: String, value: String) -> some View {
        HStack(spacing: 13) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(13.5))
                Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
            }
            Spacer()
            Text(value).font(NoopHTMLFont.sans(12.5, weight: .semibold)).foregroundStyle(Self.blushLight)
        }
        .padding(.vertical, 14)
    }
}

// MARK: Widgets

private extension NoopAct5Screens {
    var widgetsScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 14) {
                act5BackHeader("Settings", action: navigation.back)
                pageTitle("Widgets", copy: "Three, and each answers one question without opening the app.")
                    .padding(.bottom, 2)

                widgetSurface(colors: [Color(hex: 0x14384A), Color(hex: 0x0C1A24), NoopHTMLColor.canvas], minHeight: 242) {
                    NoopSectionLabel("Home Screen · small", color: Color.white.opacity(0.5))
                    HStack(alignment: .top, spacing: 13) {
                        VStack(alignment: .leading) {
                            HStack(spacing: 6) { Circle().fill(NoopHTMLColor.blue).frame(width: 7, height: 7); NoopSectionLabel("Charge", color: Color(hex: 0x8B958F)) }
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Text("56").font(NoopHTMLFont.outfit200(44)).tracking(-1.3)
                                Text("of 92").font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x7F8A85))
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                widgetChargeTrack
                                Text("Enough for the evening").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.inkSoft)
                            }
                        }
                        .frame(width: 146, height: 146, alignment: .leading)
                        .padding(15)
                        .background(NoopHTMLColor.canvas.opacity(0.74), in: RoundedRectangle(cornerRadius: 26))
                        .overlay(RoundedRectangle(cornerRadius: 26).stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.45), radius: 15, y: 12)
                        Text("Am I good for what I had planned? The bar carries the day’s spend, the pale stretch behind it is what you woke with.")
                            .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color.white.opacity(0.62)).lineSpacing(4)
                    }
                }

                widgetSurface(colors: [Color(hex: 0x1E2340), Color(hex: 0x111421), NoopHTMLColor.canvas], minHeight: 291) {
                    NoopSectionLabel("Home Screen · medium", color: Color.white.opacity(0.5))
                    HStack(spacing: 16) {
                        VStack(alignment: .leading) {
                            NoopSectionLabel("Last night", color: Self.lavender)
                            Spacer()
                            Text("7h 12m").font(NoopHTMLFont.outfit(32, weight: .ultraLight))
                            Text("7m over your need").font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x8B958F))
                            Spacer()
                            Text("Deep came early. Nothing to fix.").font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.inkSoft)
                        }
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
                                            .font(NoopHTMLFont.sans(8.5))
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
                                Text("56").font(NoopHTMLFont.outfit(24, weight: .light)).foregroundStyle(NoopHTMLColor.blueLight)
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
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color.white.opacity(0.62)).lineSpacing(4)
                }

                widgetSurface(colors: [Color(hex: 0x232323), Color(hex: 0x141414), NoopHTMLColor.canvas]) {
                    NoopSectionLabel("Lock Screen · circular and inline", color: Color.white.opacity(0.5))
                    HStack(spacing: 20) {
                        ZStack {
                            Circle().stroke(Color.white.opacity(0.16), lineWidth: 6)
                            Circle().trim(from: 0, to: 0.56).stroke(NoopHTMLColor.blueLight, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                            VStack(spacing: 0) { Text("56").font(NoopHTMLFont.outfit(22, weight: .light)); NoopSectionLabel("chg", color: Color.white.opacity(0.6)) }
                        }.frame(width: 74, height: 74)
                        VStack(alignment: .leading, spacing: 9) {
                            Text("9:41").font(NoopHTMLFont.outfit200(34))
                            HStack(spacing: 7) { Circle().fill(NoopHTMLColor.blueLight).frame(width: 6, height: 6).shadow(color: NoopHTMLColor.blueLight.opacity(0.7), radius: 4); Text("Charge 56 · slept 7h 12m").font(NoopHTMLFont.sans(12)) }
                        }
                    }.padding(.vertical, 6)
                    Text("A glance without unlocking. The ring is the same gauge as the orb, and the inline line replaces the one thing people check the app for.")
                        .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color.white.opacity(0.62)).lineSpacing(4)
                }

                Text("Long-press your Home Screen, tap the +, and search Noop. All three read the last sync — they never wake the strap on their own.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2)
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

    var labScreen: some View {
        NoopScreen(topInset: 56) {
            VStack(alignment: .leading, spacing: 12) {
                act5BackHeader("Settings", action: navigation.back)
                pageTitle("The Lab", copy: "Things that are still being worked out, and the tools for telling someone when they go wrong. Every switch here says what it can and cannot reach.")
                    .padding(.bottom, 8)

                VStack(alignment: .leading, spacing: 9) {
                    Text("Read this once").font(NoopHTMLFont.sans(12.5, weight: .semibold)).foregroundStyle(Color(hex: 0xF6DCB4))
                    Text("Three of these write a persistent flag to the strap itself. They are marked. Turning such a switch off stops Noop sending it — it does not undo what the strap already stored, so Noop offers to clear it instead of pretending.")
                        .font(NoopHTMLFont.sans(12)).foregroundStyle(Color(hex: 0xC9BFA9)).lineSpacing(4)
                }
                .padding(.vertical, 1)
                .padding(.bottom, 2)
                .padding(16)
                .background(Self.warm.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Self.warm.opacity(0.24), lineWidth: 0.5))

                labGroup("Readings still being worked out", blurb: "These change what a number says. If one of them settles, it leaves the Lab and becomes the default.") {
                    labToggle("Sleep staging V2", detail: "A cardiorespiratory recipe that recovers deep and REM better on nights the old stager flattened to light. On by default after a 44-person benchmark.", badge: "default on")
                    Divider().overlay(NoopHTMLColor.border)
                    labToggle("Motion-aware wake", detail: "Re-reads scored wake as light sleep when your posture was stable and there were no steps. A no-op on a sparse night.")
                    Divider().overlay(NoopHTMLColor.border)
                    labToggle("Continuous HRV capture", detail: "Holds the dense beat-to-beat stream armed so overnight variability has more to work with. Costs roughly a day of battery.")
                    Divider().overlay(NoopHTMLColor.border)
                    labToggle("Overnight only", detail: "Arms that stream inside quiet hours instead of around the clock. Most of the benefit, a fraction of the cost.", gate: "Follows Continuous HRV capture — with the switch above off, this does nothing.")
                    Divider().overlay(NoopHTMLColor.border)
                    labToggle("SpO₂ strap estimate", detail: "Shows the strap’s own unverified nightly oxygen mean where no calibrated figure exists. Display only — writes nothing.")
                }

                labGroup("Probes that touch the strap", blurb: "Each of these sends something to the hardware. Two write a flag that survives a reboot, so turning the switch off offers to clear it rather than leaving it set.") {
                    labToggle("Broadcast heart rate", detail: "Makes the strap advertise its pulse as a standard sensor, so a bike computer or a gym machine can read it.", badge: "writes to strap")
                    Divider().overlay(NoopHTMLColor.border)
                    labToggle("R22 deep data", detail: "Writes sixteen feature flags that unlock the denser frame set. Noop reads every one back and reports what the strap actually stored.", badge: "writes to strap", gate: "Needs the full encrypted bond — close the official app and pair to Noop first.", persistent: true)
                    Divider().overlay(NoopHTMLColor.border)
                    labToggle("ECG raw data", detail: "Stores the raw-ECG config key on an attested MG. One tap writes it, then Noop reads it back rather than trusting the write.", badge: "writes to strap", gate: "Waiting for your strap to identify itself as an MG. Only an MG has the electrodes, so Noop will not write this to anything else.", persistent: true)
                    Divider().overlay(NoopHTMLColor.border)
                    labToggle("Record protocol frames", detail: "Captures raw frames to a file for working out what an undocumented packet means. Local, and large.")
                }

                labGroup("Diagnostics", blurb: "The exports that make a bug report answerable. All local, all plain files.") {
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

                Text("If a probe here changes a reading you care about, it belongs in Settings and not in the Lab. Say so and it will move.")
                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(4).padding(.horizontal, 2).padding(.top, 4)
            }
        }
    }

    func labGroup<Content: View>(_ title: String, blurb: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            NoopSectionLabel(title).padding(.horizontal, 2).padding(.top, 9)
            Text(blurb)
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(NoopHTMLColor.faint)
                .lineSpacing(4)
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
            dividedCard { content() }
        }
    }

    func labToggle(_ title: String, detail: String, badge: String? = nil, gate: String? = nil, persistent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 13) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(title).font(NoopHTMLFont.sans(13.5))
                        if let badge {
                            Text(badge.uppercased())
                                .font(NoopHTMLFont.sans(9.5, weight: .semibold))
                                .tracking(0.6)
                                .foregroundStyle(badge == "writes to strap" ? Color(hex: 0xF6DCB4) : Color(hex: 0xC9D0EE))
                                .padding(.horizontal, 7).frame(height: 21)
                                .background((badge == "writes to strap" ? Self.warm : Self.lavender).opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NoopA5TintToggle(isOn: labControlIsOn(title), tint: Self.lavender) {
                    toggleLabControl(title)
                }
            }
            if let gate {
                Text(labGateCopy(title, fallback: gate)).font(NoopHTMLFont.sans(11)).foregroundStyle(Color(hex: 0x8B92AE)).lineSpacing(3)
            }
            if title == "R22 deep data", let report = live.r22DisableReport {
                Text(report).font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
            }
            if title == "ECG raw data", let report = live.ecgRawDataGate {
                Text(report.summary).font(NoopHTMLFont.sans(10.5)).foregroundStyle(NoopHTMLColor.faint).lineSpacing(3)
            }
        }
        .padding(.vertical, 14)
    }

    func labAction(_ title: String, detail: String, symbol: String) -> some View {
        Button {
            actionNotice = title == "Mark an experiment phase" ? "Experiment phase marked in the local capture file." : "\(title) is ready."
        } label: {
            HStack(spacing: 13) {
                Image(systemName: symbol).font(.system(size: 17, weight: .medium)).foregroundStyle(NoopHTMLColor.blue).frame(width: 21)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.blueLight)
                    Text(detail).font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85)).lineSpacing(2)
                }
                Spacer()
            }
            .padding(.vertical, 14)
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

private struct NoopA5TintToggle: View {
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(isOn ? tint : Color.white.opacity(0.09))
                .frame(width: 46, height: 28)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle().fill(NoopHTMLColor.ink).frame(width: 24, height: 24).padding(2)
                }
        }
        .buttonStyle(.plain)
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
                        Text("Step 2 of 4").font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
                    }

                    Spacer(minLength: 24)

                    VStack(alignment: .leading, spacing: 25) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("When do you usually sleep?")
                                .font(NoopHTMLFont.outfit(29, weight: .light)).tracking(-0.9).lineSpacing(1)
                            Text("This is the only question that changes the whole app. Everything else Noop works out by watching for a week.")
                                .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
                        }

                        VStack(spacing: 9) {
                            shiftOption("At night, mostly", detail: "A normal bedtime that lands in the evening. Today means midnight to midnight.")
                            shiftOption("Rotating shifts", detail: "It changes week to week. Noop will anchor your day to your sleep instead of the clock.")
                            shiftOption("Permanent nights", detail: "You sleep in daylight. Every screen in the app will be written for that, not translated into it.")
                        }

                        VStack(alignment: .leading, spacing: 9) {
                            Text("What Noop will not ask you").font(NoopHTMLFont.sans(12.5, weight: .semibold))
                            Text("Your weight goal, a calorie target, a step count to beat, or who you would like to compare yourself with. None of them would change a word of what it tells you.")
                                .font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4.5)
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
                                .font(NoopHTMLFont.sans(15, weight: .semibold))
                                .foregroundStyle(selectedShift == nil ? NoopHTMLColor.muted : Self.blushDark)
                                .frame(maxWidth: .infinity).frame(height: 56)
                                .background(selectedShift == nil ? Color.white.opacity(0.07) : Self.blush, in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(selectedShift == nil ? Color.white.opacity(0.1) : .clear, lineWidth: 0.5))
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        .disabled(selectedShift == nil)

                        Button("I would rather not say") {
                            selectedShift = nil
                            navigation.push(.pair)
                        }
                        .font(NoopHTMLFont.sans(13))
                        .foregroundStyle(Color(hex: 0x7F8A85))
                        .frame(height: 42)
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
                    Text(title).font(NoopHTMLFont.sans(14.5, weight: .semibold))
                    Text(detail).font(NoopHTMLFont.sans(12)).foregroundStyle(NoopHTMLColor.copy).lineSpacing(4)
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
                        Button(action: navigation.back) {
                            NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft)
                                .offset(x: -1)
                                .frame(width: 34, height: 34)
                                .background(Color.white.opacity(0.06), in: Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.09), lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        NoopSectionLabel(paired ? "Paired" : "Looking")
                        Spacer()
                        Color.clear.frame(width: 34, height: 34)
                    }

                    Spacer(minLength: 24)

                    VStack(spacing: 24) {
                        NoopA5PairPulse(paired: paired)

                        VStack(spacing: 9) {
                            Text(paired ? "That is everything." : "Hold the button until it blinks.")
                                .font(NoopHTMLFont.outfit(27, weight: .light)).tracking(-0.8).multilineTextAlignment(.center)
                            Text(paired
                                 ? "Three nights were buffered on the strap and they are importing now. Noop will watch for a week before it tells you anything — the first read arrives next Sunday."
                                 : "Noop found one strap nearby. Nothing is connected until you tap Connect, and pairing does not send anything anywhere.")
                                .font(NoopHTMLFont.sans(13.5)).foregroundStyle(NoopHTMLColor.copy).multilineTextAlignment(.center).lineSpacing(4).frame(maxWidth: 290)
                        }

                        HStack(spacing: 13) {
                            NoopCanonicalGlyph(name: .watch, size: 20, color: NoopHTMLColor.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("WHOOP 5.0 / MG").font(NoopHTMLFont.sans(13.5, weight: .semibold))
                                Text(paired ? "connected · 52% · importing 3 nights" : "signal strong · 52% battery")
                                    .font(NoopHTMLFont.sans(11.5)).foregroundStyle(Color(hex: 0x7F8A85))
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
                                .font(NoopHTMLFont.sans(15, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.blueInk)
                                .frame(maxWidth: .infinity).frame(height: 58)
                                .background(NoopHTMLColor.blue, in: RoundedRectangle(cornerRadius: 19))
                                .shadow(color: NoopHTMLColor.blue.opacity(0.28), radius: 13, y: 8)
                        }
                        .buttonStyle(NoopHTMLPressStyle())
                        Text(paired
                             ? "You can wear it loosely. Noop would rather have an imperfect night than none."
                             : "If nothing appears, the strap is asleep — put it on the charger for a moment.")
                            .font(NoopHTMLFont.sans(11)).foregroundStyle(NoopHTMLColor.faint).multilineTextAlignment(.center).lineSpacing(3)
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
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30.0, paused: reduceMotion || paired)) { timeline in
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
