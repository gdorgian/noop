#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Charge
//
// The one screen in Aura that is allowed to be dense, because it is the screen a user opens when they
// have already decided they want the numbers. Even here the rule holds: every driver gets a sentence in
// plain language under it, and none of them is presented as a verdict on its own.

struct AuraChargeView: View {
    private let reading: AuraChargeReading

    init(reading: AuraChargeReading = .prototype) {
        self.reading = reading
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            variabilityCard

            HStack(spacing: 8) {
                AuraStatTile(label: String(localized: "Stress today"),
                             value: reading.stress, valueTint: AuraPalette.accent)
                AuraStatTile(label: String(localized: "Your normal"),
                             value: reading.baseline, unit: "ms")
            }

            VStack(spacing: 9) {
                ForEach(reading.drivers) { driver in
                    driverCard(driver)
                }
            }

            AuraInfoBanner(text: reading.banner, accent: AuraPalette.accent)
        }
    }

    // MARK: Variability

    private var variabilityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(reading.variability)
                        .font(.system(size: 46, weight: .ultraLight, design: .rounded).monospacedDigit())
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(verbatim: "ms")
                        .font(.system(size: 16))
                        .foregroundStyle(AuraPalette.textQuiet)
                }
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 11) {
                    extremum(reading.dayHigh, label: String(localized: "max"))
                    extremum(reading.dayLow, label: String(localized: "min"))
                }
            }
            .padding(.bottom, 14)

            Text(String(localized: "Variability through the day"))
                .font(.system(size: 11.5))
                .foregroundStyle(AuraPalette.textQuiet)
                .padding(.bottom, 16)

            AuraDotColumns(counts: reading.columnCounts,
                           offsets: reading.columnOffsets,
                           tint: AuraPalette.accent)
                .padding(.bottom, 11)

            HStack {
                ForEach(reading.axis, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AuraPalette.textDim)
                    if label != reading.axis.last { Spacer(minLength: 4) }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 19)
        .padding(.bottom, 16)
        .auraCard()
    }

    private func extremum(_ value: String, label: String) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(AuraPalette.textQuiet)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(AuraPalette.textDim)
        }
    }

    // MARK: Drivers

    private func driverCard(_ driver: AuraChargeReading.Driver) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(driver.name)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(AuraPalette.textPrimary)
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(driver.value)
                        .font(.system(size: 22, design: .rounded).monospacedDigit())
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(driver.unit)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AuraPalette.textFaint)
                }
            }
            .padding(.bottom, 12)

            AuraRangeBar(position: driver.position, baseline: driver.baseline, tint: AuraPalette.accent)
                .padding(.bottom, 10)

            Text(driver.plain)
                .font(.system(size: 13))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 17)
        .padding(.vertical, 16)
        .auraCard(cornerRadius: AuraPalette.tileRadius)
        .accessibilityElement(children: .combine)
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

    let variability: String
    let dayHigh: String
    let dayLow: String
    let stress: String
    let baseline: String
    /// Dots per column for the day's variability texture.
    let columnCounts: [Int]
    /// How far each column is pushed down from the top, in dot-steps.
    let columnOffsets: [Int]
    let axis: [String]
    let drivers: [Driver]
    let banner: String

    static let prototype = AuraChargeReading(
        variability: "56",
        dayHigh: "62",
        dayLow: "41",
        stress: String(localized: "Low"),
        baseline: "48",
        columnCounts: [3, 4, 4, 5, 6, 6, 5, 4, 3, 3, 4, 5, 4, 3, 2, 3, 4, 5, 5, 4, 3, 4],
        columnOffsets: [3, 2, 2, 1, 0, 0, 1, 2, 3, 3, 2, 1, 2, 3, 4, 3, 2, 1, 1, 2, 3, 2],
        axis: ["12am", "6am", "12pm", "6pm"],
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
        banner: String(localized: "Your variability is 17% above your own 30-day normal — the strongest it’s been this month.")
    )
}
#endif
