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

// MARK: Card header

/// A card's title and its one trailing note ("Tap a night", "Balanced", "Band is your own normal").
public struct AuraCardHeader: View {
    private let title: String
    private let note: String?
    private let noteTint: Color
    private let symbol: String?
    private let symbolTint: Color

    public init(
        title: String,
        note: String? = nil,
        noteTint: Color = AuraPalette.textQuiet,
        symbol: String? = nil,
        symbolTint: Color = AuraPalette.rest
    ) {
        self.title = title
        self.note = note
        self.noteTint = noteTint
        self.symbol = symbol
        self.symbolTint = symbolTint
    }

    public var body: some View {
        HStack(spacing: 9) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13))
                    .foregroundStyle(symbolTint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(symbolTint.opacity(0.16)))
            }
            Text(title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(AuraPalette.textPrimary)
            Spacer(minLength: 8)
            if let note {
                Text(note)
                    .font(.system(size: 11.5, weight: noteTint == AuraPalette.textQuiet ? .regular : .semibold))
                    .foregroundStyle(noteTint)
            }
        }
    }
}

// MARK: Stat tile

/// A small headline number in its own tile — "Avg sleep 6.8h", "Your normal 48ms".
public struct AuraStatTile: View {
    private let label: String
    private let value: String
    private let unit: String
    private let valueTint: Color

    public init(label: String, value: String, unit: String = "", valueTint: Color = AuraPalette.textPrimary) {
        self.label = label
        self.value = value
        self.unit = unit
        self.valueTint = valueTint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(AuraPalette.textQuiet)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .light, design: .rounded).monospacedDigit())
                    .foregroundStyle(valueTint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 13))
                        .foregroundStyle(AuraPalette.textFaint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .auraCard(cornerRadius: AuraPalette.tileRadius)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Icon tile

/// An icon, a status tag and a two-line caption — the Band and You screens' 2-up grid.
public struct AuraIconTile: View {
    private let symbol: String
    private let tint: Color
    private let tag: String
    private let title: String
    private let detail: String
    private let action: (() -> Void)?

    public init(
        symbol: String,
        tint: Color,
        tag: String,
        title: String,
        detail: String,
        action: (() -> Void)? = nil
    ) {
        self.symbol = symbol
        self.tint = tint
        self.tag = tag
        self.title = title
        self.detail = detail
        self.action = action
    }

    public var body: some View {
        Button { action?() } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 17))
                        .foregroundStyle(tint)
                    Spacer(minLength: 6)
                    Text(tag)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(AuraPalette.textQuiet)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule(style: .continuous).fill(Color.white.opacity(0.06)))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AuraPalette.textQuiet)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .auraCard(cornerRadius: AuraPalette.tileRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityElement(children: .combine)
    }
}

// MARK: List row

/// A row inside a grouped card: a key with either a value or a subtitle-and-chevron.
public struct AuraListRow: View {
    private let key: String
    private let value: String?
    private let subtitle: String?
    private let showsDivider: Bool
    private let action: (() -> Void)?

    public init(
        key: String,
        value: String? = nil,
        subtitle: String? = nil,
        showsDivider: Bool,
        action: (() -> Void)? = nil
    ) {
        self.key = key
        self.value = value
        self.subtitle = subtitle
        self.showsDivider = showsDivider
        self.action = action
    }

    public var body: some View {
        Button { action?() } label: {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(key)
                            .font(.system(size: subtitle == nil ? 14 : 14.5,
                                          weight: subtitle == nil ? .regular : .medium))
                            .foregroundStyle(subtitle == nil ? AuraPalette.textTertiary : AuraPalette.textPrimary)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 11.5))
                                .foregroundStyle(AuraPalette.textQuiet)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 8)
                    if let value {
                        Text(value)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AuraPalette.textPrimary)
                            .multilineTextAlignment(.trailing)
                    }
                    if action != nil { AuraChevron() }
                }
                .frame(minHeight: subtitle == nil ? 52 : 62)
                if showsDivider {
                    Rectangle().fill(AuraPalette.cardBorder).frame(height: 0.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityElement(children: .combine)
    }
}

// MARK: Segmented chips

/// The Trends range picker. Full-width pills rather than an inset segmented control, because the active
/// one is filled with the accent and needs the room to read as a state and not a button.
public struct AuraSegmentedChips<Value: Hashable>: View {
    private let options: [(value: Value, label: String)]
    private let selection: Value
    private let onSelect: (Value) -> Void

    public init(options: [(value: Value, label: String)], selection: Value, onSelect: @escaping (Value) -> Void) {
        self.options = options
        self.selection = selection
        self.onSelect = onSelect
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isOn = option.value == selection
                Button { onSelect(option.value) } label: {
                    Text(option.label)
                        .font(.system(size: 12.5, weight: isOn ? .semibold : .medium))
                        .foregroundStyle(isOn ? AuraPalette.onAccent : AuraPalette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(isOn ? AnyShapeStyle(AuraPalette.accent)
                                           : AnyShapeStyle(Color.white.opacity(0.06)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .strokeBorder(isOn ? Color.clear : Color.white.opacity(0.07), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            }
        }
        .animation(NoopMotion.value, value: selection)
    }
}

// MARK: Radio row

/// One choice in an exclusive group — how much Noop says.
public struct AuraRadioRow: View {
    private let title: String
    private let detail: String
    private let isOn: Bool
    private let action: () -> Void

    public init(title: String, detail: String, isOn: Bool, action: @escaping () -> Void) {
        self.title = title
        self.detail = detail
        self.isOn = isOn
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(isOn ? AuraPalette.accent : Color.clear)
                    .frame(width: 18, height: 18)
                    .overlay(
                        Circle().strokeBorder(AuraPalette.card, lineWidth: isOn ? 4 : 0)
                    )
                    .overlay(
                        Circle().strokeBorder(isOn ? AuraPalette.accent : Color.white.opacity(0.22),
                                              lineWidth: 1.5)
                    )
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(AuraPalette.textQuiet)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isOn ? Color.white.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: Note banner

/// The quieter sibling of `AuraInfoBanner`: a tinted wash instead of a solid fill, for a note that
/// belongs to a metric's own colour world rather than to the app's chrome.
public struct AuraNoteBanner: View {
    private let text: String
    private let tint: Color

    public init(text: String, tint: Color) {
        self.text = text
        self.tint = tint
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(verbatim: "i")
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundStyle(tint)
                .frame(width: 19, height: 19)
                .overlay(Circle().strokeBorder(tint.opacity(0.7), lineWidth: 1.4))
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 14))
                .lineSpacing(2)
                .foregroundStyle(AuraPalette.textPrimary.opacity(0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: AuraPalette.tileRadius, style: .continuous)
                .fill(tint.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: AuraPalette.tileRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.22), lineWidth: 0.5))
        )
    }
}

// MARK: Read card

/// "The read" — a paragraph of plain language on the coaching surface, closing a screen the way Svea's
/// call opens Today.
public struct AuraReadCard: View {
    private let overline: String
    private let text: String

    public init(overline: String, text: String) {
        self.overline = overline
        self.text = text
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "#8FDCFA"), Color(hex: "#0B6FA8")],
                                         center: UnitPoint(x: 0.34, y: 0.3), startRadius: 0, endRadius: 20))
                    .frame(width: 20, height: 20)
                Text(overline).auraOverline()
            }
            Text(text)
                .font(.system(size: 16))
                .lineSpacing(3)
                .foregroundStyle(AuraPalette.textPrimary.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .auraCard(surface: AuraCardSurface.coaching(accent: AuraPalette.accent))
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
