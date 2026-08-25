#if os(iOS)
import Foundation
import SwiftUI
import StrandDesign

/// Act 1, screen 2. The bedtime anchor is saved by the person and derived only from a saved wake
/// time plus Noop's canonical sleep need. Nothing here predicts sleep onset or physiological recharge.
struct AuraRestTonightView: View {
    private let reading: AuraRestReading
    private let onBack: () -> Void

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var behavior: BehaviorStore

    @State private var showWakePicker = false
    @State private var enableAlarmAfterPicking = false
    @State private var windDownOn = WindDownNudge.isEnabled
    @State private var notificationPermissionDenied = false

    @AppStorage("aura.tonight.commitEpoch") private var commitEpoch = 0.0
    @AppStorage("aura.tonight.bedtimeMinutes") private var committedBedtime = -1
    @AppStorage("aura.tonight.wakeMinutes") private var committedWake = -1

    init(reading: AuraRestReading, onBack: @escaping () -> Void) {
        self.reading = reading
        self.onBack = onBack
    }

    #if DEBUG
    private var prototypeMode: Bool {
        ProcessInfo.processInfo.arguments.contains("--aura-prototype")
    }
    #else
    private var prototypeMode: Bool { false }
    #endif

    /// A default control seed is not evidence that the person chose 07:00. A wake time is considered
    /// saved only after one of the real stores contains an explicit value or its feature is enabled.
    private var savedWakeMinutes: Int? {
        #if DEBUG
        if prototypeMode,
           UserDefaults.standard.object(forKey: "behavior.smartAlarmMinutes") == nil,
           UserDefaults.standard.object(forKey: "windDown.wakeMinutes") == nil {
            return 6 * 60 + 25
        }
        #endif

        if behavior.smartAlarmEnabled
            || UserDefaults.standard.object(forKey: "behavior.smartAlarmMinutes") != nil {
            return Self.normalized(behavior.smartAlarmMinutes)
        }
        if WindDownNudge.isEnabled
            || UserDefaults.standard.object(forKey: "windDown.wakeMinutes") != nil {
            return Self.normalized(WindDownNudge.wakeMinutes)
        }
        return nil
    }

    private var needMinutes: Int? {
        guard reading.sleepNeedMinutes.isFinite, reading.sleepNeedMinutes > 0 else { return nil }
        return Int(reading.sleepNeedMinutes.rounded())
    }

    private var proposedBedtime: Int? {
        guard let wake = savedWakeMinutes, let need = needMinutes else { return nil }
        return Self.normalized(wake - need)
    }

    private var hasSavedPlan: Bool {
        guard commitEpoch > 0,
              Date().timeIntervalSince1970 - commitEpoch < 20 * 60 * 60,
              let proposedBedtime,
              let savedWakeMinutes else { return false }
        return committedBedtime == proposedBedtime && committedWake == savedWakeMinutes
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                NoopSpecHeader(parent: String(localized: "Rest"), onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: NoopSpecTokens.cardGap) {
                        Text(String(localized: "Tonight"))
                            .noopText(.screenTitle)
                            .foregroundStyle(NoopSpecTokens.textPrimary)

                        bedtimeAnchor
                        windDownCard
                        scheduleOutcome

                        Text(String(localized: "Built from your saved wake time and Noop Aura’s current sleep-need estimate. This is schedule arithmetic, not a sleep prediction or a medical target."))
                            .noopText(.finePrint)
                            .foregroundStyle(NoopSpecTokens.textDim)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, NoopSpecTokens.screenPadding)
                    .padding(.bottom, NoopSpecTokens.scrollBottomInset)
                }
                .scrollIndicators(.hidden)
                .simultaneousGesture(backSwipe)
            }
        }
        .sheet(isPresented: $showWakePicker) {
            AuraTonightWakePicker(
                initialMinutes: savedWakeMinutes ?? behavior.smartAlarmMinutes,
                onCancel: {
                    enableAlarmAfterPicking = false
                    showWakePicker = false
                },
                onSave: saveWakeTime
            )
            .presentationDetents([.height(370)])
            .presentationDragIndicator(.hidden)
            .preferredColorScheme(.dark)
        }
        .alert(String(localized: "Notifications are off"), isPresented: $notificationPermissionDenied) {
            Button(String(localized: "OK"), role: .cancel) {}
        } message: {
            Text(String(localized: "No wind-down reminder was enabled. Allow notifications in iOS Settings, then try again."))
        }
        .onAppear { windDownOn = WindDownNudge.isEnabled }
    }

    private var background: some View {
        NoopSpecTokens.canvas
            .overlay(alignment: .top) {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [NoopSpecTokens.lavender.opacity(0.19), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 230
                        )
                    )
                    .frame(width: 460, height: 400)
                    .offset(y: -145)
                    .blur(radius: 18)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var backSwipe: some Gesture {
        DragGesture(minimumDistance: 22)
            .onEnded { value in
                guard value.translation.width > 78,
                      abs(value.translation.height) < 58 else { return }
                onBack()
            }
    }

    // MARK: Bedtime anchor

    private var bedtimeAnchor: some View {
        NoopSpecCard(.hero) {
            VStack(alignment: .leading, spacing: 15) {
                NoopSpecCaption("BEDTIME ANCHOR", color: NoopSpecTokens.lavenderText)

                Text(hasSavedPlan ? Self.timeText(committedBedtime) : "—")
                    .noopText(.heroNumeral)
                    .foregroundStyle(NoopSpecTokens.textPrimary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(anchorBasis)
                    .noopText(.body)
                    .foregroundStyle(NoopSpecTokens.textBody)

                if hasSavedPlan {
                    HStack(spacing: 10) {
                        AuraPlanCheckmark()
                        Text(savedPlanLine)
                            .noopText(.subline)
                            .foregroundStyle(NoopSpecTokens.textBody)
                        Spacer(minLength: 8)
                        Button(String(localized: "Change")) {
                            commitEpoch = 0
                            showWakePicker = true
                        }
                        .noopText(.buttonLabel)
                        .foregroundStyle(NoopSpecTokens.lavenderText)
                        .buttonStyle(.plain)
                    }
                    .frame(minHeight: 44)
                } else {
                    NoopSpecButton(
                        savedWakeMinutes == nil
                            ? String(localized: "Set a wake time")
                            : String(localized: "Save tonight’s window")
                    ) {
                        if savedWakeMinutes == nil { showWakePicker = true }
                        else { commitPlan() }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var anchorBasis: String {
        guard let wake = savedWakeMinutes, let need = needMinutes else {
            return String(localized: "Set a wake time to calculate a sleep window without guessing.")
        }
        let basis = reading.sleepNeedIsPersonalized
            ? String(localized: "personalized from \(reading.sleepNeedSampleCount) recorded nights")
            : String(localized: "population-anchored while your history builds")
        if hasSavedPlan {
            return String(localized: "Counted back \(Self.durationText(need)) from your saved \(Self.timeText(wake)) wake time; your need is \(basis).")
        }
        return String(localized: "Your saved wake time is \(Self.timeText(wake)). Saving uses your current \(Self.durationText(need)) need, \(basis).")
    }

    private var savedPlanLine: String {
        guard hasSavedPlan else { return String(localized: "No plan saved") }
        return String(localized: "Wake \(Self.timeText(committedWake))")
    }

    private func commitPlan() {
        guard let proposedBedtime, let savedWakeMinutes else {
            showWakePicker = true
            return
        }
        committedBedtime = proposedBedtime
        committedWake = savedWakeMinutes
        commitEpoch = Date().timeIntervalSince1970
    }

    // MARK: Real controls

    private var windDownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            NoopSpecCaption("WIND-DOWN")

            NoopSpecCard(.list) {
                // A concrete zero-spacing stack is required here. Applying a card background
                // directly to a multi-child ViewBuilder makes SwiftUI decorate each child as a
                // separate card instead of producing the single binding list-card anatomy.
                VStack(spacing: 0) {
                    NoopSpecRow(
                        label: wristTitle,
                        subline: wristSubline,
                        isFirst: true,
                        minHeight: 70,
                        action: toggleAlarm
                    ) {
                        NoopSpecToggle(
                            isOn: Binding(
                                get: { behavior.smartAlarmEnabled },
                                set: { _ in toggleAlarm() }
                            ),
                            hue: NoopSpecTokens.lavender
                        )
                    }

                    NoopSpecRow(
                        label: phoneTitle,
                        subline: phoneSubline,
                        minHeight: 70,
                        action: toggleWindDown
                    ) {
                        NoopSpecToggle(
                            isOn: Binding(
                                get: { windDownOn },
                                set: { _ in toggleWindDown() }
                            ),
                            hue: NoopSpecTokens.lavender
                        )
                    }

                    NoopSpecRow(
                        label: String(localized: "Wake during light sleep"),
                        subline: String(localized: "No validated light-sleep wake watcher is active in this build."),
                        minHeight: 70
                    ) {
                        NoopSpecChip(
                            String(localized: "Coming soon"),
                            hue: NoopSpecTokens.lavender,
                            textColor: NoopSpecTokens.lavenderText
                        )
                    }
                }
            }
        }
    }

    private var wristTitle: String {
        guard let wake = savedWakeMinutes else { return String(localized: "Wrist wake alarm") }
        return String(localized: "Wrist wake alarm · \(Self.timeText(wake))")
    }

    private var wristSubline: String {
        guard savedWakeMinutes != nil else { return String(localized: "Choose a wake time first.") }
        if model.whoop5Detected {
            return String(localized: "Fixed-time wrist command; experimental on WHOOP 5. Keep a backup alarm.")
        }
        return String(localized: "Fixed-time wrist buzz. Keep a backup alarm.")
    }

    private var phoneTitle: String {
        guard windDownOn else { return String(localized: "Phone wind-down reminder") }
        return String(localized: "Phone wind-down reminder · \(Self.timeText(WindDownNudge.nudgeMinuteOfDay()))")
    }

    private var phoneSubline: String {
        guard savedWakeMinutes != nil else { return String(localized: "Choose a wake time first.") }
        return windDownOn
            ? String(localized: "One local notification at the scheduled time. No wrist buzz.")
            : String(localized: "Off. Turning it on requests iOS notification permission if needed.")
    }

    private func toggleAlarm() {
        if !behavior.smartAlarmEnabled && savedWakeMinutes == nil {
            enableAlarmAfterPicking = true
            showWakePicker = true
            return
        }
        behavior.smartAlarmEnabled.toggle()
        model.applySmartAlarm()
    }

    private func toggleWindDown() {
        guard let wake = savedWakeMinutes else {
            enableAlarmAfterPicking = false
            showWakePicker = true
            return
        }
        if windDownOn {
            WindDownNudge.setEnabled(false)
            windDownOn = false
            return
        }

        WindDownNudge.setWakeMinutes(wake)
        WindDownNudge.setEnabled(true) { outcome in
            switch outcome {
            case .scheduled: windDownOn = true
            case .denied:
                windDownOn = false
                notificationPermissionDenied = true
            case .off: windDownOn = false
            }
        }
    }

    private func saveWakeTime(_ minutes: Int) {
        let normalized = Self.normalized(minutes)
        behavior.smartAlarmMinutes = normalized
        WindDownNudge.setWakeMinutes(normalized)
        if enableAlarmAfterPicking {
            behavior.smartAlarmEnabled = true
            model.applySmartAlarm()
        } else if behavior.smartAlarmEnabled {
            model.applySmartAlarm()
        }
        enableAlarmAfterPicking = false
        showWakePicker = false
        commitEpoch = 0
    }

    // MARK: Factual schedule outcome

    private var scheduleOutcome: some View {
        NoopSpecCard(.standard, tint: NoopSpecTokens.lavender) {
            VStack(alignment: .leading, spacing: 9) {
                NoopSpecCaption("WHAT TONIGHT ALLOWS", color: NoopSpecTokens.lavenderText)
                Text(scheduleOutcomeText)
                    .noopText(.body)
                    .foregroundStyle(NoopSpecTokens.textBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var scheduleOutcomeText: String {
        guard hasSavedPlan, let need = needMinutes else {
            return String(localized: "Save tonight’s window to compare its clock time with your current sleep need. No physiological recharge is predicted.")
        }
        let allowance = Self.forwardMinutes(from: committedBedtime, to: committedWake)
        let delta = allowance - need
        let comparison: String
        if delta == 0 {
            comparison = String(localized: "matching your current need")
        } else if delta > 0 {
            comparison = String(localized: "+\(Self.durationText(delta)) versus your current need")
        } else {
            comparison = String(localized: "−\(Self.durationText(-delta)) versus your current need")
        }
        return String(localized: "This saved window allows \(Self.durationText(allowance)), \(comparison). Actual sleep determines the ledger.")
    }

    // MARK: Formatting

    private static func normalized(_ minutes: Int) -> Int {
        ((minutes % 1440) + 1440) % 1440
    }

    private static func forwardMinutes(from start: Int, to end: Int) -> Int {
        normalized(end - start)
    }

    private static func durationText(_ minutes: Int) -> String {
        let value = max(0, minutes)
        if value < 60 { return "\(value)m" }
        if value.isMultiple(of: 60) { return "\(value / 60)h" }
        return "\(value / 60)h \(value % 60)m"
    }

    private static func timeText(_ minutes: Int) -> String {
        let normalized = normalized(minutes)
        var components = DateComponents()
        components.calendar = Calendar.current
        components.hour = normalized / 60
        components.minute = normalized % 60
        return components.date.map(timeFormatter.string) ?? "—"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("jmm")
        return formatter
    }()
}

private struct AuraPlanCheckmark: View {
    var body: some View {
        ZStack {
            Circle().fill(NoopSpecTokens.lavender)
            Path { path in
                path.move(to: CGPoint(x: 5, y: 9))
                path.addLine(to: CGPoint(x: 8, y: 12))
                path.addLine(to: CGPoint(x: 14, y: 6))
            }
            .stroke(
                Color(hex: "#0D1120"),
                style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(width: 19, height: 19)
        .accessibilityHidden(true)
    }
}

private struct AuraTonightWakePicker: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date

    let onCancel: () -> Void
    let onSave: (Int) -> Void

    init(initialMinutes: Int, onCancel: @escaping () -> Void, onSave: @escaping (Int) -> Void) {
        let normalized = ((initialMinutes % 1440) + 1440) % 1440
        var components = DateComponents()
        components.calendar = Calendar.current
        components.hour = normalized / 60
        components.minute = normalized % 60
        _date = State(initialValue: components.date ?? Date())
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        NoopSpecBottomSheet {
            VStack(alignment: .leading, spacing: 14) {
                Text(String(localized: "Wake time"))
                    .noopText(.screenTitle)
                    .foregroundStyle(NoopSpecTokens.textPrimary)

                Text(String(localized: "Used for tonight’s schedule and, if enabled, the fixed-time wrist alarm."))
                    .noopText(.bodySmall)
                    .foregroundStyle(NoopSpecTokens.textQuiet)

                DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, maxHeight: 150)
                    .clipped()

                HStack(spacing: 10) {
                    NoopSpecButton(String(localized: "Cancel"), kind: .secondary) {
                        onCancel()
                        dismiss()
                    }
                    NoopSpecButton(String(localized: "Save")) {
                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                        onSave((components.hour ?? 0) * 60 + (components.minute ?? 0))
                        dismiss()
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(NoopSpecTokens.canvas.ignoresSafeArea())
    }
}
#endif
