import SwiftUI
import StrandDesign

/// Aura's release sheet. The four 11.7 readings are fixed product copy from the final HTML; the
/// history beneath them is always rendered from `AppChangelog`, which remains the single source of
/// truth for version, date and release-entry text.
struct WhatsNewView: View {
    enum Presentation {
        case bump
        case bell
    }

    let presentation: Presentation
    let onClose: () -> Void

    init(presentation: Presentation = .bump, onClose: @escaping () -> Void) {
        self.presentation = presentation
        self.onClose = onClose
    }

    private var currentRelease: AppChangelog.Release? { AppChangelog.releases.first }

    var body: some View {
        VStack(spacing: 0) {
            // The final drawing leaves 46 pt of the screen behind the sheet visible.
            Color.clear.frame(height: 46)

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 38, height: 4)
                    .padding(.top, 11)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        releaseHeader
                        readings
                        releaseHistory
                    }
                    .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    footer
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(NoopPalette.card)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.55), radius: 24, y: -16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(NoopPalette.canvas.ignoresSafeArea())
        // The HTML positions the sheet from the physical screen edge: its 46 pt backdrop includes
        // the status-bar region, and the panel continues beneath the home indicator. Without this,
        // SwiftUI adds both safe-area insets before applying the measured geometry.
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        #if os(iOS)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
        #else
        .frame(width: 560, height: 720)
        .background(NoopPalette.canvas)
        #endif
    }

    private var releaseHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Text(presentation == .bell ? "Version notes" : "New")
                    .font(NoopSpecType.captionMicro)
                    .tracking(1.045)
                    .textCase(.uppercase)
                    .foregroundStyle(presentation == .bell ? NoopSpecTokens.textBody : NoopSpecTokens.auraPale)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        presentation == .bell
                            ? Color.white.opacity(0.07)
                            : NoopPalette.accent.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )

                if let currentRelease {
                    Text(releaseStamp(currentRelease))
                        .font(NoopSpecType.subline)
                        .foregroundStyle(NoopPalette.textQuiet)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(presentation == .bell ? "What 11.7 brought." : "Noop is Noop Aura now.")
                    .font(.custom(NoopSpecType.Face.outfitLight, size: 27))
                    .tracking(-0.81)
                    .foregroundStyle(NoopPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    presentation == .bell
                        ? "The four readings from this version, and every version before it."
                        : "The name changed because the app did. Four things are worth a minute; the rest is in the list below."
                )
                .font(NoopSpecType.body)
                .foregroundStyle(NoopPalette.textSecondary)
                .lineSpacing(NoopSpecType.lineSpacing(
                    size: 13.5,
                    cssLineHeight: 1.6,
                    face: NoopSpecType.Face.sansRegular
                ))
                .fixedSize(horizontal: false, vertical: true)
            }
            // Chrome draws these glyph bounds two points higher at the same measured sizes. Move
            // only the ink so the block keeps the HTML's height and the readings stay anchored.
            .offset(y: -2)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
    }

    private var readings: some View {
        VStack(spacing: 0) {
            releaseReading(
                icon: .lift,
                title: "The lift",
                detail: "Strength has its own place now: your programs, a screen built for the set you are in, and what each session actually loaded. Every target is optional — a line can be nothing but an exercise name.",
                first: true
            )
            releaseReading(
                icon: .gauge,
                title: "What the day cost",
                detail: "Today carries an estimate of what you spent, as a range rather than a figure. It will never set a number for you to eat against."
            )
            releaseReading(
                icon: .trends,
                title: "What changed",
                detail: "Trends opens with what moved since you last looked. Twelve kinds of finding, and nothing in the list needs answering."
            )
            releaseReading(
                icon: .mic,
                title: "Speak to Svea",
                detail: "Hold the mic in a conversation and talk instead of typing. Voice is how you say it; Manner is still how she writes back."
            )
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
    }

    private func releaseReading(
        icon: ReleaseReadingIcon,
        title: String,
        detail: String,
        first: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            releaseIcon(icon)
                .frame(width: 34, height: 34)
                .background(NoopPalette.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(NoopPalette.accent.opacity(0.18), lineWidth: 0.5)
                }

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(NoopSpecType.cardTitle)
                    .foregroundStyle(NoopPalette.textPrimary)
                Text(detail)
                    .font(.custom(NoopSpecType.Face.sansRegular, size: 12.5))
                    .foregroundStyle(NoopPalette.textSecondary)
                    .lineSpacing(NoopSpecType.lineSpacing(
                        size: 12.5,
                        cssLineHeight: 1.6,
                        face: NoopSpecType.Face.sansRegular
                    ))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // SwiftUI matches the requested baselines but omits CSS's edge leading around multiline
        // text. Preserve it here so the six-point row-height loss does not compound down the list.
        .padding(.top, 16)
        .padding(.bottom, 18)
        .overlay(alignment: .top) {
            if !first {
                Rectangle()
                    .fill(NoopSpecTokens.hairline)
                    .frame(height: 0.5)
            }
        }
    }

    private var releaseHistory: some View {
        LazyVStack(alignment: .leading, spacing: 11) {
            Text("Every version")
                .font(NoopSpecType.caption)
                .tracking(NoopSpecType.Tracking.caption)
                .textCase(.uppercase)
                .foregroundStyle(NoopPalette.textFaint)

            ForEach(Array(AppChangelog.releases.enumerated()), id: \.offset) { index, release in
                if beginsYear(index) {
                    Text(releaseYear(release.date) ?? release.date)
                        .font(NoopSpecType.caption)
                        .tracking(NoopSpecType.Tracking.caption)
                        .foregroundStyle(NoopPalette.textQuiet)
                        .padding(.top, index == 0 ? 0 : 8)
                }
                historyCard(release, installed: index == 0)
            }

            Text("The versions and their dates are real. The entries under each come from the release feed; none is invented for this screen.")
                .font(NoopSpecType.subline)
                .foregroundStyle(NoopPalette.textQuiet)
                .lineSpacing(NoopSpecType.lineSpacing(
                    size: 11.5,
                    cssLineHeight: 1.65,
                    face: NoopSpecType.Face.sansRegular
                ))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
    }

    private func historyCard(_ release: AppChangelog.Release, installed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(displayVersion(release.version))
                    .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(NoopSpecTokens.textBody)
                Text(release.date)
                    .font(NoopSpecType.subline)
                    .foregroundStyle(NoopPalette.textQuiet)
                if installed {
                    Text("installed")
                        .font(NoopSpecType.captionMicro)
                        .tracking(0.9)
                        .textCase(.uppercase)
                        .foregroundStyle(NoopSpecTokens.auraPale)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(NoopPalette.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                Spacer(minLength: 0)
            }

            Text(LocalizedStringKey(release.title))
                .font(NoopSpecType.rowLabelStrong)
                .foregroundStyle(NoopPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(release.items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(NoopPalette.accent.opacity(0.72))
                        .frame(width: 4, height: 4)
                        .padding(.top, 7)
                    Text(LocalizedStringKey(item))
                        .font(NoopSpecType.subline)
                        .foregroundStyle(NoopPalette.textSecondary)
                        .lineSpacing(NoopSpecType.lineSpacing(
                            size: 11.5,
                            cssLineHeight: 1.55,
                            face: NoopSpecType.Face.sansRegular
                        ))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.028), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.055), lineWidth: 0.5)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Button(action: onClose) {
                Text(presentation == .bell ? "Done" : "Start using it")
                    .font(.custom(NoopSpecType.Face.sansSemiBold, size: 15))
                    .foregroundStyle(NoopSpecTokens.onAura)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(NoopPalette.accent, in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .shadow(color: NoopPalette.accent.opacity(0.28), radius: 13, y: 8)
            }
            .buttonStyle(.plain)

            Text(
                presentation == .bell
                    ? "Kept in the bell for as long as the version is installed."
                    : "Shown once. After this it lives in the bell, without the New on it."
            )
            .font(NoopSpecType.finePrint)
            .foregroundStyle(NoopPalette.textQuiet)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(minHeight: 17.6)
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 26)
        .background {
            LinearGradient(
                stops: [
                    .init(color: NoopPalette.card.opacity(0), location: 0),
                    .init(color: NoopPalette.card, location: 0.38),
                    .init(color: NoopPalette.card, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
    }

    @ViewBuilder
    private func releaseIcon(_ icon: ReleaseReadingIcon) -> some View {
        #if os(iOS)
        NoopCanonicalGlyph(name: icon.canonicalName, size: 19, color: NoopPalette.accent)
        #else
        Image(systemName: icon.systemName)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(NoopPalette.accent)
        #endif
    }

    /// The changelog is already an ordered array (“Newest first”). Iterating that array with its
    /// source index keeps versions and their entries stable; the only visual grouping is the year.
    private func beginsYear(_ index: Int) -> Bool {
        guard AppChangelog.releases.indices.contains(index) else { return false }
        guard index > 0 else { return true }
        return releaseYear(AppChangelog.releases[index].date)
            != releaseYear(AppChangelog.releases[index - 1].date)
    }

    private func releaseYear(_ date: String) -> String? {
        date.split(separator: " ")
            .map(String.init)
            .last(where: { token in
                token.count == 4 && token.allSatisfy(\.isNumber)
            })
    }

    /// The HTML speaks release families (`11.7`) while the feed stores patch-qualified versions
    /// (`11.7.0`). Keep two-component versions such as `1.0` intact.
    private func displayVersion(_ raw: String) -> String {
        let parts = raw.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts.last == "0" else { return raw }
        return parts.dropLast().joined(separator: ".")
    }

    private func releaseStamp(_ release: AppChangelog.Release) -> String {
        let version = displayVersion(release.version)
        // The 11.7 Aura presentation landed on 17 September (the date is also in this branch's
        // history). The imported upstream feed stores only its month, so retain that source value
        // for every other version rather than inventing a day.
        return version == "11.7" ? "11.7 · 17 September" : "\(version) · \(release.date)"
    }
}

private enum ReleaseReadingIcon {
    case lift, gauge, trends, mic

    #if os(iOS)
    var canonicalName: NoopCanonicalGlyphName {
        switch self {
        case .lift: .weight
        case .gauge: .gauge
        case .trends: .trends
        case .mic: .mic
        }
    }
    #else
    var systemName: String {
        switch self {
        case .lift: "dumbbell"
        case .gauge: "gauge.with.dots.needle.50percent"
        case .trends: "chart.bar.xaxis"
        case .mic: "mic"
        }
    }
    #endif
}
