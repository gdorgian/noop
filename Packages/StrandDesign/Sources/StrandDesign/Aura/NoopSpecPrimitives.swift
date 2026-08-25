#if !os(watchOS)
import SwiftUI

// MARK: - 1. Card

public struct NoopSpecCard<Content: View>: View {
    public enum Kind: Sendable {
        case standard
        case row
        case hero
        case list

        fileprivate var radius: CGFloat {
            self == .hero ? NoopSpecTokens.Radius.hero : NoopSpecTokens.Radius.card
        }

        fileprivate var insets: EdgeInsets {
            switch self {
            case .standard: return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            case .row: return EdgeInsets(top: 15, leading: 16, bottom: 15, trailing: 16)
            case .hero: return EdgeInsets(top: 20, leading: 18, bottom: 18, trailing: 18)
            case .list: return EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            }
        }
    }

    private let kind: Kind
    private let tint: Color?
    private let tintOpacity: Double
    private let borderOpacity: Double
    private let content: Content

    public init(
        _ kind: Kind = .standard,
        tint: Color? = nil,
        tintOpacity: Double = 0.09,
        borderOpacity: Double = 0.24,
        @ViewBuilder content: () -> Content
    ) {
        self.kind = kind
        self.tint = tint
        self.tintOpacity = tintOpacity
        self.borderOpacity = borderOpacity
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: kind.radius, style: .continuous)
        content
            .padding(kind.insets)
            .background(
                shape.fill(tint.map { NoopSpecTokens.tint($0, opacity: tintOpacity) } ?? NoopSpecTokens.card)
            )
            .overlay(
                shape.strokeBorder(
                    tint.map { NoopSpecTokens.tintBorder($0, opacity: borderOpacity) }
                        ?? NoopSpecTokens.cardBorder,
                    lineWidth: NoopSpecTokens.hairlineWidth
                )
            )
    }
}

// MARK: - 2. List row

public struct NoopSpecRow<Leading: View, Trailing: View>: View {
    private let label: String
    private let subline: String?
    private let isFirst: Bool
    private let minHeight: CGFloat
    private let action: (() -> Void)?
    private let leading: Leading
    private let trailing: Trailing

    public init(
        label: String,
        subline: String? = nil,
        isFirst: Bool = false,
        minHeight: CGFloat = 62,
        action: (() -> Void)? = nil,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.label = label
        self.subline = subline
        self.isFirst = isFirst
        self.minHeight = minHeight
        self.action = action
        self.leading = leading()
        self.trailing = trailing()
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        let content = Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 12) {
                    leading
                    VStack(alignment: .leading, spacing: 4) {
                        labelStack
                        trailing
                    }
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 12) {
                    leading
                    labelStack
                    Spacer(minLength: 8)
                    trailing
                }
            }
        }
        .padding(.vertical, 11)
        .frame(minHeight: minHeight)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle()
                    .fill(NoopSpecTokens.hairline)
                    .frame(height: NoopSpecTokens.hairlineWidth)
            }
        }

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var labelStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .noopText(.rowLabel)
                .foregroundStyle(NoopSpecTokens.textPrimary)
            if let subline {
                Text(subline)
                    .noopText(.subline)
                    .foregroundStyle(NoopSpecTokens.textQuiet)
            }
        }
    }
}

public extension NoopSpecRow where Leading == EmptyView {
    init(
        label: String,
        subline: String? = nil,
        isFirst: Bool = false,
        minHeight: CGFloat = 62,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            label: label,
            subline: subline,
            isFirst: isFirst,
            minHeight: minHeight,
            action: action,
            leading: { EmptyView() },
            trailing: trailing
        )
    }
}

public extension NoopSpecRow where Leading == EmptyView, Trailing == EmptyView {
    init(
        label: String,
        subline: String? = nil,
        isFirst: Bool = false,
        minHeight: CGFloat = 62,
        action: (() -> Void)? = nil
    ) {
        self.init(
            label: label,
            subline: subline,
            isFirst: isFirst,
            minHeight: minHeight,
            action: action,
            leading: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}

// MARK: - 3. Pushed-screen header

public struct NoopSpecBackChevron: View {
    public init() {}

    public var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 9, y: 0))
            path.addLine(to: CGPoint(x: 0, y: 4.5))
            path.addLine(to: CGPoint(x: 9, y: 9))
        }
        .stroke(
            NoopSpecTokens.textPrimary,
            style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round)
        )
        .frame(width: 9, height: 9)
        .offset(x: -2)
        .allowsHitTesting(false)
    }
}

public struct NoopSpecHeader: View {
    private let parent: String
    private let onBack: () -> Void

    public init(parent: String, onBack: @escaping () -> Void) {
        self.parent = parent
        self.onBack = onBack
    }

    public var body: some View {
        HStack(spacing: NoopSpecTokens.headerGap) {
            Button(action: onBack) {
                ZStack {
                    Circle()
                        .fill(NoopSpecTokens.controlFill)
                        .overlay(
                            Circle().strokeBorder(
                                NoopSpecTokens.controlBorder,
                                lineWidth: NoopSpecTokens.hairlineWidth
                            )
                        )
                        .frame(width: 34, height: 34)
                    NoopSpecBackChevron()
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(parent)
                .noopText(.rowLabel)
                .foregroundStyle(NoopSpecTokens.textTertiary)

            Spacer(minLength: 0)
        }
        .padding(NoopSpecTokens.headerInsets)
    }
}

// MARK: - 4. Toggle

public struct NoopSpecToggle: View {
    @Binding private var isOn: Bool
    private let hue: Color

    public init(isOn: Binding<Bool>, hue: Color = NoopSpecTokens.aura) {
        self._isOn = isOn
        self.hue = hue
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.control, style: .continuous)
                .fill(isOn ? hue : NoopSpecTokens.controlTrack)
                .animation(NoopSpecMotion.toggleTrack, value: isOn)

            Circle()
                .fill(NoopSpecTokens.textPrimary)
                .frame(width: 24, height: 24)
                .offset(x: isOn ? 20 : 2)
                .animation(NoopSpecMotion.toggleKnob, value: isOn)
        }
        .frame(width: 46, height: 28)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 5. Segmented control

public struct NoopSpecSegmented<Value: Hashable>: View {
    private let options: [(value: Value, label: String)]
    @Binding private var selection: Value
    private let hue: Color
    private let selectedText: Color

    public init(
        options: [(value: Value, label: String)],
        selection: Binding<Value>,
        hue: Color = NoopSpecTokens.aura,
        selectedText: Color = NoopSpecTokens.auraPale
    ) {
        self.options = options
        self._selection = selection
        self.hue = hue
        self.selectedText = selectedText
    }

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 0))

        layout {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    withAnimation(NoopSpecMotion.segment) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.custom(
                            selected ? NoopSpecType.Face.sansSemiBold : NoopSpecType.Face.sansRegular,
                            size: 11.5,
                            relativeTo: .caption
                        ))
                        .foregroundStyle(selected ? selectedText : NoopSpecTokens.textTertiary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? 44 : 32)
                        .background(
                            RoundedRectangle(
                                cornerRadius: NoopSpecTokens.Radius.segment,
                                style: .continuous
                            )
                            .fill(selected ? hue.opacity(0.20) : .clear)
                        )
                        .overlay(
                            RoundedRectangle(
                                cornerRadius: NoopSpecTokens.Radius.segment,
                                style: .continuous
                            )
                            .strokeBorder(
                                selected ? hue.opacity(0.42) : .clear,
                                lineWidth: NoopSpecTokens.hairlineWidth
                            )
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.control, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: - 6. Chip

public struct NoopSpecChip: View {
    private let text: String
    private let hue: Color
    private let textColor: Color

    public init(
        _ text: String,
        hue: Color = NoopSpecTokens.aura,
        textColor: Color = NoopSpecTokens.auraPale
    ) {
        self.text = text
        self.hue = hue
        self.textColor = textColor
    }

    public var body: some View {
        Text(text)
            .noopText(.chipValue)
            .foregroundStyle(textColor)
            .padding(.vertical, 5)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.chip, style: .continuous)
                    .fill(hue.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.chip, style: .continuous)
                    .strokeBorder(hue.opacity(0.26), lineWidth: NoopSpecTokens.hairlineWidth)
            )
    }
}

// MARK: - 7. Buttons

public struct NoopSpecButton: View {
    public enum Kind: Sendable { case primary, secondary, destructive }

    private let title: String
    private let kind: Kind
    private let action: () -> Void

    public init(_ title: String, kind: Kind = .primary, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .noopText(.buttonLabel)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: kind == .primary ? 48 : 44)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(
                            kind == .primary ? .clear : NoopSpecTokens.controlBorder,
                            lineWidth: NoopSpecTokens.hairlineWidth
                        )
                )
        }
        .buttonStyle(NoopSpecPressedButtonStyle())
    }

    private var radius: CGFloat {
        kind == .primary
            ? NoopSpecTokens.Radius.buttonPrimary
            : NoopSpecTokens.Radius.buttonSecondary
    }

    private var fill: Color {
        kind == .primary ? NoopSpecTokens.aura : NoopSpecTokens.controlFill
    }

    private var foreground: Color {
        switch kind {
        case .primary: return NoopSpecTokens.onAura
        case .secondary: return NoopSpecTokens.textBody
        case .destructive: return NoopSpecTokens.hot
        }
    }
}

private struct NoopSpecPressedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .brightness(configuration.isPressed ? 0.07 : 0)
            .animation(NoopSpecMotion.buttonPressed, value: configuration.isPressed)
    }
}

// MARK: - 8. Uppercase caption

public struct NoopSpecCaption: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = NoopSpecTokens.textLabel) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .noopText(.caption)
            .foregroundStyle(color)
    }
}

// MARK: - 10. Tab bar

public enum NoopSpecGlyph: Sendable {
    case today
    case trends
    case moon
    case person
}

public struct NoopSpecTabItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let label: String
    public let glyph: NoopSpecGlyph

    public init(id: ID, label: String, glyph: NoopSpecGlyph) {
        self.id = id
        self.label = label
        self.glyph = glyph
    }
}

public struct NoopSpecTabBar<ID: Hashable>: View {
    private let items: [NoopSpecTabItem<ID>]
    private let selection: ID
    private let onSelect: (ID) -> Void
    private let onAction: () -> Void
    private let activeHue: Color
    private let activeInk: Color

    public init(
        items: [NoopSpecTabItem<ID>],
        selection: ID,
        activeHue: Color = NoopSpecTokens.aura,
        activeInk: Color = NoopSpecTokens.onAura,
        onSelect: @escaping (ID) -> Void,
        onAction: @escaping () -> Void
    ) {
        precondition(items.count == 4, "Noop Aura tab bar has exactly four destinations")
        self.items = items
        self.selection = selection
        self.activeHue = activeHue
        self.activeInk = activeInk
        self.onSelect = onSelect
        self.onAction = onAction
    }

    public var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(0, geometry.size.width - 12)
            let unit = max(0, (contentWidth - 12 - 44) / 4.7)

            HStack(spacing: 3) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index == 2 { actionButton }
                    tab(item, width: unit * (item.id == selection ? 1.7 : 1))
                }
            }
            .padding(6)
            .background(tabBarSurface)
        }
        .frame(height: 58)
        .padding(.horizontal, 14)
        .padding(.bottom, 26)
    }

    private func tab(_ item: NoopSpecTabItem<ID>, width: CGFloat) -> some View {
        let selected = item.id == selection
        return Button { onSelect(item.id) } label: {
            HStack(spacing: 7) {
                NoopSpecGlyphView(item.glyph)
                    .frame(width: 19, height: 19)
                if selected {
                    Text(item.label)
                        .noopText(.buttonLabel)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(selected ? activeInk : NoopSpecTokens.textQuiet)
            .frame(width: width, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(selected ? activeHue : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var actionButton: some View {
        Button(action: onAction) {
            Text(verbatim: "+")
                .font(.custom(NoopSpecType.Face.outfitLight, fixedSize: 23))
                .foregroundStyle(NoopSpecTokens.onAura)
                .offset(y: -1)
                .frame(width: 44, height: 44)
                .background(Circle().fill(NoopSpecTokens.aura))
                .shadow(color: NoopSpecTokens.aura.opacity(0.40), radius: 7, y: 4)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 46)
        .accessibilityLabel("Add or start")
    }

    private var tabBarSurface: some View {
        RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.panel, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.panel, style: .continuous)
                    .fill(NoopSpecTokens.tabBarFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.panel, style: .continuous)
                    .strokeBorder(NoopSpecTokens.tabBarBorder, lineWidth: NoopSpecTokens.hairlineWidth)
            )
            .shadow(color: .black.opacity(0.50), radius: 13, y: 8)
            .allowsHitTesting(false)
    }
}

private struct NoopSpecGlyphView: View {
    let glyph: NoopSpecGlyph

    init(_ glyph: NoopSpecGlyph) { self.glyph = glyph }

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 24
            context.scaleBy(x: scale, y: scale)
            var path = Path()

            switch glyph {
            case .today:
                path.addEllipse(in: CGRect(x: 7.5, y: 7.5, width: 9, height: 9))
                Self.line(&path, 12, 3, 12, 5)
                Self.line(&path, 12, 19, 12, 21)
                Self.line(&path, 4.2, 12, 2, 12)
                Self.line(&path, 22, 12, 20, 12)
                Self.line(&path, 5.6, 5.6, 4.2, 4.2)
                Self.line(&path, 19.8, 19.8, 18.4, 18.4)
                Self.line(&path, 18.4, 5.6, 19.8, 4.2)
                Self.line(&path, 4.2, 19.8, 5.6, 18.4)
            case .trends:
                Self.line(&path, 4, 18, 4, 9)
                Self.line(&path, 9.5, 18, 9.5, 5)
                Self.line(&path, 15, 18, 15, 12)
                Self.line(&path, 20.5, 18, 20.5, 9)
            case .moon:
                path.move(to: CGPoint(x: 20, y: 14.5))
                path.addCurve(
                    to: CGPoint(x: 9.5, y: 4),
                    control1: CGPoint(x: 15.9, y: 15.7),
                    control2: CGPoint(x: 8.3, y: 8.1)
                )
                path.addCurve(
                    to: CGPoint(x: 20, y: 14.5),
                    control1: CGPoint(x: 7.5, y: 11.9),
                    control2: CGPoint(x: 12.1, y: 20.7)
                )
                path.closeSubpath()
            case .person:
                path.addEllipse(in: CGRect(x: 8.8, y: 4.5, width: 6.4, height: 6.4))
                path.move(to: CGPoint(x: 5.5, y: 19.5))
                path.addCurve(
                    to: CGPoint(x: 18.5, y: 19.5),
                    control1: CGPoint(x: 5.5, y: 12.4),
                    control2: CGPoint(x: 18.5, y: 12.4)
                )
            }

            context.stroke(
                path,
                with: .foreground,
                style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private static func line(_ path: inout Path, _ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) {
        path.move(to: CGPoint(x: x1, y: y1))
        path.addLine(to: CGPoint(x: x2, y: y2))
    }
}

// MARK: - 14. Bottom sheet

public struct NoopSpecBottomSheet<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.18))
                .frame(width: 36, height: 4)
                .padding(.top, 10)
                .padding(.bottom, 12)
            content
        }
        .background(
            RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.panel, style: .continuous)
                .fill(NoopSpecTokens.card)
                .overlay(
                    RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.panel, style: .continuous)
                        .strokeBorder(NoopSpecTokens.cardBorder, lineWidth: NoopSpecTokens.hairlineWidth)
                )
        )
        .transition(.move(edge: .bottom))
    }
}

// MARK: - Shared screen/state helpers

public struct NoopSpecScreen<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    public init(spacing: CGFloat = NoopSpecTokens.cardGap, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: spacing) { content }
                .padding(.horizontal, NoopSpecTokens.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, NoopSpecTokens.scrollBottomInset)
        }
        .background(NoopSpecTokens.canvas)
        .scrollIndicators(.hidden)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : (reduceMotion ? 0 : NoopSpecMotion.enterRise))
        .onAppear {
            withAnimation(reduceMotion ? NoopSpecMotion.enterReduced : NoopSpecMotion.enter) {
                appeared = true
            }
        }
    }
}

public struct NoopSpecFigurePlaceholder: View {
    private let width: CGFloat
    private let height: CGFloat

    public init(width: CGFloat, height: CGFloat = 18) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        Capsule(style: .continuous)
            .fill(NoopSpecTokens.subtleFill)
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(NoopSpecTokens.cardBorder, lineWidth: NoopSpecTokens.hairlineWidth)
            )
            .frame(width: width, height: height)
            .accessibilityLabel("Loading")
    }
}
#endif
