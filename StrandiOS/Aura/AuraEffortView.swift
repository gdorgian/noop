#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura Effort
//
// The handoff's Session root is preserved as a single hero and a short explanation of today's real data.
// AuraEffortReading does not contain a prescribed workout, HR band or predicted load, so this screen never
// borrows those prototype values: it offers the existing live tracker and displays only stored readings.

struct AuraEffortView: View {
    private let reading: AuraEffortReading
    /// Starts a guided Live Session. The liquid Today carried this control; Aura Today replaced that
    /// screen and the entry point went with it, leaving the feature reachable only by deep link. Effort
    /// is where it belongs anyway — a session is effort you are about to spend, next to the target that
    /// says how much is left.
    private let onStartLiveSession: () -> Void

    init(reading: AuraEffortReading, onStartLiveSession: @escaping () -> Void = {}) {
        self.reading = reading
        self.onStartLiveSession = onStartLiveSession
    }

    var body: some View {
        VStack(spacing: 9) {
            sessionHero
            whyCard
            loadCard
            latestSessionCard
            restDecisionCard
            Text(String(localized: "Live sessions record what happened. A prescribed workout will appear only when Noop has a validated model and the data it needs."))
                .font(.custom("Instrument Sans", fixedSize: 11.5))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textDim)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
    }

    // MARK: Live-session hero

    private var sessionHero: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(localized: "Live session"))
                    .font(.custom("Instrument Sans", fixedSize: 10).weight(.semibold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.accent)
                Spacer(minLength: 8)
                Text(String(localized: "uses current strap data"))
                    .font(.custom("Instrument Sans", fixedSize: 11))
                    .foregroundStyle(AuraPalette.textQuiet)
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(String(localized: "Track your effort live"))
                    .font(.custom("Outfit", fixedSize: 29).weight(.light))
                    .tracking(-0.9)
                    .foregroundStyle(AuraPalette.textPrimary)
                Text(reading.note)
                    .font(.custom("Instrument Sans", fixedSize: 13.5))
                    .lineSpacing(3.5)
                    .foregroundStyle(Color(hex: "#B7C3C9"))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 14) {
                heroStat(value: reading.effort, label: String(localized: "Effort now"))
                heroDivider
                heroStat(value: String(reading.activities.count), label: String(localized: "sessions today"))
                heroDivider
                heroStat(
                    value: reading.weekLoad.isEmpty ? "—" : formattedLoad(weekTotal),
                    label: String(localized: "7-day load")
                )
            }
            .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(String(localized: "Today’s range"))
                        .font(.custom("Instrument Sans", fixedSize: 10).weight(.semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(AuraPalette.textFaint)
                    Spacer(minLength: 8)
                    Text(reading.targetCaption)
                        .font(.custom("Instrument Sans", fixedSize: 11))
                        .foregroundStyle(AuraPalette.textQuiet)
                        .multilineTextAlignment(.trailing)
                }

                if reading.effort == "—" {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.09))
                        .frame(height: 8)
                    Text(String(localized: "Effort position pending"))
                        .font(.custom("Instrument Sans", fixedSize: 11.5))
                        .foregroundStyle(AuraPalette.textDim)
                } else {
                    AuraEffortSlider(fraction: reading.fraction, stops: reading.stops)
                }
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )

            VStack(spacing: 8) {
                Button(action: onStartLiveSession) {
                    Text(String(localized: "Start live session"))
                        .font(.custom("Instrument Sans", fixedSize: 15).weight(.semibold))
                        .foregroundStyle(AuraPalette.onAccent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(AuraPalette.accent)
                        )
                }
                .buttonStyle(.plain)

                HStack(spacing: 8) {
                    Text(String(localized: "Choose something else"))
                        .foregroundStyle(Color(hex: "#C6CEC9"))
                    Text(String(localized: "Coming soon"))
                        .foregroundStyle(AuraPalette.accent)
                }
                .font(.custom("Instrument Sans", fixedSize: 13.5))
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    colors: [AuraPalette.accent.opacity(0.16), AuraPalette.accent.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(AuraPalette.accent.opacity(0.30), lineWidth: 0.5)
                )
        )
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.custom("Outfit", fixedSize: 21).weight(.light))
                .tracking(-0.5)
                .monospacedDigit()
                .foregroundStyle(AuraPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.custom("Instrument Sans", fixedSize: 10.5))
                .foregroundStyle(AuraPalette.textFaint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 0.5, height: 30)
    }

    // MARK: What today's data says

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(String(localized: "What today’s data says")).auraOverline()

            VStack(spacing: 11) {
                dataRow(
                    label: String(localized: "Effort so far"),
                    note: String(localized: "Stored from today’s heart-rate load."),
                    chip: reading.effort == "—" ? String(localized: "pending") : reading.effort,
                    tint: reading.effort == "—" ? AuraPalette.textQuiet : AuraPalette.accent,
                    isMuted: reading.effort == "—"
                )

                dataRow(
                    label: String(localized: "Recovery-matched range"),
                    note: reading.note,
                    chip: reading.targetCaption,
                    tint: targetPending ? AuraPalette.textQuiet : AuraPalette.accent,
                    isMuted: targetPending
                )

                dataRow(
                    label: String(localized: "Sessions recorded today"),
                    note: latestActivity?.detail ?? String(localized: "No workouts recorded today."),
                    chip: String(reading.activities.count),
                    tint: reading.activities.isEmpty ? AuraPalette.textQuiet : AuraPalette.accent,
                    isMuted: reading.activities.isEmpty
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 14)
        .auraCard(cornerRadius: 20)
    }

    private var targetPending: Bool {
        reading.targetCaption == String(localized: "target pending")
    }

    private func dataRow(
        label: String,
        note: String,
        chip: String,
        tint: Color,
        isMuted: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Circle()
                .fill(tint)
                .frame(width: 9, height: 9)
                .overlay(Circle().stroke(tint.opacity(0.14), lineWidth: 4))
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.custom("Instrument Sans", fixedSize: 13))
                    .foregroundStyle(AuraPalette.textPrimary)
                Text(note)
                    .font(.custom("Instrument Sans", fixedSize: 11.5))
                    .lineSpacing(2.5)
                    .foregroundStyle(AuraPalette.textQuiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Text(chip)
                .font(.custom("Instrument Sans", fixedSize: 10.5).weight(.semibold))
                .foregroundStyle(isMuted ? AuraPalette.textSecondary : Color(hex: "#8FD3F5"))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint.opacity(0.13)))
        }
    }

    // MARK: Real seven-day load

    private var loadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(String(localized: "Load, last seven days")).auraOverline()
                Spacer(minLength: 8)
                Text(reading.weekLoad.isEmpty
                     ? String(localized: "no recorded load")
                     : String(localized: "\(formattedLoad(weekTotal)) total"))
                    .font(.custom("Instrument Sans", fixedSize: 11).monospacedDigit())
                    .foregroundStyle(AuraPalette.textDim)
            }

            if reading.weekLoad.isEmpty {
                Text(String(localized: "No Effort has been recorded in this window."))
                    .font(.custom("Instrument Sans", fixedSize: 12))
                    .foregroundStyle(AuraPalette.textQuiet)
                    .frame(maxWidth: .infinity, minHeight: 62, alignment: .center)
            } else {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(Array(reading.weekLoad.enumerated()), id: \.offset) { index, value in
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(loadTint(index: index, value: value))
                            .frame(maxWidth: .infinity)
                            .frame(height: max(3, 62 * CGFloat(min(max(value / max(reading.weekCeiling, 1), 0), 1))))
                    }
                }
                .frame(height: 62, alignment: .bottom)

                HStack(spacing: 6) {
                    ForEach(Array(reading.weekLoad.enumerated()), id: \.offset) { index, _ in
                        Text(reading.weekDays.indices.contains(index) ? reading.weekDays[index] : "")
                            .font(.custom("Instrument Sans", fixedSize: 9.5).weight(index == reading.weekHighlighted ? .semibold : .regular))
                            .foregroundStyle(index == reading.weekHighlighted ? Color(hex: "#8FD3F5") : AuraPalette.textDim)
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            Text(reading.weekVerdict)
                .font(.custom("Instrument Sans", fixedSize: 11.5))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textQuiet)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 13)
        .auraCard(cornerRadius: 20)
    }

    private var weekTotal: Double { reading.weekLoad.reduce(0, +) }

    private func loadTint(index: Int, value: Double) -> Color {
        if index == reading.weekHighlighted { return AuraPalette.accent }
        if value / max(reading.weekCeiling, 1) > 0.78 { return Color(hex: "#F2B45C") }
        return value > 0 ? AuraPalette.accent.opacity(0.50) : Color.white.opacity(0.07)
    }

    private func formattedLoad(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.1f", value)
    }

    // MARK: Latest recorded session

    private var latestActivity: AuraEffortReading.Activity? { reading.activities.first }

    private var latestSessionCard: some View {
        HStack(spacing: 13) {
            Image(systemName: latestActivity == nil ? "figure.walk.motion" : "activity.rings")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(latestActivity?.tint ?? AuraPalette.textDim)
                .frame(width: 30, height: 30)
                .background(Circle().fill((latestActivity?.tint ?? AuraPalette.textQuiet).opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(latestActivity.map { String(localized: "Latest today · \($0.name)") }
                     ?? String(localized: "No session recorded today"))
                    .font(.custom("Instrument Sans", fixedSize: 13.5).weight(.semibold))
                    .foregroundStyle(AuraPalette.textPrimary)
                Text(latestActivity?.detail ?? String(localized: "Start a live session when you are ready."))
                    .font(.custom("Instrument Sans", fixedSize: 11.5))
                    .foregroundStyle(AuraPalette.textQuiet)
            }
            Spacer(minLength: 8)
            if let latestActivity {
                Text(latestActivity.load)
                    .font(.custom("Outfit", fixedSize: 17))
                    .monospacedDigit()
                    .foregroundStyle(AuraPalette.textSecondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .auraCard(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    // MARK: Rest decision

    private var restDecisionCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(String(localized: "Rather not today?"))
                .font(.custom("Instrument Sans", fixedSize: 13.5).weight(.semibold))
                .foregroundStyle(AuraPalette.textPrimary)
            Text(String(localized: "Skipping costs you nothing. There is no streak to break here — a rest day is a training decision."))
                .font(.custom("Instrument Sans", fixedSize: 12))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 7) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 11))
                Text(String(localized: "Mark a rest day"))
                Text(String(localized: "Coming soon"))
                    .foregroundStyle(Color(hex: "#C9D0EE"))
            }
            .font(.custom("Instrument Sans", fixedSize: 12.5).weight(.semibold))
            .foregroundStyle(AuraPalette.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AuraPalette.rest.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AuraPalette.rest.opacity(0.24), lineWidth: 0.5)
                    )
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 15)
        .padding(.bottom, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AuraPalette.rest.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(AuraPalette.rest.opacity(0.18), lineWidth: 0.5)
                )
        )
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

    let greeting: String
    let effort: String
    let targetCaption: String
    /// Position on the Minimal → All out track, 0…1.
    let fraction: Double
    let stops: [(label: String, position: Double)]
    let note: String
    let activities: [Activity]
    let weekLoad: [Double]
    let weekDays: [String]
    /// Index of today's real reading, or -1 when today has no Effort yet.
    let weekHighlighted: Int
    let weekVerdict: String
    let weekCeiling: Double
    let headline: String

    #if DEBUG
    static let prototype = AuraEffortReading(
        greeting: String(localized: "Saturday"),
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
        weekHighlighted: 6,
        weekVerdict: String(localized: "3 of 7 target days in range · 2 below · 2 above"),
        weekCeiling: 21,
        headline: String(localized: "Effort so far today")
    )
    #endif
}
#endif
