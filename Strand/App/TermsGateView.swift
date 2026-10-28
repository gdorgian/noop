import SwiftUI
import StrandDesign
import Foundation

/// The full-screen Noop Aura clickwrap. It sits above onboarding, pairing and Bluetooth until the
/// current terms version is accepted; the agreement text itself is always read from the bundled
/// `TERMS.md`.
///
/// Paged since 28 Oct 2026, so nothing has to be scrolled to be agreed to: the plain summary first,
/// then each of the four statements on a page of its own with its binding wording beneath it and its
/// own "I agree" always in reach. Each agreement is a separate, deliberate act, as the four ticks
/// were; the last one accepts. The full agreement is one tap away on every page.
struct TermsGateView: View {
    let onAccept: () -> Void

    @AppStorage("noop.acceptedTermsVersion") private var previouslyAcceptedVersion = ""
    @State private var checks = Array(repeating: false, count: 4)
    /// 0 is the summary; 1…4 are the statements.
    @State private var page = 0
    @State private var forward = true
    @State private var readingAgreement = false

    /// The four statements in plain words, each over its binding wording from `Terms.attestations`.
    private static let statements = [
        "I am not WHOOP staff, and I will not ask anyone at WHOOP to support Noop Aura.",
        "This is my device, my data and my risk.",
        "Noop Aura is unofficial, given as-is, and not a medical device.",
        "I will not hold its author liable for anything that follows from using it.",
    ]

    private let changedSectionNumbers: Set<Int> = [7, 8]

    private var document: TermsDocument.Document? { TermsDocument.bundled }
    private var isUpdate: Bool {
        !previouslyAcceptedVersion.isEmpty && previouslyAcceptedVersion != Terms.currentVersion
    }

    var body: some View {
        ZStack {
            NoopPalette.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                progress
                    .padding(.horizontal, 22)
                    .padding(.top, 14)
                Group {
                    if page == 0 { summaryPage } else { statementPage(page - 1) }
                }
                .id(page)
                .transition(.asymmetric(
                    insertion: .offset(x: forward ? 28 : -28).combined(with: .opacity),
                    removal: .offset(x: forward ? -28 : 28).combined(with: .opacity)
                ))
            }
            .frame(maxWidth: 560)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $readingAgreement) { agreementSheet }
    }

    // MARK: Pages

    /// Four marks, one per statement, filling as each is agreed to. Back steps to the page before.
    private var progress: some View {
        HStack(spacing: 6) {
            Button {
                go(to: page - 1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(NoopPalette.textQuiet)
                    .frame(width: 44, height: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(page == 0 ? 0 : 1)
            .disabled(page == 0)
            .accessibilityLabel("Back")
            Spacer()
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(checks[i] ? NoopPalette.accent : Color.white.opacity(0.14))
                    .frame(width: page == i + 1 ? 22 : 7, height: 7)
            }
            .accessibilityElement()
            .accessibilityLabel("\(checks.filter { $0 }.count) of 4 agreed")
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .animation(.spring(duration: 0.4, bounce: 0.15), value: page)
        .animation(.spring(duration: 0.4, bounce: 0.15), value: checks)
    }

    private var summaryPage: some View {
        pageLayout {
            introduction
            if isUpdate { changedNotice }
            summaryCard
            fullAgreementLink
        } footer: {
            primaryButton(isUpdate ? "Review the changes" : "Continue") { go(to: 1) }
            Text(isUpdate
                ? "Not now keeps you on the version you accepted and leaves Noop Aura closed. Nothing already recorded is touched, and nothing is deleted."
                : "Declining leaves Noop Aura closed and nothing has been collected yet. There is no account to cancel and no data to remove.")
                .noopText(NoopSpecType.Role.finePrint)
                .foregroundStyle(NoopPalette.textQuiet)
                .multilineTextAlignment(.center)
        }
    }

    /// One statement: the plain sentence large, its binding wording beneath, and its own agreement.
    private func statementPage(_ index: Int) -> some View {
        pageLayout {
            VStack(alignment: .leading, spacing: 18) {
                TermsAgreeMark(agreed: checks[index])
                    .frame(width: 52, height: 52)
                Text("Statement \(index + 1) of 4")
                    .noopText(NoopSpecType.Role.subline)
                    .foregroundStyle(NoopPalette.textQuiet)
                Text(Self.statements[index])
                    .font(Font.custom(NoopSpecType.Face.outfitLight, size: 28))
                    .tracking(-0.8)
                    .lineSpacing(4)
                    .foregroundStyle(NoopPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 8) {
                    Text("IN FULL")
                        .noopText(NoopSpecType.Role.caption)
                        .foregroundStyle(NoopPalette.textFaint)
                    Text(Terms.attestations[index])
                        .noopText(NoopSpecType.Role.bodySmall)
                        .foregroundStyle(NoopSpecTokens.textBody)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(NoopPalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(NoopPalette.cardBorder, lineWidth: 0.5)
                }
                fullAgreementLink
            }
            .padding(.top, 24)
        } footer: {
            primaryButton(index == 3 ? (isUpdate ? "I agree, and accept the changes" : "I agree, and accept") : "I agree",
                          enabled: !checks[index] && document != nil) {
                agree(index)
            }
            Text(index == 3
                ? "Accepting writes which version you accepted, and when, to this phone."
                : "Each statement is agreed to on its own. Noop Aura will not agree for you.")
                .noopText(NoopSpecType.Role.finePrint)
                .foregroundStyle(NoopPalette.textQuiet)
                .multilineTextAlignment(.center)
        }
    }

    private var fullAgreementLink: some View {
        Button {
            readingAgreement = true
        } label: {
            Label("Read the full agreement", systemImage: "doc.text")
                .noopText(NoopSpecType.Role.bodySmall)
                .foregroundStyle(NoopSpecTokens.auraLight)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var agreementSheet: some View {
        NavigationStack {
            ScrollView {
                agreement
                    .padding(.horizontal, 22)
                    .padding(.vertical, 20)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
            }
            .background(NoopPalette.canvas)
            .navigationTitle("The agreement")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { readingAgreement = false }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// A page whose content scrolls only if a small screen needs it, over a footer that never moves.
    private func pageLayout<Content: View, Footer: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) { content() }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            #if os(iOS)
            .scrollBounceBehavior(.basedOnSize)
            #endif
            VStack(spacing: 10) { footer() }
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
        }
    }

    private func primaryButton(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(NoopSpecType.Role.buttonLabel.font)
                .foregroundStyle(NoopSpecTokens.onAura)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(NoopPalette.accent, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                .shadow(color: NoopPalette.accent.opacity(0.28), radius: 13, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
    }

    private func go(to target: Int) {
        guard (0...4).contains(target) else { return }
        forward = target > page
        withAnimation(.snappy(duration: 0.28)) { page = target }
    }

    /// The statement is ticked where it stands, then the next one comes; the last accepts.
    private func agree(_ index: Int) {
        withAnimation(.spring(duration: 0.4, bounce: 0.4)) { checks[index] = true }
        #if os(iOS)
        NoopHaptics.play(.add)
        #endif
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            if index == 3 {
                if checks.allSatisfy({ $0 }) { onAccept() }
            } else {
                go(to: index + 2)
            }
        }
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
                    : "Noop Aura asks for this once. The plain version is first, and it is accurate; then four short statements, each agreed to on its own.")
                    .noopText(NoopSpecType.Role.body)
                    .foregroundStyle(NoopPalette.textSecondary)
            }
        }
        .padding(.top, 24)
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

    /// Full-syntax `AttributedString(markdown:)` drops the break between paragraphs ("§6).By installing"),
    /// so each paragraph and list item is parsed for inline emphasis only and laid out on its own.
    private func legalText(_ markdown: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Self.legalBlocks(markdown).enumerated()), id: \.offset) { _, block in
                Text((try? AttributedString(markdown: block)) ?? AttributedString(block))
                    .noopText(NoopSpecType.Role.bodySmall)
                    .foregroundStyle(NoopSpecTokens.textBody)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// Paragraphs split on blank lines, list items split on their markers, quote markers and soft wraps removed.
    static func legalBlocks(_ markdown: String) -> [String] {
        var blocks: [String] = []
        var current: [String] = []
        func flush() {
            if !current.isEmpty { blocks.append(current.joined(separator: " ")) }
            current = []
        }
        for raw in markdown.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(">") { line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces) }
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flush()
                line = "•  " + line.dropFirst(2)
            }
            current.append(line)
        }
        flush()
        return blocks
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

/// A statement's mark: an empty ring, filling with the accent and drawing its tick when agreed to.
private struct TermsAgreeMark: View {
    let agreed: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(agreed ? NoopPalette.accent : Color.white.opacity(0.24), lineWidth: 1.5)
            Circle()
                .fill(NoopPalette.accent)
                .scaleEffect(agreed ? 1 : 0.3)
                .opacity(agreed ? 1 : 0)
            TermsCheckmark()
                .trim(from: 0, to: agreed ? 1 : 0)
                .stroke(NoopSpecTokens.onAura, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .padding(14)
        }
        .animation(.spring(duration: 0.45, bounce: 0.35), value: agreed)
        .accessibilityHidden(true)
    }
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
