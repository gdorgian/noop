import SwiftUI
import UserNotifications
import StrandAnalytics

struct NoopOnboardingView: View {
    let onFinished: () -> Void

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var schedule: OnboardingSchedule?
    @State private var scanning = false
    @State private var notificationsAsked = false

    var body: some View {
        ZStack {
            NoopHTMLColor.canvas.ignoresSafeArea()
            topGlow
            VStack(spacing: 0) {
                progressHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 10)
                Group {
                    switch step {
                    case 0: promiseStep
                    case 1: scheduleStep
                    case 2: connectionStep
                    case 3: noticesStep
                    default: doneStep
                    }
                }
                .id(step)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .preferredColorScheme(.dark)
        .foregroundStyle(NoopHTMLColor.ink)
        .font(NoopHTMLFont.sans(14))
        .onChange(of: live.bonded) { _, bonded in
            if bonded { scanning = false }
        }
    }

    private var topGlow: some View {
        VStack {
            Ellipse()
                .fill(RadialGradient(colors: [Color(hex: 0xE08A9B).opacity(0.15), .clear], center: .center, startRadius: 0, endRadius: 215))
                .frame(width: 470, height: 410)
                .blur(radius: 18)
                .offset(y: -235)
            Spacer()
        }
        // Wider than the phone: let it draw past the edges without widening the onboarding stack,
        // which laid the terms gate above it out at 470 pt and pushed it off both edges.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var progressHeader: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<Self.stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color(hex: 0xE08A9B) : Color.white.opacity(0.14))
                        .frame(width: index == step ? 22 : 7, height: 7)
                        .animation(.easeInOut(duration: 0.18), value: step)
                }
            }
            Spacer()
            Text("Step \(step + 1) of \(Self.stepCount)")
                .font(NoopHTMLFont.sans(11.5))
                .foregroundStyle(Color(hex: 0x7F8A85))
        }
    }

    private var promiseStep: some View {
        onboardingPage {
            VStack(alignment: .leading, spacing: 10) {
                Text("What Noop does")
                    .font(NoopHTMLFont.outfit(29, weight: .light))
                    .tracking(-0.8)
                Text("Three quiet promises.")
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
            VStack(spacing: 9) {
                promise("See your morning recovery", "Recovery combines valid nightly inputs against your own baselines. Missing inputs stay missing.", "circle.dashed.inset.filled", NoopHTMLColor.blue)
                promise("Watch your heart, live", "Connect a WHOOP or heart-rate strap and watch each beat, variability and zones as they happen.", "waveform.path.ecg", NoopHTMLColor.blue)
                promise("Own your data, locally", "No account is required. Data stays on this iPhone unless you explicitly enable a destination.", "lock.shield", NoopHTMLColor.green)
            }
        } footer: {
            primaryButton("Continue", enabled: true) { advance() }
        }
    }

    private var scheduleStep: some View {
        onboardingPage {
            VStack(alignment: .leading, spacing: 10) {
                Text("When do you usually sleep?")
                    .font(NoopHTMLFont.outfit(29, weight: .light))
                    .tracking(-0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Text("This is the only question that changes the whole app. Everything else Noop works out by watching for a week.")
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(4)
            }

            VStack(spacing: 9) {
                ForEach(OnboardingSchedule.allCases) { option in
                    Button { schedule = option } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(schedule == option ? Color(hex: 0xE08A9B) : .clear)
                                .frame(width: 20, height: 20)
                                .overlay(Circle().stroke(schedule == option ? Color(hex: 0xE08A9B) : Color.white.opacity(0.22), lineWidth: 1.5))
                                .overlay(Circle().stroke(NoopHTMLColor.canvas, lineWidth: schedule == option ? 4 : 0))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.title)
                                    .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                                    .foregroundStyle(NoopHTMLColor.ink)
                                Text(option.detail)
                                    .font(NoopHTMLFont.sans(12))
                                    .foregroundStyle(NoopHTMLColor.copy)
                                    .lineSpacing(2)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(schedule == option ? Color(hex: 0xE08A9B).opacity(0.1) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).stroke(schedule == option ? Color(hex: 0xE08A9B).opacity(0.4) : NoopHTMLColor.border, lineWidth: 0.5))
                    }
                    .buttonStyle(NoopPlainHitStyle())
                }
            }

            NoopHTMLCard(radius: 20, padding: 16, tint: NoopHTMLColor.night) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("What Noop will not ask you")
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                    Text(NoopPositionCopy.inlineSentence)
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(Color(hex: 0x939C97))
                        .lineSpacing(4.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } footer: {
            VStack(spacing: 4) {
                primaryButton("Continue", enabled: schedule != nil) {
                    guard let schedule else { return }
                    save(schedule)
                    advance()
                }
                Button("I would rather not say") {
                    enableScheduleInference()
                    advance()
                }
                .font(NoopHTMLFont.sans(13))
                .foregroundStyle(Color(hex: 0x7F8A85))
                .frame(height: 42)
            }
        }
    }

    private var connectionStep: some View {
        onboardingPage {
            VStack(alignment: .leading, spacing: 10) {
                Text("Connect your strap")
                    .font(NoopHTMLFont.outfit(29, weight: .light))
                    .tracking(-0.8)
                Text("Noop talks to it directly over Bluetooth Low Energy. There is no server in the middle.")
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(4)
            }

            ZStack {
                if scanning && !live.bonded {
                    Circle()
                        .stroke(NoopHTMLColor.blue.opacity(0.42), lineWidth: 1)
                        .frame(width: 170, height: 170)
                        .transition(.scale.combined(with: .opacity))
                }
                Circle()
                    .fill(live.bonded ? NoopHTMLColor.green.opacity(0.14) : NoopHTMLColor.blue.opacity(0.13))
                    .frame(width: 104, height: 104)
                Image(systemName: live.bonded ? "checkmark" : "applewatch.side.right")
                    .font(.system(size: 39, weight: .light))
                    .foregroundStyle(live.bonded ? NoopHTMLColor.green : NoopHTMLColor.blue)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)

            VStack(spacing: 9) {
                connectionLine("Wear it snug, with the sensor against your skin.")
                connectionLine("Keep it charged and within about a metre of this iPhone.")
                connectionLine("When iOS asks for Bluetooth, choose Allow.")
            }

            Button(live.bonded ? "Connected" : scanning ? "Looking…" : "Start looking") {
                startScanning()
            }
            .buttonStyle(NoopHTMLButtonStyle(kind: live.bonded ? .secondary : .primary, fullWidth: true))
            .disabled(scanning && !live.bonded)
        } footer: {
            // One primary action per page: until a strap answers, moving on is the quiet choice.
            if live.bonded {
                primaryButton("Continue", enabled: true) { advance() }
            } else {
                Button("Set up later") { advance() }
                    .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .frame(maxWidth: .infinity, minHeight: 54)
            }
        }
    }

    private static let stepCount = 5

    /// The permission is asked here, once, with the reason beside it, rather than at whatever moment
    /// a first notice happens to have something to say (26 Oct 2026).
    private var noticesStep: some View {
        onboardingPage {
            VStack(alignment: .leading, spacing: 10) {
                Text("A few quiet notices")
                    .font(NoopHTMLFont.outfit(29, weight: .light))
                    .tracking(-0.8)
                Text("Noop speaks up rarely, and only about your strap and your record. These four are on; everything else waits in Settings › Notifications.")
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(4)
            }
            VStack(spacing: 10) {
                promise("Your night is in", "Once last night is scored: its sleep and recovery.", "moon.fill", NoopHTMLColor.night)
                promise("Battery", "At 15%, and once when it finishes charging.", "battery.25", NoopHTMLColor.green)
                promise("Sync reminder", "When the strap hasn't synced for three hours.", "arrow.triangle.2.circlepath", NoopHTMLColor.blue)
                promise("Backup reminder", "Your record lives only on this phone. Once a month at most.", "externaldrive.fill", Color(hex: 0xE08A9B))
            }
        } footer: {
            VStack(spacing: 4) {
                primaryButton(notificationsAsked ? "Continue" : "Allow notifications", enabled: true) {
                    guard !notificationsAsked else { advance(); return }
                    Task { @MainActor in
                        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                        notificationsAsked = true
                        advance()
                    }
                }
                Button("Not now") { advance() }
                    .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .opacity(notificationsAsked ? 0 : 1)
                    .disabled(notificationsAsked)
            }
        }
        .task {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            notificationsAsked = status != .notDetermined
        }
    }

    private var doneStep: some View {
        onboardingPage {
            Spacer(minLength: 34)
            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(NoopHTMLColor.green.opacity(0.22))
                        .frame(width: 130, height: 130)
                        .blur(radius: 34)
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 52, weight: .light))
                        .foregroundStyle(LinearGradient(colors: [NoopHTMLColor.blueLight, NoopHTMLColor.green], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                VStack(spacing: 10) {
                    Text("Your thread starts here.")
                        .font(NoopHTMLFont.outfit(30, weight: .light))
                        .tracking(-0.8)
                    Text("Every beat, every night, every day, woven into one quiet picture of you. Welcome to Noop.")
                        .font(NoopHTMLFont.sans(14))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            Spacer(minLength: 34)
        } footer: {
            primaryButton("Enter Noop", enabled: true) { onFinished() }
        }
    }

    private func onboardingPage<Content: View, Footer: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) { content() }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            footer()
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
        }
    }

    private func promise(_ title: String, _ detail: String, _ symbol: String, _ tint: Color) -> some View {
        HStack(spacing: 14) {
            NoopIconDisc(symbol: symbol, color: tint, size: 42)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(NoopHTMLFont.sans(14.5, weight: .semibold))
                Text(detail)
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func connectionLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(NoopHTMLColor.blue)
                .frame(width: 22, height: 22)
                .background(NoopHTMLColor.blue.opacity(0.12), in: Circle())
            Text(text)
                .font(NoopHTMLFont.sans(13))
                .foregroundStyle(NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func primaryButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(NoopHTMLButtonStyle(kind: .primary, fullWidth: true))
            .opacity(enabled ? 1 : 0.38)
            .disabled(!enabled)
            .frame(height: 54)
    }

    private func advance() {
        withAnimation(.timingCurve(0.22, 0.61, 0.36, 1, duration: 0.3)) {
            step = min(Self.stepCount - 1, step + 1)
        }
    }

    private func startScanning() {
        guard !live.bonded, !scanning else { return }
        scanning = true
        model.scan()

        // BLE discovery can legitimately return nothing. Do not strand onboarding on a disabled
        // “Looking…” button; let the person retry after one bounded scan window.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(10))
            if !live.bonded { scanning = false }
        }
    }

    private func save(_ option: OnboardingSchedule) {
        let defaults = UserDefaults.standard
        defaults.set(option.rawValue, forKey: "noop.schedule.kind")
        defaults.set(false, forKey: "noop.schedule.inferFromHistory")
        switch option {
        case .mostlyNights:
            SleepSchedulePrefs.store(.dayWorker)
        case .rotating, .permanentNights:
            SleepSchedulePrefs.store(SleepSchedule(awakeStartHour: 22, awakeEndHour: 10))
        }
    }

    private func enableScheduleInference() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "noop.schedule.kind")
        defaults.removeObject(forKey: SleepSchedulePrefs.awakeStartKey)
        defaults.removeObject(forKey: SleepSchedulePrefs.awakeEndKey)
        defaults.set(true, forKey: "noop.schedule.inferFromHistory")
        SleepSchedule.current = .dayWorker
    }
}

private enum OnboardingSchedule: String, CaseIterable, Identifiable {
    case mostlyNights = "mostly-nights"
    case rotating
    case permanentNights = "permanent-nights"
    var id: String { rawValue }

    var title: String {
        switch self {
        case .mostlyNights: "At night, mostly"
        case .rotating: "Rotating shifts"
        case .permanentNights: "Permanent nights"
        }
    }

    var detail: String {
        switch self {
        case .mostlyNights: "A normal bedtime that lands in the evening. Today means midnight to midnight."
        case .rotating: "It changes week to week. Noop will anchor your day to your sleep instead of the clock."
        case .permanentNights: "You sleep in daylight. Every screen in the app will be written for that, not translated into it."
        }
    }
}
