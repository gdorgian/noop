#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Rest
//
// Sleep, answered in the order a person actually asks: how was last night, how does that compare to my
// own week, what happened inside it, and what does that mean. The week chart is tappable, and the two
// cards below it re-read for whichever night is selected — so the screen is one story about one night,
// not a dashboard of seven.

struct AuraRestView: View {
    private let reading: AuraRestReading

    /// Which night the week chart has selected. Defaults to the most recent.
    @State private var selectedNight: Int

    init(reading: AuraRestReading = .prototype) {
        self.reading = reading
        _selectedNight = State(initialValue: reading.nights.count - 1)
    }

    /// The selected night, or nil if there are none. Optional rather than force-indexed: an empty week
    /// is a legitimate state once this reads real data (a new user, a fresh install).
    private var night: AuraRestReading.Night? {
        guard !reading.nights.isEmpty else { return nil }
        return reading.nights[min(max(selectedNight, 0), reading.nights.count - 1)]
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            HStack(spacing: 8) {
                AuraStatTile(label: String(localized: "Avg sleep"), value: "6.8", unit: "h")
                AuraStatTile(label: String(localized: "Deep sleep"), value: "1.6", unit: "h",
                             valueTint: AuraPalette.rest)
            }

            weekCard
            nightCard
            AuraNoteBanner(text: restNote, tint: AuraPalette.rest)
        }
    }

    // MARK: Week

    private var weekCard: some View {
        VStack(spacing: 20) {
            AuraCardHeader(title: String(localized: "This week"),
                           note: String(localized: "Tap a night"),
                           symbol: "moon")
            AuraSleepBars(
                nights: reading.nights.map {
                    AuraSleepBars.Night(id: $0.id, day: $0.day, hours: $0.hours)
                },
                selected: selectedNight,
                average: reading.personalAverage
            ) { index in
                withAnimation(NoopMotion.value) { selectedNight = index }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .auraCard()
    }

    // MARK: One night

    private var nightCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(selectedNight == reading.nights.count - 1
                     ? String(localized: "Last night")
                     : String(localized: "That night"))
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(AuraPalette.textPrimary)
                Spacer(minLength: 8)
                Text(reading.nightWindow)
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(AuraPalette.textQuiet)
            }
            .padding(.bottom, 16)

            AuraHypnogram(stages: reading.hypnogram)
                .padding(.bottom, 9)

            HStack {
                ForEach(reading.hypnogramAxis, id: \.self) { label in
                    Text(label)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AuraPalette.textDim)
                    if label != reading.hypnogramAxis.last { Spacer(minLength: 4) }
                }
            }
            .padding(.bottom, 18)

            VStack(spacing: 14) {
                ForEach(reading.stages) { stage in
                    AuraStageRow(name: stage.name, duration: stage.duration,
                                 fraction: stage.fraction, tint: stage.tint)
                }
            }
        }
        .padding(18)
        .auraCard()
    }

    /// The selected night's own note, followed by the line that turns the dashed average into a claim.
    private var restNote: String {
        guard let night else { return reading.averageNote }
        return "\(night.note) \(reading.averageNote)"
    }
}

// MARK: - Reading

struct AuraRestReading {
    struct Night: Identifiable {
        let id: Int
        let day: String
        let hours: Double
        let note: String
    }

    struct Stage: Identifiable {
        let id: String
        let name: String
        let duration: String
        /// Share of the widest stage bar, not of the night — the bars compare stages to each other.
        let fraction: Double
        let tint: Color
    }

    let nights: [Night]
    let personalAverage: Double
    let averageNote: String
    let nightWindow: String
    let hypnogram: [Int]
    let hypnogramAxis: [String]
    let stages: [Stage]

    static let prototype = AuraRestReading(
        nights: [
            Night(id: 0, day: String(localized: "S"), hours: 5.5, note: String(localized: "Late night, short.")),
            Night(id: 1, day: String(localized: "M"), hours: 7.3, note: String(localized: "Best night of the week.")),
            Night(id: 2, day: String(localized: "T"), hours: 5.5, note: String(localized: "Woke twice after midnight.")),
            Night(id: 3, day: String(localized: "W"), hours: 6.1, note: String(localized: "Fine, a little short.")),
            Night(id: 4, day: String(localized: "T"), hours: 7.0, note: String(localized: "Solid and unbroken.")),
            Night(id: 5, day: String(localized: "F"), hours: 6.6, note: String(localized: "Late to bed, slept through.")),
            Night(id: 6, day: String(localized: "S"), hours: 7.2, note: String(localized: "Full night, deep came early.")),
        ],
        personalAverage: 6.46,
        averageNote: String(localized: "The dashed line is your own normal, 6h 28m — you’re above it four nights out of seven."),
        nightWindow: "23:14 – 06:41",
        hypnogram: [1, 1, 2, 3, 3, 3, 2, 2, 3, 3, 2, 1, 0, 1, 2, 3, 3, 2, 2, 1,
                    1, 2, 2, 3, 2, 1, 0, 1, 1, 2, 2, 1, 1, 0],
        hypnogramAxis: ["11pm", "2am", "4am", "6am"],
        stages: [
            Stage(id: "deep", name: String(localized: "Deep"), duration: "1h 34m",
                  fraction: 0.61, tint: Color(hex: "#9AA7E0")),
            Stage(id: "rem", name: String(localized: "REM"), duration: "1h 48m",
                  fraction: 0.70, tint: Color(hex: "#6E7DB8")),
            Stage(id: "light", name: String(localized: "Light"), duration: "3h 42m",
                  fraction: 0.88, tint: Color(hex: "#48527D")),
            Stage(id: "awake", name: String(localized: "Awake"), duration: "8m",
                  fraction: 0.07, tint: Color.white.opacity(0.18)),
        ]
    )
}
#endif
