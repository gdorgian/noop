#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Effort
//
// Effort against a target, not against other people. The slider is a read-out rather than a control —
// you do not choose your strain — and the note under it says what would close the gap, which is the only
// actionable thing on the screen.

struct AuraEffortView: View {
    private let reading: AuraEffortReading

    init(reading: AuraEffortReading = .prototype) {
        self.reading = reading
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            targetCard
            loggedCard
            weekCard
        }
    }

    // MARK: Today against target

    private var targetCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(reading.effort)
                    .font(.system(size: 54, weight: .ultraLight, design: .rounded).monospacedDigit())
                    .foregroundStyle(AuraPalette.textPrimary)
                Text(reading.targetCaption)
                    .font(.system(size: 14.5))
                    .foregroundStyle(AuraPalette.textQuiet)
            }
            .padding(.bottom, 6)

            Text(String(localized: "Effort so far today"))
                .font(.system(size: 13))
                .foregroundStyle(AuraPalette.textTertiary)
                .padding(.bottom, 24)

            AuraEffortSlider(fraction: reading.fraction, stops: reading.stops)
                .padding(.bottom, 20)

            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "#8FDCFA"), Color(hex: "#0B6FA8")],
                                         center: UnitPoint(x: 0.34, y: 0.3), startRadius: 0, endRadius: 18))
                    .frame(width: 18, height: 18)
                    .padding(.top, 1)
                Text(reading.note)
                    .font(.system(size: 13.5))
                    .lineSpacing(2)
                    .foregroundStyle(AuraPalette.textPrimary.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .auraCard()
    }

    // MARK: Logged

    private var loggedCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(String(localized: "Logged today")).auraOverline()
            ForEach(reading.activities) { activity in
                HStack(spacing: 12) {
                    Circle()
                        .fill(activity.tint)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AuraPalette.textPrimary)
                        Text(activity.detail)
                            .font(.system(size: 11.5))
                            .foregroundStyle(AuraPalette.textQuiet)
                    }
                    Spacer(minLength: 8)
                    Text(activity.load)
                        .font(.system(size: 19, design: .rounded).monospacedDigit())
                        .foregroundStyle(AuraPalette.textPrimary)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .auraCard()
    }

    // MARK: Week

    private var weekCard: some View {
        VStack(spacing: 18) {
            AuraCardHeader(title: String(localized: "Load this week"),
                           note: reading.weekVerdict,
                           noteTint: AuraPalette.accent)
            AuraWeekBars(values: reading.weekLoad, days: reading.weekDays,
                         highlighted: reading.weekLoad.count - 1)
        }
        .padding(18)
        .auraCard()
    }
}

// MARK: - Reading

struct AuraEffortReading {
    struct Activity: Identifiable {
        let id: String
        let name: String
        let detail: String
        let load: String
        let tint: Color
    }

    let effort: String
    let targetCaption: String
    /// Position on the Minimal → All out track, 0…1.
    let fraction: Double
    let stops: [(label: String, position: Double)]
    let note: String
    let activities: [Activity]
    let weekLoad: [Double]
    let weekDays: [String]
    let weekVerdict: String

    static let prototype = AuraEffortReading(
        effort: "6.2",
        targetCaption: String(localized: "of a 12 target"),
        fraction: 0.52,
        stops: [
            (label: String(localized: "Minimal"), position: 8),
            (label: String(localized: "Moderate"), position: 52),
            (label: String(localized: "All out"), position: 92),
        ],
        note: String(localized: "Moderate is where you want to land. A 35-minute easy walk closes the gap without touching tomorrow."),
        activities: [
            Activity(id: "walk", name: String(localized: "Morning walk"),
                     detail: String(localized: "32 min · easy"), load: "2.1", tint: AuraPalette.accent),
            Activity(id: "rest", name: String(localized: "Everything else"),
                     detail: String(localized: "Moving around the day"), load: "3.4",
                     tint: Color.white.opacity(0.28)),
            Activity(id: "stairs", name: String(localized: "Stairs, twice"),
                     detail: String(localized: "6 min · brief and sharp"), load: "0.7",
                     tint: AuraPalette.effort),
        ],
        weekLoad: [8.4, 14.2, 6.1, 15.8, 11.2, 4.6, 6.2],
        weekDays: [
            String(localized: "M"), String(localized: "T"), String(localized: "W"),
            String(localized: "T"), String(localized: "F"), String(localized: "S"),
            String(localized: "S"),
        ],
        weekVerdict: String(localized: "Balanced")
    )
}
#endif
