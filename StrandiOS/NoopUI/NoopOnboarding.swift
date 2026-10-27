import SwiftUI
import UserNotifications
import StrandAnalytics

// MARK: - First run
//
// Rebuilt 28 Oct 2026. One Aura orb carries through every page: large on the welcome, small above each
// question, calm and green once the strap answers, and large again on the summary. Five questions sit
// between the two, each with one primary action and a quiet way past it, and each can be stepped back
// to. The summary shows what was set rather than thanking the wearer for setting it.
//
// Permissions (Bluetooth, Apple Health, notifications) are each asked on their own page with the reason
// beside them, and no button says "Allow": the system sheet is where that word belongs (HIG, privacy).

private enum OnboardingMotion {
    /// Page to page: a short slide and a fade, not a full-width push. Quick, because there are nine.
    static let page = Animation.snappy(duration: 0.28)
    /// The orb changing size between pages, the progress bar filling.
    static let morph = Animation.spring(duration: 0.42, bounce: 0.12)
    /// Each block of a page arriving.
    static let reveal = Animation.smooth(duration: 0.28)
    /// A big figure ticking to its new value.
    static let figure = Animation.snappy(duration: 0.2)
    static let stagger = 0.03
    static let staggerCap = 0.2
    static let pageShift: CGFloat = 28
    /// The beat between tapping an answer and the page moving on, so the choice is seen to land.
    static let answerBeat: Duration = .milliseconds(240)
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome, born, sex, weight, height, sleep, strap, health, notices, done

    /// The pages the progress bar counts: the questions, not the welcome or the summary.
    static let counted: [OnboardingStep] = [.born, .sex, .weight, .height, .sleep, .strap, .health, .notices]

    #if DEBUG
    /// `--noop-onboarding-step <name>` opens straight onto one page, for screenshots and checks.
    static var requested: OnboardingStep? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--noop-onboarding-step"), i + 1 < args.count else { return nil }
        return allCases.first { "\($0)" == args[i + 1] }
    }
    #endif
}

struct NoopOnboardingView: View {
    let onFinished: () -> Void

    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var live: LiveState
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var health: HealthKitBridge
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    @Namespace private var unitPill

    @State private var step: OnboardingStep = .welcome
    /// Which way the last move went, so a page leaves toward where it came from on the way back.
    @State private var forward = true
    @State private var schedule: OnboardingSchedule?
    @State private var learnsSchedule = false
    /// Bluetooth off, not allowed or missing: said beside the button rather than a scan that finds nothing.
    @State private var radioBlocked: String?
    @State private var scanning = false
    @State private var notificationsAsked = false
    @State private var notificationsOn = false
    @State private var healthAsking = false
    // About you, held here until Continue so "Skip for now" leaves the profile exactly as it was.
    @State private var birth = Date()
    @State private var sex = "female"
    @State private var weightKg = 70.0
    @State private var heightCm = 170.0
    @State private var profileSaved = false
    /// Bumped on every page move, for the one light tap that goes with it.
    @State private var moves = 0
    /// Bumped when something lands: the strap answering, the summary arriving. Fires the ring.
    @State private var bursts = 0
    @State private var bloomed = false
    @State private var loaded = false

    private var imperial: Bool { unitSystemRaw == UnitSystem.imperial.rawValue }

    var body: some View {
        ZStack {
            NoopHTMLColor.canvas.ignoresSafeArea()
            topGlow
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                orb
                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .born: bornStep
                    case .sex: sexStep
                    case .weight: weightStep
                    case .height: heightStep
                    case .sleep: sleepStep
                    case .strap: strapStep
                    case .health: healthStep
                    case .notices: noticesStep
                    case .done: doneStep
                    }
                }
                .id(step)
                .transition(pageTransition)
            }
        }
        .preferredColorScheme(.dark)
        .foregroundStyle(NoopHTMLColor.ink)
        .font(NoopHTMLFont.sans(14))
        .sensoryFeedback(.success, trigger: live.bonded) { _, bonded in bonded && step == .strap }
        .sensoryFeedback(.selection, trigger: schedule)
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: moves)
        .onChange(of: live.bonded) { _, bonded in
            if bonded {
                scanning = false
                if step == .strap { bursts += 1 }
            }
        }
        .onAppear(perform: load)
    }

    // MARK: Chrome

    private var topGlow: some View {
        VStack {
            Ellipse()
                .fill(RadialGradient(colors: [glowColor.opacity(0.15), .clear], center: .center, startRadius: 0, endRadius: 215))
                .frame(width: 470, height: 410)
                .blur(radius: 18)
                .offset(y: -235)
                .animation(OnboardingMotion.page, value: glowColor)
            Spacer()
        }
        // Wider than the phone: let it draw past the edges without widening the onboarding stack,
        // which laid the terms gate above it out at 470 pt and pushed it off both edges.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var glowColor: Color { NoopAuraOrbModel.palette(orbColour).top }

    private var header: some View {
        let index = OnboardingStep.counted.firstIndex(of: step)
        let fraction = CGFloat((index ?? 0) + 1) / CGFloat(OnboardingStep.counted.count)
        return ZStack {
            Capsule()
                .fill(Color.white.opacity(0.12))
                .frame(width: 132, height: 5)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(NoopHTMLColor.blush)
                        .frame(width: 132 * fraction, height: 5)
                }
                .animation(OnboardingMotion.morph, value: step)
            .accessibilityElement()
            .accessibilityLabel("Step \((index ?? 0) + 1) of \(OnboardingStep.counted.count)")
            HStack {
                Button { go(back: true) } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(NoopPlainHitStyle())
                .accessibilityLabel("Back")
                Spacer()
                Text("\((index ?? 0) + 1) of \(OnboardingStep.counted.count)")
                    .font(NoopHTMLFont.sans(11.5))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(index ?? 0)))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .padding(.trailing, 10)
                    .accessibilityHidden(true)
            }
        }
        .opacity(index == nil ? 0 : 1)
        .allowsHitTesting(index != nil)
        .animation(OnboardingMotion.page, value: index == nil)
    }

    // MARK: Orb

    /// The orb is the one thing on screen that never leaves. It blooms in on the welcome, shrinks to sit
    /// above each question, gives a small beat on every move, warms from teal toward green as the setup
    /// fills in, settles when the strap answers, and grows back for the summary.
    private var orb: some View {
        let side: CGFloat = switch step {
        case .welcome: 248
        case .done: 208
        default: 78
        }
        // Drawn at full size and scaled: laid out small, the orb's halo blur shrinks below a pixel and
        // leaves a hard second outline, and a scale animates on the GPU where a frame change re-lays out.
        return ZStack {
            OnboardingRingBurst(trigger: bursts, colour: glowColor)
                .frame(width: Self.orbSide * 0.8, height: Self.orbSide * 0.8)
            NoopAuraOrb(shapeScore: orbShape, colorScore: orbColour)
                .frame(width: Self.orbSide, height: Self.orbSide)
                .keyframeAnimator(initialValue: 1.0, trigger: moves) { content, beat in
                    content.scaleEffect(reduceMotion ? 1 : beat)
                } keyframes: { _ in
                    SpringKeyframe(1.07, duration: 0.14, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.5, spring: .bouncy(duration: 0.5, extraBounce: 0.1))
                }
        }
        .scaleEffect(side / Self.orbSide)
        .frame(width: side, height: side)
        // First appearance: out of a soft blur rather than popping in.
        .scaleEffect(bloomed || reduceMotion ? 1 : 0.86)
        .blur(radius: bloomed || reduceMotion ? 0 : 14)
        .opacity(bloomed ? 1 : 0)
        .frame(maxWidth: .infinity)
        .padding(.top, step == .welcome ? 18 : 4)
        .animation(OnboardingMotion.morph, value: step)
        .animation(OnboardingMotion.morph, value: live.bonded)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.smooth(duration: 0.9)) { bloomed = true }
        }
    }

    private static let orbSide: CGFloat = 248

    private var orbShape: Double {
        if step == .strap && scanning && !live.bonded { return 0.55 }
        return live.bonded || step == .done ? 0.08 : 0.22
    }

    /// Teal (0.5) at the start, toward green (0.2) as each question is answered; greener still with a
    /// strap that answers.
    private var orbColour: Double {
        if live.bonded && (step == .strap || step == .done) { return 0.12 }
        if step == .done { return 0.18 }
        guard let i = OnboardingStep.counted.firstIndex(of: step) else { return 0.5 }
        return 0.5 - 0.3 * Double(i) / Double(OnboardingStep.counted.count)
    }

    // MARK: Welcome

    private var welcomeStep: some View {
        page(centered: true) {
            VStack(spacing: 10) {
                Text("Noop Aura")
                    .font(NoopHTMLFont.outfit(38, weight: .light))
                    .tracking(-1.2)
                    .entrance(0)
                Text("Your strap, read on this iPhone.\nNo account, no subscription, no server in the middle.")
                    .font(NoopHTMLFont.sans(14))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .entrance(1)
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 16) {
                welcomeLine("circle.dashed.inset.filled", NoopHTMLColor.blue, "Recovery every morning", "Scored against your own baselines. Missing inputs stay missing.")
                    .entrance(2)
                welcomeLine("waveform.path.ecg", NoopHTMLColor.blush, "Your heart, live", "Each beat, variability and zones as they happen.")
                    .entrance(3)
                welcomeLine("lock.shield", NoopHTMLColor.green, "Yours, locally", "Data stays on this iPhone unless you send it somewhere.")
                    .entrance(4)
            }
            .padding(.top, 8)
        } footer: {
            primaryButton("Get started") { go() }
        }
    }

    private func welcomeLine(_ symbol: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            NoopIconDisc(symbol: symbol, color: tint, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(NoopHTMLFont.sans(14.5, weight: .semibold))
                Text(detail)
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: About you
    //
    // One question a page, each answered with one gesture: a wheel, a tap, a ruler. Each value is written
    // when its page is continued, so "Skip" leaves that one value as it was.

    private var bornStep: some View {
        page {
            heading("When were you born?", "Your age sets your maximum heart rate, and with it every zone.")
            bigFigure("\(ageFromBirth)", value: ageFromBirth, unit: "years old")
                .entrance(2)
            DatePicker("Born", selection: $birth, in: ProfileStore.dateOfBirthRange, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .entrance(3)
        } footer: {
            answerFooter { profile.dateOfBirth = birth }
        }
        .sensoryFeedback(.selection, trigger: ageFromBirth)
    }

    private var ageFromBirth: Int { ProfileStore.years(from: birth, to: Date()) }

    private var divider: some View {
        Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
    }

    private var sexStep: some View {
        page {
            heading("What's your sex?", "Only the calorie estimate uses it. Nothing else changes.")
            VStack(spacing: 9) {
                ForEach(Array(Self.sexOptions.enumerated()), id: \.offset) { i, option in
                    choiceCard(option.title, option.detail, selected: sex == option.tag) { answerSex(option.tag) }
                        .entrance(2 + i)
                }
            }
        } footer: {
            answerFooter { profile.sex = sex }
        }
        .sensoryFeedback(.selection, trigger: sex)
    }

    private static let sexOptions: [(tag: String, title: String, detail: String)] = [
        ("female", "Female", "Calories use the female formula."),
        ("male", "Male", "Calories use the male formula."),
        ("nonbinary", "Other", "Calories use the average of both."),
    ]

    /// A tap is the answer: it is saved, seen to land, and the page moves on by itself.
    private func answerSex(_ tag: String) {
        sex = tag
        profile.sex = tag
        profileSaved = true
        Task { @MainActor in
            try? await Task.sleep(for: OnboardingMotion.answerBeat)
            if step == .sex { go() }
        }
    }

    private var weightStep: some View {
        page {
            heading("Your weight", "For the calorie estimate only, never a goal. Apple Health weigh-ins keep it current.")
            bigFigure("\(weightBinding.wrappedValue)", value: weightBinding.wrappedValue, unit: imperial ? "lb" : "kg")
                .entrance(2)
            OnboardingRuler(range: imperial ? 77...440 : 35...200, value: weightBinding, major: 10) { "\($0)" }
                .id(imperial)
                .entrance(3)
            unitSwitch(metric: "kg", imperial: "lb")
                .entrance(4)
        } footer: {
            answerFooter { profile.weightKg = weightKg }
        }
    }

    private var heightStep: some View {
        page {
            heading("Your height", "With your weight, it sets how much energy your body spends at rest.")
            bigFigure(imperial ? heightText : "\(heightBinding.wrappedValue)", value: heightBinding.wrappedValue, unit: imperial ? "" : "cm")
                .entrance(2)
            OnboardingRuler(range: imperial ? 48...86 : 120...220, value: heightBinding, major: imperial ? 12 : 10) { value in
                imperial ? "\(value / 12)′" : "\(value)"
            }
            .id(imperial)
            .entrance(3)
            unitSwitch(metric: "cm", imperial: "ft")
                .entrance(4)
        } footer: {
            answerFooter { profile.heightCm = heightCm }
        }
    }

    private func answerFooter(save: @escaping () -> Void) -> some View {
        VStack(spacing: 4) {
            primaryButton("Continue") {
                save()
                profileSaved = true
                go()
            }
            secondaryButton("Skip") { go() }
        }
    }

    /// The value being picked, large, rolling digit by digit as it changes.
    private func bigFigure(_ text: String, value: Int, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .font(NoopHTMLFont.outfit(76, weight: .light))
                .tracking(-2)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(value)))
            if !unit.isEmpty {
                Text(unit)
                    .font(NoopHTMLFont.sans(17, weight: .medium))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .animation(OnboardingMotion.figure, value: value)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// Metric or imperial for both weight and height. The white pill slides between the two.
    private func unitSwitch(metric: String, imperial imperialLabel: String) -> some View {
        HStack(spacing: 0) {
            ForEach([(UnitSystem.metric, metric), (UnitSystem.imperial, imperialLabel)], id: \.0) { system, label in
                let on = unitSystemRaw == system.rawValue
                Button {
                    withAnimation(OnboardingMotion.morph) { unitSystemRaw = system.rawValue }
                } label: {
                    Text(label)
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        .foregroundStyle(on ? NoopHTMLColor.canvas : NoopHTMLColor.copy)
                        .frame(width: 64, height: 34)
                        .background {
                            if on { Capsule().fill(NoopHTMLColor.ink).matchedGeometryEffect(id: "unit", in: unitPill) }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(NoopPlainHitStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.07), in: Capsule())
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: unitSystemRaw)
    }

    private var weightBinding: Binding<Int> {
        Binding(
            get: { Int((imperial ? weightKg / 0.45359237 : weightKg).rounded()) },
            set: { weightKg = imperial ? Double($0) * 0.45359237 : Double($0) }
        )
    }

    private var heightBinding: Binding<Int> {
        Binding(
            get: { Int((imperial ? heightCm / 2.54 : heightCm).rounded()) },
            set: { heightCm = imperial ? Double($0) * 2.54 : Double($0) }
        )
    }

    private var weightText: String { "\(weightBinding.wrappedValue) \(imperial ? "lb" : "kg")" }
    private var heightText: String { imperial ? "\(heightBinding.wrappedValue / 12)′ \(heightBinding.wrappedValue % 12)″" : "\(heightBinding.wrappedValue) cm" }

    // MARK: Sleep

    private var sleepStep: some View {
        page {
            heading("When do you usually sleep?", "The one answer that changes the whole app. Everything else Noop works out by watching for a week.")
            VStack(spacing: 9) {
                ForEach(Array(OnboardingSchedule.allCases.enumerated()), id: \.element) { i, option in
                    choiceCard(option.title, option.detail, selected: schedule == option) {
                        schedule = option
                        learnsSchedule = false
                    }
                    .entrance(2 + i)
                }
            }
            NoopHTMLCard(radius: 20, padding: 16, tint: NoopHTMLColor.night) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("What Noop will not ask you")
                        .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                    Text(NoopPositionCopy.inlineSentence)
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.faint)
                        .lineSpacing(4.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .entrance(5)
        } footer: {
            VStack(spacing: 4) {
                primaryButton("Continue", enabled: schedule != nil) {
                    guard let schedule else { return }
                    save(schedule)
                    learnsSchedule = false
                    go()
                }
                secondaryButton("Let Noop learn it") {
                    enableScheduleInference()
                    schedule = nil
                    learnsSchedule = true
                    go()
                }
            }
        }
    }

    private func choiceCard(_ title: String, _ detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(selected ? NoopHTMLColor.blush : Color.white.opacity(0.22), lineWidth: 1.5)
                    Circle().fill(NoopHTMLColor.blush).padding(5).scaleEffect(selected ? 1 : 0.4).opacity(selected ? 1 : 0)
                }
                .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                    Text(detail)
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? NoopHTMLColor.blush.opacity(0.1) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(selected ? NoopHTMLColor.blush.opacity(0.4) : NoopHTMLColor.border, lineWidth: 0.5))
            .animation(OnboardingMotion.morph, value: selected)
            // Chosen: a small lift and settle, so the answer is felt to land.
            .keyframeAnimator(initialValue: 1.0, trigger: selected) { card, lift in
                card.scaleEffect(reduceMotion ? 1 : lift)
            } keyframes: { _ in
                SpringKeyframe(selected ? 1.025 : 1, duration: 0.12, spring: .snappy)
                SpringKeyframe(1, duration: 0.4, spring: .bouncy(duration: 0.4, extraBounce: 0.1))
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Strap

    private var strapStep: some View {
        page {
            heading("Connect your strap", "Noop talks to it directly over Bluetooth. There is no server in the middle.")
            HStack(spacing: 14) {
                ZStack {
                    if scanning && !live.bonded && !reduceMotion {
                        Circle()
                            .stroke(NoopHTMLColor.blue.opacity(0.5), lineWidth: 1)
                            .phaseAnimator([false, true]) { ring, out in
                                ring.scaleEffect(out ? 1.6 : 1).opacity(out ? 0 : 0.9)
                            } animation: { out in out ? .easeOut(duration: 1.5) : .linear(duration: 0) }
                    }
                    Circle().fill(statusTint.opacity(0.13))
                    Image(systemName: live.bonded ? "checkmark" : "applewatch.side.right")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(statusTint)
                        .contentTransition(.symbolEffect(.replace))
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(strapTitle)
                        .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                        .contentTransition(.opacity)
                    Text(strapDetail)
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(live.bonded ? NoopHTMLColor.green.opacity(0.35) : NoopHTMLColor.border, lineWidth: 0.5))
            .animation(OnboardingMotion.reveal, value: live.bonded)
            .animation(OnboardingMotion.reveal, value: scanning)
            .accessibilityElement(children: .combine)
            .entrance(2)
            .onReceive(model.ble.$radioStateErrorShown) { blocked in
                radioBlocked = blocked ? (live.lastSyncError ?? "Turn Bluetooth on to look for your strap.") : nil
            }

            VStack(alignment: .leading, spacing: 11) {
                connectionLine("Wear it snug, sensor against your skin.")
                connectionLine("Charged, and within about a metre of this iPhone.")
                connectionLine("When iOS asks about Bluetooth, choose Allow.")
            }
            .entrance(3)
        } footer: {
            // One primary action per page: until a strap answers, moving on is the quiet choice.
            VStack(spacing: 4) {
                if live.bonded {
                    primaryButton("Continue") { go() }
                } else {
                    primaryButton(scanning ? "Looking…" : "Start looking", enabled: !scanning && radioBlocked == nil) {
                        startScanning()
                    }
                    secondaryButton("Set up later") { go() }
                }
            }
        }
    }

    private var statusTint: Color {
        if live.bonded { return NoopHTMLColor.green }
        return radioBlocked != nil ? NoopHTMLColor.warm : NoopHTMLColor.blue
    }

    private var strapTitle: String {
        if live.bonded { return "Connected" }
        if radioBlocked != nil { return "Bluetooth is unavailable" }
        return scanning ? "Looking for your strap" : "Not connected yet"
    }

    private var strapDetail: String {
        if live.bonded { return "Noop is reading your strap. The first night fills in tomorrow morning." }
        if let radioBlocked { return radioBlocked }
        return scanning
            ? "Keep it close. This takes a few seconds."
            : "A WHOOP or a standard heart-rate strap."
    }

    private func connectionLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(NoopHTMLColor.blue)
                .frame(width: 22, height: 22)
                .background(NoopHTMLColor.blue.opacity(0.12), in: Circle())
            Text(text)
                .font(NoopHTMLFont.sans(13))
                .foregroundStyle(NoopHTMLColor.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
    }

    // MARK: Apple Health

    private var healthStep: some View {
        page {
            heading("Apple Health", "Noop can write what your strap records, like sleep, heart rate and workouts, into Apple Health, so your other apps see it too. It reads your weigh-ins back. Apple asks about each kind of data.")
            HStack(spacing: 14) {
                Image(systemName: health.auth == .authorized ? "checkmark" : "heart.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(healthTint)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 52, height: 52)
                    .background(healthTint.opacity(0.13), in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(healthTitle).font(NoopHTMLFont.sans(14.5, weight: .semibold))
                    Text(healthDetail)
                        .font(NoopHTMLFont.sans(12.5))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(health.auth == .authorized ? NoopHTMLColor.green.opacity(0.35) : NoopHTMLColor.border, lineWidth: 0.5))
            .animation(OnboardingMotion.reveal, value: health.auth)
            .accessibilityElement(children: .combine)
            .entrance(2)
        } footer: {
            VStack(spacing: 4) {
                if healthCanAsk {
                    primaryButton(healthAsking ? "Waiting for Apple Health…" : "Connect Apple Health", enabled: !healthAsking) {
                        healthAsking = true
                        Task { @MainActor in
                            await health.requestAuthorization()
                            healthAsking = false
                        }
                    }
                    secondaryButton("Not now") { go() }
                } else {
                    primaryButton("Continue") { go() }
                    // Keeps the footer the same height as the asking state, so nothing jumps.
                    secondaryButton(" ") {}.hidden()
                }
            }
        }
        .sensoryFeedback(.success, trigger: health.auth) { _, auth in auth == .authorized }
    }

    private var healthCanAsk: Bool { health.auth == .unknown }

    private var healthTint: Color {
        switch health.auth {
        case .authorized: NoopHTMLColor.green
        case .unavailable, .entitlementMissing, .denied: NoopHTMLColor.warm
        case .unknown: NoopHTMLColor.blush
        }
    }

    private var healthTitle: String {
        switch health.auth {
        case .authorized: "Connected"
        case .denied: "Turned off"
        case .unavailable: "Not on this device"
        case .entitlementMissing: "Not available in this build"
        case .unknown: "Not connected"
        }
    }

    private var healthDetail: String {
        switch health.auth {
        case .authorized: "Change which kinds of data any time in the Health app."
        case .denied: "Turn it on in Settings › Health › Data Access & Devices › Noop Aura."
        case .unavailable: "Apple Health isn't on this device. Everything else works the same."
        case .entitlementMissing: "This install can't reach Apple Health. You can import a Health export later from Settings › Data and connections."
        case .unknown: "Optional. You can connect later from Settings › Data and connections."
        }
    }

    // MARK: Notices

    /// The permission is asked here, once, with the reason beside it, rather than at whatever moment
    /// a first notice happens to have something to say (26 Oct 2026).
    private var noticesStep: some View {
        page {
            heading("A few quiet notices", "Noop speaks up rarely, and only about your strap and your record. These four are on; everything else waits in Settings › Notifications.")
            VStack(spacing: 0) {
                noticeRow("Your night is in", "Once last night is scored: its sleep and recovery.", "moon.fill", NoopHTMLColor.night)
                divider.padding(.leading, 52)
                noticeRow("Battery", "At 15%, and once when it finishes charging.", "battery.25", NoopHTMLColor.green)
                divider.padding(.leading, 52)
                noticeRow("Sync reminder", "When the strap hasn't synced for three hours.", "arrow.triangle.2.circlepath", NoopHTMLColor.blue)
                divider.padding(.leading, 52)
                noticeRow("Backup reminder", "Your record lives only on this iPhone. Once a month at most.", "externaldrive.fill", NoopHTMLColor.blush)
            }
            .padding(.horizontal, 16)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(NoopHTMLColor.border, lineWidth: 0.5))
            .entrance(2)
        } footer: {
            VStack(spacing: 4) {
                if notificationsAsked {
                    primaryButton("Continue") { go() }
                    secondaryButton(" ") {}.hidden()
                } else {
                    // Not "Allow": that word belongs to the system alert this opens (HIG, pre-alert screens).
                    primaryButton("Turn on notices") {
                        Task { @MainActor in
                            notificationsOn = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
                            notificationsAsked = true
                            go()
                        }
                    }
                    secondaryButton("Not now") { go() }
                }
            }
        }
        .task { await readNotificationStatus() }
    }

    private func noticeRow(_ title: String, _ detail: String, _ symbol: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            NoopIconDisc(symbol: symbol, color: tint, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(NoopHTMLFont.sans(14, weight: .semibold))
                Text(detail)
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    // MARK: Summary

    private var doneStep: some View {
        page(centered: true) {
            VStack(spacing: 10) {
                Text("Your thread starts here.")
                    .font(NoopHTMLFont.outfit(30, weight: .light))
                    .tracking(-0.8)
                    .entrance(0)
                Text(live.bonded
                     ? "Wear it tonight. Your first recovery arrives in the morning."
                     : "Connect your strap when it's to hand. Noop starts reading the moment it answers.")
                    .font(NoopHTMLFont.sans(14))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .entrance(1)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 0) {
                summaryRow("Strap", live.bonded ? "Connected" : "Later, from You › Settings", done: live.bonded)
                    .entrance(3)
                divider
                summaryRow("Sleep", schedule?.title ?? (learnsSchedule ? "Noop will learn it" : "At night, mostly"), done: schedule != nil || learnsSchedule)
                    .entrance(4)
                divider
                summaryRow("Apple Health", health.auth == .authorized ? "Connected" : "Not connected", done: health.auth == .authorized)
                    .entrance(5)
                divider
                summaryRow("Notices", notificationsOn ? "On" : "Off", done: notificationsOn)
                    .entrance(6)
                divider
                summaryRow("About you", profileSaved ? "\(profile.age) · \(weightText)" : "Defaults for now", done: profileSaved)
                    .entrance(7)
            }
            .padding(.horizontal, 16)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(NoopHTMLColor.border, lineWidth: 0.5))
            .entrance(2)
        } footer: {
            primaryButton("Enter Noop Aura") { onFinished() }
        }
        .sensoryFeedback(.success, trigger: step) { _, now in now == .done }
        .task { await readNotificationStatus() }
    }

    private func summaryRow(_ title: String, _ value: String, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle.dashed")
                .font(.system(size: 15))
                .foregroundStyle(done ? NoopHTMLColor.green : NoopHTMLColor.muted)
            Text(title).font(NoopHTMLFont.sans(14))
            Spacer(minLength: 12)
            Text(value)
                .font(NoopHTMLFont.sans(13))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(minHeight: 46)
        .accessibilityElement(children: .combine)
    }

    // MARK: Page scaffolding

    private func heading(_ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(NoopHTMLFont.outfit(29, weight: .light))
                .tracking(-0.8)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .entrance(0)
            Text(detail)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .entrance(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func page<Content: View, Footer: View>(
        centered: Bool = false,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) { content() }
                    .padding(.horizontal, 22)
                    .padding(.top, centered ? 26 : 18)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            footer()
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
        }
    }

    private func primaryButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(NoopHTMLButtonStyle(kind: .primary, fullWidth: true))
            .opacity(enabled ? 1 : 0.38)
            .disabled(!enabled)
            .frame(height: 54)
            .animation(OnboardingMotion.reveal, value: enabled)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(NoopHTMLFont.sans(13.5, weight: .semibold))
            .foregroundStyle(NoopHTMLColor.copy)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .buttonStyle(NoopPlainHitStyle())
    }

    private var pageTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        let shift = OnboardingMotion.pageShift
        return .asymmetric(
            insertion: .offset(x: forward ? shift : -shift).combined(with: .opacity),
            removal: .offset(x: forward ? -shift : shift).combined(with: .opacity)
        )
    }

    // MARK: Actions

    private func go(back: Bool = false) {
        let target = OnboardingStep(rawValue: step.rawValue + (back ? -1 : 1))
        guard let target else { return }
        forward = !back
        moves += 1
        withAnimation(OnboardingMotion.page) { step = target }
        if target == .done { bursts += 1 }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        birth = profile.dateOfBirth
        sex = profile.sex
        weightKg = profile.weightKg
        heightCm = profile.heightCm
        #if DEBUG
        if let requested = OnboardingStep.requested { step = requested }
        #endif
    }


    private func readNotificationStatus() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        notificationsAsked = status != .notDetermined
        notificationsOn = status == .authorized || status == .provisional
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

// MARK: - Staggered entrance

/// Each block of a page arrives a beat after the one above it: 45 ms apart, never more than 300 ms in
/// all, and never holding a tap back. With Reduce Motion it is a plain fade.
private struct OnboardingEntrance: ViewModifier {
    let index: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 10)
            .blur(radius: shown || reduceMotion ? 0 : 4)
            .onAppear {
                let delay = min(Double(index) * OnboardingMotion.stagger, OnboardingMotion.staggerCap)
                withAnimation(OnboardingMotion.reveal.delay(delay)) { shown = true }
            }
    }
}

private extension View {
    func entrance(_ index: Int) -> some View { modifier(OnboardingEntrance(index: index)) }
}

// MARK: - Ruler

/// A horizontal ruler that scrolls under a fixed needle and snaps to whole units, with a tick of
/// haptic for each one passed, like a physical dial. Momentum and rubber-banding are the system
/// scroll view's own.
private struct OnboardingRuler: View {
    let range: ClosedRange<Int>
    @Binding var value: Int
    var major: Int = 10
    let label: (Int) -> String

    @State private var position: Int?
    private static let pitch: CGFloat = 12

    init(range: ClosedRange<Int>, value: Binding<Int>, major: Int = 10, label: @escaping (Int) -> String) {
        self.range = range
        _value = value
        self.major = major
        self.label = label
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(.horizontal) {
                // Eager, not lazy: a lazy stack hasn't measured the ticks off screen, so the opening
                // position landed short of the value (seen at 162 for 178).
                HStack(spacing: 0) {
                    ForEach(range, id: \.self) { v in
                        tick(v).id(v)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, (geo.size.width - Self.pitch) / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .center)
            .scrollIndicators(.hidden)
        }
        .frame(height: 70)
        .mask(LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .black, location: 0.22),
            .init(color: .black, location: 0.78),
            .init(color: .clear, location: 1)
        ], startPoint: .leading, endPoint: .trailing))
        .overlay(alignment: .top) {
            Capsule()
                .fill(NoopHTMLColor.blush)
                .frame(width: 3, height: 46)
                .shadow(color: NoopHTMLColor.blush.opacity(0.6), radius: 6)
                .offset(y: -6)
                .allowsHitTesting(false)
        }
        .onAppear {
            position = min(max(value, range.lowerBound), range.upperBound)
        }
        .onChange(of: position) { _, p in
            if let p, p != value { value = p }
        }
        .onChange(of: value) { _, v in
            if position != v { position = v }
        }
        .sensoryFeedback(.selection, trigger: value)
        .accessibilityElement()
        .accessibilityValue(label(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(value + 1, range.upperBound)
            case .decrement: value = max(value - 1, range.lowerBound)
            @unknown default: break
            }
        }
    }

    private func tick(_ v: Int) -> some View {
        let isMajor = v % major == 0
        let isHalf = !isMajor && major % 2 == 0 && v % (major / 2) == 0
        return VStack(spacing: 8) {
            Capsule()
                .fill(isMajor ? NoopHTMLColor.inkSoft : Color.white.opacity(isHalf ? 0.4 : 0.2))
                .frame(width: isMajor ? 2 : 1.5, height: isMajor ? 32 : isHalf ? 22 : 14)
            Text(isMajor ? label(v) : "")
                .font(NoopHTMLFont.sans(11.5, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(NoopHTMLColor.faint)
                .fixedSize()
        }
        .frame(width: Self.pitch, height: 70, alignment: .top)
    }
}

// MARK: - Ring burst

/// A ring of light that leaves the orb when something lands: the strap answering, the setup finishing.
/// One sharp ring and one soft glow, expanding and fading together. Nothing with Reduce Motion.
private struct OnboardingRingBurst: View {
    let trigger: Int
    let colour: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Frame {
        var scale = 1.0
        var opacity = 0.0
    }

    var body: some View {
        ZStack {
            Circle().stroke(colour, lineWidth: 2)
            Circle().stroke(colour, lineWidth: 12).blur(radius: 10)
        }
        .keyframeAnimator(initialValue: Frame(), trigger: trigger) { ring, f in
            ring.scaleEffect(f.scale).opacity(reduceMotion ? 0 : f.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                MoveKeyframe(0.75)
                CubicKeyframe(1.9, duration: 1.0)
            }
            KeyframeTrack(\.opacity) {
                MoveKeyframe(0.9)
                CubicKeyframe(0, duration: 1.0)
            }
        }
        .allowsHitTesting(false)
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
