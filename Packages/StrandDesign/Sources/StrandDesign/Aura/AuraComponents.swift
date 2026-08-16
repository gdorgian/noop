#if !os(watchOS)
import SwiftUI

// MARK: - Aura components
//
// The repeating parts of an Aura screen. They live in the design system rather than beside the screen
// because Rest / Charge / Effort / Trends all reuse them, and because this is the only layer with CI:
// `swift-packages.yml` compiles and tests `Packages/**`, whereas nothing compiles the app targets by
// default. Anything that can live here, should.

// MARK: Card surface

/// The Aura card: a flat dark fill with a hairline edge. Deliberately NOT `NoopPanelSurface` — that
/// carries a top-lit gradient and elevation shadow tuned for the Titanium chrome, which reads as a raised
/// tile. Aura's cards sit flat in the scene so the orb is the only thing with depth on the screen.
public struct AuraCardSurface: View {
    private let cornerRadius: CGFloat
    private let fill: AnyShapeStyle
    private let borderColor: Color

    public init(
        cornerRadius: CGFloat = AuraPalette.cardRadius,
        fill: AnyShapeStyle = AnyShapeStyle(AuraPalette.card),
        borderColor: Color = AuraPalette.cardBorder
    ) {
        self.cornerRadius = cornerRadius
        self.fill = fill
        self.borderColor = borderColor
    }

    /// The coaching card's variant: a soft diagonal gradient with an accent-tinted edge.
    public static func coaching(accent: Color) -> AuraCardSurface {
        AuraCardSurface(
            fill: AnyShapeStyle(
                LinearGradient(
                    colors: [AuraPalette.coachSurfaceTop, AuraPalette.coachSurfaceBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            ),
            borderColor: accent.opacity(0.2)
        )
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 0.5)
            )
    }
}

public extension View {
    /// Wraps content in the Aura card treatment.
    func auraCard(
        cornerRadius: CGFloat = AuraPalette.cardRadius,
        surface: AuraCardSurface? = nil
    ) -> some View {
        background(surface ?? AuraCardSurface(cornerRadius: cornerRadius))
    }
}

// MARK: Hatched track

/// The diagonal hatch behind a pillar's fill bar. A striped track reads as "capacity" where a flat one
/// reads as an empty bar, which matters when the fill is the only quantity on the card.
public struct AuraHatchTrack: Shape {
    /// Slant of the stripes, in degrees from vertical.
    private let angle: Double
    private let stripeWidth: CGFloat
    private let spacing: CGFloat

    public init(angle: Double = 25, stripeWidth: CGFloat = 3, spacing: CGFloat = 3) {
        self.angle = angle
        self.stripeWidth = stripeWidth
        self.spacing = spacing
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let period = stripeWidth + spacing
        guard period > 0, rect.width > 0, rect.height > 0 else { return path }
        // Shear each stripe by the height it spans, and start far enough left that the slanted stripes
        // still cover the leading edge.
        let shear = CGFloat(tan(angle * .pi / 180)) * rect.height
        var x = rect.minX - shear - period
        while x < rect.maxX + period {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + shear, y: rect.minY))
            path.addLine(to: CGPoint(x: x + shear + stripeWidth, y: rect.minY))
            path.addLine(to: CGPoint(x: x + stripeWidth, y: rect.maxY))
            path.closeSubpath()
            x += period
        }
        return path
    }
}

// MARK: Pillar card

/// One of the three pillars under the orb — Rest, Charge, Effort. Carries a value and a filled bar, and
/// nothing else: the pillar is a door to its own screen, not a summary of it.
public struct AuraPillarCard: View {
    private let title: String
    private let value: String
    private let unit: String
    private let fraction: Double
    private let tint: Color
    private let action: () -> Void

    public init(
        title: String,
        value: String,
        unit: String = "",
        fraction: Double,
        tint: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.value = value
        self.unit = unit
        self.fraction = fraction
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                Text(title)
                    .font(StrandFont.overlineScaled(10))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(AuraPalette.textFaint)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(StrandFont.number(20, weight: .regular))
                        .foregroundStyle(AuraPalette.textPrimary)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(StrandFont.footnote)
                            .foregroundStyle(AuraPalette.textFaint)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                bar
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 13)
            .padding(.bottom, 14)
            .auraCard(cornerRadius: AuraPalette.pillarRadius)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(title), \(value) \(unit)"))
        .accessibilityAddTraits(.isButton)
    }

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                AuraHatchTrack()
                    .fill(Color.white.opacity(0.07))
                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(width: geo.size.width * AuraGaugeMath.clampFraction(fraction))
            }
        }
        .frame(height: 7)
        .clipShape(Capsule(style: .continuous))
    }
}

// MARK: Signal row

/// A vitals row: name, value, a bare trend line, and a chevron through to the detail. The sparkline here
/// is intentionally stripped — no area wash, no head dot, no hover — because four of these stack up and
/// any one of them competing with the orb would break the screen's single focal point.
public struct AuraSignalRow: View {
    private let name: String
    private let value: String
    private let unit: String
    private let systemImage: String
    private let tint: Color
    private let series: [Double]
    private let showsDivider: Bool
    private let action: () -> Void

    public init(
        name: String,
        value: String,
        unit: String,
        systemImage: String,
        tint: Color,
        series: [Double],
        showsDivider: Bool,
        action: @escaping () -> Void
    ) {
        self.name = name
        self.value = value
        self.unit = unit
        self.systemImage = systemImage
        self.tint = tint
        self.series = series
        self.showsDivider = showsDivider
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(tint)
                        .frame(width: 21, height: 21)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(StrandFont.footnote)
                            .foregroundStyle(AuraPalette.textQuiet)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(value)
                                .font(StrandFont.number(18, weight: .regular))
                                .foregroundStyle(AuraPalette.textPrimary)
                            Text(unit)
                                .font(StrandFont.footnote)
                                .foregroundStyle(AuraPalette.textFaint)
                        }
                    }
                    Spacer(minLength: 8)
                    Sparkline(
                        values: series,
                        gradient: Gradient(colors: [tint, tint]),
                        lineWidth: 1.6,
                        showsArea: false,
                        showsHead: false,
                        showsHover: false
                    )
                    .frame(width: 56, height: 22)
                    .accessibilityHidden(true)
                    AuraChevron()
                }
                .frame(minHeight: 62)
                if showsDivider {
                    Rectangle()
                        .fill(AuraPalette.cardBorder)
                        .frame(height: 0.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(name), \(value) \(unit)"))
        .accessibilityAddTraits(.isButton)
    }
}

/// The round disc-and-chevron affordance used at the end of a tappable row.
public struct AuraChevron: View {
    public init() {}

    public var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(AuraPalette.textSecondary)
            .frame(width: 28, height: 28)
            .background(Circle().fill(AuraPalette.controlFill))
    }
}

// MARK: Info banner

/// The screen's one closing note, on a solid accent fill. Solid rather than tinted because it is the last
/// thing on the screen and has to hold its own against the orb at the top.
public struct AuraInfoBanner: View {
    private let text: String
    private let accent: Color

    public init(text: String, accent: Color) {
        self.text = text
        self.accent = accent
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(verbatim: "i")
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundStyle(AuraPalette.onAccent)
                .frame(width: 19, height: 19)
                .overlay(Circle().strokeBorder(AuraPalette.onAccent.opacity(0.55), lineWidth: 1.4))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.onAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: AuraPalette.tileRadius, style: .continuous)
                .fill(accent)
        )
    }
}

// MARK: Overline

public extension Text {
    /// Aura's section label: small, wide-tracked, all-caps, and quiet enough to be scanned past.
    func auraOverline() -> some View {
        font(StrandFont.overlineScaled(10))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(AuraPalette.textQuiet)
    }
}

#if DEBUG
#Preview("Aura components") {
    ScrollView {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                AuraPillarCard(title: "Rest", value: "7h 12m", fraction: 0.96, tint: AuraPalette.rest) {}
                AuraPillarCard(title: "Charge", value: "56", unit: "ms", fraction: 0.78,
                               tint: AuraBodyState.restored.accent) {}
                AuraPillarCard(title: "Effort", value: "6.2", unit: "/12", fraction: 0.52,
                               tint: AuraPalette.effort) {}
            }
            VStack(spacing: 0) {
                AuraSignalRow(name: "Heart rate", value: "58", unit: "bpm", systemImage: "heart",
                              tint: AuraBodyState.restored.accent,
                              series: [62, 60, 59, 61, 58, 57, 58, 58], showsDivider: true) {}
                AuraSignalRow(name: "Variability", value: "56", unit: "ms", systemImage: "waveform.path.ecg",
                              tint: AuraBodyState.restored.accent,
                              series: [44, 48, 46, 51, 49, 54, 53, 56], showsDivider: false) {}
            }
            .padding(.horizontal, 16)
            .auraCard()
            AuraInfoBanner(text: "Your variability is 17% above your own 30-day normal.",
                           accent: AuraBodyState.restored.accent)
        }
        .padding(20)
    }
    .background(AuraPalette.canvas)
}
#endif
#endif
