import SwiftUI
import StrandDesign
import Foundation

/// The full-screen Noop Aura clickwrap. It sits above onboarding, pairing and Bluetooth until the
/// current terms version is accepted. The visual source of truth is `plumbing/terms` in the final
/// Act 5 HTML; the agreement text itself is always read from the bundled `TERMS.md`.
struct TermsGateView: View {
    let onAccept: () -> Void

    @AppStorage("noop.acceptedTermsVersion") private var previouslyAcceptedVersion = ""
    @State private var checks = Array(repeating: false, count: 4)

    private let changedSectionNumbers: Set<Int> = [7, 8]

    private var document: TermsDocument.Document? { TermsDocument.bundled }
    private var isUpdate: Bool {
        !previouslyAcceptedVersion.isEmpty && previouslyAcceptedVersion != Terms.currentVersion
    }
    private var allChecked: Bool { checks.allSatisfy { $0 } }

    var body: some View {
        ZStack {
            NoopPalette.canvas.ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    introduction

                    if isUpdate {
                        changedNotice
                            .padding(.horizontal, 22)
                            .padding(.top, 18)
                    }

                    summaryCard
                        .padding(.horizontal, 22)
                        .padding(.top, 18)

                    Text("That is the summary, and the summary is not the agreement. The nine sections below are, and they are what you are accepting.")
                        .noopText(NoopSpecType.Role.bodySmall)
                        .foregroundStyle(NoopPalette.textQuiet)
                        .padding(.horizontal, 24)
                        .padding(.top, 15)

                    agreement
                        .padding(.horizontal, 22)
                        .padding(.top, 22)

                    attestations
                        .padding(.horizontal, 22)
                        .padding(.top, 26)

                    gateLine
                        .padding(.horizontal, 24)
                        .padding(.top, 13)
                        .padding(.bottom, 18)
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            #if os(iOS)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            #endif
            .safeAreaInset(edge: .bottom, spacing: 0) {
                actionBar
            }
        }
        .preferredColorScheme(.dark)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 9) {
                Text(isUpdate ? "UPDATED" : "BEFORE YOU START")
                    .font(NoopSpecType.Role.captionMicro.font)
                    .tracking(NoopSpecType.Role.captionMicro.tracking(at: .large))
                    .foregroundStyle(isUpdate ? NoopSpecTokens.lavenderText : NoopSpecTokens.auraPale)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (isUpdate ? NoopPalette.rest : NoopPalette.accent).opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )

                Text("version \(Terms.currentVersion)")
                    .noopText(NoopSpecType.Role.subline)
                    .foregroundStyle(NoopPalette.textQuiet)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(isUpdate ? "Two things changed in the terms." : "What you are agreeing to.")
                    .font(Font.custom(NoopSpecType.Face.outfitLight, size: 29))
                    .tracking(-0.87)
                    .lineSpacing(4)
                    .foregroundStyle(NoopPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(isUpdate
                    ? "You accepted version \(previouslyAcceptedVersion) before. Noop Aura will not carry your acceptance over on its own, so here is version \(Terms.currentVersion) with the changes marked."
                    : "Noop Aura asks for this once, and it would rather you read it than scroll past it. So the plain version is first, and it is accurate.")
                    .noopText(NoopSpecType.Role.body)
                    .foregroundStyle(NoopPalette.textSecondary)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 56)
    }

    private var changedNotice: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Two sections changed")
                .noopText(NoopSpecType.Role.buttonLabel)
                .foregroundStyle(NoopPalette.textPrimary)
            Text("Your acknowledgment, which is now four statements ticked one at a time instead of one blanket box, and WHOOP personnel, which was a polite request and is now backed by the first of those statements. Both are marked below. Everything else is word for word what you accepted before.")
                .noopText(NoopSpecType.Role.bodySmall)
                .foregroundStyle(NoopPalette.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(NoopPalette.rest.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(NoopPalette.rest.opacity(0.20), lineWidth: 0.5)
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow(.wave, "Noop Aura reads your body and tells you what it sees. It is not a doctor, and nothing it says is a diagnosis.", first: true)
            summaryRow(.independent, "It is not made by WHOOP and nobody at WHOOP supports it. It runs on your iPhone, and only on your iPhone.")
            summaryRow(.shield, "Your nights, sessions and logs stay on this phone and in your own iCloud. Noop Aura keeps no copy of them.")
            summaryRow(.cloud, "Nothing reaches Svea until you turn her on, and you choose what she may read, purpose by purpose.")
            summaryRow(.download, "You can export everything, or delete everything, from one screen, without asking anyone first.")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 3)
        .background(NoopPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(NoopPalette.cardBorder, lineWidth: 0.5)
        }
    }

    private func summaryRow(_ symbol: TermsSummarySymbol, _ text: String, first: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 11) {
            TermsSummaryGlyph(symbol: symbol)
                .frame(width: 16, height: 16)
                .padding(.top, 2)
            Text(text)
                .noopText(NoopSpecType.Role.bodySmall)
                .foregroundStyle(NoopSpecTokens.textBody)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            if !first {
                Rectangle().fill(NoopSpecTokens.hairline).frame(height: 0.5)
            }
        }
    }

    @ViewBuilder
    private var agreement: some View {
        if let document {
            VStack(alignment: .leading, spacing: 22) {
                if !document.preamble.isEmpty {
                    legalText(document.preamble)
                }

                ForEach(document.sections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(String(format: "%02d", section.number ?? 0))
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(NoopPalette.textQuiet)

                            Text(section.heading)
                                .noopText(NoopSpecType.Role.rowLabelStrong)
                                .foregroundStyle(NoopPalette.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let number = section.number,
                               isUpdate,
                               changedSectionNumbers.contains(number) {
                                Text("CHANGED")
                                    .font(NoopSpecType.Role.captionMicro.font)
                                    .tracking(0.95)
                                    .foregroundStyle(NoopSpecTokens.lavenderText)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(NoopPalette.rest.opacity(0.16), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                            }
                        }

                        legalText(section.body)
                    }
                }

                if !document.closing.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Rectangle().fill(NoopSpecTokens.hairline).frame(height: 0.5)
                        Text("IN CLOSING")
                            .noopText(NoopSpecType.Role.caption)
                            .foregroundStyle(NoopPalette.textFaint)
                            .padding(.top, 8)
                        legalText(document.closing)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Text("The agreement could not be opened on this build.")
                    .noopText(NoopSpecType.Role.rowLabelStrong)
                    .foregroundStyle(NoopPalette.textPrimary)
                Text("Noop Aura will not ask you to accept text it cannot show. Reinstall this build and try again.")
                    .noopText(NoopSpecType.Role.bodySmall)
                    .foregroundStyle(NoopPalette.textSecondary)
            }
        }
    }

    private func legalText(_ markdown: String) -> some View {
        Text((try? AttributedString(markdown: markdown)) ?? AttributedString(markdown))
            .noopText(NoopSpecType.Role.bodySmall)
            .foregroundStyle(NoopSpecTokens.textBody)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var attestations: some View {
        VStack(spacing: 0) {
            attestationRow(0, "I am not WHOOP staff, and I will not ask anyone at WHOOP to support Noop Aura.", first: true)
            attestationRow(1, "This is my device, my data and my risk.")
            attestationRow(2, "Noop Aura is unofficial, given as-is, and not a medical device.")
            attestationRow(3, "I will not hold its author liable for anything that follows from using it.")
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .background(NoopPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(NoopPalette.cardBorder, lineWidth: 0.5)
        }
    }

    private func attestationRow(_ index: Int, _ text: String, first: Bool = false) -> some View {
        Button {
            checks[index].toggle()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(checks[index] ? NoopPalette.accent : Color.clear)
                    .frame(width: 22, height: 22)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(checks[index] ? NoopPalette.accent : Color.white.opacity(0.24), lineWidth: 0.5)
                    }
                    .overlay {
                        if checks[index] {
                            TermsCheckmark()
                                .stroke(NoopSpecTokens.onAura, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
                                .frame(width: 13, height: 13)
                        }
                    }

                Text(text)
                    .noopText(NoopSpecType.Role.buttonLabel)
                    .foregroundStyle(checks[index] ? NoopPalette.textPrimary : NoopSpecTokens.textBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 48)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if !first {
                    Rectangle().fill(NoopSpecTokens.hairline).frame(height: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityValue(checks[index] ? "Checked" : "Unchecked")
    }

    private var gateLine: some View {
        Text(allChecked
            ? "All four ticked. Accept is live, and accepting writes which version you accepted and when to this phone."
            : "Accept turns on when all four are ticked. Noop Aura will not tick them for you, and it does not ask how far you scrolled.")
            .noopText(NoopSpecType.Role.subline)
            .foregroundStyle(allChecked ? NoopSpecTokens.auraLight : NoopPalette.textQuiet)
    }

    private var actionBar: some View {
        VStack(spacing: 6) {
            Button(action: onAccept) {
                Text(isUpdate ? "Accept the changes" : "Accept and continue")
                    .font(NoopSpecType.Role.buttonLabel.font)
                    .foregroundStyle(allChecked ? NoopSpecTokens.onAura : NoopPalette.textQuiet)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(
                        allChecked ? NoopPalette.accent : Color.white.opacity(0.05),
                        in: RoundedRectangle(cornerRadius: 19, style: .continuous)
                    )
                    .overlay {
                        if !allChecked {
                            RoundedRectangle(cornerRadius: 19, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                        }
                    }
                    .shadow(color: allChecked ? NoopPalette.accent.opacity(0.28) : .clear, radius: 13, x: 0, y: 8)
            }
            .buttonStyle(.plain)
            .disabled(!allChecked || document == nil)

            Text(isUpdate ? "Not now" : "I would rather not")
                .noopText(NoopSpecType.Role.bodySmall)
                .foregroundStyle(NoopPalette.textQuiet)
                .frame(height: 42)

            Text(isUpdate
                ? "Not now keeps you on the version you accepted and leaves Noop Aura closed. Nothing already recorded is touched, and nothing is deleted."
                : "Declining leaves Noop Aura closed and nothing has been collected yet. There is no account to cancel and no data to remove.")
                .noopText(NoopSpecType.Role.finePrint)
                .foregroundStyle(NoopPalette.textQuiet)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
        .padding(.bottom, 10)
        .background {
            LinearGradient(
                // Fade only across the bar's 20 pt top padding, so the agreement never shows through
                // the button (it did while the fade ran to 30% of the bar).
                stops: [
                    .init(color: NoopPalette.canvas.opacity(0), location: 0),
                    .init(color: NoopPalette.canvas, location: 0.11),
                    .init(color: NoopPalette.canvas, location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private enum TermsSummarySymbol {
    case wave, independent, shield, cloud, download
}

private struct TermsSummaryGlyph: View {
    let symbol: TermsSummarySymbol

    var body: some View {
        #if os(iOS)
        NoopCanonicalGlyph(name: canonical, size: 16, color: NoopPalette.accent)
        #else
        Image(systemName: fallback)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(NoopPalette.accent)
        #endif
    }

    #if os(iOS)
    private var canonical: NoopCanonicalGlyphName {
        switch symbol {
        case .wave: .wave
        case .independent: .x
        case .shield: .shield
        case .cloud: .cloud
        case .download: .download
        }
    }
    #else
    private var fallback: String {
        switch symbol {
        case .wave: "waveform.path.ecg"
        case .independent: "xmark"
        case .shield: "shield"
        case .cloud: "cloud"
        case .download: "arrow.down"
        }
    }
    #endif
}

private struct TermsCheckmark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.52))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.42, y: rect.minY + rect.height * 0.75))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.84, y: rect.minY + rect.height * 0.27))
        return path
    }
}
