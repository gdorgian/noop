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
            debtCard
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
                     : (night?.dateLabel ?? "—"))
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

    private var debtCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            AuraCardHeader(
                title: String(localized: "Sleep debt"),
                note: reading.debtHeadline,
                noteTint: reading.debtIsDebt ? AuraPalette.effort : AuraPalette.rest,
                symbol: "moon.stars",
                symbolTint: AuraPalette.rest
            )

            Text(reading.debtExplanation)
                .font(.system(size: 12.5))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textQuiet)
                .fixedSize(horizontal: false, vertical: true)

            if reading.debtNights.isEmpty {
                Text(String(localized: "No nights with enough sleep data yet."))
                    .font(.system(size: 13.5))
                    .foregroundStyle(AuraPalette.textQuiet)
                    .frame(maxWidth: .infinity, minHeight: 54, alignment: .center)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(reading.debtNights.enumerated()), id: \.element.id) { index, item in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.date)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .foregroundStyle(AuraPalette.textPrimary)
                                Text(item.slept)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(AuraPalette.textQuiet)
                            }
                            Spacer(minLength: 8)
                            Text(item.change)
                                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                .foregroundStyle(item.addedDebt ? AuraPalette.effort : AuraPalette.rest)
                        }
                        .frame(minHeight: 51)
                        if index < reading.debtNights.count - 1 {
                            Rectangle().fill(AuraPalette.cardBorder).frame(height: 0.5)
                        }
                    }
                }
            }
        }
        .padding(18)
        .auraCard()
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
        let dateLabel: String
        let hours: Double
        let note: String
        let window: String
        let hypnogram: [Int]
        let hypnogramAxis: [String]
        let stages: [Stage]
    }

    struct DebtNight: Identifiable {
        let id: String
        let date: String
        let slept: String
        let change: String
        let addedDebt: Bool
    }

    let nights: [NightReading]
    let personalAverage: Double
    let averageNote: String
    let averageSleepValue: String
    let averageDeepValue: String
    let debtHeadline: String
    let debtExplanation: String
    let debtIsDebt: Bool
    let debtNights: [DebtNight]

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
            NightReading(id: 0, day: String(localized: "S"), dateLabel: "10/8", hours: 5.5, note: String(localized: "Late night, short."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 1, day: String(localized: "M"), dateLabel: "11/8", hours: 7.3, note: String(localized: "Best night of the week."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 2, day: String(localized: "T"), dateLabel: "12/8", hours: 5.5, note: String(localized: "Woke twice after midnight."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 3, day: String(localized: "W"), dateLabel: "13/8", hours: 6.1, note: String(localized: "Fine, a little short."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 4, day: String(localized: "T"), dateLabel: "14/8", hours: 7.0, note: String(localized: "Solid and unbroken."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 5, day: String(localized: "F"), dateLabel: "15/8", hours: 6.6, note: String(localized: "Late to bed, slept through."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
            NightReading(id: 6, day: String(localized: "S"), dateLabel: "16/8", hours: 7.2, note: String(localized: "Full night, deep came early."),
                  window: "23:14 – 06:41", hypnogram: prototypeHypnogram, hypnogramAxis: ["11pm", "2am", "4am", "6am"], stages: prototypeStages),
        ],
        personalAverage: 6.46,
        averageNote: String(localized: "The dashed line is your own normal, 6h 28m — you’re above it four nights out of seven."),
        averageSleepValue: "6.8",
        averageDeepValue: "1.6",
        debtHeadline: String(localized: "4h 12m debt"),
        debtExplanation: String(localized: "Your running balance across the last 14 recorded nights. Short nights add debt; longer nights pay it back."),
        debtIsDebt: true,
        debtNights: [
            DebtNight(id: "2026-08-14", date: "14/8", slept: "7h 0m slept", change: "+1h debt", addedDebt: true),
            DebtNight(id: "2026-08-15", date: "15/8", slept: "8h 20m slept", change: "−20m debt", addedDebt: false),
            DebtNight(id: "2026-08-16", date: "16/8", slept: "7h 12m slept", change: "+48m debt", addedDebt: true),
        ]
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
