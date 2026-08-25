#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Charge
//
// The Act 2 ledger composition, with one deliberate production distinction: NOOP currently computes a
// morning recovery score, not a validated battery that drains through the day. The visual hierarchy is
// preserved while the unsupported spending ledger stays explicitly dormant.

struct AuraChargeView: View {
    private let reading: AuraChargeReading
    private let onOpenDaytimeCharge: () -> Void

    init(reading: AuraChargeReading, onOpenDaytimeCharge: @escaping () -> Void = {}) {
        self.reading = reading
        self.onOpenDaytimeCharge = onOpenDaytimeCharge
    }

    var body: some View {
        VStack(spacing: 16) {
            chargeHero
            whereItWent
            tonightCard
            Text(String(localized: "Morning Charge is scored from the latest valid night. It does not drain during the day in this build; the daytime ledger remains off until its model and missing-data rules are validated."))
                .font(AuraFont.ui(11.5))
                .lineSpacing(4)
                .foregroundStyle(AuraPalette.textDim)
                .padding(.horizontal, 2)
        }
    }

    private var chargeHero: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "Morning Charge"))
                        .font(AuraFont.ui(10, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AuraPalette.textLabel)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(reading.score)
                            .font(AuraFont.display(58, weight: .thin))
                            .tracking(-2.3)
                            .monospacedDigit()
                            .foregroundStyle(reading.scoreAvailable ? AuraPalette.accent : AuraPalette.textQuiet)
                        Text(reading.scoreAvailable ? String(localized: "of 100") : String(localized: "not scored"))
                            .font(AuraFont.ui(13))
                            .foregroundStyle(AuraPalette.textQuiet)
                    }
                }
                Spacer(minLength: 12)
                Text(reading.scoreBand)
                    .font(AuraFont.ui(11.5, weight: .semibold))
                    .foregroundStyle(AuraPalette.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AuraPalette.accent.opacity(0.12)))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(AuraPalette.accent.opacity(0.20))
                        .frame(width: geometry.size.width * reading.scoreFraction)
                    Capsule()
                        .fill(AuraPalette.accent)
                        .frame(width: geometry.size.width * reading.scoreFraction, height: 8)
                }
            }
            .frame(height: 12)

            Text(reading.scoreAvailable
                 ? String(localized: "Your latest valid night produced this morning recovery score.")
                 : String(localized: "A valid scored night is needed before Morning Charge appears."))
                .font(AuraFont.ui(13))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private var whereItWent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Where it went"))
                .font(AuraFont.ui(10, weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(AuraPalette.textFaint)
                .padding(.horizontal, 4)

            Button(action: onOpenDaytimeCharge) {
                HStack(spacing: 13) {
                    ZStack {
                        Circle().fill(AuraPalette.accent.opacity(0.10)).frame(width: 38, height: 38)
                        Image(systemName: "battery.50percent")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(AuraPalette.accent)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Daytime Charge"))
                            .font(AuraFont.ui(13.5, weight: .medium))
                            .foregroundStyle(AuraPalette.textPrimary)
                        Text(String(localized: "Awake time, sessions, stress, and movement ledger"))
                            .font(AuraFont.ui(11.5))
                            .foregroundStyle(AuraPalette.textQuiet)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text(String(localized: "Coming soon"))
                        .font(AuraFont.ui(11, weight: .semibold))
                        .foregroundStyle(AuraPalette.accent)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 74)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .auraCard()
        }
    }

    private var tonightCard: some View {
        HStack(spacing: 13) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(Color(hex: "#C9D0EE"))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "Tonight's recharge model"))
                    .font(AuraFont.ui(13.5, weight: .semibold))
                    .foregroundStyle(AuraPalette.textPrimary)
                Text(String(localized: "Coming soon — no recharge amount or bedtime is estimated in this build."))
                    .font(AuraFont.ui(12))
                    .lineSpacing(3)
                    .foregroundStyle(Color(hex: "#C9D0EE"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AuraPalette.rest.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(AuraPalette.rest.opacity(0.24), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Reading

struct AuraChargeReading {
    struct Driver: Identifiable {
        let id: String
        let name: String
        let value: String
        let unit: String
        /// Where the value sits in the user's own range, 0–100.
        let position: Double
        /// Where their baseline sits in that same range.
        let baseline: Double
        let plain: String
    }

    let score: String
    let scoreFraction: Double
    let scoreAvailable: Bool
    let scoreBand: String
    let variability: String
    let variabilityCaption: String
    let dayHigh: String
    let dayLow: String
    let stress: String
    let baseline: String
    let variabilitySeries: [Double]
    let variabilityLabels: [String]
    let variabilityWindow: ClosedRange<Double>
    let variabilityNormalRange: ClosedRange<Double>?
    let axis: [String]
    let drivers: [Driver]
    let banner: String

    let headline: String

    #if DEBUG
    static let prototype = AuraChargeReading(
        score: "78",
        scoreFraction: 0.78,
        scoreAvailable: true,
        scoreBand: String(localized: "High recovery"),
        variability: "56",
        variabilityCaption: String(localized: "Each point is one night. The shaded band is your normal range."),
        dayHigh: "62",
        dayLow: "41",
        stress: String(localized: "Low"),
        baseline: "48",
        variabilitySeries: [44, 48, 46, 51, 49, 54, 53, 56],
        variabilityLabels: ["8 Aug", "9 Aug", "10 Aug", "11 Aug", "12 Aug", "13 Aug", "14 Aug", "15 Aug"],
        variabilityWindow: 35...65,
        variabilityNormalRange: 44...52,
        axis: ["8 Aug", "10 Aug", "13 Aug", "15 Aug"],
        drivers: [
            Driver(id: "hrv", name: String(localized: "Heart rhythm"), value: "56", unit: "ms",
                   position: 74, baseline: 48,
                   plain: String(localized: "Comfortably above your normal — the clearest sign you’ve recovered.")),
            Driver(id: "rhr", name: String(localized: "Resting heart rate"), value: "58", unit: "bpm",
                   position: 68, baseline: 56,
                   plain: String(localized: "Two beats slower than usual. A good sign, nothing to read into.")),
            Driver(id: "resp", name: String(localized: "Breathing rate"), value: "14.2", unit: "/min",
                   position: 55, baseline: 52,
                   plain: String(localized: "Right where it always is. This one only matters when it jumps.")),
            Driver(id: "temp", name: String(localized: "Skin temperature"), value: "−0.2", unit: "°C",
                   position: 58, baseline: 54,
                   plain: String(localized: "Slightly cool, which is normal after a proper night’s sleep.")),
        ],
        banner: String(localized: "Your variability is 17% above your own 30-day normal — the strongest it’s been this month."),
        headline: String(localized: "Your body is settled")
    )
    #endif
}
#endif
