#if os(iOS)
import Foundation
import SwiftUI
import StrandDesign

// MARK: - Why this sleep

struct AuraRestWhyView: View {
    let reading: AuraRestReading
    let nightID: Int?
    let onBack: () -> Void

    private var night: AuraRestReading.NightReading? {
        nightID.flatMap { id in reading.nights.first(where: { $0.id == id }) }
            ?? reading.nights.last
    }

    var body: some View {
        ZStack {
            AuraRestDetailBackground()

            VStack(spacing: 0) {
                NoopSpecHeader(parent: String(localized: "Rest"), onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: NoopSpecTokens.cardGap) {
                        Text(String(localized: "Why this sleep"))
                            .noopText(.screenTitle)
                            .foregroundStyle(NoopSpecTokens.textPrimary)

                        scoreCard
                        methodCard
                        whatWouldMoveIt

                        Text(String(localized: "A stored Rest score and a per-factor explanation are different records. Noop Aura does not reconstruct missing historical factor points."))
                            .noopText(.finePrint)
                            .foregroundStyle(NoopSpecTokens.textDim)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, NoopSpecTokens.screenPadding)
                    .padding(.bottom, NoopSpecTokens.scrollBottomInset)
                }
                .scrollIndicators(.hidden)
                .simultaneousGesture(AuraRestBackSwipe(action: onBack))
            }
        }
    }

    private var scoreCard: some View {
        NoopSpecCard(.hero) {
            VStack(alignment: .leading, spacing: 13) {
                NoopSpecCaption("REST SCORE", color: NoopSpecTokens.lavenderText)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(scoreText)
                        .noopText(.heroNumeral)
                        .foregroundStyle(NoopSpecTokens.textPrimary)
                    Spacer(minLength: 8)
                    NoopSpecChip(
                        scoreBandText,
                        hue: NoopSpecTokens.lavender,
                        textColor: NoopSpecTokens.lavenderText
                    )
                }

                Text(scoreExplanation)
                    .noopText(.body)
                    .foregroundStyle(NoopSpecTokens.textBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var scoreText: String {
        night?.score.map { "\(Int($0.rounded()))" } ?? "—"
    }

    private var scoreBandText: String {
        night?.score.map { AuraRestScoreBand(score: $0).label } ?? String(localized: "Unavailable")
    }

    private var scoreExplanation: String {
        guard let night else {
            return String(localized: "No recorded sleep is available for this explanation.")
        }
        guard night.score != nil else {
            return String(localized: "This sleep has duration and stage data, but no stored Rest score.")
        }
        return String(localized: "The score is stored for \(night.dateLabel). Per-factor points were not saved for that sleep, so signed contributors cannot be shown honestly.")
    }

    private struct MethodTerm: Identifiable {
        let id: String
        let label: String
        let subline: String
    }

    private var terms: [MethodTerm] {
        [
            MethodTerm(
                id: "duration",
                label: String(localized: "Duration"),
                subline: String(localized: "50% of Noop’s on-device Rest method")
            ),
            MethodTerm(
                id: "efficiency",
                label: String(localized: "Sleep efficiency"),
                subline: String(localized: "20% of Noop’s on-device Rest method")
            ),
            MethodTerm(
                id: "restorative",
                label: String(localized: "Restorative share"),
                subline: String(localized: "20% of Noop’s on-device Rest method")
            ),
            MethodTerm(
                id: "consistency",
                label: String(localized: "Consistency"),
                subline: String(localized: "10% of Noop’s on-device Rest method")
            ),
        ]
    }

    private var methodCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            NoopSpecCaption("METHOD TERMS")

            NoopSpecCard(.list) {
                VStack(spacing: 0) {
                    ForEach(Array(terms.enumerated()), id: \.element.id) { index, term in
                        NoopSpecRow(
                            label: term.label,
                            subline: term.subline,
                            isFirst: index == 0,
                            minHeight: 70
                        ) {
                            NoopSpecChip(
                                String(localized: "Not saved"),
                                hue: NoopSpecTokens.lavender,
                                textColor: NoopSpecTokens.lavenderText
                            )
                        }
                    }
                }
            }
        }
    }

    private var whatWouldMoveIt: some View {
        NoopSpecCard(.standard, tint: NoopSpecTokens.lavender) {
            VStack(alignment: .leading, spacing: 9) {
                NoopSpecCaption("WHAT WOULD MOVE IT", color: NoopSpecTokens.lavenderText)
                Text(String(localized: "Duration, efficiency, restorative share and consistency are the four measured terms in Noop’s on-device method. Without the saved term values for this sleep, naming one as the cause—or predicting a point gain—would be invented."))
                    .noopText(.body)
                    .foregroundStyle(NoopSpecTokens.textBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Running debt

struct AuraRestDebtView: View {
    let reading: AuraRestReading
    let onBack: () -> Void

    var body: some View {
        ZStack {
            AuraRestDetailBackground()

            VStack(spacing: 0) {
                NoopSpecHeader(parent: String(localized: "Rest"), onBack: onBack)

                ScrollView {
                    VStack(alignment: .leading, spacing: NoopSpecTokens.cardGap) {
                        Text(String(localized: "Sleep debt"))
                            .noopText(.screenTitle)
                            .foregroundStyle(NoopSpecTokens.textPrimary)

                        totalCard
                        stripCard
                        howItClears

                        Text(String(localized: "Sleep debt is a rolling arithmetic balance, not a moral ledger and not a diagnosis."))
                            .noopText(.finePrint)
                            .foregroundStyle(NoopSpecTokens.textDim)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, NoopSpecTokens.screenPadding)
                    .padding(.bottom, NoopSpecTokens.scrollBottomInset)
                }
                .scrollIndicators(.hidden)
                .simultaneousGesture(AuraRestBackSwipe(action: onBack))
            }
        }
    }

    private var totalCard: some View {
        NoopSpecCard(.hero) {
            VStack(alignment: .leading, spacing: 10) {
                NoopSpecCaption("RUNNING BALANCE", color: NoopSpecTokens.lavenderText)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(balanceFigure)
                        .noopText(.heroNumeral)
                        .foregroundStyle(NoopSpecTokens.textPrimary)
                    Text(balanceState)
                        .noopText(.rowFigure)
                        .foregroundStyle(NoopSpecTokens.textQuiet)
                }

                Text(rangeCaption)
                    .noopText(.bodySmall)
                    .foregroundStyle(NoopSpecTokens.textQuiet)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var balanceFigure: String {
        guard reading.debtNightCount > 0 else { return "—" }
        return Self.durationText(abs(Int(reading.debtBalanceMinutes.rounded())))
    }

    private var balanceState: String {
        guard reading.debtNightCount > 0 else { return String(localized: "unavailable") }
        if reading.debtBalanceMinutes < 0 { return String(localized: "debt") }
        if reading.debtBalanceMinutes > 0 { return String(localized: "ahead") }
        return String(localized: "on target")
    }

    private var rangeCaption: String {
        guard reading.debtNightCount > 0 else { return String(localized: "No recorded nights yet") }
        return String(localized: "Over the last \(reading.debtNightCount) recorded nights")
    }

    private var stripCard: some View {
        NoopSpecCard(.standard) {
            VStack(alignment: .leading, spacing: 14) {
                NoopSpecCaption("FOURTEEN-NIGHT STRIP")

                if reading.debtNights.isEmpty {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(NoopSpecTokens.subtleFill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 76)
                        .overlay {
                            Text(String(localized: "No recorded nights yet"))
                                .noopText(.subline)
                                .foregroundStyle(NoopSpecTokens.textDim)
                        }
                } else {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(reading.debtNights.prefix(14)) { item in
                            VStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(item.deltaMinutes >= 0
                                          ? NoopSpecTokens.lavender
                                          : NoopSpecTokens.controlTrack)
                                    .frame(width: 6, height: 52)
                                Text(Self.dayLetter(item.id))
                                    .noopText(.captionMicro)
                                    .foregroundStyle(NoopSpecTokens.textTertiary)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Self.ledgerAccessibility(item))
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if reading.debtNightCount < 14 {
                    Text(String(localized: "Still building a picture. Fourteen nights makes this honest."))
                        .noopText(.bodySmall)
                        .foregroundStyle(NoopSpecTokens.textQuiet)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var howItClears: some View {
        NoopSpecCard(.standard, tint: NoopSpecTokens.lavender) {
            VStack(alignment: .leading, spacing: 9) {
                NoopSpecCaption("HOW IT CLEARS", color: NoopSpecTokens.lavenderText)
                Text(String(localized: "Each recorded night adds credited sleep minus your current need. After fourteen counted nights, the oldest contribution leaves the window."))
                    .noopText(.body)
                    .foregroundStyle(NoopSpecTokens.textBody)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static func durationText(_ minutes: Int) -> String {
        let value = max(0, minutes)
        if value < 60 { return "\(value)m" }
        if value.isMultiple(of: 60) { return "\(value / 60)h" }
        return "\(value / 60)h \(value % 60)m"
    }

    private static func dayLetter(_ day: String) -> String {
        guard let date = dayParser.date(from: day) else { return "·" }
        return dayFormatter.string(from: date)
    }

    private static func ledgerAccessibility(_ night: AuraRestReading.DebtNight) -> String {
        "\(night.date), \(night.slept), \(night.change)"
    }

    private static let dayParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.activeLocale
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter
    }()
}

// MARK: - Shared pushed-screen pieces

private struct AuraRestDetailBackground: View {
    var body: some View {
        NoopSpecTokens.canvas
            .overlay(alignment: .top) {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [NoopSpecTokens.lavender.opacity(0.19), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 230
                        )
                    )
                    .frame(width: 460, height: 400)
                    .offset(y: -145)
                    .blur(radius: 18)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct AuraRestBackSwipe: Gesture {
    let action: () -> Void

    var body: some Gesture {
        DragGesture(minimumDistance: 22)
            .onEnded { value in
                guard value.translation.width > 78,
                      abs(value.translation.height) < 58 else { return }
                action()
            }
    }
}
#endif
