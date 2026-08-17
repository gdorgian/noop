#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Today
//
// The brief this answers is one sentence: the incumbent is too complicated. So this screen carries NO
// score. The body gets one colour (the orb), one sentence (the verdict and its instruction) and one thing
// to do (Svea's call). Every number on it is a doorway, not a read-out — the three pillars and the four
// signals exist to be tapped, and the detail lives on the screen the user chose to open.
//
// The greeting, headline and the two header controls are NOT here: they are shared by all seven screens
// and belong to `AuraShell`.

struct AuraTodayView: View {
    private let state: AuraBodyState
    private let reading: AuraTodayReading
    private let onNavigate: (AuraScreen) -> Void

    /// Whether Svea's proposed session is still open, and what the user did with it.
    @State private var decision: SessionDecision = .open

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The one gate every never-settling animation in the app consults — system Reduce Motion, Low Power
    /// Mode, or the in-app quiet-motion preference.
    @ObservedObject private var motion = NoopMotionState.shared
    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    init(
        state: AuraBodyState = .restored,
        reading: AuraTodayReading = .prototype,
        onNavigate: @escaping (AuraScreen) -> Void
    ) {
        self.state = state
        self.reading = reading
        self.onNavigate = onNavigate
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            orbSection
            pillars
            coachCard
            signalsCard
            AuraInfoBanner(text: reading.banner, accent: AuraPalette.accent)
        }
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
            // `AuraPillarCard` takes plain strings (its values are dynamic), so the titles are localized
            // here rather than relying on a LocalizedStringKey inside the component.
            AuraPillarCard(title: String(localized: "Rest"), value: reading.restValue,
                           fraction: reading.restFraction, tint: AuraPalette.rest) {
                onNavigate(.rest)
            }
            AuraPillarCard(title: String(localized: "Charge"), value: reading.chargeValue, unit: "ms",
                           fraction: reading.chargeFraction, tint: AuraPalette.accent) {
                onNavigate(.charge)
            }
            AuraPillarCard(title: String(localized: "Effort"), value: reading.effortValue,
                           unit: reading.effortUnit,
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
                    .shadow(color: AuraPalette.accent.opacity(0.5), radius: 6)
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
        .auraCard(surface: AuraCardSurface.coaching(accent: AuraPalette.accent))
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
                        .fill(AuraPalette.accent))
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
                .foregroundStyle(AuraPalette.accent)
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
            .fill(AuraPalette.accent.opacity(0.14)))
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
                    tint: signal.tint,
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

// MARK: - Reading
//
// The prototype's fixed values, in one place. When this screen is wired to `Repository`, this is the only
// type that changes: build it from real metrics and the layout above is untouched.

struct AuraTodayReading {
    /// Shell chrome derived from the live profile and current time. The content view does not render
    /// these directly; `AuraShell` owns the shared header and battery/profile controls.
    let greeting: String
    let headline: String
    let profileName: String
    let initial: String

    let restValue: String
    let restFraction: Double
    let chargeValue: String
    let chargeFraction: Double
    let effortValue: String
    let effortUnit: String
    let effortFraction: Double
    let signals: [Signal]
    let banner: String

    struct Signal: Identifiable {
        let id: String
        let name: String
        let value: String
        let unit: String
        let systemImage: String
        let tint: Color
        let series: [Double]
    }

    /// The values from the Claude Design prototype, verbatim. Not live data.
    static let prototype = AuraTodayReading(
        greeting: String(localized: "Hi, Gabriel"),
        headline: String(localized: "Here’s your morning read"),
        profileName: "Gabriel D.",
        initial: "G",
        restValue: "7h 12m",
        restFraction: 0.96,
        chargeValue: "56",
        chargeFraction: 0.78,
        effortValue: "6.2",
        effortUnit: "/12",
        effortFraction: 0.52,
        signals: [
            Signal(id: "hr", name: String(localized: "Heart rate"), value: "58", unit: "bpm",
                   systemImage: "heart", tint: AuraPalette.accent,
                   series: [62, 60, 59, 61, 58, 57, 58, 58]),
            Signal(id: "hrv", name: String(localized: "Variability"), value: "56", unit: "ms",
                   systemImage: "waveform.path.ecg", tint: AuraPalette.accent,
                   series: [44, 48, 46, 51, 49, 54, 53, 56]),
            Signal(id: "resp", name: String(localized: "Breathing"), value: "14.2", unit: "/min",
                   systemImage: "lungs", tint: AuraPalette.rest,
                   series: [14, 14.4, 14.1, 13.9, 14.3, 14.2, 14, 14.2]),
            Signal(id: "temp", name: String(localized: "Skin temp"), value: "−0.2", unit: "°C",
                   systemImage: "thermometer.medium", tint: AuraPalette.effort,
                   series: [0.3, 0.1, -0.1, 0, -0.3, -0.2, -0.1, -0.2]),
        ],
        banner: String(localized: "Your variability is 17% above your own 30-day normal — the strongest it’s been this month.")
    )
}
#endif
