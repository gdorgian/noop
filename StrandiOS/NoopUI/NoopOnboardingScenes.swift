import SwiftUI

// MARK: - Onboarding scenes
//
// The moving pictures and shared pieces behind the first-run pages (NoopOnboarding.swift): the motion
// vocabulary, the staggered entrance, the ruler, the ring of light, the sky that turns from night to day,
// the phone and strap finding each other, the record flowing into Apple Health, the notice stack, and a
// preview of the question iOS is about to ask. Every scene holds still under Reduce Motion.

enum OnboardingMotion {
    /// Page to page: a short slide and a fade, not a full-width push. Quick, because there are many.
    static let page = Animation.snappy(duration: 0.28)
    /// The orb changing size between pages, the progress bar filling, cards changing state.
    static let morph = Animation.spring(duration: 0.42, bounce: 0.12)
    /// Each block of a page arriving.
    static let reveal = Animation.smooth(duration: 0.28)
    /// A big figure ticking to its new value.
    static let figure = Animation.snappy(duration: 0.2)
    /// The sky turning between night and day.
    static let sky = Animation.spring(duration: 1.1, bounce: 0.08)
    static let stagger = 0.03
    static let staggerCap = 0.2
    static let pageShift: CGFloat = 28
    /// The beat between an answer landing and the page moving on, so the choice is seen to take.
    static let answerBeat: Duration = .milliseconds(240)
}

// MARK: Staggered entrance

/// Each block of a page arrives a beat after the one above it: 30 ms apart, never more than 200 ms in
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

extension View {
    func onboardingEntrance(_ index: Int) -> some View { modifier(OnboardingEntrance(index: index)) }
}

/// A colour between two hex values, for scenes that blend continuously (night to day).
private func onboardingBlend(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
    func channel(_ hex: UInt32, _ shift: UInt32) -> Double { Double((hex >> shift) & 0xFF) / 255 }
    let u = min(max(t, 0), 1)
    return Color(red: channel(a, 16) + (channel(b, 16) - channel(a, 16)) * u,
                 green: channel(a, 8) + (channel(b, 8) - channel(a, 8)) * u,
                 blue: channel(a, 0) + (channel(b, 0) - channel(a, 0)) * u)
}

// MARK: - Ruler

/// A horizontal ruler that scrolls under a fixed needle and snaps to whole units, with a tick of
/// haptic for each one passed, like a physical dial. Momentum and rubber-banding are the system
/// scroll view's own.
struct OnboardingRuler: View {
    let range: ClosedRange<Int>
    @Binding var value: Int
    var major: Int = 10
    let label: (Int) -> String

    @State private var position: Int?
    /// Only a finger picks a value. Until one has moved the ruler, the positions the scroll view reports
    /// come from layout settling, not from a choice: taken as picks, they wrote 2013, then 1998, over a
    /// 1985 birth year.
    @State private var touched = false
    private static let pitch: CGFloat = 12

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
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
                .simultaneousGesture(DragGesture(minimumDistance: 2).onChanged { _ in touched = true })
                .task {
                    // After the first layout pass, so the scroll view knows where every tick is.
                    await Task.yield()
                    proxy.scrollTo(clamped(value), anchor: .center)
                }
            }
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
        .onChange(of: position) { _, p in
            if touched, let p, p != value { value = p }
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

    private func clamped(_ v: Int) -> Int { min(max(v, range.lowerBound), range.upperBound) }

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

// MARK: - Finale

/// The way in, as one scene on one clock, built like squeezing a hand gripper. The orb travels down
/// from where it sat on the summary to the centre, growing and rounding into a perfect circle in its own
/// drifting sparkle; then it is pressed, slowly smaller
/// against resistance, shaking finer and harder the closer it gets, its glow building like pressure,
/// the sparkle pressed in and shaking with it. At full strain ENTER appears and counts down, flashing
/// faster and faster; pressed, or when the count runs out, it lets go: the
/// orb, its sparkle and the word all fly outward and grow as they pass, as if bursting through the
/// screen, under a flash. The strain is the `.anticipate` haptic and the release is the `.welcome` boom.
struct OnboardingFinaleScene: View {
    let colour: Color
    /// Where the summary's orb was on screen: the orb sets off from here and travels to the centre.
    let from: CGRect
    /// When ENTER was pressed; nil until then.
    let burstAt: Date?
    let onEnter: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var ready = false

    /// The orb's journey from where it sat on the summary to the centre, growing as it comes.
    private static let travel = 0.85
    /// The squeeze, in seconds from the start; ENTER appears as it reaches full strain.
    private static let squeeze = 0.9...3.3
    static let readyAt = 3.3
    private static let orbRadius: CGFloat = 132
    /// Once ENTER is up it counts down like a bomb: flashing slowly at first, then faster and faster,
    /// and when the count runs out it goes off by itself. Flashes per second grow exponentially from
    /// `countdownFrom` to `countdownTo` across `countdownLength`.
    static let countdownStart = readyAt + 0.4
    static let countdownLength = 3.0
    private static let countdownFrom = 0.8
    private static let countdownTo = 9.0
    private static var countdownGrowth: Double { log(countdownTo / countdownFrom) / countdownLength }

    /// Flashes completed `τ` seconds into the countdown.
    private static func countdownPhase(_ tau: Double) -> Double {
        countdownFrom / countdownGrowth * (exp(countdownGrowth * tau) - 1)
    }

    /// How far the squeeze presses the orb in, at full strain.
    private static let pressedIn = 0.16

    var body: some View {
        GeometryReader { geo in
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion && burstAt == nil)) { timeline in
                let t = reduceMotion ? 4 : timeline.date.timeIntervalSince(start)
                let b = burstAt.map { timeline.date.timeIntervalSince($0) }
                let burst = b.map { Self.easeOut(min($0 / 1.0, 1)) } ?? 0
                let fade = b.map { 1 - Self.smooth(($0 - 0.3) / 0.6) } ?? 1
                let strain = Self.smooth((t - Self.squeeze.lowerBound) / (Self.squeeze.upperBound - Self.squeeze.lowerBound))
                // The shake of hands at their limit: fine and irregular, growing with the strain, and
                // gone the moment they let go.
                // The countdown: ENTER flashing on and off, faster and faster, each flash a sharp rise,
                // a held glow and a quick fall to dim.
                let tau = t - Self.countdownStart
                let blink = reduceMotion || b != nil || tau < 0
                    ? 1 : 0.25 + 0.75 * Self.smooth(cos(2 * .pi * Self.countdownPhase(tau)) * 2.5 + 0.5)
                let shake = reduceMotion || b != nil ? CGPoint.zero : Self.tremble(t, amount: 0.2 + 1.4 * pow(strain, 1.5))
                ZStack {
                    Canvas { context, size in
                        draw(&context, size: size, centre: CGPoint(x: centre.x + shake.x, y: centre.y + shake.y),
                             t: t, strain: strain, burst: burst, fade: fade, b: b)
                    }
                    Text("ENTER")
                        .font(NoopHTMLFont.outfit(30, weight: .regular))
                        .tracking(6)
                        .foregroundStyle(NoopHTMLColor.blue)
                        .shadow(color: NoopHTMLColor.blue.opacity(0.9), radius: 14)
                        .opacity(Self.smooth((t - Self.readyAt) / 0.4) * blink * (1 - burst))
                        .scaleEffect((0.92 + 0.08 * Self.smooth((t - Self.readyAt) / 0.4)) * (1 + 4 * burst))
                        .blur(radius: 12 * burst)
                        .position(x: centre.x + shake.x, y: centre.y + shake.y)
                }
            }
            Button(action: onEnter) {
                Color.clear
                    .frame(width: 260, height: 130)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(centre)
            .disabled(!ready || burstAt != nil)
            .accessibilityLabel("Enter Noop Aura")
            .onAppear {
                start = Date()
                NoopHaptics.play(.anticipate)
            }
            .task {
                try? await Task.sleep(for: .seconds(reduceMotion ? 0 : Self.readyAt))
                ready = true
                try? await Task.sleep(for: .seconds(Self.countdownStart - Self.readyAt))
                // Not pressed by the end of the count: it goes off on its own.
                try? await Task.sleep(for: .seconds(Self.countdownLength))
                onEnter()
            }
        }
        .ignoresSafeArea()
    }

    private func draw(_ context: inout GraphicsContext, size: CGSize, centre: CGPoint, t: Double, strain: Double, burst: Double, fade: Double, b: Double?) {
        // The edges closing in as the pressure builds.
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .radialGradient(
            Gradient(colors: [.clear, .black.opacity(0.6 * strain * fade)]),
            center: centre, startRadius: 170, endRadius: max(size.width, size.height) * 0.7))

        // The journey down: from the summary's orb to the centre, growing on the way.
        let journey = reduceMotion ? 1 : Self.easeInOut(min(t / Self.travel, 1))
        let startRadius = from.width / 2 * 0.82
        let centre = CGPoint(x: from.midX + (centre.x - from.midX) * journey, y: from.midY + (centre.y - from.midY) * journey)
        // Pressed in against resistance, with a fine flutter in the size as the grip wavers.
        let squeezed = 1 - Self.pressedIn * strain + 0.003 * strain * sin(t * 47) * (b == nil ? 1 : 0)
        let radius = (startRadius + (Self.orbRadius - startRadius) * journey) * squeezed * (1 + 9 * pow(burst, 2))
        let outward = 1 + 7 * pow(burst, 1.5)
        guard radius > 1 else { return }

        // The orb's own drift: embers born on the rim and wandering out round it, pressed in with the
        // orb and flung out on release. Drawn by the same routine as every Aura orb in the app.
        let scale = radius * 2 / NoopAuraOrbModel.referenceSide
        let spin = NoopAuraOrbModel.naturalSpin(t)
        let reach = radius * 0.9
        context.drawLayer { layer in
            layer.opacity = fade
            let side = (radius + reach) * 2
            layer.translateBy(x: centre.x - side / 2, y: centre.y - side / 2)
            NoopAuraDrift.draw(in: &layer, size: CGSize(width: side, height: side), t: t, spin: spin, scale: scale,
                               rim: radius, reach: reach, tint: Color(hex: 0x70C0FF))
        }

        // The orb: halo brightening with the pressure, the wash, the dark well and a lit rim.
        let halo = radius * 1.55
        context.fill(Path(ellipseIn: CGRect(x: centre.x - halo, y: centre.y - halo, width: halo * 2, height: halo * 2)),
                     with: .radialGradient(Gradient(colors: [colour.opacity((0.3 + 0.45 * strain) * fade), .clear]),
                                           center: centre, startRadius: radius * 0.8, endRadius: halo))
        let disc = Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
        context.fill(disc, with: .linearGradient(Gradient(colors: [Color(hex: 0x69D3DD).opacity(fade), Color(hex: 0x70C0FF).opacity(fade)]),
                                                 startPoint: CGPoint(x: centre.x, y: centre.y - radius), endPoint: CGPoint(x: centre.x, y: centre.y + radius)))
        context.fill(disc, with: .radialGradient(Gradient(stops: [
            .init(color: .black.opacity(fade), location: 0), .init(color: .black.opacity(fade), location: 0.62), .init(color: .clear, location: 1)
        ]), center: centre, startRadius: 0, endRadius: radius))
        context.stroke(disc, with: .color(.white.opacity((0.4 + 0.4 * strain) * fade)), lineWidth: 1.2 + 0.8 * strain)

        // The orb's own sparkle inside the well, by the same routine as every Aura orb, kept off a soft
        // oval round ENTER so the word always has clear space.
        context.drawLayer { layer in
            layer.opacity = fade
            layer.translateBy(x: centre.x - radius, y: centre.y - radius)
            layer.clip(to: Path(ellipseIn: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)))
            let middle = CGPoint(x: radius, y: radius)
            NoopAuraEmbers.draw(in: &layer, size: CGSize(width: radius * 2, height: radius * 2), t: t, spin: spin,
                                scale: scale, tint: Color(hex: 0x70C0FF)) { _ in middle }
            layer.blendMode = .destinationOut
            layer.translateBy(x: radius, y: radius)
            layer.scaleBy(x: 1, y: 0.42)
            layer.fill(Path(ellipseIn: CGRect(x: -100, y: -100, width: 200, height: 200)),
                       with: .radialGradient(Gradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.75), .init(color: .clear, location: 1)]),
                                             center: .zero, startRadius: 0, endRadius: 100))
        }

        // The flash as it lets go.
        if let b, b < 0.5, !reduceMotion {
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xBFE6FF).opacity(0.38 * (1 - b / 0.5))))
        }
    }

    /// Two quick, unrelated wobbles summed, so the shake never settles into a rhythm.
    private static func tremble(_ t: Double, amount: Double) -> CGPoint {
        CGPoint(x: amount * (0.6 * sin(t * 53) + 0.4 * sin(t * 31 + 1.3)),
                y: amount * (0.6 * sin(t * 47 + 0.7) + 0.4 * sin(t * 37 + 2.1)))
    }

    private static func smooth(_ t: Double) -> Double {
        let u = min(max(t, 0), 1)
        return u * u * (3 - 2 * u)
    }

    private static func easeInOut(_ t: Double) -> Double {
        let u = min(max(t, 0), 1)
        return u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2
    }

    private static func easeOut(_ t: Double) -> Double {
        let u = min(max(t, 0), 1)
        return 1 - pow(1 - u, 3)
    }
}

/// A summary row's mark, arriving as a drop: it falls into the empty circle, a ripple spreads, and the
/// mark pops in. Green with a tick for what was set, a quiet grey dash for what was left for later.
struct OnboardingDropMark: View {
    let landed: Bool
    let done: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Fall {
        var drop = 0.0
        var ripple = 0.0
    }

    private var tint: Color { done ? NoopHTMLColor.green : NoopHTMLColor.muted }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(NoopHTMLColor.muted, style: StrokeStyle(lineWidth: 1.2, dash: [2, 2.2]))
                .opacity(landed ? 0 : 1)
            Image(systemName: done ? "checkmark.circle.fill" : "minus.circle.fill")
                .font(.system(size: 17))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, tint)
                .scaleEffect(landed ? 1 : 0.4)
                .opacity(landed ? 1 : 0)
                .animation(.spring(duration: 0.4, bounce: 0.45).delay(reduceMotion ? 0 : 0.15), value: landed)
        }
        .frame(width: 18, height: 18)
        .keyframeAnimator(initialValue: Fall(), trigger: landed) { mark, fall in
            mark.overlay {
                if landed && !reduceMotion {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(tint)
                        .offset(y: -28 * (1 - fall.drop))
                        .opacity(fall.drop < 1 ? 1 : 0)
                    Circle()
                        .stroke(tint, lineWidth: 1.2)
                        .scaleEffect(1 + 1.1 * fall.ripple)
                        .opacity(fall.ripple > 0 ? 0.8 * (1 - fall.ripple) : 0)
                }
            }
        } keyframes: { _ in
            KeyframeTrack(\.drop) {
                CubicKeyframe(1, duration: 0.16)
            }
            KeyframeTrack(\.ripple) {
                LinearKeyframe(0, duration: 0.15)
                CubicKeyframe(1, duration: 0.45)
            }
        }
    }
}

// MARK: - Sky

/// Which sky the sleep page shows: the answer drawn as the hours the wearer is awake under.
enum OnboardingSky: Equatable {
    case undecided, night, day, rotating

    /// 0 is deep night, 1 full day. Undecided sits at dusk.
    var daylight: Double {
        switch self {
        case .night: 0
        case .day: 1
        case .undecided: 0.3
        case .rotating: 0.5
        }
    }

    /// The glow the page wears behind it.
    var glow: Color {
        switch self {
        case .night: NoopHTMLColor.night
        case .day: NoopHTMLColor.warm
        case .undecided, .rotating: NoopHTMLColor.blueLight
        }
    }
}

/// A small landscape whose sky turns with the answer: a dozing moon among the stars for a night sleeper;
/// for a day sleeper the sun rises, pulls an eye mask on, rolls onto its side and tucks a cloud over
/// itself like a blanket; for rotating
/// shifts a sky that keeps turning between the two. The change is a spring on the light itself, so the
/// sun rises and the moon sets rather than one picture swapping for another.
struct OnboardingSkyScene: View {
    let sky: OnboardingSky
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// When the day sleeper was chosen: the sun's bedtime runs on this clock, one step after another.
    @State private var bedtimeStart: Date?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            OnboardingSkyCanvas(
                daylight: sky.daylight,
                cycling: sky == .rotating && !reduceMotion ? 1 : 0,
                sleepy: sky == .day ? 1 : 0,
                bedtime: reduceMotion ? OnboardingSkyCanvas.bedtimeLength : timeline.date.timeIntervalSince(bedtimeStart ?? timeline.date),
                time: reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            )
        }
        .animation(OnboardingMotion.sky, value: sky)
        .onChange(of: sky, initial: true) { _, now in
            bedtimeStart = now == .day ? Date() : nil
        }
        .clipShape(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 0.5))
        .accessibilityHidden(true)
    }
}

private struct OnboardingSkyCanvas: View, Animatable {
    var daylight: Double
    var cycling: Double
    /// 1 for a day sleeper. Animated, so leaving the answer fades the bedtime out with the sky.
    var sleepy: Double
    /// Seconds since the day sleeper was chosen.
    let bedtime: Double
    let time: Double

    var animatableData: AnimatablePair<Double, AnimatablePair<Double, Double>> {
        get { AnimatablePair(daylight, AnimatablePair(cycling, sleepy)) }
        set { daylight = newValue.first; cycling = newValue.second.first; sleepy = newValue.second.second }
    }

    /// The sun's bedtime, in seconds from the answer: it rises, pulls the mask down, rolls onto its
    /// side, then draws a cloud up over itself like a blanket and starts to snore.
    private static let maskOn = 0.9...1.5
    private static let rollOver = 1.7...2.4
    private static let tuckIn = 2.5...3.4
    static let bedtimeLength = 3.6

    private static let stars: [(x: Double, y: Double, r: Double)] = (0..<34).map { i in
        let a = Double(i)
        return (x: (sin(a * 12.9898) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude,
                y: (sin(a * 78.233) * 12345.678).truncatingRemainder(dividingBy: 1).magnitude * 0.62,
                r: 0.6 + (sin(a * 3.7) + 1) * 0.55)
    }

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            // Rotating shifts: the light keeps turning, a full day every nine seconds.
            let turning = 0.5 + 0.5 * sin(time * 0.7)
            let p = daylight * (1 - cycling) + turning * cycling

            let sky = Path(CGRect(origin: .zero, size: size))
            context.fill(sky, with: .linearGradient(
                Gradient(colors: [onboardingBlend(0x070B22, 0x3D86D6, p), onboardingBlend(0x2B2458, 0xF5C88E, p)]),
                startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))

            // Stars, each on its own slow twinkle.
            let starAlpha = pow(max(0, 1 - p * 1.6), 1.4)
            if starAlpha > 0.01 {
                for (i, s) in Self.stars.enumerated() {
                    let twinkle = 0.55 + 0.45 * sin(time * (1.3 + Double(i % 5) * 0.37) + Double(i))
                    let rect = CGRect(x: s.x * w - s.r, y: s.y * h - s.r, width: s.r * 2, height: s.r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(starAlpha * twinkle)))
                }
            }

            // Cloud, drifting across in daylight, behind the sun so it never covers the face.
            let cloudAlpha = max(0, (p - 0.35) / 0.65) * 0.9
            if cloudAlpha > 0.01 {
                for (i, c) in [(0.1, 0.22, 1.0), (0.55, 0.38, 0.75), (0.85, 0.16, 0.6)].enumerated() {
                    let span = w + 120
                    let x = (c.0 * span + time * (7 + Double(i) * 3)).truncatingRemainder(dividingBy: span) - 60
                    context.fill(Self.cloud(at: CGPoint(x: x, y: c.1 * h), scale: c.2), with: .color(.white.opacity(cloudAlpha)))
                }
            }

            // Sun: rises from behind the hills as the day comes.
            let rolled = sleepy * Self.stage(bedtime, Self.rollOver)
            let sun = CGPoint(x: w * 0.72, y: h * (1.12 - 0.78 * p) + 4 * rolled)
            let sunGlow = CGRect(x: sun.x - 70, y: sun.y - 70, width: 140, height: 140)
            context.fill(Path(ellipseIn: sunGlow), with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFE1A0).opacity(0.55 * p * (1 - 0.35 * rolled)), .clear]),
                center: sun, startRadius: 0, endRadius: 70))
            drawSleepingSun(&context, at: sun, rolled: rolled)

            // Moon: a crescent that sinks as the sun comes up, dozing with one closed eye.
            let moon = CGPoint(x: w * 0.27, y: h * (0.26 + 0.95 * p))
            context.drawLayer { layer in
                layer.fill(Path(ellipseIn: CGRect(x: moon.x - 16, y: moon.y - 16, width: 32, height: 32)),
                           with: .color(Color(hex: 0xEEF1FF)))
                layer.blendMode = .destinationOut
                layer.fill(Path(ellipseIn: CGRect(x: moon.x - 8, y: moon.y - 21, width: 32, height: 32)),
                           with: .color(.black))
            }
            context.fill(Path(ellipseIn: CGRect(x: moon.x - 40, y: moon.y - 40, width: 80, height: 80)),
                         with: .radialGradient(Gradient(colors: [Color(hex: 0xB9C3FF).opacity(0.22 * (1 - p)), .clear]),
                                               center: moon, startRadius: 0, endRadius: 40))
            let moonDozing = max(0, 1 - p / 0.4)
            if moonDozing > 0.01 {
                var eye = Path()
                eye.move(to: CGPoint(x: moon.x - 12, y: moon.y + 2))
                eye.addQuadCurve(to: CGPoint(x: moon.x - 6, y: moon.y + 4), control: CGPoint(x: moon.x - 9, y: moon.y + 6.5))
                context.stroke(eye, with: .color(Color(hex: 0x5A62A8).opacity(moonDozing)), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                drawSnore(&context, from: CGPoint(x: moon.x + 8, y: moon.y - 10), rate: 0.26, amount: moonDozing)
            }

            // Two ranges of hills, lit by the hour.
            var back = Path()
            back.move(to: CGPoint(x: 0, y: h * 0.78))
            back.addQuadCurve(to: CGPoint(x: w * 0.55, y: h * 0.7), control: CGPoint(x: w * 0.25, y: h * 0.58))
            back.addQuadCurve(to: CGPoint(x: w, y: h * 0.74), control: CGPoint(x: w * 0.8, y: h * 0.8))
            back.addLine(to: CGPoint(x: w, y: h))
            back.addLine(to: CGPoint(x: 0, y: h))
            back.closeSubpath()
            context.fill(back, with: .color(onboardingBlend(0x151B3A, 0x6E9F73, p)))
            var front = Path()
            front.move(to: CGPoint(x: 0, y: h * 0.9))
            front.addQuadCurve(to: CGPoint(x: w * 0.6, y: h * 0.86), control: CGPoint(x: w * 0.32, y: h * 0.74))
            front.addQuadCurve(to: CGPoint(x: w, y: h * 0.82), control: CGPoint(x: w * 0.84, y: h * 0.94))
            front.addLine(to: CGPoint(x: w, y: h))
            front.addLine(to: CGPoint(x: 0, y: h))
            front.closeSubpath()
            context.fill(front, with: .color(onboardingBlend(0x0B0F24, 0x4B8352, p)))

            // A lit window in the valley: the house is awake when its wearer is.
            let window = CGRect(x: w * 0.6, y: h * 0.8, width: 7, height: 6)
            context.fill(Path(roundedRect: window, cornerRadius: 1.5), with: .color(Color(hex: 0xFFD27A).opacity(0.25 + 0.6 * (1 - p))))
        }
    }

    /// 0 before a stage of the bedtime, 1 after it, eased between.
    private static func stage(_ t: Double, _ span: ClosedRange<Double>) -> Double {
        let u = min(max((t - span.lowerBound) / (span.upperBound - span.lowerBound), 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// Three puffs as one path, filled once: puffs filled separately showed their overlaps as seams.
    private static func cloud(at origin: CGPoint, scale: Double) -> Path {
        var cloud = Path()
        for (dx, dy, r) in [(0.0, 0.0, 16.0), (16, -6, 20), (34, 0, 15)] {
            let rr = r * scale
            cloud.addEllipse(in: CGRect(x: origin.x + dx * scale - rr, y: origin.y + dy * scale - rr, width: rr * 2, height: rr * 1.7))
        }
        return cloud
    }

    /// The sun and its bedtime: the mask slides down over its eyes, it rolls onto its side, and a cloud
    /// is pulled up over it like a blanket. The face and mask turn with the sun; the
    /// snore always rises straight up.
    private func drawSleepingSun(_ context: inout GraphicsContext, at sun: CGPoint, rolled: Double) {
        let masked = sleepy * Self.stage(bedtime, Self.maskOn)
        let tucked = sleepy * Self.stage(bedtime, Self.tuckIn)

        var body = context
        body.translateBy(x: sun.x, y: sun.y)
        body.rotate(by: .radians(-0.55 * rolled))
        body.translateBy(x: -sun.x, y: -sun.y)
        body.fill(Path(ellipseIn: CGRect(x: sun.x - 24, y: sun.y - 24, width: 48, height: 48)), with: .color(Color(hex: 0xFFD978)))

        if masked > 0.01 {
            let maskY = sun.y - 5 - (1 - masked) * 26
            // Strap round the back, peeking out at both sides.
            var strap = Path()
            strap.move(to: CGPoint(x: sun.x - 24, y: maskY - 1))
            strap.addLine(to: CGPoint(x: sun.x + 24, y: maskY - 1))
            body.stroke(strap, with: .color(Color(hex: 0x3B3F78).opacity(masked)), lineWidth: 2.5)
            // One padded mask over both eyes, dipping at the nose, with a stitched edge: fabric, not
            // sunglasses (two lenses read as shades at this size).
            let left = sun.x - 19, right = sun.x + 19, top = maskY - 8, bottom = maskY + 7
            var mask = Path()
            mask.move(to: CGPoint(x: left, y: maskY))
            mask.addCurve(to: CGPoint(x: sun.x, y: top), control1: CGPoint(x: left, y: top), control2: CGPoint(x: sun.x - 9, y: top))
            mask.addCurve(to: CGPoint(x: right, y: maskY), control1: CGPoint(x: sun.x + 9, y: top), control2: CGPoint(x: right, y: top))
            mask.addCurve(to: CGPoint(x: sun.x, y: bottom - 3), control1: CGPoint(x: right, y: bottom + 3), control2: CGPoint(x: sun.x + 7, y: bottom))
            mask.addCurve(to: CGPoint(x: left, y: maskY), control1: CGPoint(x: sun.x - 7, y: bottom), control2: CGPoint(x: left, y: bottom + 3))
            mask.closeSubpath()
            body.fill(mask, with: .color(Color(hex: 0x5B60B0).opacity(masked)))
            body.stroke(mask, with: .color(.white.opacity(0.55 * masked)), style: StrokeStyle(lineWidth: 0.7, dash: [1.6, 1.6]))
            // Rosy cheeks and a contented little smile.
            let face = masked * masked
            for dx in [-11.0, 11.0] {
                body.fill(Path(ellipseIn: CGRect(x: sun.x + dx - 3.5, y: sun.y + 6, width: 7, height: 4)),
                          with: .color(Color(hex: 0xFF9A7A).opacity(0.75 * face)))
            }
            var smile = Path()
            smile.move(to: CGPoint(x: sun.x - 4, y: sun.y + 11))
            smile.addQuadCurve(to: CGPoint(x: sun.x + 4, y: sun.y + 11), control: CGPoint(x: sun.x, y: sun.y + 14.5))
            body.stroke(smile, with: .color(Color(hex: 0xB86A2E).opacity(face)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }

        // The blanket: a cloud pulled up from below and laid over the body. It is drawn in the sun's own
        // turned frame and clipped to a circle just wider than the sun, so it follows the round of it
        // like cloth over a shoulder; it overshoots a touch as it is tugged up, settles under the smile,
        // and then rises and falls with the sun's breathing.
        if tucked > 0.01 {
            let tug = 2.5 * sin(tucked * .pi)
            let breath = sin(time * 1.6) * 1.3 * tucked
            let edge = sun.y + 32 - 16 * tucked - tug + breath
            body.drawLayer { cloth in
                cloth.clip(to: Path(ellipseIn: CGRect(x: sun.x - 28, y: sun.y - 28, width: 56, height: 56)))
                var blanket = Path(CGRect(x: sun.x - 30, y: edge, width: 60, height: 40))
                for i in -3...3 {
                    let bump = 5.5 + (i % 2 == 0 ? 1 : 0)
                    blanket.addEllipse(in: CGRect(x: sun.x + Double(i) * 8.5 - bump, y: edge - bump, width: bump * 2, height: bump * 2))
                }
                cloth.fill(blanket, with: .color(.white.opacity(0.97 * tucked)))
                // A soft fold under the puffs, so it reads as cloth with weight.
                var fold = Path()
                fold.move(to: CGPoint(x: sun.x - 26, y: edge + 7))
                fold.addQuadCurve(to: CGPoint(x: sun.x + 26, y: edge + 7), control: CGPoint(x: sun.x, y: edge + 11))
                cloth.stroke(fold, with: .color(Color(hex: 0xC9D2E6).opacity(0.8 * tucked)), lineWidth: 1.2)
            }
        }
        drawSnore(&context, from: CGPoint(x: sun.x + 22, y: sun.y - 18), rate: 0.32, amount: tucked)
    }

    /// Z's drifting up and away from a sleeper, each fading as it rises.
    private func drawSnore(_ context: inout GraphicsContext, from origin: CGPoint, rate: Double, amount: Double) {
        guard amount > 0.01 else { return }
        for i in 0..<3 {
            let u = (time * rate + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let z = Text("z")
                .font(NoopHTMLFont.outfit(10 + u * 8, weight: .semibold))
                .foregroundStyle(Color.white.opacity(sin(u * .pi) * amount))
            context.draw(z, at: CGPoint(x: origin.x + u * 22 + sin(u * 6) * 3, y: origin.y - u * 34))
        }
    }
}

/// A strap seen from above: the band, and the sensor pod on it. Lit, the pod glows its tint.
struct OnboardingStrapGlyph: View {
    var lit: Bool
    var tint: Color

    var body: some View {
        ZStack {
            Capsule()
                .fill(LinearGradient(colors: [Color(hex: 0x23292A), Color(hex: 0x151918)], startPoint: .top, endPoint: .bottom))
                .frame(width: 236, height: 44)
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x2F3736), Color(hex: 0x1A1F1E)], startPoint: .top, endPoint: .bottom))
                .frame(width: 92, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(lit ? tint.opacity(0.7) : Color.white.opacity(0.14), lineWidth: lit ? 1.5 : 0.75)
                )
                .shadow(color: lit ? tint.opacity(0.55) : .clear, radius: 18)
            Circle()
                .fill(lit ? tint : Color.white.opacity(0.25))
                .frame(width: 7, height: 7)
                .shadow(color: lit ? tint : .clear, radius: 6)
        }
    }
}

// MARK: - Strap

/// Pairing as a scene. Waiting, the strap sits dim. Looking, two slow ripples leave the pod. Connected, the pod lights green, a pulse trace runs along the band, and the live
/// heart rate beats in over it at its own pace.
struct OnboardingStrapScene: View {
    let looking: Bool
    let connected: Bool
    let heartRate: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if looking && !connected && !reduceMotion {
                // Two slow ripples from the pod: the strap being called, nothing more.
                ForEach(0..<2, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(NoopHTMLColor.blueLight.opacity(0.35), lineWidth: 1)
                        .frame(width: 92, height: 70)
                        .phaseAnimator([false, true]) { ring, out in
                            ring.scaleEffect(out ? 2.2 : 1).opacity(out ? 0 : 1)
                        } animation: { out in
                            out ? .easeOut(duration: 2.4).delay(Double(i) * 1.2) : .linear(duration: 0)
                        }
                }
                .transition(.opacity)
            }
            OnboardingStrapGlyph(lit: connected || looking, tint: connected ? NoopHTMLColor.green : NoopHTMLColor.blueLight)
                .opacity(connected || looking ? 1 : 0.7)
            if connected {
                OnboardingPulseTrace(bpm: heartRate ?? 60)
                    .frame(width: 236, height: 44)
                    .mask(Capsule().frame(width: 236, height: 44))
                    .transition(.opacity)
                if let heartRate {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(NoopHTMLColor.red)
                            .symbolEffect(.pulse, isActive: !reduceMotion)
                        Text("\(heartRate)")
                            .font(NoopHTMLFont.outfit(26, weight: .light))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(heartRate)))
                        Text("bpm")
                            .font(NoopHTMLFont.sans(11.5, weight: .medium))
                            .foregroundStyle(NoopHTMLColor.copy)
                    }
                    .animation(OnboardingMotion.figure, value: heartRate)
                    .offset(y: -66)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .animation(.bouncy(duration: 0.55, extraBounce: 0.1), value: connected)
        .animation(OnboardingMotion.reveal, value: looking)
        .accessibilityHidden(true)
    }
}

/// A heartbeat trace scrolling along the band, one beat per real beat.
private struct OnboardingPulseTrace: View {
    let bpm: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let beat = 60 / Double(max(bpm, 30))
                let pxPerSecond = 70.0
                let shift = (t * pxPerSecond).truncatingRemainder(dividingBy: beat * pxPerSecond)
                var trace = Path()
                let mid = size.height / 2
                var x = -beat * pxPerSecond + shift
                trace.move(to: CGPoint(x: x, y: mid))
                while x < size.width {
                    let span = beat * pxPerSecond
                    trace.addLine(to: CGPoint(x: x + span * 0.42, y: mid))
                    trace.addLine(to: CGPoint(x: x + span * 0.47, y: mid - 4))
                    trace.addLine(to: CGPoint(x: x + span * 0.52, y: mid + 3))
                    trace.addLine(to: CGPoint(x: x + span * 0.56, y: mid - 15))
                    trace.addLine(to: CGPoint(x: x + span * 0.6, y: mid + 9))
                    trace.addLine(to: CGPoint(x: x + span * 0.64, y: mid))
                    x += span
                    trace.addLine(to: CGPoint(x: x, y: mid))
                }
                context.stroke(trace, with: .color(NoopHTMLColor.green.opacity(0.85)), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Link

/// The picture every permission page shares: what is asking on one side, where it goes on the other,
/// and one calm pulse of light at a time easing along a fine arc between them. Waiting, the pulse gives
/// up halfway; open, it arrives, the far side glows for a moment and the tile takes a tick; closed, the
/// line greys and nothing moves. One composition for Bluetooth and Apple Health, so the pages read as one family. Static
/// with Reduce Motion.
enum OnboardingLinkState: Equatable { case waiting, open, closed }

struct OnboardingLink<Source: View, Destination: View>: View {
    let state: OnboardingLinkState
    let sourceLabel: String
    let destinationLabel: String
    /// A fainter pulse runs back along a lower arc once open (Health: weigh-ins come back).
    var returns = false
    @ViewBuilder let source: () -> Source
    @ViewBuilder let destination: () -> Destination
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let from = CGPoint(x: w * 0.2, y: h * 0.42)
            let to = CGPoint(x: w * 0.8, y: h * 0.42)
            ZStack {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion || state == .closed)) { timeline in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    Canvas { context, _ in
                        let up = CGPoint(x: w / 2, y: from.y - h * 0.42)
                        let down = CGPoint(x: w / 2, y: from.y + h * 0.36)
                        var outward = Path()
                        outward.move(to: from)
                        outward.addQuadCurve(to: to, control: up)
                        var back = Path()
                        back.move(to: to)
                        back.addQuadCurve(to: from, control: down)
                        // The way the data goes: a fine line, quiet until something travels along it.
                        let line = state == .closed ? Color.white.opacity(0.08) : Color.white.opacity(0.14)
                        context.stroke(outward, with: .color(line), lineWidth: 1)
                        if returns && state == .open { context.stroke(back, with: .color(.white.opacity(0.08)), lineWidth: 1) }
                        guard !reduceMotion, state != .closed else { return }
                        let open = state == .open
                        // One pulse at a time, eased along the arc. Waiting, it gives up halfway; open, it
                        // arrives and the far side lights for a moment.
                        let period = open ? 2.0 : 2.6
                        let phase = (t / period).truncatingRemainder(dividingBy: 1)
                        let travel = Self.ease(min(phase / 0.7, 1))
                        let reach = open ? 1.0 : 0.55
                        let head = travel * reach
                        let fade = open ? 1.0 : 1 - Self.ease(max(0, (travel - 0.6) / 0.4))
                        let tint = open ? NoopHTMLColor.green : NoopHTMLColor.blueLight
                        Self.drawPulse(&context, along: outward, head: head, fade: fade * (phase < 0.7 ? 1 : 0), tint: tint)
                        if open {
                            let arrival = phase < 0.7 ? 0 : sin((phase - 0.7) / 0.3 * .pi)
                            context.fill(Path(ellipseIn: CGRect(x: to.x - 52, y: to.y - 43, width: 104, height: 104)),
                                         with: .radialGradient(Gradient(colors: [tint.opacity(0.28 * arrival), .clear]),
                                                               center: CGPoint(x: to.x, y: to.y + 9), startRadius: 20, endRadius: 52))
                            if returns {
                                // Weigh-ins coming back: a fainter pulse the other way, between the others.
                                let backPhase = (phase + 0.5).truncatingRemainder(dividingBy: 1)
                                Self.drawPulse(&context, along: back, head: Self.ease(min(backPhase / 0.7, 1)),
                                               fade: 0.55 * (backPhase < 0.7 ? 1 : 0), tint: .white)
                            }
                        }
                    }
                }
                tile(sourceLabel, content: source)
                    .position(x: from.x, y: from.y + 9)
                tile(destinationLabel, content: destination)
                    .overlay(alignment: .topTrailing) { badge.offset(x: 7, y: -7) }
                    .position(x: to.x, y: to.y + 9)
            }
            .saturation(state == .closed ? 0 : 1)
            .opacity(state == .closed ? 0.7 : 1)
            .animation(.bouncy(duration: 0.5, extraBounce: 0.12), value: state)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var badge: some View {
        if state != .waiting {
            Image(systemName: state == .open ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white, state == .open ? NoopHTMLColor.green : NoopHTMLColor.muted)
                .background(Circle().fill(NoopHTMLColor.canvas).padding(1))
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
    }

    private func tile<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 7) {
            content()
                .frame(width: 62, height: 62)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 0.5))
            Text(label)
                .font(NoopHTMLFont.sans(11.5, weight: .medium))
                .foregroundStyle(NoopHTMLColor.copy)
        }
    }

    private static func ease(_ t: Double) -> Double {
        let u = min(max(t, 0), 1)
        return u < 0.5 ? 4 * u * u * u : 1 - pow(-2 * u + 2, 3) / 2
    }

    /// A short streak of light ending at `head` (0…1 along the path): a soft glow under a bright core,
    /// both tapering out behind.
    private static func drawPulse(_ context: inout GraphicsContext, along path: Path, head: Double, fade: Double, tint: Color) {
        guard fade > 0.01, head > 0.01 else { return }
        let tail = max(0, head - 0.16)
        let streak = path.trimmedPath(from: tail, to: head)
        context.drawLayer { glow in
            glow.addFilter(.blur(radius: 5))
            glow.stroke(streak, with: .color(tint.opacity(0.55 * fade)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        }
        let start = path.trimmedPath(from: 0, to: max(tail, 0.001)).currentPoint ?? .zero
        let end = streak.currentPoint ?? .zero
        context.stroke(streak, with: .linearGradient(Gradient(colors: [tint.opacity(0), tint.opacity(0.95 * fade)]),
                                                     startPoint: start, endPoint: end),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
    }
}

/// The dark tile the link scenes draw Noop's own things on.
struct OnboardingDarkTile<Icon: View>: View {
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        LinearGradient(colors: [Color(hex: 0x123A3A), Color(hex: 0x0B1514)], startPoint: .top, endPoint: .bottom)
            .overlay(icon())
    }
}

// MARK: - Notices

/// What a notice from Noop looks like on the Lock Screen: a stack of them, the front one lifting away
/// every few seconds to show the next, as Notification Centre does.
struct OnboardingNoticeStack: View {
    struct Notice {
        let symbol: String
        let tint: Color
        let title: String
        let body: String
    }

    let notices: [Notice]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2.6)) { timeline in
            let front = reduceMotion ? 0 : Int(timeline.date.timeIntervalSinceReferenceDate / 2.6) % notices.count
            ZStack {
                ForEach(notices.indices, id: \.self) { i in
                    let depth = (i - front + notices.count) % notices.count
                    card(notices[i])
                        .scaleEffect(1 - CGFloat(min(depth, 2)) * 0.06, anchor: .bottom)
                        .offset(y: CGFloat(min(depth, 2)) * 11)
                        .opacity(depth > 2 ? 0 : 1 - Double(depth) * 0.3)
                        .zIndex(Double(notices.count - depth))
                }
            }
            .animation(.spring(duration: 0.6, bounce: 0.18), value: front)
        }
        .padding(.bottom, 22)
        .accessibilityHidden(true)
    }

    private func card(_ notice: Notice) -> some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [Color(hex: 0x123A3A), Color(hex: 0x0B1514)], startPoint: .top, endPoint: .bottom))
                .frame(width: 38, height: 38)
                .overlay(Image(systemName: notice.symbol).font(.system(size: 16, weight: .semibold)).foregroundStyle(notice.tint))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(notice.title).font(NoopHTMLFont.sans(13.5, weight: .semibold))
                    Spacer(minLength: 6)
                    Text("now").font(NoopHTMLFont.sans(11.5)).foregroundStyle(NoopHTMLColor.faint)
                }
                Text(notice.body)
                    .font(NoopHTMLFont.sans(12.5))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                    .lineLimit(2)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: 0x1D2221), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }
}

// MARK: - The question iOS asks

/// A faithful preview of the system alert that follows, in iOS's own words, so the question arrives
/// already explained. Both answers are drawn the same: this page does not lean on either. The type is the
/// system's on purpose, because it is the system's alert being shown.
struct OnboardingSystemAlertPreview: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Text("iOS asks next, in its own words")
                .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(NoopHTMLColor.faint)
            VStack(spacing: 14) {
                VStack(spacing: 5) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(message)
                        .font(.system(size: 12.5))
                        .foregroundStyle(NoopHTMLColor.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .multilineTextAlignment(.center)
                HStack(spacing: 8) {
                    answer("Don't Allow")
                    answer("Allow")
                }
            }
            .padding(16)
            .frame(maxWidth: 300)
            .background(Color(hex: 0x262B2A), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            Text("Either answer is fine. You can change it any time in Settings.")
                .font(NoopHTMLFont.sans(12))
                .foregroundStyle(NoopHTMLColor.faint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("iOS will ask next: \(title). \(message). Either answer is fine; you can change it in Settings.")
    }

    private func answer(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(Color.white.opacity(0.09), in: Capsule())
    }
}

/// The sheet Apple Health shows next, in miniature: its title, the purpose Noop gives, and one switch
/// per kind of data, all off until the wearer turns them on. Drawn plain, without any switch lit, for
/// the same reason the alert preview leans on neither answer.
struct OnboardingHealthSheetPreview: View {
    let message: String
    let kinds: [String]

    var body: some View {
        VStack(spacing: 10) {
            Text("Apple Health asks next, on its own sheet")
                .font(NoopHTMLFont.sans(11.5, weight: .semibold))
                .tracking(0.6)
                .textCase(.uppercase)
                .foregroundStyle(NoopHTMLColor.faint)
            VStack(alignment: .leading, spacing: 12) {
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 34, height: 4)
                    .frame(maxWidth: .infinity)
                Text("Health Access")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(NoopHTMLColor.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Turn On All")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: 0x4C9BFF))
                VStack(spacing: 0) {
                    ForEach(kinds, id: \.self) { kind in
                        HStack {
                            Text(kind).font(.system(size: 13))
                            Spacer()
                            Capsule()
                                .fill(Color.white.opacity(0.16))
                                .frame(width: 34, height: 20)
                                .overlay(alignment: .leading) {
                                    Circle().fill(Color.white).frame(width: 16, height: 16).padding(2)
                                }
                        }
                        .padding(.vertical, 7)
                        if kind != kinds.last {
                            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 0.5)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(16)
            .frame(maxWidth: 300)
            .background(Color(hex: 0x262B2A), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 0.5))
            Text("Turn on what you want. You can change it any time in the Health app.")
                .font(NoopHTMLFont.sans(12))
                .foregroundStyle(NoopHTMLColor.faint)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Apple Health will ask next, on a sheet listing each kind of data with its own switch. Turn on what you want; you can change it later in the Health app.")
    }
}
