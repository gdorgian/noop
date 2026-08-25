#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Today
//
// Native recreation of Act 2 / Today from the supplied 402 × 874 handoff. The orb remains the hero and
// carries the real live strap pulse plus the four-part breathing prompt. The daytime-depleting Charge
// ledger is deliberately not guessed: until that model ships, its exact visual slot says Coming soon.
//
// The greeting, headline and the two header controls are NOT here: they are shared by all seven screens
// and belong to `AuraShell`.

struct AuraTodayView: View {
    private let state: AuraBodyState
    private let reading: AuraTodayReading
    private let onNavigate: (AuraScreen) -> Void
    private let onOpenSignal: (AuraTodayReading.Signal) -> Void
    private let onOpenVitals: () -> Void
    private let onOpenStress: () -> Void
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
        onOpenVitals: @escaping () -> Void,
        onOpenStress: @escaping () -> Void,
        onOpenCoach: @escaping () -> Void = {}
    ) {
        self.state = state
        self.reading = reading
        self.onNavigate = onNavigate
        self.onOpenSignal = onOpenSignal
        self.onOpenVitals = onOpenVitals
        self.onOpenStress = onOpenStress
        self.onOpenCoach = onOpenCoach
    }

    var body: some View {
        VStack(spacing: 10) {
            orbSection
            stateRead
            latestSleepCard
            coachCard
            daytimeChargeCard
            liveHeartCard
            vitalsCard
            stressCard
        }
    }

    // MARK: Orb

    private var orbSection: some View {
        Button { onNavigate(.charge) } label: {
            ZStack {
                AuraOrb(
                    state: state,
                    poseStill: poseStill,
                    available: reading.chargeAvailable,
                    fraction: reading.chargeFraction,
                    wakeFraction: reading.chargeFraction
                )
                AuraLivePulseOverlay()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 318)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(reading.verdict))
        .accessibilityHint(Text("Opens your Charge detail"))
    }

    private var stateRead: some View {
        Button { onNavigate(.charge) } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(reading.verdict)
                        .font(AuraFont.display(19, weight: .regular))
                        .tracking(-0.38)
                        .foregroundStyle(AuraPalette.textPrimary)
                    AuraInlineChevron(tint: AuraPalette.textFaint)
                }
                Text(reading.coaching)
                    .font(AuraFont.ui(13.5))
                    .foregroundStyle(AuraPalette.textTertiary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
            .padding(.bottom, 8)
        }
        .buttonStyle(.plain)
    }

    // MARK: Supporting reads

    private var latestSleepCard: some View {
        Button { onNavigate(.rest) } label: {
            HStack(spacing: 12) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AuraPalette.rest)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Latest scored sleep"))
                        .font(AuraFont.ui(13))
                        .foregroundStyle(AuraPalette.textSecondary)
                    Text(reading.banner)
                        .font(AuraFont.ui(11.5))
                        .foregroundStyle(AuraPalette.textQuiet)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                AuraInlineChevron(tint: AuraPalette.rest)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AuraPalette.rest.opacity(0.09))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(AuraPalette.rest.opacity(0.20), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var coachCard: some View {
        Button(action: onOpenCoach) {
            HStack(spacing: 13) {
                AuraSveaGlyph()
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(reading.chargeAvailable
                         ? String(localized: "Svea has read your latest score")
                         : String(localized: "Svea is waiting for your next night"))
                        .font(AuraFont.ui(14.5, weight: .semibold))
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(reading.sessionRationale)
                        .font(AuraFont.ui(12))
                        .foregroundStyle(AuraPalette.textSecondary.opacity(0.92))
                        .lineSpacing(3)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                AuraInlineChevron(tint: Color(hex: "#A9B4E0"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AuraPalette.rest.opacity(0.16), AuraPalette.rest.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(AuraPalette.rest.opacity(0.30), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var daytimeChargeCard: some View {
        Button { onNavigate(.charge) } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(localized: "Daytime Charge"))
                        .font(AuraFont.ui(10, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AuraPalette.textFaint)
                    Spacer()
                    Text(String(localized: "Coming soon"))
                        .font(AuraFont.ui(10.5, weight: .semibold))
                        .foregroundStyle(AuraPalette.accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AuraPalette.accent.opacity(0.12)))
                        .overlay(Capsule().strokeBorder(AuraPalette.accent.opacity(0.25), lineWidth: 0.5))
                }

                AuraPendingDayTrace()
                    .frame(height: 54)

                Text(String(localized: "A draining daytime battery will appear here after its model and missing-data rules are validated."))
                    .font(AuraFont.ui(12.5))
                    .foregroundStyle(AuraPalette.textTertiary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 13)
            .auraCard()
        }
        .buttonStyle(.plain)
    }

    private var liveHeartCard: some View {
        AuraLiveHeartCard(signal: reading.signals.first(where: { $0.id == "hr" })) {
            if let signal = reading.signals.first(where: { $0.id == "hr" }) { onOpenSignal(signal) }
        }
    }

    private var vitalsCard: some View {
        let overnight = reading.signals
        let measured = overnight.filter { $0.value != "—" }.count
        return AuraTodayLinkCard(
            symbol: "lungs.fill",
            title: String(localized: "Vitals"),
            subtitle: String(localized: "\(measured) of \(overnight.count) latest overnight signals available"),
            figure: measured == 0 ? String(localized: "waiting") : String(localized: "review"),
            tint: AuraPalette.accent
        ) {
            onOpenVitals()
        }
    }

    private var stressCard: some View {
        AuraTodayLinkCard(
            symbol: "waveform.path.ecg",
            title: String(localized: "Stress"),
            subtitle: String(localized: "Daily autonomic-load proxy from HRV and resting heart rate"),
            figure: reading.stressBand,
            tint: reading.stressAvailable ? AuraPalette.accent : AuraPalette.textQuiet
        ) {
            onOpenStress()
        }
    }
}

private struct AuraInlineChevron: View {
    let tint: Color

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }
}

private struct AuraSveaGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AuraPalette.rest.opacity(0.45), AuraPalette.rest.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 26
                    )
                )
                .frame(width: 44, height: 44)
                .blur(radius: 2)
            UnevenRoundedRectangle(
                topLeadingRadius: 16,
                bottomLeadingRadius: 13,
                bottomTrailingRadius: 17,
                topTrailingRadius: 12,
                style: .continuous
            )
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#DDE3F6"), AuraPalette.rest, Color(hex: "#4A56A8")],
                    center: UnitPoint(x: 0.44, y: 0.38),
                    startRadius: 0,
                    endRadius: 24
                )
            )
            .frame(width: 28, height: 28)
            .rotationEffect(.degrees(-8))
            .shadow(color: AuraPalette.rest.opacity(0.5), radius: 6)
        }
        .accessibilityHidden(true)
    }
}

private struct AuraPendingDayTrace: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let midY = geometry.size.height * 0.58
            ZStack(alignment: .leading) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: width, y: midY))
                }
                .stroke(AuraPalette.accent.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))

                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text(String(localized: "MODEL NOT ACTIVE"))
                        .font(AuraFont.ui(9.5, weight: .semibold))
                        .tracking(1.1)
                }
                .foregroundStyle(AuraPalette.textFaint)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(AuraPalette.canvas.opacity(0.9)))
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct AuraTodayLinkCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let figure: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(tint.opacity(0.10)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AuraFont.ui(14.5, weight: .semibold))
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(subtitle)
                        .font(AuraFont.ui(12))
                        .foregroundStyle(AuraPalette.textTertiary)
                        .lineLimit(2)
                }
                Spacer(minLength: 6)
                Text(figure)
                    .font(AuraFont.ui(11.5, weight: .semibold))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                AuraInlineChevron(tint: AuraPalette.textDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .auraCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
    }
}

private struct AuraLiveHeartCard: View {
    @EnvironmentObject private var model: AppModel
    let signal: AuraTodayReading.Signal?
    let action: () -> Void

    private var bpm: Int? {
        model.live.connected ? (model.bpm ?? model.live.heartRate) : nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    Circle()
                        .fill(AuraPalette.accent.opacity(0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AuraPalette.accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Heart"))
                        .font(AuraFont.ui(14.5, weight: .semibold))
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(model.live.connected
                         ? String(localized: "Live from your connected strap")
                         : String(localized: "Connect your strap for a live reading"))
                        .font(AuraFont.ui(12))
                        .foregroundStyle(AuraPalette.textTertiary)
                }
                Spacer(minLength: 6)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(verbatim: bpm.map(String.init) ?? signal?.value ?? "—")
                        .font(AuraFont.display(26, weight: .light))
                        .tracking(-0.65)
                        .monospacedDigit()
                        .foregroundStyle(AuraPalette.textPrimary)
                        .contentTransition(.numericText())
                    Text(verbatim: "bpm")
                        .font(AuraFont.ui(10.5))
                        .foregroundStyle(AuraPalette.textFaint)
                }
                AuraInlineChevron(tint: AuraPalette.textDim)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .auraCard(cornerRadius: 20)
        }
        .buttonStyle(.plain)
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
        return bpm == nil ? String(localized: "WAITING FOR BPM") : ""
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let phase = breathingPhase(at: context.date)
            VStack(spacing: 5) {
                Text(verbatim: bpm.map(String.init) ?? "—")
                    .font(AuraFont.display(52, weight: .thin))
                    .tracking(-1.56)
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: "#F6FDFF"))
                    .shadow(color: Color(hex: "#041E30").opacity(0.55), radius: 8, y: 2)
                    .contentTransition(.numericText())
                Text(statusLabel.isEmpty ? phase : statusLabel)
                    .font(AuraFont.ui(statusLabel.isEmpty ? 12.5 : 9.5, weight: .semibold))
                    .tracking(statusLabel.isEmpty ? 1.38 : 1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: "#F6FDFF").opacity(0.86))
                    .shadow(color: Color(hex: "#041E30").opacity(0.5), radius: 4, y: 1)
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
    let stressBand: String
    let stressAvailable: Bool
    let selectedDayLabel: String
    let selectedDayID: String?
    let currentDayID: String?
    let browsingPastDay: Bool
    let dayCells: [DayCell]
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

    struct DayCell: Identifiable {
        let id: String
        let weekday: String
        let number: String
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
        stressBand: String(localized: "medium"),
        stressAvailable: true,
        selectedDayLabel: String(localized: "Today"),
        selectedDayID: "2026-08-24",
        currentDayID: "2026-08-24",
        browsingPastDay: false,
        dayCells: [
            DayCell(id: "2026-08-18", weekday: "Tue", number: "18"),
            DayCell(id: "2026-08-19", weekday: "Wed", number: "19"),
            DayCell(id: "2026-08-20", weekday: "Thu", number: "20"),
            DayCell(id: "2026-08-21", weekday: "Fri", number: "21"),
            DayCell(id: "2026-08-22", weekday: "Sat", number: "22"),
            DayCell(id: "2026-08-23", weekday: "Sun", number: "23"),
            DayCell(id: "2026-08-24", weekday: "Mon", number: "24"),
        ],
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
