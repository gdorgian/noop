#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Today
//
// The Today screen in the Aura design language, replacing the liquid Today on iPhone.
//
// The brief this answers is one sentence: the incumbent is too complicated. So this screen carries NO
// score. The body gets one colour (the orb), one sentence (the verdict + its instruction) and one thing
// to do (Svea's call). Every number on the screen is a doorway, not a read-out — the three pillars and
// the four signals exist to be tapped, and the detail lives on the screen the user chose to open.
//
// SCOPE: this is the first of Aura's seven screens. Rest / Charge / Effort / Trends / Band / You are
// still the incumbent screens, so the pillars and signal rows route to their existing homes through
// `onNavigate` rather than to Aura screens that do not exist yet.
//
// DATA: every value here is the fixed set from the design prototype, held in `AuraTodayReading.prototype`
// so that wiring it to `Repository` later is a single, obvious substitution rather than a hunt through
// the layout. Nothing on this screen reads live data yet.

/// Where a tap on Aura Today wants to go. The screen names the intent; the shell decides how to serve it,
/// which is what keeps this view free of any knowledge of the tab bar.
enum AuraDestination {
    case rest
    case charge
    case effort
    case band
    case profile
}

struct AuraTodayView: View {
    /// Handles a navigation intent. Supplied by `RootTabView`.
    private let onNavigate: (AuraDestination) -> Void

    /// The body state driving colour, gauge position and voice together. Fixed until this screen is
    /// wired to real data; overriding it is how the screen is reviewed across all four states.
    private let state: AuraBodyState
    private let reading: AuraTodayReading

    /// Written out rather than synthesized: a struct with any `private` stored property gets a PRIVATE
    /// memberwise initializer, which the tab shell in another file could not call.
    init(
        state: AuraBodyState = .restored,
        reading: AuraTodayReading = .prototype,
        onNavigate: @escaping (AuraDestination) -> Void
    ) {
        self.state = state
        self.reading = reading
        self.onNavigate = onNavigate
    }

    /// Whether Svea's proposed session is still open, and what the user did with it.
    @State private var decision: SessionDecision = .open

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The one gate every never-settling animation in the app consults — system Reduce Motion, Low Power
    /// Mode, or the in-app quiet-motion preference.
    @ObservedObject private var motion = NoopMotionState.shared
    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    /// Bumped by the tab shell when the user re-taps the already-active Today tab while it is at its
    /// root (#197/#198). Every tab root is expected to honour it, so Aura does too.
    @Environment(\.scrollToTopSignal) private var scrollToTopSignal

    /// Target for that scroll-to-top.
    private static let topAnchorID = "auraToday.top"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: AuraPalette.cardGap) {
                    Color.clear.frame(height: 0).id(Self.topAnchorID)
                    header
                    orbSection
                    pillars
                    coachCard
                    signalsCard
                    AuraInfoBanner(text: reading.banner, accent: state.accent)
                    Color.clear.frame(height: NoopMetrics.tabBarClearance)
                }
                .padding(.horizontal, AuraPalette.screenPadding)
            }
            .background { sceneBackground }
            .scrollIndicators(.hidden)
            .onChangeCompat(of: scrollToTopSignal) { _ in
                withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo(Self.topAnchorID, anchor: .top) }
            }
        }
    }

    // MARK: Background

    /// The canvas plus a single ambient wash bled behind the header, tinted by the body state. It sits
    /// behind the scroll rather than inside it, so pulling the content never drags the atmosphere with it.
    private var sceneBackground: some View {
        AuraPalette.canvas
            .overlay(alignment: .top) {
                Ellipse()
                    .fill(
                        RadialGradient(
                            stops: [
                                .init(color: state.accent.opacity(state.ambientOpacity), location: 0),
                                .init(color: state.accent.opacity(0), location: 0.7),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 230
                        )
                    )
                    .frame(width: 460, height: 400)
                    .offset(y: -140)
                    .blur(radius: 18)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(reading.greeting)
                    .font(StrandFont.subhead)
                    .foregroundStyle(AuraPalette.textSecondary)
                Text(reading.headline)
                    .font(.system(size: 23, weight: .regular, design: .rounded))
                    .foregroundStyle(AuraPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                batteryButton
                profileButton
            }
            .padding(.top, 2)
        }
        .padding(.top, 12)
    }

    private var batteryButton: some View {
        Button { onNavigate(.band) } label: {
            VStack(spacing: 1) {
                BatteryGlyph(fraction: reading.bandBatteryFraction, tint: state.accent)
                // `verbatim` — a bare number needs no String Catalog entry.
                Text(verbatim: "\(reading.bandBatteryPercent)")
                    .font(.system(size: 8.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AuraPalette.textSecondary)
            }
            .frame(width: 38, height: 38)
            .background(Circle().fill(AuraPalette.controlFill))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Band battery \(reading.bandBatteryPercent) percent"))
    }

    private var profileButton: some View {
        Button { onNavigate(.profile) } label: {
            Text(reading.initial)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AuraPalette.textPrimary.opacity(0.85))
                .frame(width: 38, height: 38)
                .background(
                    Circle().fill(
                        LinearGradient(colors: [Color(hex: "#3A4340"), Color(hex: "#242B29")],
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Account"))
    }

    // MARK: Orb

    private var orbSection: some View {
        VStack(spacing: 8) {
            AuraOrb(state: state, poseStill: poseStill)
                .frame(height: 272)
            Text(state.label)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .foregroundStyle(AuraPalette.textPrimary)
            Text(state.coaching)
                .font(.system(size: 14.5))
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(AuraPalette.textSecondary)
                .frame(maxWidth: 290)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 10)
        // The orb is decorative and hidden from VoiceOver; this pair carries the whole read instead.
        .accessibilityElement(children: .combine)
    }

    // MARK: Pillars

    private var pillars: some View {
        HStack(spacing: 8) {
            // `AuraPillarCard` takes plain strings (its values are dynamic), so the titles are
            // localized here rather than relying on a LocalizedStringKey inside the component.
            AuraPillarCard(title: String(localized: "Rest"), value: reading.restValue,
                           fraction: reading.restFraction, tint: AuraPalette.rest) {
                onNavigate(.rest)
            }
            AuraPillarCard(title: String(localized: "Charge"), value: reading.chargeValue, unit: "ms",
                           fraction: reading.chargeFraction, tint: state.accent) {
                onNavigate(.charge)
            }
            AuraPillarCard(title: String(localized: "Effort"), value: reading.effortValue, unit: "/12",
                           fraction: reading.effortFraction, tint: AuraPalette.effort) {
                onNavigate(.effort)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Svea

    private var coachCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Circle()
                    .fill(
                        RadialGradient(colors: [Color(hex: "#8FDCFA"), Color(hex: "#0B6FA8")],
                                       center: UnitPoint(x: 0.34, y: 0.3), startRadius: 0, endRadius: 22)
                    )
                    .frame(width: 22, height: 22)
                    .shadow(color: state.accent.opacity(0.5), radius: 6)
                Text("Svea · today’s call").auraOverline()
            }
            .padding(.bottom, 12)

            Text(state.session)
                .font(.system(size: 19, weight: .medium))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            Text(state.sessionRationale)
                .font(.system(size: 13.5))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 16)

            if decision == .open {
                sessionChoices
            } else {
                settledSession
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .auraCard(surface: AuraCardSurface.coaching(accent: state.accent))
        .animation(NoopMotion.card, value: decision)
    }

    private var sessionChoices: some View {
        HStack(spacing: 8) {
            Button { settle(.accepted) } label: {
                Text("Accept")
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(AuraPalette.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(RoundedRectangle(cornerRadius: AuraPalette.controlRadius, style: .continuous)
                        .fill(state.accent))
            }
            .buttonStyle(.plain)

            secondaryChoice("Swap", decision: .swapped)
            secondaryChoice("Rest", decision: .resting)
        }
    }

    /// `LocalizedStringKey`, not `String`, so these literals are extracted into the String Catalog.
    private func secondaryChoice(_ title: LocalizedStringKey, decision target: SessionDecision) -> some View {
        Button { settle(target) } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AuraPalette.textPrimary)
                .padding(.horizontal, 17)
                .frame(height: 46)
                .background(RoundedRectangle(cornerRadius: AuraPalette.controlRadius, style: .continuous)
                    .fill(AuraPalette.controlFill))
        }
        .buttonStyle(.plain)
    }

    private var settledSession: some View {
        HStack(spacing: 6) {
            Text(decision.confirmation)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(state.accent)
            Spacer(minLength: 8)
            Button { settle(.open) } label: {
                Text("Change")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(AuraPalette.textPrimary)
                    .padding(.horizontal, 13)
                    .frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: AuraPalette.controlRadius, style: .continuous)
            .fill(state.accent.opacity(0.14)))
    }

    private func settle(_ target: SessionDecision) {
        withAnimation(NoopMotion.card) { decision = target }
    }

    // MARK: Signals

    private var signalsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(reading.signals.enumerated()), id: \.element.id) { index, signal in
                AuraSignalRow(
                    name: signal.name,
                    value: signal.value,
                    unit: signal.unit,
                    systemImage: signal.systemImage,
                    tint: signal.usesStateAccent ? state.accent : signal.tint,
                    series: signal.series,
                    showsDivider: index < reading.signals.count - 1
                ) {
                    onNavigate(.charge)
                }
            }
        }
        .padding(.horizontal, 16)
        .auraCard()
    }
}

// MARK: - Session decision

extension AuraTodayView {
    /// What the user did with Svea's proposed session. `open` means they have not answered yet.
    enum SessionDecision: Equatable {
        case open
        case accepted
        case swapped
        case resting

        /// The line shown in place of the buttons once answered.
        var confirmation: String {
            switch self {
            case .open:     return ""
            case .accepted: return String(localized: "Locked in for today")
            case .swapped:  return String(localized: "Swapped — Svea is picking another")
            case .resting:  return String(localized: "Rest day it is")
            }
        }
    }
}

// MARK: - Battery glyph

/// The band's charge, drawn small enough to sit inside a 38pt header disc where an SF Symbol's own
/// battery variants read as either empty or full and nothing between.
private struct BatteryGlyph: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .strokeBorder(tint, lineWidth: 1.2)
            .frame(width: 13, height: 7)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(tint)
                    .padding(1)
                    .frame(width: 13 * AuraGaugeMath.clampFraction(fraction))
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Reading
//
// The prototype's fixed values, in one place. When this screen is wired to `Repository`, this is the only
// type that changes: build it from real metrics and the layout above is untouched.

struct AuraTodayReading {
    let greeting: String
    let headline: String
    let initial: String
    let bandBatteryPercent: Int

    let restValue: String
    let restFraction: Double
    let chargeValue: String
    let chargeFraction: Double
    let effortValue: String
    let effortFraction: Double

    let signals: [Signal]
    let banner: String

    var bandBatteryFraction: Double { Double(bandBatteryPercent) / 100 }

    struct Signal: Identifiable {
        let id: String
        let name: String
        let value: String
        let unit: String
        let systemImage: String
        /// Signals that ARE the body state (heart rate, variability) take its accent, so they shift
        /// temperature with the orb. The rest keep their own fixed identity colour.
        let usesStateAccent: Bool
        let tint: Color
        let series: [Double]
    }

    /// The values from the Claude Design prototype, verbatim. Not live data.
    static let prototype = AuraTodayReading(
        greeting: String(localized: "Hi, Gabriel"),
        headline: String(localized: "Here’s your morning read"),
        initial: "G",
        bandBatteryPercent: 62,
        restValue: "7h 12m",
        restFraction: 0.96,
        chargeValue: "56",
        chargeFraction: 0.78,
        effortValue: "6.2",
        effortFraction: 0.52,
        signals: [
            Signal(id: "hr", name: String(localized: "Heart rate"), value: "58", unit: "bpm",
                   systemImage: "heart", usesStateAccent: true, tint: .clear,
                   series: [62, 60, 59, 61, 58, 57, 58, 58]),
            Signal(id: "hrv", name: String(localized: "Variability"), value: "56", unit: "ms",
                   systemImage: "waveform.path.ecg", usesStateAccent: true, tint: .clear,
                   series: [44, 48, 46, 51, 49, 54, 53, 56]),
            Signal(id: "resp", name: String(localized: "Breathing"), value: "14.2", unit: "/min",
                   systemImage: "lungs", usesStateAccent: false, tint: AuraPalette.rest,
                   series: [14, 14.4, 14.1, 13.9, 14.3, 14.2, 14, 14.2]),
            Signal(id: "temp", name: String(localized: "Skin temp"), value: "−0.2", unit: "°C",
                   systemImage: "thermometer.medium", usesStateAccent: false, tint: AuraPalette.effort,
                   series: [0.3, 0.1, -0.1, 0, -0.3, -0.2, -0.1, -0.2]),
        ],
        banner: String(localized: "Your variability is 17% above your own 30-day normal — the strongest it’s been this month.")
    )
}

#if DEBUG
#Preview("Aura Today") {
    AuraTodayView(onNavigate: { _ in })
}
#endif
#endif
