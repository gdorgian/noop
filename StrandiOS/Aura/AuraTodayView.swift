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
    private let onOpenSignal: (AuraTodayReading.Signal) -> Void
    /// Opens the coach. The card below has always carried Svea's name and today's call; until now it was
    /// a read-only paragraph, and the only way to actually reach the coach was the More sheet — two taps
    /// away from the sentence that names it.
    private let onOpenCoach: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The one gate every never-settling animation in the app consults — system Reduce Motion, Low Power
    /// Mode, or the in-app quiet-motion preference.
    @ObservedObject private var motion = NoopMotionState.shared
    private var poseStill: Bool { motion.poseStill(reduceMotion) }

    init(
        state: AuraBodyState,
        reading: AuraTodayReading,
        onNavigate: @escaping (AuraScreen) -> Void,
        onOpenSignal: @escaping (AuraTodayReading.Signal) -> Void,
        onOpenCoach: @escaping () -> Void = {}
    ) {
        self.state = state
        self.reading = reading
        self.onNavigate = onNavigate
        self.onOpenSignal = onOpenSignal
        self.onOpenCoach = onOpenCoach
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
            Button { onNavigate(.charge) } label: {
                ZStack {
                    AuraOrb(state: state, poseStill: poseStill, available: reading.chargeAvailable)
                    AuraLivePulseOverlay()
                }
                .frame(height: 272)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("Opens your Charge detail"))
            Text(reading.verdict)
                .font(.system(size: 34, weight: .light, design: .rounded))
                .foregroundStyle(AuraPalette.textPrimary)
            Text(reading.coaching)
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
                           unit: reading.restUnit,
                           fraction: reading.restFraction, tint: AuraPalette.rest) {
                onNavigate(.rest)
            }
            AuraPillarCard(title: String(localized: "Charge"), value: reading.chargeValue,
                           unit: reading.chargeUnit,
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
                Text(String(localized: "Recovery-matched target")).auraOverline()
            }
            .padding(.bottom, 12)

            Text(reading.session)
                .font(.system(size: 19, weight: .medium))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            Text(reading.sessionRationale)
                .font(.system(size: 13.5))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .auraCard(surface: AuraCardSurface.coaching(accent: AuraPalette.accent))
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpenCoach)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Opens the coach"))
    }

    // MARK: Signals

    private var signalsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(reading.signals.enumerated()), id: \.element.id) { index, signal in
                if signal.id == "hr" {
                    AuraLiveHeartRateSignalRow(
                        signal: signal,
                        showsDivider: index < reading.signals.count - 1,
                        action: { onOpenSignal(signal) }
                    )
                } else {
                    AuraSignalRow(
                        name: signal.name,
                        value: signal.value,
                        unit: signal.unit,
                        systemImage: signal.systemImage,
                        tint: signal.tint,
                        series: signal.series,
                        showsDivider: index < reading.signals.count - 1,
                        action: { onOpenSignal(signal) }
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .auraCard()
    }
}

/// The handoff mock generated this number from its breathing timer. Production uses AppModel's
/// spike-filtered, rolling live heart rate and explicitly renders an unavailable state when the strap is
/// offline. The four-second phase words are breathing guidance only; they never alter the BPM value.
private struct AuraLivePulseOverlay: View {
    @EnvironmentObject private var model: AppModel

    private var bpm: Int? {
        model.live.connected ? (model.bpm ?? model.live.heartRate) : nil
    }

    private var statusLabel: String {
        guard model.live.connected else { return String(localized: "STRAP OFFLINE") }
        return bpm == nil ? String(localized: "WAITING FOR BPM") : String(localized: "LIVE BPM")
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let phase = breathingPhase(at: context.date)
            VStack(spacing: 5) {
                Text(verbatim: bpm.map(String.init) ?? "—")
                    .font(.system(size: 50, weight: .ultraLight, design: .rounded).monospacedDigit())
                    .foregroundStyle(AuraPalette.textPrimary)
                    .contentTransition(.numericText())
                Text(statusLabel)
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.1)
                    .foregroundStyle(AuraPalette.textQuiet)
                Text(phase)
                    .font(.system(size: 11.5, weight: .semibold))
                    .tracking(1.0)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textSecondary)
                    .padding(.top, 2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel(phase: phase))
        }
    }

    private func breathingPhase(at date: Date) -> String {
        let second = Int(date.timeIntervalSinceReferenceDate) % 16
        switch second / 4 {
        case 0: return String(localized: "In")
        case 1: return String(localized: "Hold")
        case 2: return String(localized: "Out")
        default: return String(localized: "Hold")
        }
    }

    private func accessibilityLabel(phase: String) -> Text {
        if let bpm {
            return Text("Live heart rate \(bpm) beats per minute. Breathing prompt: \(phase)")
        }
        if model.live.connected {
            return Text("Strap connected. Waiting for a heart-rate sample. Breathing prompt: \(phase)")
        }
        return Text("Live heart rate unavailable. Strap offline. Breathing prompt: \(phase)")
    }
}

/// Isolates the one-second strap publisher to the single row that needs it. Today, its orb and every
/// other chart stay still while this leaf updates from the live WHOOP stream.
private struct AuraLiveHeartRateSignalRow: View {
    @EnvironmentObject private var model: AppModel
    let signal: AuraTodayReading.Signal
    let showsDivider: Bool
    let action: () -> Void

    private var value: String {
        guard model.live.connected, let bpm = model.bpm ?? model.live.heartRate else { return signal.value }
        return String(bpm)
    }

    private var name: String {
        model.live.connected && (model.bpm ?? model.live.heartRate) != nil
            ? String(localized: "Live heart rate")
            : signal.name
    }

    var body: some View {
        AuraSignalRow(
            name: name,
            value: value,
            unit: signal.unit,
            systemImage: signal.systemImage,
            tint: signal.tint,
            series: signal.series,
            showsDivider: showsDivider,
            action: action
        )
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
    let restUnit: String
    let restFraction: Double
    let chargeValue: String
    let chargeUnit: String
    let chargeAvailable: Bool
    let chargeFraction: Double
    let effortValue: String
    let effortUnit: String
    let effortFraction: Double
    let signals: [Signal]
    let banner: String
    let verdict: String
    let coaching: String
    let session: String
    let sessionRationale: String

    struct Signal: Identifiable {
        let id: String
        let name: String
        let value: String
        let unit: String
        let systemImage: String
        let tint: Color
        let series: [Double]
        let labels: [String]
    }

    #if DEBUG
    /// The values from the Claude Design prototype, verbatim. Not live data.
    static let prototype = AuraTodayReading(
        greeting: String(localized: "Good morning"),
        headline: "",
        profileName: "Gabriel D.",
        initial: "G",
        restValue: "7h 12m",
        restUnit: "",
        restFraction: 0.96,
        chargeValue: "56",
        chargeUnit: "%",
        chargeAvailable: true,
        chargeFraction: 0.78,
        effortValue: "6.2",
        effortUnit: "/12",
        effortFraction: 0.52,
        signals: [
            Signal(id: "hr", name: String(localized: "Heart rate"), value: "58", unit: "bpm",
                   systemImage: "heart", tint: AuraPalette.accent,
                   series: [62, 60, 59, 61, 58, 57, 58, 58], labels: []),
            Signal(id: "hrv", name: String(localized: "Variability"), value: "56", unit: "ms",
                   systemImage: "waveform.path.ecg", tint: AuraPalette.accent,
                   series: [44, 48, 46, 51, 49, 54, 53, 56], labels: []),
            Signal(id: "resp", name: String(localized: "Breathing"), value: "14.2", unit: "/min",
                   systemImage: "lungs", tint: AuraPalette.rest,
                   series: [14, 14.4, 14.1, 13.9, 14.3, 14.2, 14, 14.2], labels: []),
            Signal(id: "temp", name: String(localized: "Skin temp"), value: "−0.2", unit: "°C",
                   systemImage: "thermometer.medium", tint: AuraPalette.effort,
                   series: [0.3, 0.1, -0.1, 0, -0.3, -0.2, -0.1, -0.2], labels: []),
        ],
        banner: String(localized: "Your variability is 17% above your own 30-day normal — the strongest it’s been this month."),
        verdict: String(localized: "Well restored"),
        coaching: String(localized: "Your body has room today. Good day to ask something of it."),
        session: String(localized: "Aim for your recovery-matched Effort range"),
        sessionRationale: String(localized: "The target follows today’s Charge. The activity is your choice.")
    )
    #endif
}
#endif
