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

/// The type scale: eight steps named after the iOS text styles they stand in for. Nothing below 11 pt.
enum NoopType {
    /// Uppercase section labels, chart axes, badges.
    static let eyebrow: CGFloat = 11
    /// Secondary lines under a value or row: units, dates.
    static let caption: CGFloat = 12
    /// Supporting copy and metadata; small-control labels.
    static let footnote: CGFloat = 13
    /// Row titles, buttons, table values.
    static let subhead: CGFloat = 15
    /// Primary body text and card titles.
    static let body: CGFloat = 17
    /// Values inside cards.
    static let title3: CGFloat = 22
    /// Page and hero values.
    static let title2: CGFloat = 28
    /// Screen titles and the largest numbers.
    static let title1: CGFloat = 34
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

/// The three control sizes. Height, label size, icon size and padding move together, so a button can
/// never end up big with a tiny label again. Every size keeps a 44 pt hit area.
enum NoopControlSize {
    /// Chips, inline actions, buttons beside a section label.
    case small
    /// Toolbar buttons, segmented tabs, secondary actions in a card.
    case medium
    /// The main action of a screen or sheet.
    case large

    var height: CGFloat { switch self { case .small: 32; case .medium: 40; case .large: 52 } }
    var text: CGFloat { switch self { case .small: NoopType.footnote; case .medium, .large: NoopType.subhead } }
    var icon: CGFloat { switch self { case .small: 13; case .medium: 15; case .large: 17 } }
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
    /// Keeps a small-looking control at the 44 × 44 pt hit area iOS asks for, without changing how it looks.
    func noopHitTarget() -> some View {
        frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
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
            .background(background, in: RoundedRectangle(cornerRadius: size == .large ? NoopRadius.button : size.height / 2,
                                                         style: .continuous))
            .noopHitTarget()
        }
        .buttonStyle(NoopHTMLPressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
    }

    private var foreground: Color {
        switch variant {
        case .primary: accent.ink
        case .secondary: NoopHTMLColor.ink
        case .plain: accent.fill
        case .destructive: NoopHTMLColor.red
        }
    }

    private var background: Color {
        switch variant {
        case .primary: accent.fill
        case .secondary: Color.white.opacity(0.07)
        case .plain: .clear
        case .destructive: NoopHTMLColor.red.opacity(0.12)
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

/// A selectable pill: filters and choices. Selected fills white, so the accent stays for actions.
struct NoopChip: View {
    let title: String
    var systemImage: String? = nil
    /// A colour key before the title (a status or series dot).
    var dot: Color? = nil
    let isOn: Bool
    var size: NoopControlSize = .small
    let action: () -> Void

    var body: some View {
        Button { withAnimation(NoopMotion.swap) { action() } } label: {
            HStack(spacing: NoopSpace.xxs + 2) {
                if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
                if let systemImage { Image(systemName: systemImage).font(.system(size: size.icon, weight: .semibold)) }
                Text(title).font(NoopHTMLFont.sans(size.text, weight: .semibold)).lineLimit(1)
            }
            .foregroundStyle(isOn ? NoopHTMLColor.canvas : NoopHTMLColor.inkSoft)
            .padding(.horizontal, size.padding + 2)
            .frame(height: size.height + 4)
            .background(isOn ? NoopHTMLColor.ink : Color.white.opacity(0.07), in: Capsule())
            .noopHitTarget()
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// Equal-width tabs in a track: periods (7D / 30D), modes (Cardio / Muscular).
struct NoopTabs<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: NoopSpace.xxs) {
            ForEach(options, id: \.value) { option in
                let on = option.value == selection
                Button { withAnimation(NoopMotion.swap) { selection = option.value } } label: {
                    Text(option.label)
                        .font(NoopHTMLFont.sans(NoopType.footnote, weight: .semibold))
                        .foregroundStyle(on ? NoopHTMLColor.ink : NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity).frame(height: NoopControlSize.medium.height - 4)
                        .background(on ? Color.white.opacity(0.1) : .clear, in: Capsule())
                        .noopHitTarget()
                }
                .buttonStyle(NoopHTMLPressStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.white.opacity(0.05), in: Capsule())
        .sensoryFeedback(.selection, trigger: selection)
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
