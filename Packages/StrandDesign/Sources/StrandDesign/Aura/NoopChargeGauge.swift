#if !os(watchOS)
import SwiftUI

// MARK: - 9. Strap battery chip

/// The physical strap's battery, not Charge. `nil` is an honest disconnected/unavailable state.
public struct NoopStrapBatteryChip: View {
    private let level: Double?
    private let charging: Bool
    private let action: () -> Void

    public init(level: Double?, charging: Bool = false, action: @escaping () -> Void) {
        self.level = level.flatMap(Self.validatedLevel)
        self.charging = charging
        self.action = action
    }

    private var hue: Color? {
        guard let level else { return nil }
        if level <= 0.10 { return NoopSpecTokens.hot }
        if level <= 0.20 { return NoopSpecTokens.attention }
        return nil
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                batteryGlyph
                Text(label)
                    .noopText(.chipValue)
                    .foregroundStyle(hue ?? (level == nil ? NoopSpecTokens.textFaint : NoopSpecTokens.textBody))
            }
            .padding(.horizontal, 11)
            // Keep the HTML's chip geometry when the honest unavailable label is an em dash.
            .frame(minWidth: 78, minHeight: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(hue.map { $0.opacity(0.12) } ?? NoopSpecTokens.controlFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(
                        hue.map { $0.opacity(0.34) } ?? NoopSpecTokens.controlBorderStrong,
                        lineWidth: NoopSpecTokens.hairlineWidth
                    )
            )
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Strap battery")
        .accessibilityValue(accessibilityValue)
    }

    private var batteryGlyph: some View {
        HStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 3.4, style: .continuous)
                .strokeBorder(
                    hue ?? NoopSpecTokens.textPrimary.opacity(level == nil ? 0.22 : 0.40),
                    lineWidth: NoopSpecTokens.glyphStrokeWidth
                )
                .frame(width: 21, height: 11)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                        .fill(hue ?? (level == nil ? NoopSpecTokens.textFaint : NoopSpecTokens.auraLight))
                        .frame(width: 18.6 * (level ?? 0), height: 8.6)
                        .padding(.leading, 1.2)
                }

            RoundedRectangle(cornerRadius: 0.8, style: .continuous)
            .fill(hue ?? NoopSpecTokens.textPrimary.opacity(level == nil ? 0.22 : 0.40))
            .frame(width: 1.6, height: 4.4)
        }
        .overlay {
            if charging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(NoopSpecTokens.onAura)
            }
        }
        .accessibilityHidden(true)
    }

    private var label: String {
        guard let level else { return "—" }
        return "\(Int((level * 100).rounded()))%"
    }

    private var accessibilityValue: String {
        guard let level else { return "Unavailable" }
        let percentage = Int((level * 100).rounded())
        return charging ? "\(percentage) percent, charging" : "\(percentage) percent"
    }

    private static func validatedLevel(_ value: Double) -> Double? {
        guard value.isFinite else { return nil }
        return min(max(value, 0), 1)
    }
}

// MARK: - 11. Orb

/// The breathing visual around the REAL live strap pulse. Breathing phase is clock-derived; BPM is never
/// simulated. If no live pulse is available the composition renders an em dash.
public struct NoopSpecOrb: View {
    private let pulse: Int?
    private let action: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = NoopMotionState.shared
    @State private var cycleStart = Date()

    private static let orbSize: CGFloat = 176
    private static let glowSize: CGFloat = 268
    private static let ringSize: CGFloat = 224

    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    public init(pulse: Int?, action: (() -> Void)? = nil) {
        self.pulse = pulse.flatMap { (20...250).contains($0) ? $0 : nil }
        self.action = action
    }

    public var body: some View {
        Group {
            if let action {
                Button(action: action) { composition }
                    .buttonStyle(.plain)
            } else {
                composition
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live heart rate and breathing guide")
        .accessibilityValue(accessibilityValue)
    }

    private var composition: some View {
        ZStack {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: poseStill)) { context in
                let phase = cyclePhase(at: context.date)
                ZStack {
                    glow(
                        scale: poseStill ? NoopSpecMotion.breathHeldScale : glowScale(at: phase),
                        opacity: poseStill ? 0.56 : glowOpacity(at: phase)
                    )
                    haloRing(
                        scale: poseStill ? NoopSpecMotion.breathHeldScale : ringScale(at: phase),
                        opacity: poseStill ? 0.34 : ringOpacity(at: phase)
                    )
                    orbBody(
                        scale: poseStill ? NoopSpecMotion.breathHeldScale : orbScale(at: phase),
                        sheenAngle: poseStill ? 0 : sheenAngle(at: context.date),
                        phaseWord: poseStill ? nil : phaseWord(at: phase)
                    )
                }
            }

            if poseStill {
                // The visual pose is held, but the four-second breathing instruction remains useful.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    pulseWords(phaseWord: phaseWord(at: cyclePhase(at: context.date)))
                }
            }
        }
        .frame(width: Self.glowSize, height: Self.glowSize)
        .contentShape(Circle())
    }

    private func glow(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    stops: [
                        .init(color: NoopSpecTokens.aura.opacity(0.40), location: 0),
                        .init(color: NoopSpecTokens.aura.opacity(0), location: 0.68),
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: Self.glowSize / 2
                )
            )
            .frame(width: Self.glowSize, height: Self.glowSize)
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: 6)
    }

    private func haloRing(scale: CGFloat, opacity: Double) -> some View {
        Circle()
            .strokeBorder(NoopSpecTokens.auraPale.opacity(0.50), lineWidth: NoopSpecTokens.glyphStrokeWidth)
            .frame(width: Self.ringSize, height: Self.ringSize)
            .scaleEffect(scale)
            .opacity(opacity)
    }

    private func orbBody(scale: CGFloat, sheenAngle: Double, phaseWord: String?) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: Color(hex: "#9FE2FB"), location: 0),
                            .init(color: Color(hex: "#2FB2F0"), location: 0.55),
                            .init(color: Color(hex: "#0A5F92"), location: 1),
                        ],
                        center: UnitPoint(x: 0.38, y: 0.32),
                        startRadius: 0,
                        endRadius: Self.orbSize * 0.92
                    )
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color(hex: "#042A42").opacity(0.50)],
                        startPoint: UnitPoint(x: 0.5, y: 0.30),
                        endPoint: .bottom
                    )
                )
                .blur(radius: 8)
                .mask(Circle())

            Circle()
                .fill(
                    AngularGradient(
                        stops: [
                            .init(color: .white.opacity(0), location: 0),
                            .init(color: .white.opacity(0.40), location: 0.29),
                            .init(color: .white.opacity(0), location: 0.58),
                            .init(color: .white.opacity(0), location: 1),
                        ],
                        center: .center,
                        angle: .degrees(200)
                    )
                )
                .blendMode(.overlay)
                .rotationEffect(.degrees(sheenAngle))

            if let phaseWord { pulseWords(phaseWord: phaseWord) }
        }
        .frame(width: Self.orbSize, height: Self.orbSize)
        .clipShape(Circle())
        .shadow(color: Color(hex: "#0B6FA8").opacity(0.55), radius: 26, y: 18)
        .scaleEffect(scale)
    }

    private func pulseWords(phaseWord: String) -> some View {
        VStack(spacing: 5) {
            Text(pulse.map(String.init) ?? "—")
                .noopText(.heroNumeral)
                .foregroundStyle(Color(hex: "#F6FDFF"))
                .shadow(color: Color(hex: "#041E30").opacity(0.55), radius: 8, y: 2)
            Text(phaseWord)
                .noopText(.breathWord)
                .foregroundStyle(Color(hex: "#F6FDFF").opacity(0.82))
        }
    }

    private func cyclePhase(at date: Date) -> Double {
        let elapsed = max(0, date.timeIntervalSince(cycleStart))
            .truncatingRemainder(dividingBy: NoopSpecMotion.breathDuration)
        return elapsed / NoopSpecMotion.breathDuration
    }

    private func phaseWord(at phase: Double) -> String {
        switch phase {
        case 0..<0.25: return String(localized: "In", bundle: .module)
        case 0.25..<0.50: return String(localized: "Hold", bundle: .module)
        case 0.50..<0.75: return String(localized: "Out", bundle: .module)
        default: return String(localized: "Hold", bundle: .module)
        }
    }

    private func boxValue(at phase: Double, low: CGFloat, high: CGFloat) -> CGFloat {
        switch phase {
        case 0..<0.25:
            return low + (high - low) * CGFloat(phase / 0.25)
        case 0.25..<0.50:
            return high
        case 0.50..<0.75:
            return high - (high - low) * CGFloat((phase - 0.50) / 0.25)
        default:
            return low
        }
    }

    private func orbScale(at phase: Double) -> CGFloat { boxValue(at: phase, low: 0.82, high: 1.16) }
    private func glowScale(at phase: Double) -> CGFloat { boxValue(at: phase, low: 0.86, high: 1.24) }
    private func ringScale(at phase: Double) -> CGFloat { boxValue(at: phase, low: 0.80, high: 1.32) }
    private func glowOpacity(at phase: Double) -> Double { Double(boxValue(at: phase, low: 0.32, high: 0.80)) }
    private func ringOpacity(at phase: Double) -> Double { Double(boxValue(at: phase, low: 0.55, high: 0.12)) }

    private func sheenAngle(at date: Date) -> Double {
        date.timeIntervalSince(cycleStart)
            .truncatingRemainder(dividingBy: NoopSpecMotion.sheenDuration)
            / NoopSpecMotion.sheenDuration * 360
    }

    private var accessibilityValue: String {
        let heart = pulse.map { "\($0) beats per minute" } ?? "Heart rate unavailable"
        return "\(heart). Breathing guide active."
    }
}

// MARK: - 12. Charge gauge

/// Presentation for a real 0–100 stored Charge value and its real waking value. This view does not
/// calculate daytime depletion.
public struct NoopChargeGauge: View {
    private let charge: Double
    private let wake: Double
    private let animateArrival: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double
    @State private var hasAppeared = false

    private static let count = 41
    private static let span: Double = 250
    private static let start: Double = -125
    private static let tickRadius: CGFloat = 142
    private static let markerRadius: CGFloat = 131

    public init(charge: Double, wake: Double, animateArrival: Bool = false) {
        let resolvedCharge = Self.validatedPercent(charge)
        let resolvedWake = max(resolvedCharge, Self.validatedPercent(wake))
        self.charge = resolvedCharge
        self.wake = resolvedWake
        self.animateArrival = animateArrival
        self._shown = State(initialValue: animateArrival ? resolvedWake : resolvedCharge)
    }

    public var body: some View {
        let lit = index(for: shown)
        let ghost = index(for: wake)
        let color = NoopSpecTokens.chargeColor(shown)

        ZStack {
            ForEach(0..<Self.count, id: \.self) { tickIndex in
                tick(tickIndex, lit: lit, ghost: ghost, color: color)
            }
            marker(at: lit)
        }
        .frame(width: 306, height: 306)
        .frame(height: 318)
        .onAppear {
            guard !hasAppeared else { return }
            hasAppeared = true
            guard animateArrival else {
                shown = charge
                return
            }
            if reduceMotion {
                withAnimation(NoopSpecMotion.chargeDrainReduced) { shown = charge }
            } else {
                shown = wake
                DispatchQueue.main.async {
                    withAnimation(NoopSpecMotion.chargeDrain) { shown = charge }
                }
            }
        }
        .onChange(of: charge) { newValue in
            guard hasAppeared else { return }
            withAnimation(NoopSpecMotion.gaugeTick) {
                shown = Self.validatedPercent(newValue)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Charge")
        .accessibilityValue("\(Int(charge.rounded())) of \(Int(wake.rounded())) at wake")
    }

    private func tick(_ index: Int, lit: Int, ghost: Int, color: Color) -> some View {
        let isLit = index <= lit
        let isGhost = !isLit && index <= ghost
        let opacity = lit > 0 ? 0.32 + 0.68 * Double(index) / Double(max(lit, 1)) : 0.32

        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                isLit ? color.opacity(min(opacity, 1))
                    : isGhost ? NoopSpecTokens.auraPale.opacity(0.28)
                    : Color.white.opacity(0.13)
            )
            .frame(width: 2, height: index.isMultiple(of: 5) ? 15 : 9)
            .offset(y: -Self.tickRadius)
            .rotationEffect(.degrees(angle(for: index)))
    }

    private func marker(at index: Int) -> some View {
        NoopSpecTriangle()
            .fill(NoopSpecTokens.textPrimary)
            .frame(width: 12, height: 9)
            .shadow(color: .black.opacity(0.50), radius: 3)
            .offset(y: -Self.markerRadius)
            .rotationEffect(.degrees(angle(for: index)))
    }

    private func index(for value: Double) -> Int {
        min(max(Int((value / 100 * 40).rounded()), 0), 40)
    }

    private func angle(for index: Int) -> Double {
        Self.start + Self.span * Double(index) / Double(Self.count - 1)
    }

    private static func validatedPercent(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 100)
    }
}

public struct NoopSpecTriangle: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.closeSubpath()
        }
    }
}

// MARK: - 13. Charge bar

public struct NoopChargeBar: View {
    private let charge: Double
    private let wake: Double
    private let height: CGFloat

    public init(charge: Double, wake: Double, height: CGFloat = 12) {
        let chargeFraction = Self.validatedFraction(charge / 100)
        self.charge = chargeFraction
        self.wake = max(chargeFraction, Self.validatedFraction(wake / 100))
        self.height = max(height, 1)
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
                Capsule(style: .continuous)
                    .fill(NoopSpecTokens.auraPale.opacity(0.16))
                    .frame(width: geometry.size.width * wake)
                Capsule(style: .continuous)
                    .fill(NoopSpecTokens.chargeColor(charge * 100))
                    .frame(width: geometry.size.width * charge)
                    .animation(NoopSpecMotion.chargeBar, value: charge)
            }
        }
        .frame(height: height)
    }

    private static func validatedFraction(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}
#endif
