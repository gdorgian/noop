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

    /// Stable onset id of the night selected in the week chart. Defaults to the most recent.
    @State private var selectedNightID: Int

    init(reading: AuraRestReading = .prototype) {
        self.reading = reading
        _selectedNightID = State(initialValue: reading.nights.last?.id ?? 0)
    }

    /// The selected night, or nil if there are none. Optional rather than force-indexed: an empty week
    /// is a legitimate state once this reads real data (a new user, a fresh install).
    private var night: AuraRestReading.NightReading? {
        guard !reading.nights.isEmpty else { return nil }
        return reading.nights.first(where: { $0.id == selectedNightID }) ?? reading.nights.last
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            HStack(spacing: 8) {
                AuraStatTile(label: String(localized: "Avg sleep"), value: reading.averageSleepValue, unit: "h")
                AuraStatTile(label: String(localized: "Deep sleep"), value: reading.averageDeepValue, unit: "h",
                             valueTint: AuraPalette.rest)
            }

            weekCard
            nightCard
            AuraNoteBanner(text: restNote, tint: AuraPalette.rest)
        }
        .onChangeCompat(of: reading.nights.map(\.id)) { _ in
            guard reading.nights.contains(where: { $0.id == selectedNightID }) else {
                selectedNightID = reading.nights.last?.id ?? 0
                return
            }
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
                selected: selectedNightID,
                average: reading.personalAverage
            ) { id in
                withAnimation(NoopMotion.value) { selectedNightID = id }
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
                Text(night?.id == reading.nights.last?.id
                     ? String(localized: "Last night")
                     : String(localized: "That night"))
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(AuraPalette.textPrimary)
                Spacer(minLength: 8)
                Text(night?.window ?? "—")
                    .font(.system(size: 11.5).monospacedDigit())
                    .foregroundStyle(AuraPalette.textQuiet)
            }
            .padding(.bottom, 16)

            AuraHypnogram(stages: night?.hypnogram ?? [])
                .padding(.bottom, 9)

            HStack {
                ForEach(Array((night?.hypnogramAxis ?? []).enumerated()), id: \.offset) { index, label in
                    Text(label)
                        .font(.system(size: 10.5))
                        .foregroundStyle(AuraPalette.textDim)
                    if index < (night?.hypnogramAxis.count ?? 0) - 1 { Spacer(minLength: 4) }
                }
            }
            .padding(.bottom, 18)

            VStack(spacing: 14) {
                ForEach(night?.stages ?? []) { stage in
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
    struct Stage: Identifiable {
        let id: String
        let name: String
        let duration: String
        /// Share of the widest stage bar, not of the night — the bars compare stages to each other.
        let fraction: Double
        let tint: Color
    }

    struct NightReading: Identifiable {
        let id: Int
        let day: String
        let hours: Double
        let note: String
        let window: String
        let hypnogram: [Int]
        let hypnogramAxis: [String]
        let stages: [Stage]
    }

    let nights: [NightReading]
    let personalAverage: Double
    let averageNote: String
    let averageSleepValue: String
    let averageDeepValue: String

    var headline: String {
        guard let latest = nights.last else { return String(localized: "No sleep recorded yet") }
        return String(localized: "You slept \(AuraRestReading.durationText(latest.hours * 60))")
    }

    private static func durationText(_ minutes: Double) -> String {
        let rounded = max(0, Int(minutes.rounded()))
        return String(localized: "\(rounded / 60)h \(rounded % 60)m")
    }

    static let prototype = AuraRestReading(
        nights: [
            NightReading(id: 0, day: String(localized: "S"), hours: 5.5, note: String(localized: "Late night, short."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 1, day: String(localized: "M"), hours: 7.3, note: String(localized: "Best night of the week."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 2, day: String(localized: "T"), hours: 5.5, note: String(localized: "Woke twice after midnight."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 3, day: String(localized: "W"), hours: 6.1, note: String(localized: "Fine, a little short."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 4, day: String(localized: "T"), hours: 7.0, note: String(localized: "Solid and unbroken."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 5, day: String(localized: "F"), hours: 6.6, note: String(localized: "Late to bed, slept through."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 6, day: String(localized: "S"), hours: 7.2, note: String(localized: "Full night, deep came early."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
        ],
        personalAverage: 6.46,
        averageNote: String(localized: "The dashed line is your own normal, 6h 28m — you’re above it four nights out of seven."),
        averageSleepValue: "6.8",
        averageDeepValue: "1.6"
    )

    private static let prototypeHypnogram = [
        1, 1, 2, 3, 3, 3, 2, 2, 3, 3, 2, 1, 0, 1, 2, 3, 3, 2, 2, 1,
        1, 2, 2, 3, 2, 1, 0, 1, 1, 2, 2, 1, 1, 0,
    ]

    private static let prototypeStages = [
        Stage(id: "deep", name: String(localized: "Deep"), duration: "1h 34m",
              fraction: 0.61, tint: AuraHypnogram.stageColors[3]),
        Stage(id: "rem", name: String(localized: "REM"), duration: "1h 48m",
              fraction: 0.70, tint: AuraHypnogram.stageColors[2]),
        Stage(id: "light", name: String(localized: "Light"), duration: "3h 42m",
              fraction: 0.88, tint: AuraHypnogram.stageColors[1]),
        Stage(id: "awake", name: String(localized: "Awake"), duration: "8m",
              fraction: 0.07, tint: AuraHypnogram.stageColors[0]),
    ]
}
#endif
