#if os(iOS)
import SwiftUI

// NoopSystem — the one place sizes are decided.
//
// Screens choose from these and never set a font size, control height, corner radius or spacing value of
// their own. The structure follows how mature SwiftUI design systems are organised (tokens first, then a
// small set of components that only take a size and a variant), and the values follow Apple's iOS text
// styles and 44 pt hit-area rule. Colours and font families stay in NoopDesign (`NoopHTMLColor`,
// `NoopHTMLFont`); this file decides how big things are and how they pair.

// MARK: - Tokens

/// The type scale. The roles are the 11.7 handoff's (`NoopSpecType`: caption, subline, row label, row
/// title, card title…), set larger than the handoff draws them — the owner chose a roomier, Bevel-like
/// read (24 Oct 2026) — so the hierarchy is the designer's and the sizes are Apple-sized. Every screen
/// uses a step, never a number, so the whole app moves together when a step changes.
enum NoopType {
    /// Uppercase section captions, chart axes, badges. (Handoff caption 10.)
    static let eyebrow: CGFloat = 12
    /// Sub-lines under a row or value: units, dates, explanations. (Handoff subline 11.5.)
    static let caption: CGFloat = 14
    /// Row labels and supporting copy. (Handoff rowLabel / body 13.5.)
    static let footnote: CGFloat = 15
    /// Row titles, button labels, table values. (Handoff cardTitle 14, buttonLabel 12.5.)
    static let subhead: CGFloat = 17
    /// Card titles and primary values in a row. (Handoff rowFigure 17.)
    static let body: CGFloat = 18
    /// Values inside cards, section heads. (Handoff sectionHead 19, headline 23.)
    static let title3: CGFloat = 24
    /// Page values and screen titles. (Handoff screenTitle 25.)
    static let title2: CGFloat = 30
    /// The largest numbers.
    static let title1: CGFloat = 36
}

/// Spacing on a 4 pt grid. Gaps between things use these and nothing else.
enum NoopSpace {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// Corner radii. Three shapes, so every surface reads as one family.
enum NoopRadius {
    /// Fields, table cells, small tiles.
    static let control: CGFloat = 12
    /// Buttons of the large size.
    static let button: CGFloat = 16
    /// Cards and panels.
    static let card: CGFloat = 20
}

/// The three control sizes, taken from the 11.7 design handoff (`docs/design/11.7/app`), measured across
/// every drawn screen: 34 pt is its round icon button (57 uses) and its chip (68 uses), 44 its secondary
/// button, 52 its main action. Height, label, icon and padding move together, so a control can never be
/// big with a tiny label. Every size is tappable over at least 44 × 44 pt (`noopHitTarget`).
enum NoopControlSize {
    /// Header icon buttons (bell, gear, calendar), header chips, filter chips, period tabs, buttons beside
    /// a section label. Everything at the top of a screen is this size.
    case small
    /// Secondary buttons in a card or sheet.
    case medium
    /// The main action of a screen or sheet.
    case large

    var height: CGFloat { switch self { case .small: 34; case .medium: 44; case .large: 52 } }
    var text: CGFloat { switch self { case .small: NoopType.footnote; case .medium, .large: NoopType.subhead } }
    var icon: CGFloat { switch self { case .small: 15; case .medium: 16; case .large: 17 } }
    var padding: CGFloat { switch self { case .small: 12; case .medium: 16; case .large: 20 } }
}

/// The accent a section of the app speaks in — the same colour as its ambient glow (`NoopAmbient`): Rest
/// night, Goals warm, You blush, Fitness volt and so on. The shell sets it once per section; every
/// component below reads it, so a section's buttons and links always match its own colour.
struct NoopAccent {
    let fill: Color
    /// Text and icons on top of `fill`.
    let ink: Color

    init(fill: Color, ink: Color = NoopHTMLColor.canvas) {
        self.fill = fill
        self.ink = ink
    }

    static let blue = NoopAccent(fill: NoopHTMLColor.blue, ink: NoopHTMLColor.blueInk)
    static let volt = NoopAccent(fill: NoopHTMLColor.volt, ink: NoopHTMLColor.voltInk)

    /// The pair for a section colour, keeping the tuned ink colours where the palette has one.
    static func of(_ color: Color) -> NoopAccent {
        if color == NoopHTMLColor.volt { return .volt }
        if color == NoopHTMLColor.blue { return .blue }
        return NoopAccent(fill: color)
    }
}

private struct NoopAccentKey: EnvironmentKey { static let defaultValue = NoopAccent.blue }

extension EnvironmentValues {
    var noopAccent: NoopAccent {
        get { self[NoopAccentKey.self] }
        set { self[NoopAccentKey.self] = newValue }
    }
}

extension View {
    /// Gives a small-looking control the 44 × 44 pt hit area iOS asks for, WITHOUT changing its size: the
    /// extra area is an invisible tappable layer behind the view, so layout and any background added after
    /// this call keep the view's own size. (It used to set a 44 pt frame, which grew every circle drawn
    /// after it — the bell on Today, the gear on You.)
    func noopHitTarget() -> some View {
        background {
            Color.clear
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Components

/// A text button. `primary` is the one thing a screen is for; `secondary` the rest; `plain` a text-only
/// action; `destructive` removes something.
struct NoopActionButton: View {
    enum Variant { case primary, secondary, plain, destructive }

    let title: String
    var systemImage: String? = nil
    var variant: Variant = .primary
    var size: NoopControlSize = .large
    var fullWidth = true
    var enabled = true
    let action: () -> Void

    @Environment(\.noopAccent) private var accent

    var body: some View {
        Button(action: action) {
            HStack(spacing: NoopSpace.xs) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: size.icon, weight: .semibold)) }
                Text(title).font(NoopHTMLFont.sans(size.text, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, variant == .plain ? 0 : size.padding)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: size.height)
            .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(variant == .secondary || variant == .destructive ? Color.white.opacity(0.08) : .clear,
                              lineWidth: 0.5))
            .noopHitTarget()
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
        // A disabled primary turns a neutral grey with white text instead of fading the accent; the
        // others still fade.
        .opacity(enabled || variant == .primary ? 1 : 0.45)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }

    /// The primary 52 is a capsule; 15 on the 44 secondary; a capsule on chips.
    private var radius: CGFloat { switch size { case .large: size.height / 2; case .medium: 15; case .small: size.height / 2 } }

    private var foreground: Color {
        switch variant {
        case .primary: enabled ? accent.ink : NoopHTMLColor.ink
        case .secondary: NoopHTMLColor.ink
        case .plain: accent.fill
        case .destructive: NoopHTMLColor.red
        }
    }

    private var background: Color {
        switch variant {
        case .primary: enabled ? accent.fill : Color.white.opacity(0.22)
        case .secondary, .destructive: Color.white.opacity(0.07)
        case .plain: .clear
        }
    }
}

/// A round icon button: small beside a section label, medium in a page header, large as a floating action.
struct NoopIconButton: View {
    let systemImage: String
    var size: NoopControlSize = .medium
    var label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            NoopIconDiscShape(size: size) {
                Image(systemName: systemImage).font(.system(size: size.icon, weight: .semibold))
            }
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityLabel(label)
    }
}

/// Every sheet's close button: one size app-wide, a 42 pt disc lifted off the sheet with a light rim,
/// so it reads as the way out rather than as a secondary icon (Bevel's measured 42 pt, 25 Oct 2026).
struct NoopCloseButton: View {
    var label = "Close"
    let action: () -> Void

    static let side: CGFloat = 42

    var body: some View {
        NoopGlassDisc(symbol: "xmark", label: label, action: action)
    }
}

/// The close and back discs: Liquid Glass that swells and catches the light under the finger, the
/// system's own press (27 Oct 2026), and the old frosted disc before iOS 26.
struct NoopGlassDisc: View {
    let symbol: String
    let label: String
    var nudge: CGFloat = 0
    var tint: Color = NoopHTMLColor.ink
    let action: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            Button(action: action) {
                glyph
                    .glassEffect(.regular.interactive(), in: .circle)
                    .noopHitTarget()
            }
            .buttonStyle(NoopPlainHitStyle())
            .accessibilityLabel(label)
        } else {
            Button(action: action) {
                glyph
                    .background(Color.white.opacity(0.13), in: Circle())
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
                    .noopHitTarget()
            }
            .buttonStyle(NoopHTMLPressStyle())
            .accessibilityLabel(label)
        }
    }

    private var glyph: some View {
        Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tint)
            .offset(x: nudge)
            .frame(width: NoopCloseButton.side, height: NoopCloseButton.side)
            .contentShape(Circle())
    }
}

/// The back control at the top of every pushed page: the close button's disc with a chevron,
/// so back and close read as one family. Change its size or look here only.
struct NoopBackButton: View {
    var label = "Back"
    let action: () -> Void

    var body: some View {
        NoopGlassDisc(symbol: "chevron.left", label: label, nudge: -1, action: action)
    }
}

/// Every sheet's top (27 Oct 2026), the system's own sheet layout: the glass close disc leading, the
/// title centred at sheet size, and an optional action trailing. The two sides take the same width, so
/// the title stays centred whatever sits on the right. Change the sheet header here only.
struct NoopSheetHeader<Trailing: View>: View {
    let title: String
    /// A short line under the title: the day, the exercise.
    var subtitle: String? = nil
    var closeLabel = "Close"
    let close: () -> Void
    @ViewBuilder var trailing: Trailing

    @State private var side: CGFloat = NoopCloseButton.side

    var body: some View {
        HStack(spacing: NoopSpace.s) {
            NoopCloseButton(label: closeLabel, action: close)
                .frame(width: side, alignment: .leading)
            VStack(spacing: 1) {
                Text(title)
                    .font(NoopHTMLFont.sheetTitle).tracking(-0.4)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .lineLimit(1).minimumScaleFactor(0.75)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.copy)
                        .lineLimit(1).minimumScaleFactor(0.85)
                }
            }
            .frame(maxWidth: .infinity)
            trailing
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
                    side = max(NoopCloseButton.side, $0)
                }
                .frame(width: side, alignment: .trailing)
        }
        .frame(minHeight: NoopCloseButton.side)
    }
}

extension NoopSheetHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, closeLabel: String = "Close", close: @escaping () -> Void) {
        self.init(title: title, subtitle: subtitle, closeLabel: closeLabel, close: close) { EmptyView() }
    }
}

/// A sheet header's trailing action: a word on the same glass as the close disc, the system's
/// confirm placement.
struct NoopSheetAction: View {
    let title: String
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                .foregroundStyle(enabled ? NoopHTMLColor.ink : NoopHTMLColor.faint)
                .padding(.horizontal, 16)
                .frame(height: NoopCloseButton.side)
                .modifier(NoopGlassCapsule())
                .noopHitTarget()
        }
        .buttonStyle(NoopPlainHitStyle())
        .disabled(!enabled)
    }
}

private struct NoopGlassCapsule: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(Color.white.opacity(0.13), in: Capsule())
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
        }
    }
}

/// The name beside a back button: the same size and weight as a tab page's title.
struct NoopBackTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(NoopHTMLFont.outfit(NoopType.title3, weight: .medium))
            .tracking(-0.4)
            .foregroundStyle(NoopHTMLColor.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }
}

/// The disc behind an icon control, for a menu label or a custom glyph: same sizes as `NoopIconButton`.
struct NoopIconDiscShape<Content: View>: View {
    var size: NoopControlSize = .medium
    @ViewBuilder var content: Content

    var body: some View {
        content
            .foregroundStyle(NoopHTMLColor.inkSoft)
            .frame(width: size.height, height: size.height)
            .background(Color.white.opacity(0.06), in: Circle())
            .overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
            .noopHitTarget()
    }
}

/// A selectable pill (handoff primitive §6): unselected on the control fill; selected takes the section
/// hue as a tint — 12 % fill, 30 % border, the hue as text — never a solid block.
struct NoopChip: View {
    let title: String
    var systemImage: String? = nil
    /// A colour key before the title (a status or series dot).
    var dot: Color? = nil
    let isOn: Bool
    var size: NoopControlSize = .small
    let action: () -> Void

    @Environment(\.noopAccent) private var accent

    var body: some View {
        Button { withAnimation(NoopMotion.swap) { action() } } label: {
            HStack(spacing: NoopSpace.xxs + 2) {
                if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
                if let systemImage { Image(systemName: systemImage).font(.system(size: size.icon, weight: .semibold)) }
                Text(title).font(NoopHTMLFont.sans(size.text, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(isOn ? accent.fill : NoopHTMLColor.inkSoft)
            .padding(.horizontal, size.padding + 2)
            .frame(height: size.height)
            .background(isOn ? accent.fill.opacity(0.12) : Color.white.opacity(0.07), in: Capsule())
            .overlay(Capsule().strokeBorder(isOn ? accent.fill.opacity(0.30) : Color.white.opacity(0.06), lineWidth: 0.5))
            .noopHitTarget()
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Equal-width tabs in a track (handoff primitive §5, the segmented control): a 5 % track, the selected
/// option tinted in the section hue — 20 % fill, 42 % border, the hue as text.
struct NoopTabs<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    @Environment(\.noopAccent) private var accent

    var body: some View {
        HStack(spacing: NoopSpace.xxs) {
            ForEach(options, id: \.value) { option in
                let on = option.value == selection
                Button { withAnimation(.easeInOut(duration: 0.18)) { selection = option.value } } label: {
                    Text(option.label)
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: on ? .semibold : .regular))
                        .lineLimit(1)
                        .foregroundStyle(on ? accent.fill : NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity).frame(height: NoopControlSize.small.height)
                        .background(on ? accent.fill.opacity(0.20) : .clear,
                                    in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(on ? accent.fill.opacity(0.42) : .clear, lineWidth: 0.5))
                        .noopHitTarget()
                }
                .buttonStyle(NoopHTMLPressStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// A row that switches something (handoff primitives §2 + §4): title, an optional sub-line saying what
/// it changes, and the custom toggle in the section hue. The whole row is the tap target.
struct NoopToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var enabled = true

    @Environment(\.noopAccent) private var accent

    var body: some View {
        Button { if enabled { withAnimation(.easeInOut(duration: 0.22)) { isOn.toggle() } } } label: {
            HStack(alignment: .center, spacing: NoopSpace.s) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(NoopHTMLFont.sans(NoopType.footnote, weight: .medium)).foregroundStyle(NoopHTMLColor.ink)
                    if let subtitle {
                        Text(subtitle).font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                NoopHTMLToggle(isOn: isOn, color: accent.fill) { if enabled { isOn.toggle() } }
                    .allowsHitTesting(false)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(NoopPlainHitStyle())
        .opacity(enabled ? 1 : 0.45)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

/// A section's header: its label, then an optional text action and trailing controls sized to match.
struct NoopSectionHeader<Trailing: View>: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    @ViewBuilder var trailing: Trailing

    @Environment(\.noopAccent) private var accent

    var body: some View {
        HStack(spacing: NoopSpace.s) {
            NoopSectionLabel(title)
            Spacer(minLength: 0)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                    .foregroundStyle(accent.fill)
                    .noopHitTarget()
            }
            trailing
        }
        .frame(minHeight: 44)
    }
}

extension NoopSectionHeader where Trailing == EmptyView {
    init(_ title: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.init(title: title, actionTitle: actionTitle, action: action) { EmptyView() }
    }
}
#endif
