import SwiftUI
import StrandDesign

/// First-run acknowledgment gate (clickwrap). Shown over EVERYTHING — before onboarding, pairing, or
/// any Bluetooth access — until the current `Terms.currentVersion` is accepted, and again if the
/// terms materially change. The user must tick the (un-pre-checked) box and tap Accept; the accepted
/// version is then stored locally, the on-device equivalent of a consent record. See `Terms` / `TERMS.md`.
struct TermsGateView: View {
    let onAccept: () -> Void
    /// One flag per `Terms.attestations` entry; every one must be ticked before Accept enables.
    @State private var checks: [Bool] = Array(repeating: false, count: Terms.attestations.count)

    private var allChecked: Bool { checks.allSatisfy { $0 } }

    var body: some View {
        // The 560 × 720 card is a desktop size. A vertical ScrollView reports its content's ideal
        // width upward, so on a phone the VStack grew toward 560, overflowed the 402 pt screen and
        // was centred by the ZStack — clipping the copy at BOTH edges and putting half of each
        // toggle off-screen, which made the gate impossible to accept by tapping. Clamping to the
        // container keeps the desktop card and makes the phone use the width it actually has.
        GeometryReader { proxy in
            content(maxWidth: min(560, proxy.size.width), maxHeight: min(720, proxy.size.height))
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func content(maxWidth: CGFloat, maxHeight: CGFloat) -> some View {
        ZStack {
            StrandPalette.surfaceBase.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text("Before you use Noop Aura")
                        .font(StrandFont.title1)
                        .foregroundStyle(StrandPalette.textPrimary)
                    Text("Please read the points below, then confirm each statement.")
                        .font(StrandFont.subhead)
                        .foregroundStyle(StrandPalette.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 36)
                .padding(.bottom, 22)

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Terms.points, id: \.0) { point in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(point.0)
                                    .font(StrandFont.headline)
                                    .foregroundStyle(StrandPalette.textPrimary)
                                Text(point.1)
                                    .font(StrandFont.footnote)
                                    .foregroundStyle(StrandPalette.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Rectangle()
                            .fill(StrandPalette.hairline)
                            .frame(height: 1)
                            .padding(.vertical, 2)

                        Text("Please confirm each of these:")
                            .font(StrandFont.subhead)
                            .foregroundStyle(StrandPalette.textSecondary)

                        ForEach(Array(Terms.attestations.enumerated()), id: \.offset) { idx, line in
                            Toggle(isOn: Binding(get: { checks[idx] }, set: { checks[idx] = $0 })) {
                                Text(line)
                                    .font(StrandFont.footnote)
                                    .foregroundStyle(StrandPalette.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            #if os(macOS)
                            .toggleStyle(.checkbox)   // iOS falls back to the default switch toggle
                            #endif
                        }

                        Text("The full terms are in TERMS.md, shipped with Noop Aura. This is not legal advice.")
                            .font(StrandFont.footnote)
                            .foregroundStyle(StrandPalette.textTertiary)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 18)
                }

                Rectangle()
                    .fill(StrandPalette.hairline)
                    .frame(height: 1)

                Button(action: onAccept) {
                    Text("Accept & Continue")
                        .font(StrandFont.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent)
                .tint(StrandPalette.accent)
                .disabled(!allChecked)
                .keyboardShortcut(.defaultAction)
                .padding(26)
            }
            .frame(maxWidth: maxWidth, maxHeight: maxHeight)
        }
    }
}
