import SwiftUI
import CoreBluetooth
import UserNotifications
import StrandAnalytics

// MARK: - First run
//
// One question a page, each answered with one gesture. The Aura orb carries the pages about the wearer
// (it blooms in on the welcome, beats on every move, warms from teal toward green as the setup fills in,
// and grows back for the summary); the pages about the world outside it get a scene of their own: a sky
// that turns to the wearer's hours, the phone and strap finding each other, the record flowing into
// Apple Health, a history arriving from another app, notices as they will look.
//
// Every permission (Bluetooth, Apple Health, notifications) has its own page saying what it is for and
// what it is never used for, with the question iOS will ask previewed in iOS's own words. Their single
// button is "Continue", never "Allow": that word belongs to the system's question (HIG, pre-alert
// screens). Location and the microphone are asked only when a feature needs them; the summary says
// which and why. Moving pictures fall still under Reduce Motion (NoopOnboardingScenes.swift).

private enum OnboardingStep: Int, CaseIterable {
    case welcome, born, sex, weight, height, sleep, bluetooth, strap, health, history, notices, done

    /// The pages the progress bar counts: the questions, not the welcome or the summary.
    static let counted: [OnboardingStep] = [.born, .sex, .weight, .height, .sleep, .bluetooth, .strap, .health, .history, .notices]

    /// Pages about the wearer, which the orb sits above. The rest carry their own scene.
    var showsOrb: Bool { [.welcome, .born, .sex, .weight, .height, .done].contains(self) }

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
    @EnvironmentObject private var behavior: BehaviorStore
    @ObservedObject private var imports = NoopDataFlow.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    @Namespace private var unitPill

    @State private var step: OnboardingStep = .welcome
    /// Which way the last move went, so a page leaves toward where it came from on the way back.
    @State private var forward = true
    @State private var schedule: OnboardingSchedule?
    @State private var learnsSchedule = false
    @State private var bluetoothAsked = false
    @State private var bluetoothAuth = CBCentralManager.authorization
    /// Bluetooth off or missing: said beside the button rather than a scan that finds nothing.
    @State private var radioBlocked: String?
    @State private var scanning = false
    @State private var healthAsking = false
    @State private var importSource: String?
    @State private var notificationsAsked = false
    @State private var notificationsOn = false
    // The four notices, chosen here and written when the page is continued, so flipping one never sets
    // off the system's question before the page has explained it.
    @State private var noticeNight = true
    @State private var noticeBattery = true
    @State private var noticeSync = true
    @State private var noticeBackup = true
    // About you, written per page on Continue, so "Skip" leaves that one value exactly as it was.
    @State private var birth = Date()
    @State private var sex = "female"
    @State private var weightKg = 70.0
    @State private var heightCm = 170.0
    @State private var profileSaved = false
    /// Bumped on every page move, for the light tap and the orb's beat that go with it.
    @State private var moves = 0
    @State private var bloomed = false
    /// How many of the summary's marks have dropped in.
    @State private var landed = 0
    /// The summary has been drawn in and the way in holds the screen.
    @State private var gathered = false
    /// When ENTER was pressed; starts the burst.
    @State private var burstAt: Date?
    /// The orb's place on screen, which the way in sets off from.
    @State private var orbFrame = CGRect.zero
    /// The screen thinning away into the app as the burst spreads.
    @State private var dissolving = false
    @State private var loaded = false

    private var imperial: Bool { unitSystemRaw == UnitSystem.imperial.rawValue }

    var body: some View {
        screen
            .allowsHitTesting(burstAt == nil)
    }

    private var screen: some View {
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
                    case .bluetooth: bluetoothStep
                    case .strap: strapStep
                    case .health: healthStep
                    case .history: historyStep
                    case .notices: noticesStep
                    case .done: doneStep
                    }
                }
                .id(step)
                .transition(pageTransition)
            }
            // Gathered: the page is drawn in toward the centre and blurs away, and the way in takes over.
            .scaleEffect(gathered ? 0.82 : 1)
            .blur(radius: gathered ? 14 : 0)
            .opacity(gathered ? 0 : 1)
            if gathered {
                OnboardingFinaleScene(colour: NoopAuraOrbModel.palette(Self.noopBlue).top, from: orbFrame, burstAt: burstAt, onEnter: enter)
                    .transition(.opacity)
            }
        }
        .opacity(dissolving ? 0 : 1)
        .preferredColorScheme(.dark)
        .foregroundStyle(NoopHTMLColor.ink)
        .font(NoopHTMLFont.sans(14))
        .sensoryFeedback(.impact(weight: .light, intensity: 0.7), trigger: moves)
        .onChange(of: live.bonded) { _, bonded in
            if bonded { scanning = false }
        }
        .onReceive(model.ble.$bluetoothAuthorization) { bluetoothAuth = $0 }
        .onAppear(perform: load)
    }

    // MARK: Chrome

    private var topGlow: some View {
        VStack {
            Ellipse()
                .fill(RadialGradient(colors: [glowColor.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 215))
                .frame(width: 470, height: 410)
                .blur(radius: 18)
                .offset(y: -235)
                .animation(OnboardingMotion.sky, value: glowColor)
            Spacer()
        }
        // Wider than the phone: let it draw past the edges without widening the onboarding stack,
        // which laid the terms gate above it out at 470 pt and pushed it off both edges.
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var glowColor: Color {
        step == .sleep ? sky.glow : NoopAuraOrbModel.palette(orbColour).top
    }

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

    private static let orbSide: CGFloat = 248

    private var orb: some View {
        let side: CGFloat = switch step {
        case .welcome: 248
        case .done: 208
        case _ where step.showsOrb: 78
        default: 0
        }
        // Drawn at full size and scaled: laid out small, the orb's halo blur shrinks below a pixel and
        // leaves a hard second outline, and a scale animates on the GPU where a frame change re-lays out.
        return ZStack {
            NoopAuraOrb(shapeScore: live.bonded || step == .done ? 0.08 : 0.22, colorScore: orbColour, paused: !step.showsOrb)
                .frame(width: Self.orbSide, height: Self.orbSide)
                .keyframeAnimator(initialValue: 1.0, trigger: moves) { content, beat in
                    content.scaleEffect(reduceMotion ? 1 : beat)
                } keyframes: { _ in
                    SpringKeyframe(1.07, duration: 0.14, spring: .snappy)
                    SpringKeyframe(1.0, duration: 0.5, spring: .bouncy(duration: 0.5, extraBounce: 0.1))
                }
        }
        .scaleEffect(max(side, 1) / Self.orbSide)
        .frame(width: side, height: side)
        // Where it sits on screen, so the way in can carry it from here to the centre.
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { orbFrame = $0 }
        .opacity(step.showsOrb && bloomed && !gathered ? 1 : 0)
        // First appearance: out of a soft blur rather than popping in.
        .scaleEffect(bloomed || reduceMotion ? 1 : 0.86)
        .blur(radius: bloomed || reduceMotion ? 0 : 14)
        .frame(maxWidth: .infinity)
        .padding(.top, step == .welcome ? 18 : step.showsOrb ? 4 : 0)
        .animation(OnboardingMotion.morph, value: step)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.smooth(duration: 0.9)) { bloomed = true }
        }
    }

    /// Where the orb's palette is bluest, matching Noop blue.
    private static let noopBlue = 2.0 / 3.0

    /// Teal (0.5) at the start, toward green (0.2) as each question is answered; Noop blue at the end.
    private var orbColour: Double {
        // The way in wears Noop's own blue.
        if step == .done { return Self.noopBlue }
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
                    .onboardingEntrance(0)
                Text("Your strap, read on this iPhone.\nNo account, no subscription, no server in the middle.")
                    .font(NoopHTMLFont.sans(14))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .onboardingEntrance(1)
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 16) {
                iconLine("circle.dashed.inset.filled", NoopHTMLColor.blue, "Recovery every morning", "Scored against your own baselines. Missing inputs stay missing.")
                    .onboardingEntrance(2)
                iconLine("waveform.path.ecg", NoopHTMLColor.blush, "Your heart, live", "Each beat, variability and zones as they happen.")
                    .onboardingEntrance(3)
                iconLine("lock.shield", NoopHTMLColor.green, "Yours, locally", "Data stays on this iPhone unless you send it somewhere.")
                    .onboardingEntrance(4)
            }
            .padding(.top, 8)
        } footer: {
            primaryButton("Get started") { go() }
        }
    }

    // MARK: About you

    private var bornStep: some View {
        page {
            heading("When were you born?", "Your age sets your maximum heart rate, and with it every zone.")
            bigFigure("\(ageFromBirth)", value: ageFromBirth, unit: ageFromBirth == 1 ? "year old" : "years old")
                .onboardingEntrance(2)
            OnboardingRuler(range: birthYears, value: birthYearBinding, major: 10) { "\($0)" }
                .onboardingEntrance(3)
            Text("Born in \(String(birthYearBinding.wrappedValue))")
                .font(NoopHTMLFont.sans(13))
                .foregroundStyle(NoopHTMLColor.copy)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(birthYearBinding.wrappedValue)))
                .animation(OnboardingMotion.figure, value: birthYearBinding.wrappedValue)
                .frame(maxWidth: .infinity)
                .onboardingEntrance(4)
        } footer: {
            answerFooter { profile.dateOfBirth = birth }
        }
    }

    private var ageFromBirth: Int { ProfileStore.years(from: birth, to: Date()) }

    private var birthYears: ClosedRange<Int> {
        let range = ProfileStore.dateOfBirthRange
        let calendar = Calendar.current
        return calendar.component(.year, from: range.lowerBound)...calendar.component(.year, from: range.upperBound)
    }

    /// The year on the ruler; the day and month already on the profile are kept.
    private var birthYearBinding: Binding<Int> {
        Binding(
            get: { Calendar.current.component(.year, from: birth) },
            set: { year in
                let calendar = Calendar.current
                var parts = calendar.dateComponents([.year, .month, .day], from: birth)
                parts.year = year
                guard let moved = calendar.date(from: parts) else { return }
                let range = ProfileStore.dateOfBirthRange
                birth = min(max(moved, range.lowerBound), range.upperBound)
            }
        )
    }

    private struct SexOption {
        let tag: String
        let title: String
        let symbol: String
        let detail: String
    }

    private static let sexOptions = [
        SexOption(tag: "female", title: "Female", symbol: "figure.stand.dress", detail: "Calories use the female formula."),
        SexOption(tag: "male", title: "Male", symbol: "figure.stand", detail: "Calories use the male formula."),
        SexOption(tag: "nonbinary", title: "Other", symbol: "circle.lefthalf.filled", detail: "Calories use the average of both formulas."),
    ]

    private var sexStep: some View {
        page {
            heading("What's your sex?", "Only the calorie estimate uses it. Nothing else in Noop changes.")
            HStack(spacing: 10) {
                ForEach(Array(Self.sexOptions.enumerated()), id: \.offset) { i, option in
                    sexTile(option)
                        .onboardingEntrance(2 + i)
                }
            }
            Text(Self.sexOptions.first { $0.tag == sex }?.detail ?? "")
                .font(NoopHTMLFont.sans(13))
                .foregroundStyle(NoopHTMLColor.copy)
                .frame(maxWidth: .infinity)
                .id(sex)
                .transition(.opacity.combined(with: .offset(y: 4)))
                .animation(OnboardingMotion.reveal, value: sex)
                .onboardingEntrance(5)
        } footer: {
            answerFooter { profile.sex = sex }
        }
        .sensoryFeedback(.selection, trigger: sex)
    }

    private func sexTile(_ option: SexOption) -> some View {
        let on = sex == option.tag
        return Button { answerSex(option.tag) } label: {
            VStack(spacing: 14) {
                Image(systemName: option.symbol)
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(on ? NoopHTMLColor.blush : NoopHTMLColor.inkSoft)
                    .symbolEffect(.bounce, value: on)
                    .frame(height: 52)
                Text(option.title)
                    .font(NoopHTMLFont.sans(15, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 156)
            .background {
                RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous)
                    .fill(on
                          ? AnyShapeStyle(LinearGradient(colors: [NoopHTMLColor.blush.opacity(0.24), NoopHTMLColor.blush.opacity(0.06)], startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(NoopHTMLColor.card))
            }
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(on ? NoopHTMLColor.blush.opacity(0.55) : NoopHTMLColor.border, lineWidth: on ? 1 : 0.5))
            .shadow(color: on ? NoopHTMLColor.blush.opacity(0.25) : .clear, radius: 16, y: 6)
            .opacity(on ? 1 : 0.62)
            .animation(OnboardingMotion.morph, value: on)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    /// A tap is the answer: it is saved, seen to land, and the page moves on by itself.
    private func answerSex(_ tag: String) {
        sex = tag
        profile.sex = tag
        profileSaved = true
        Task { @MainActor in
            try? await Task.sleep(for: OnboardingMotion.answerBeat * 2)
            if step == .sex { go() }
        }
    }

    private var weightStep: some View {
        page {
            heading("Your weight", "For the calorie estimate only, never a goal. Apple Health weigh-ins keep it current.")
            bigFigure("\(weightBinding.wrappedValue)", value: weightBinding.wrappedValue, unit: imperial ? "lb" : "kg")
                .onboardingEntrance(2)
            OnboardingRuler(range: imperial ? 77...440 : 35...200, value: weightBinding, major: 10) { "\($0)" }
                .id(imperial)
                .onboardingEntrance(3)
            unitSwitch(metric: "kg", imperial: "lb")
                .onboardingEntrance(4)
        } footer: {
            answerFooter { profile.weightKg = weightKg }
        }
    }

    private var heightStep: some View {
        page {
            heading("Your height", "With your weight, it sets how much energy your body spends at rest.")
            bigFigure(imperial ? heightText : "\(heightBinding.wrappedValue)", value: heightBinding.wrappedValue, unit: imperial ? "" : "cm")
                .onboardingEntrance(2)
            OnboardingRuler(range: imperial ? 48...86 : 120...220, value: heightBinding, major: imperial ? 12 : 10) { value in
                imperial ? "\(value / 12)′" : "\(value)"
            }
            .id(imperial)
            .onboardingEntrance(3)
            unitSwitch(metric: "cm", imperial: "ft")
                .onboardingEntrance(4)
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
    private var heightText: String { "\(heightBinding.wrappedValue / 12)′ \(heightBinding.wrappedValue % 12)″" }

    // MARK: Sleep

    private var sky: OnboardingSky {
        if let schedule { return schedule.sky }
        return learnsSchedule ? .rotating : .undecided
    }

    private var sleepStep: some View {
        page {
            OnboardingSkyScene(sky: sky)
                .frame(height: 196)
                .overlay(alignment: .bottomLeading) {
                    Text(schedule?.caption ?? "Your hours, drawn")
                        .font(NoopHTMLFont.sans(12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.28), in: Capsule())
                        .padding(12)
                        .id(schedule)
                        .transition(.opacity)
                        .animation(OnboardingMotion.reveal, value: schedule)
                }
                .onboardingEntrance(0)
            heading("When do you sleep?", "The one answer that changes the whole app. Everything else Noop works out by watching for a week.")
            VStack(spacing: 9) {
                ForEach(Array(OnboardingSchedule.allCases.enumerated()), id: \.element) { i, option in
                    scheduleCard(option)
                        .onboardingEntrance(2 + i)
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
            .onboardingEntrance(5)
        } footer: {
            VStack(spacing: 4) {
                primaryButton("Continue", enabled: schedule != nil) {
                    guard let schedule else { return }
                    save(schedule)
                    go()
                }
                secondaryButton("Let Noop learn it") {
                    enableScheduleInference()
                    withAnimation(OnboardingMotion.sky) {
                        schedule = nil
                        learnsSchedule = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: OnboardingMotion.answerBeat * 3)
                        if step == .sleep { go() }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: schedule)
    }

    private func scheduleCard(_ option: OnboardingSchedule) -> some View {
        let on = schedule == option
        return Button {
            withAnimation(OnboardingMotion.sky) {
                schedule = option
                learnsSchedule = false
            }
        } label: {
            HStack(spacing: 13) {
                Image(systemName: option.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(on ? option.tint : NoopHTMLColor.copy)
                    .symbolEffect(.bounce, value: on)
                    .frame(width: 40, height: 40)
                    .background((on ? option.tint : Color.white).opacity(on ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: NoopRadius.control, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                    Text(option.detail)
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(on ? option.tint.opacity(0.1) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(on ? option.tint.opacity(0.45) : NoopHTMLColor.border, lineWidth: on ? 1 : 0.5))
            .animation(OnboardingMotion.morph, value: on)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Bluetooth

    private enum OnboardingRadio: Equatable { case waiting, asking, allowed, denied }

    private var radio: OnboardingRadio {
        switch bluetoothAuth {
        case .allowedAlways: .allowed
        case .denied, .restricted: .denied
        default: bluetoothAsked ? .asking : .waiting
        }
    }

    private var bluetoothStep: some View {
        page {
            OnboardingLink(state: radio == .allowed ? .open : radio == .denied ? .closed : .waiting,
                           sourceLabel: "Your strap", destinationLabel: "This iPhone") {
                OnboardingDarkTile {
                    OnboardingStrapGlyph(lit: radio == .allowed, tint: NoopHTMLColor.green)
                        .scaleEffect(0.22)
                }
            } destination: {
                OnboardingDarkTile {
                    Image(systemName: "iphone")
                        .font(.system(size: 27, weight: .light))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                }
            }
            .frame(height: 132)
                .onboardingEntrance(0)
            heading("Bluetooth, for your strap", "This is the one permission Noop can't work without: it is how your strap's data reaches this iPhone.")
            VStack(alignment: .leading, spacing: 14) {
                iconLine("arrow.left.and.right", NoopHTMLColor.blueLight, "Straight to your strap", "Noop talks to it directly. Nothing passes through a server.")
                    .onboardingEntrance(2)
                iconLine("sensor.tag.radiowaves.forward", NoopHTMLColor.green, "Only straps you add", "A WHOOP, or a heart-rate strap you pair yourself. Nothing else nearby.")
                    .onboardingEntrance(3)
                iconLine("location.slash", NoopHTMLColor.blush, "Never your whereabouts", "Bluetooth is not used to work out where you are.")
                    .onboardingEntrance(4)
            }
            switch radio {
            case .waiting, .asking:
                OnboardingSystemAlertPreview(
                    title: "“\(Self.appName)” Would Like to Use Bluetooth",
                    message: Self.purpose("NSBluetoothAlwaysUsageDescription")
                )
                .onboardingEntrance(5)
            case .allowed:
                statusLine("checkmark.circle.fill", NoopHTMLColor.green, "Bluetooth is on for Noop Aura.")
            case .denied:
                statusLine("exclamationmark.circle.fill", NoopHTMLColor.warm, "Bluetooth is off for Noop Aura. Your strap can't connect until it's on in Settings.")
            }
        } footer: {
            VStack(spacing: 4) {
                if radio == .waiting || radio == .asking {
                    // The one action this page has: it opens the system question.
                    primaryButton("Continue", enabled: radio == .waiting) {
                        bluetoothAsked = true
                        model.ble.startBluetooth()
                    }
                    secondaryButton(" ") {}.hidden()
                } else {
                    primaryButton("Continue") { go() }
                    if radio == .denied {
                        secondaryButton("Open Settings") { openSettings() }
                    } else {
                        secondaryButton(" ") {}.hidden()
                    }
                }
            }
        }
        .onChange(of: radio) { _, now in
            // Answered yes: the next page is where the strap is found, so go there.
            guard now == .allowed, bluetoothAsked else { return }
            Task { @MainActor in
                try? await Task.sleep(for: OnboardingMotion.answerBeat * 3)
                if step == .bluetooth { go() }
            }
        }
        .sensoryFeedback(trigger: radio) { _, now in
            switch now {
            case .allowed: .success
            case .denied: .warning
            default: nil
            }
        }
    }

    // MARK: Strap

    private var strapStep: some View {
        page {
            OnboardingStrapScene(looking: scanning, connected: live.bonded, heartRate: live.heartRate)
                .onboardingEntrance(0)
            heading(strapTitle, strapDetail)
                .id(strapTitle)
                .transition(.opacity)
                .animation(OnboardingMotion.reveal, value: strapTitle)
            if !live.bonded {
                VStack(alignment: .leading, spacing: 11) {
                    tipLine("Wear it snug, sensor against your skin.")
                    tipLine("Charged, and within about a metre of this iPhone.")
                    tipLine("If it's paired with another phone, close that app first.")
                }
                .onboardingEntrance(2)
            }
        } footer: {
            // One primary action per page: until a strap answers, moving on is the quiet choice.
            VStack(spacing: 4) {
                if live.bonded {
                    primaryButton("Continue") { go() }
                    secondaryButton(" ") {}.hidden()
                } else if radio == .denied {
                    primaryButton("Open Settings") { openSettings() }
                    secondaryButton("Set up later") { go() }
                } else {
                    primaryButton(scanning ? "Looking…" : "Start looking", enabled: !scanning && radioBlocked == nil) {
                        startScanning()
                    }
                    secondaryButton("Set up later") { go() }
                }
            }
        }
        .onReceive(model.ble.$radioStateErrorShown) { blocked in
            radioBlocked = blocked ? (live.lastSyncError ?? "Turn Bluetooth on to look for your strap.") : nil
        }
        .sensoryFeedback(.success, trigger: live.bonded) { _, bonded in bonded }
    }

    private var strapTitle: String {
        if live.bonded { return "Connected" }
        if radio == .denied { return "Bluetooth is off for Noop" }
        if radioBlocked != nil { return "Bluetooth is unavailable" }
        return scanning ? "Looking for your strap" : "Connect your strap"
    }

    private var strapDetail: String {
        if live.bonded {
            return live.heartRate == nil
                ? "Noop is reading your strap. Your first night fills in tomorrow morning."
                : "That's your heart, live. Your first night fills in tomorrow morning."
        }
        if radio == .denied { return "Turn it on in Settings › Noop Aura › Bluetooth, or set the strap up later from You › Settings." }
        if let radioBlocked { return radioBlocked }
        return scanning
            ? "Keep it close. This takes a few seconds."
            : "A WHOOP, or a standard heart-rate strap. Noop finds it over Bluetooth."
    }

    private func tipLine(_ text: String) -> some View {
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

    /// What Noop actually writes (HealthKitBridge.writeTypes), in the words the Health app uses.
    private static let healthWrites: [(symbol: String, title: String, tint: Color)] = [
        ("bed.double.fill", "Sleep", NoopHTMLColor.night),
        ("heart.fill", "Heart rate", NoopHTMLColor.red),
        ("waveform.path.ecg", "Heart rate variability", NoopHTMLColor.blush),
        ("lungs.fill", "Respiratory rate", NoopHTMLColor.blueLight),
        ("figure.run", "Workouts", NoopHTMLColor.green),
        ("flame.fill", "Active energy", NoopHTMLColor.amber),
    ]

    private var healthStep: some View {
        page {
            VStack(spacing: 12) {
                OnboardingLink(state: healthLink, sourceLabel: "Noop Aura", destinationLabel: "Health", returns: true) {
                    OnboardingDarkTile {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(LinearGradient(colors: [NoopHTMLColor.green, NoopHTMLColor.blueLight], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                } destination: {
                    healthAppTile
                }
                .frame(height: 132)
                HStack(spacing: 6) {
                    Image(systemName: health.auth == .authorized ? "checkmark.circle.fill" : "circle.dashed")
                        .contentTransition(.symbolEffect(.replace))
                        .foregroundStyle(healthTint)
                    Text(healthTitle)
                        .contentTransition(.opacity)
                }
                .font(NoopHTMLFont.sans(13, weight: .semibold))
                .animation(OnboardingMotion.reveal, value: health.auth)
                if health.auth != .unknown && health.auth != .authorized {
                    Text(healthDetail)
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .onboardingEntrance(0)
            heading("Apple Health", "Your strap's record, in the one place every health app reads from. Apple then shows a sheet with each kind of data; turn on only what you want.")
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Noop writes")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(Array(Self.healthWrites.enumerated()), id: \.offset) { i, item in
                        healthTile(item.symbol, item.title, item.tint, lit: health.auth == .authorized)
                            .onboardingEntrance(3 + i)
                    }
                }
                sectionLabel("Noop reads back")
                    .padding(.top, 8)
                healthTile("scalemass.fill", "Weight and body measurements", NoopHTMLColor.inkSoft, lit: health.auth == .authorized)
                    .onboardingEntrance(9)
                Label("Between this iPhone and Health only. Nothing goes anywhere else.", systemImage: "lock.fill")
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(NoopHTMLColor.faint)
                    .padding(.top, 6)
                    .onboardingEntrance(10)
            }
            if health.auth == .unknown {
                OnboardingHealthSheetPreview(
                    message: Self.purpose("NSHealthUpdateUsageDescription"),
                    kinds: ["Sleep", "Heart Rate", "Workouts"]
                )
                .onboardingEntrance(11)
            }
        } footer: {
            VStack(spacing: 4) {
                if health.auth == .unknown {
                    primaryButton(healthAsking ? "Waiting for Apple Health…" : "Continue", enabled: !healthAsking) {
                        healthAsking = true
                        Task { @MainActor in
                            await health.requestAuthorization()
                            healthAsking = false
                        }
                    }
                    secondaryButton("Not now") { go() }
                } else {
                    primaryButton("Continue") { go() }
                    secondaryButton(" ") {}.hidden()
                }
            }
        }
        .sensoryFeedback(.success, trigger: health.auth) { _, auth in auth == .authorized }
    }

    private var healthLink: OnboardingLinkState {
        switch health.auth {
        case .authorized: .open
        case .unknown: .waiting
        case .denied, .unavailable, .entitlementMissing: .closed
        }
    }

    /// Health's own colours: a white tile and a red heart that beats a little faster once connected.
    private var healthAppTile: some View {
        Color.white.overlay(
            Image(systemName: "heart.fill")
                .font(.system(size: 28))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFF5F7E), Color(hex: 0xFF2D55)], startPoint: .top, endPoint: .bottom))
                .phaseAnimator([false, true]) { heart, beat in
                    heart.scaleEffect(reduceMotion ? 1 : (beat ? 1.12 : 1))
                } animation: { beat in
                    beat ? .spring(duration: 0.18, bounce: 0.4) : .smooth(duration: health.auth == .authorized ? 0.5 : 0.9)
                }
        )
    }

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
        case .authorized, .unknown: ""
        case .denied: "Turn it on in Settings › Health › Data Access & Devices › Noop Aura."
        case .unavailable: "Apple Health isn't on this device. Everything else works the same."
        case .entitlementMissing: "This install can't reach Apple Health. You can import a Health export on the next page instead."
        }
    }

    /// One kind of data. Lit (tinted, ticked) once Health is connected, so the grid itself says what
    /// changed.
    private func healthTile(_ symbol: String, _ title: String, _ tint: Color, lit: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(lit ? 0.2 : 0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(title)
                .font(NoopHTMLFont.sans(13, weight: .medium))
                .foregroundStyle(NoopHTMLColor.inkSoft)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if lit {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(NoopHTMLColor.green)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.control + 2, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.control + 2, style: .continuous).stroke(lit ? tint.opacity(0.3) : NoopHTMLColor.border, lineWidth: 0.5))
        .animation(OnboardingMotion.morph, value: lit)
    }

    // MARK: History

    /// The wearables the importer reads, with how to get each one's export (shared with Settings).
    private static var importSources: [(String, String)] { NoopImportCatalogSheet.groups.first?.1 ?? [] }

    private static let sourceSymbols: [String: String] = [
        "WHOOP": "w.circle.fill",
        "Apple Health": "heart.fill",
        "Oura": "circle.circle",
        "Fitbit": "circle.grid.3x3.fill",
        "Garmin": "triangle.fill",
        "Xiaomi / Mi Band": "capsule.fill",
    ]

    private var historyStep: some View {
        page {
            heading("Bring your history", "Recovery leans on your baselines. An export from the app you used before gives Noop months of them on day one, instead of a week of learning.")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(Array(Self.importSources.enumerated()), id: \.offset) { i, source in
                    sourceTile(source.0)
                        .onboardingEntrance(2 + i)
                }
            }
            if let importSource, let how = Self.importSources.first(where: { $0.0 == importSource })?.1 {
                Label(how, systemImage: "arrow.down.doc")
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.control + 2, style: .continuous))
                    .id(importSource)
                    .transition(.opacity.combined(with: .offset(y: -6)))
            }
            importStatus
                .animation(OnboardingMotion.morph, value: imports.phase)
            Text("Noop tells the export apart by what's inside it, so any of these files works with the same button. More arrive later from Settings › Data and connections.")
                .font(NoopHTMLFont.sans(12))
                .foregroundStyle(NoopHTMLColor.faint)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingEntrance(9)
        } footer: {
            VStack(spacing: 4) {
                switch imports.phase {
                case .imported:
                    primaryButton("Continue") { go() }
                    secondaryButton("Add another file") { chooseImport() }
                case .reading:
                    // A large Apple Health export can take minutes; it keeps reading behind the next pages.
                    primaryButton("Continue while it reads") { go() }
                    secondaryButton(" ") {}.hidden()
                case .idle, .rejected:
                    primaryButton(isRejected ? "Choose another file" : "Choose an export") { chooseImport() }
                    secondaryButton(isRejected ? "Skip" : "I'm new to tracking") { go() }
                }
            }
        }
        .animation(OnboardingMotion.reveal, value: importSource)
        .sensoryFeedback(trigger: imports.phase) { _, now in
            switch now {
            case .imported: .success
            case .rejected: .error
            default: nil
            }
        }
    }

    private var isRejected: Bool { if case .rejected = imports.phase { return true }; return false }

    private func sourceTile(_ name: String) -> some View {
        let on = importSource == name
        return Button {
            importSource = on ? nil : name
        } label: {
            VStack(spacing: 8) {
                Image(systemName: Self.sourceSymbols[name] ?? "doc.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(on ? NoopHTMLColor.blush : NoopHTMLColor.inkSoft)
                    .symbolEffect(.bounce, value: on)
                    .frame(height: 24)
                Text(name == "Xiaomi / Mi Band" ? "Mi Band" : name)
                    .font(NoopHTMLFont.sans(12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 78)
            .background(on ? NoopHTMLColor.blush.opacity(0.12) : NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.control + 4, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.control + 4, style: .continuous).stroke(on ? NoopHTMLColor.blush.opacity(0.5) : NoopHTMLColor.border, lineWidth: on ? 1 : 0.5))
            .animation(OnboardingMotion.morph, value: on)
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityLabel(name)
        .accessibilityHint("Shows how to get this export")
        .accessibilityAddTraits(on ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: on)
    }

    @ViewBuilder
    private var importStatus: some View {
        switch imports.phase {
        case .idle:
            EmptyView()
        case .reading(let reading):
            HStack(spacing: 12) {
                ProgressView()
                    .tint(NoopHTMLColor.blueLight)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reading \(reading.fileName)")
                        .font(NoopHTMLFont.sans(13.5, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(reading.fileSize.map { "\(ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)) · stays on this iPhone" } ?? "Stays on this iPhone")
                        .font(NoopHTMLFont.sans(12))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        case .imported(let written):
            VStack(alignment: .leading, spacing: 6) {
                Label(written.source, systemImage: "checkmark.circle.fill")
                    .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.green)
                Text(NoopDataFormat.headline(written.summary))
                    .font(NoopHTMLFont.outfit(30, weight: .light))
                    .tracking(-0.6)
                Text("\(NoopDataFormat.count(written.summary.recordCount)) records written to this iPhone.")
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.green.opacity(0.08), in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(NoopHTMLColor.green.opacity(0.3), lineWidth: 0.5))
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        case .rejected(let refused):
            VStack(alignment: .leading, spacing: 5) {
                Label(refused.fileName, systemImage: "exclamationmark.circle.fill")
                    .font(NoopHTMLFont.sans(12.5, weight: .semibold))
                    .foregroundStyle(NoopHTMLColor.warm)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(refused.reason)
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .transition(.opacity)
        }
    }

    private func chooseImport() {
        Task { @MainActor in
            guard let picked = await DocumentPicker.importFile(NoopDataFlow.importTypes) else { return }
            await imports.read(picked, model: model)
        }
    }

    // MARK: Notices

    private static let noticeExamples = [
        OnboardingNoticeStack.Notice(symbol: "moon.fill", tint: NoopHTMLColor.night, title: "Your night is in", body: "7h 42m asleep. Recovery 82."),
        OnboardingNoticeStack.Notice(symbol: "battery.25", tint: NoopHTMLColor.green, title: "Strap battery at 15%", body: "About a day left. Charge it tonight."),
        OnboardingNoticeStack.Notice(symbol: "arrow.triangle.2.circlepath", tint: NoopHTMLColor.blue, title: "Last synced 3 hours ago", body: "Bring this iPhone near your strap."),
        OnboardingNoticeStack.Notice(symbol: "externaldrive.fill", tint: NoopHTMLColor.blush, title: "Time for a backup", body: "Your record lives only on this iPhone."),
    ]

    /// The permission is asked here, once, with the reason beside it, rather than at whatever moment
    /// a first notice happens to have something to say (26 Oct 2026).
    private var noticesStep: some View {
        page {
            OnboardingNoticeStack(notices: Self.noticeExamples)
                .padding(.top, 6)
                .onboardingEntrance(0)
            heading("A few quiet notices", "Noop speaks up rarely, and only about your strap and your record. Choose which; everything else waits in Settings › Notifications.")
            VStack(spacing: 0) {
                noticeRow("Your night is in", "Once last night is scored.", "moon.fill", NoopHTMLColor.night, isOn: $noticeNight)
                divider.padding(.leading, 52)
                noticeRow("Battery", "At 15%, and once when it's charged.", "battery.25", NoopHTMLColor.green, isOn: $noticeBattery)
                divider.padding(.leading, 52)
                noticeRow("Sync reminder", "After three hours without a sync.", "arrow.triangle.2.circlepath", NoopHTMLColor.blue, isOn: $noticeSync)
                divider.padding(.leading, 52)
                noticeRow("Backup reminder", "Once a month at most.", "externaldrive.fill", NoopHTMLColor.blush, isOn: $noticeBackup)
            }
            .padding(.horizontal, 16)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(NoopHTMLColor.border, lineWidth: 0.5))
            .onboardingEntrance(2)
            if !notificationsAsked {
                OnboardingSystemAlertPreview(
                    title: "“\(Self.appName)” Would Like to Send You Notifications",
                    message: "Notifications may include alerts and sounds. These can be configured in Settings."
                )
                .onboardingEntrance(3)
            }
        } footer: {
            VStack(spacing: 4) {
                primaryButton("Continue") {
                    Task { @MainActor in
                        if !notificationsAsked {
                            notificationsOn = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
                            notificationsAsked = true
                        }
                        saveNotices()
                        go()
                    }
                }
                secondaryButton(" ") {}.hidden()
            }
        }
        .task { await readNotificationStatus() }
    }

    private func noticeRow(_ title: String, _ detail: String, _ symbol: String, _ tint: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            NoopIconDisc(symbol: symbol, color: tint, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(NoopHTMLFont.sans(14, weight: .semibold))
                Text(detail)
                    .font(NoopHTMLFont.sans(12))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
            Spacer(minLength: 8)
            NoopHTMLToggle(isOn: isOn.wrappedValue, color: NoopHTMLColor.green) {
                withAnimation(OnboardingMotion.morph) { isOn.wrappedValue.toggle() }
            }
            .sensoryFeedback(.selection, trigger: isOn.wrappedValue)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isOn.wrappedValue ? "On" : "Off")
        .accessibilityAction { isOn.wrappedValue.toggle() }
    }

    private func saveNotices() {
        AuraNotices.set(.morning, noticeNight)
        AuraNotices.set(.backup, noticeBackup)
        behavior.batteryAlerts = noticeBattery
        behavior.syncReminder = noticeSync
        Task { await AuraNotices.refresh(repo: model.repo) }
    }

    // MARK: Summary

    private var doneStep: some View {
        page(centered: true) {
            VStack(spacing: 10) {
                Text("Your thread starts here.")
                    .font(NoopHTMLFont.outfit(30, weight: .light))
                    .tracking(-0.8)
                    .onboardingEntrance(0)
                Text(live.bonded
                     ? "Wear it tonight. Your first recovery arrives in the morning."
                     : "Connect your strap when it's to hand. Noop starts reading the moment it answers.")
                    .font(NoopHTMLFont.sans(14))
                    .foregroundStyle(NoopHTMLColor.copy)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .onboardingEntrance(1)
            }
            .frame(maxWidth: .infinity)
            VStack(spacing: 0) {
                ForEach(Array(summaryItems.enumerated()), id: \.offset) { i, item in
                    if i > 0 { divider }
                    summaryRow(item.title, item.value, done: item.done, landed: landed > i)
                        .onboardingEntrance(3 + i)
                }
            }
            .padding(.horizontal, 16)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(NoopHTMLColor.border, lineWidth: 0.5))
            .onboardingEntrance(2)
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("Asked only if you use them")
                iconLine("location.fill", NoopHTMLColor.blue, "Location", "Drawing the route of an outdoor workout.")
                iconLine("mic.fill", NoopHTMLColor.blush, "Microphone", "Asking Svea a question by voice, transcribed on this iPhone.")
            }
            .onboardingEntrance(9)
        } footer: {
            EmptyView()
        }
        .task { await landMarks() }
    }

    /// What was set, in the order it was asked.
    private var summaryItems: [(title: String, value: String, done: Bool)] {
        let imported = { if case .imported = imports.phase { return true }; return false }()
        return [
            ("Strap", live.bonded ? "Connected" : "Later, from You › Settings", live.bonded),
            ("Sleep", schedule?.title ?? (learnsSchedule ? "Noop will learn it" : "At night"), schedule != nil || learnsSchedule),
            ("Apple Health", health.auth == .authorized ? "Connected" : "Not connected", health.auth == .authorized),
            ("History", historySummary, imported),
            ("Notices", notificationsOn ? "On" : "Off", notificationsOn),
            ("About you", profileSaved ? "\(profile.age) · \(weightText)" : "Defaults for now", profileSaved),
        ]
    }

    /// The summary's marks drop in one by one, each with its own tap; then the page is drawn in and
    /// the way in takes the screen.
    private func landMarks() async {
        await readNotificationStatus()
        let items = summaryItems
        for i in items.indices {
            try? await Task.sleep(for: .milliseconds(i == 0 ? 650 : 260))
            guard step == .done else { return }
            withAnimation(.spring(duration: 0.4, bounce: 0.3)) { landed = i + 1 }
            NoopHaptics.play(items[i].done ? .add : .tick)
        }
        try? await Task.sleep(for: .milliseconds(1200))
        guard step == .done else { return }
        withAnimation(.easeIn(duration: reduceMotion ? 0.3 : 0.55)) { gathered = true }
    }

    private var historySummary: String {
        switch imports.phase {
        case .imported(let written): written.source
        case .reading: "Still reading"
        case .idle, .rejected: "Starting fresh"
        }
    }

    private func summaryRow(_ title: String, _ value: String, done: Bool, landed: Bool) -> some View {
        HStack(spacing: 10) {
            OnboardingDropMark(landed: landed, done: done)
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
                .onboardingEntrance(0)
            Text(detail)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingEntrance(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func iconLine(_ symbol: String, _ tint: Color, _ title: String, _ detail: String) -> some View {
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

    private func statusLine(_ symbol: String, _ tint: Color, _ text: String) -> some View {
        Label {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
        .font(NoopHTMLFont.sans(13, weight: .medium))
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: NoopRadius.control + 2, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(NoopHTMLFont.sans(11.5, weight: .semibold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(NoopHTMLColor.faint)
    }

    private var divider: some View {
        Rectangle().fill(NoopHTMLColor.border).frame(height: 0.5)
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

    /// The quiet second action. Given a blank title and hidden, it holds the footer's height so a page
    /// whose second action comes and goes doesn't jump.
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
        guard let target = OnboardingStep(rawValue: step.rawValue + (back ? -1 : 1)) else { return }
        forward = !back
        moves += 1
        withAnimation(OnboardingMotion.page) { step = target }
    }

    /// ENTER, pressed or run out: the burst and its boom together; as the screen thins, the page underneath takes the
    /// landing wave and its thud, and the app takes over.
    private func enter() {
        guard burstAt == nil else { return }
        NoopHaptics.play(.welcome)
        burstAt = Date()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.55)) { dissolving = true }
            try? await Task.sleep(for: .milliseconds(300))
            NotificationCenter.default.post(name: .noopWelcomeWave, object: nil)
            NoopHaptics.play(.land)
            try? await Task.sleep(for: .milliseconds(300))
            onFinished()
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        birth = profile.dateOfBirth
        sex = profile.sex
        weightKg = profile.weightKg
        heightCm = profile.heightCm
        noticeNight = AuraNotices.isOn(.morning)
        noticeBackup = AuraNotices.isOn(.backup)
        noticeBattery = behavior.batteryAlerts
        noticeSync = behavior.syncReminder
        #if DEBUG
        if let requested = OnboardingStep.requested { step = requested }
        #endif
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
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

    /// The name iOS puts in its own questions.
    private static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Noop Aura"
    }

    /// A purpose string exactly as Info.plist gives it to iOS, so the preview matches the real question.
    private static func purpose(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }
}

private enum OnboardingSchedule: String, CaseIterable, Identifiable {
    case mostlyNights = "mostly-nights"
    case permanentNights = "permanent-nights"
    case rotating
    var id: String { rawValue }

    var title: String {
        switch self {
        case .mostlyNights: "At night"
        case .permanentNights: "During the day"
        case .rotating: "It rotates"
        }
    }

    var detail: String {
        switch self {
        case .mostlyNights: "A normal bedtime in the evening. Your day runs midnight to midnight."
        case .permanentNights: "You work nights and sleep in daylight. Every screen is written for that, not translated into it."
        case .rotating: "Shifts change week to week. Noop anchors your day to your sleep instead of the clock."
        }
    }

    /// Shown over the sky: who this answer describes.
    var caption: String {
        switch self {
        case .mostlyNights: "Awake by day, asleep by night"
        case .permanentNights: "Awake by night, asleep by day"
        case .rotating: "Days and nights take turns"
        }
    }

    var symbol: String {
        switch self {
        case .mostlyNights: "moon.stars.fill"
        case .permanentNights: "sun.max.fill"
        case .rotating: "arrow.triangle.2.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .mostlyNights: NoopHTMLColor.night
        case .permanentNights: NoopHTMLColor.warm
        case .rotating: NoopHTMLColor.blueLight
        }
    }

    var sky: OnboardingSky {
        switch self {
        case .mostlyNights: .night
        case .permanentNights: .day
        case .rotating: .rotating
        }
    }
}
