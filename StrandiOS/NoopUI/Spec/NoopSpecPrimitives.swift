import SwiftUI

// MARK: - Noop redesign primitives
//
// Fourteen primitives account for roughly nine tenths of all 48 screens. Build them once here;
// a screen is then a list of these plus its content. Anatomy and the reasoning for each is in
// spec/20-primitives.md — this file is the implementation, not the spec.
//
// Every shape is `.continuous` and every border is `.strokeBorder` at 0.5 pt (RULES §3, §4).
// Nothing here carries a shadow: cards in this design have none.

// MARK: 1 · Card

public struct NoopSpecCard<Content: View>: View {
    public enum Kind {
        case standard, row, hero, list
        var radius: CGFloat {
            switch self {
            case .hero: return NoopSpecTokens.Radius.hero
            default: return NoopSpecTokens.Radius.card
            }
        }
        var insets: EdgeInsets {
            switch self {
            case .standard: return EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            case .row:      return EdgeInsets(top: 15, leading: 16, bottom: 15, trailing: 16)
            case .hero:     return EdgeInsets(top: 20, leading: 18, bottom: 18, trailing: 18)
            // Rows own their own 11 pt vertical padding, so the card only insets by 6.
            case .list:     return EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16)
            }
        }
    }

    private let kind: Kind
    private let tint: Color?
    private let content: Content

    /// `tint` applies the tinted-card rule (hue at 9 % with a 24 % border) instead of the standard
    /// card fill. Never both.
    public init(_ kind: Kind = .standard, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.kind = kind
        self.tint = tint
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: kind.radius, style: .continuous)
        content
            .padding(kind.insets)
            .background(shape.fill(tint.map { NoopSpecTokens.tint($0) } ?? AuraPalette.card))
            .overlay(
                shape.strokeBorder(
                    tint.map { NoopSpecTokens.tintBorder($0) } ?? AuraPalette.cardBorder,
                    lineWidth: NoopSpecTokens.hairlineWidth
                )
            )
    }
}

// MARK: 2 · List row
//
// The divider is an overlay on the row rather than a `Divider()`: `Divider` inherits a system
// colour and a leading inset, so a list built from it has visibly wrong hairlines.

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
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.label = label
        self.subline = subline
        self.isFirst = isFirst
        self.minHeight = minHeight
        self.action = action
        self.leading = leading()
        self.trailing = trailing()
    }

    @Environment(\.sizeCategory) private var sizeCategory

    public var body: some View {
        let row = HStack(spacing: 12) {
            leading
            // RULES §11: at accessibility sizes the value drops under the label instead of
            // squeezing it. The row grows; it never truncates.
            if sizeCategory.isAccessibilityCategory {
                VStack(alignment: .leading, spacing: 4) {
                    labelStack
                    trailing
                }
            } else {
                labelStack
                Spacer(minLength: 8)
                trailing
            }
        }
        .padding(.vertical, 11)
        .frame(minHeight: minHeight)
        .contentShape(Rectangle())          // the whole row is the target, never just the label
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle()
                    .fill(NoopSpecTokens.hairline)
                    .frame(height: NoopSpecTokens.hairlineWidth)
            }
        }

        if let action {
            Button(action: action) { row }.buttonStyle(.plain)
        } else {
            row
        }
    }

    private var labelStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .noopText(NoopSpecType.rowLabel)
                .foregroundStyle(AuraPalette.textPrimary)
            if let subline {
                Text(subline)
                    .noopText(
                        NoopSpecType.subline,
                        lineSpacing: NoopSpecType.lineSpacing(
                            size: 11.5, cssLineHeight: 1.45, face: NoopSpecType.Face.sansRegular
                        )
                    )
                    .foregroundStyle(AuraPalette.textQuiet)
            }
        }
    }
}

// MARK: 3 · Screen header
//
// The chevron is DRAWN, not an SF Symbol: `chevron.left` is a different weight and optical size,
// and it shrinks with the label. This one is fixed at 9 × 9 with a 1.6 pt stroke.

public struct NoopSpecBackChevron: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(.clear)
            .frame(width: 9, height: 9)
            .overlay(alignment: .leading) {
                Path { p in
                    p.move(to: CGPoint(x: 9, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: 4.5))
                    p.addLine(to: CGPoint(x: 9, y: 9))
                }
                .stroke(AuraPalette.textPrimary, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
                .frame(width: 9, height: 9)
            }
            .offset(x: -2)
            .allowsHitTesting(false)
    }
}

public struct NoopSpecHeader: View {
    private let parent: String
    private let onBack: () -> Void

    /// `parent` is the name of the screen you came FROM — a "where you came from" label, not this
    /// screen's title. The title, if any, lives in the content column below.
    public init(parent: String, onBack: @escaping () -> Void) {
        self.parent = parent
        self.onBack = onBack
    }

    public var body: some View {
        HStack(spacing: NoopSpecTokens.headerGap) {
            Button(action: onBack) {
                Circle()
                    .fill(AuraPalette.controlFill)
                    .overlay(Circle().strokeBorder(NoopSpecTokens.controlBorder, lineWidth: NoopSpecTokens.hairlineWidth))
                    .frame(width: 34, height: 34)
                    .overlay { NoopSpecBackChevron() }
            }
            .buttonStyle(.plain)

            Text(parent)
                .noopText(NoopSpecType.rowLabel)
                .foregroundStyle(AuraPalette.textSecondary)

            Spacer(minLength: 0)
        }
        .padding(NoopSpecTokens.headerInsets)
    }
}

// MARK: 4 · Toggle
//
// Two curves on one control: the track crossfades over 220 ms on a material curve while the knob
// travels over 240 ms with a slight overshoot. `SwiftUI.Toggle` gets neither, which is most of why
// a stock control reads as generic here. The hue is always passed in — a toggle never picks its own.

public struct NoopSpecToggle: View {
    @Binding private var isOn: Bool
    private let hue: Color

    public init(isOn: Binding<Bool>, hue: Color = AuraPalette.accent) {
        self._isOn = isOn
        self.hue = hue
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isOn ? hue : AuraPalette.track)
            .frame(width: 46, height: 28)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(AuraPalette.textPrimary)
                    .frame(width: 24, height: 24)
                    .offset(x: isOn ? 20 : 2)      // 2 pt inset, + 18 pt of travel
            }
            .animation(NoopSpecMotion.toggleTrack, value: isOn)
            .animation(NoopSpecMotion.toggleKnob, value: isOn)
            .allowsHitTesting(false)                // the ROW owns the tap — see NoopSpecRow
    }
}

// MARK: 5 · Segmented control

public struct NoopSpecSegmented<T: Hashable>: View {
    private let options: [(value: T, label: String)]
    @Binding private var selection: T
    private let hue: Color
    private let hueText: Color

    public init(
        options: [(value: T, label: String)],
        selection: Binding<T>,
        hue: Color = AuraPalette.accent,
        hueText: Color = NoopSpecTokens.auraPale
    ) {
        self.options = options
        self._selection = selection
        self.hue = hue
        self.hueText = hueText
    }

    @Environment(\.sizeCategory) private var sizeCategory

    public var body: some View {
        // RULES §11: at accessibility sizes this becomes a vertical list of 44 pt rows, same fills.
        let layout = sizeCategory.isAccessibilityCategory
            ? AnyLayout(VStackLayout(spacing: 4))
            : AnyLayout(HStackLayout(spacing: 0))

        layout {
            ForEach(options, id: \.value) { option in
                let on = option.value == selection
                Text(option.label)
                    .font(on
                          ? Font.custom(NoopSpecType.Face.sansSemiBold, size: 11.5)
                          : Font.custom(NoopSpecType.Face.sansRegular, size: 11.5))
                    .foregroundStyle(on ? hueText : AuraPalette.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .frame(height: sizeCategory.isAccessibilityCategory ? 44 : 32)
                    .background(
                        RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.segment, style: .continuous)
                            .fill(on ? hue.opacity(0.20) : .clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.segment, style: .continuous)
                            .strokeBorder(on ? hue.opacity(0.42) : .clear, lineWidth: NoopSpecTokens.hairlineWidth)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(NoopSpecMotion.segment) { selection = option.value } }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: NoopSpecTokens.Radius.control, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
    }
}

// MARK: 6 · Chip

public struct NoopSpecChip: View {
    private let text: String
    private let hue: Color
    private let hueText: Color

    public init(_ text: String, hue: Color = AuraPalette.accent, hueText: Color = NoopSpecTokens.auraPale) {
        self.text = text
        self.hue = hue
        self.hueText = hueText
    }

    public var body: some View {
        Text(text)
            .font(NoopSpecType.chipValue)
            .foregroundStyle(hueText)
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

// MARK: 7 · Buttons

public struct NoopSpecButton: View {
    public enum Kind { case primary, secondary, destructive }
    private let title: String
    private let kind: Kind
    private let action: () -> Void
    @State private var pressed = false

    public init(_ title: String, kind: Kind = .primary, action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(NoopSpecType.buttonLabel)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: kind == .primary ? 48 : 44)
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(kind == .primary ? .clear : NoopSpecTokens.controlBorder,
                                      lineWidth: NoopSpecTokens.hairlineWidth)
                )
        }
        .buttonStyle(.plain)
    }

    private var radius: CGFloat {
        kind == .primary ? NoopSpecTokens.Radius.buttonPrimary : NoopSpecTokens.Radius.buttonSecondary
    }
    private var fill: Color {
        kind == .primary ? AuraPalette.accent : AuraPalette.controlFill
    }
    private var foreground: Color {
        switch kind {
        case .primary: return NoopSpecTokens.onAura
        case .secondary: return NoopSpecTokens.textBody
        case .destructive: return NoopSpecTokens.hot
        }
    }
}

// MARK: 8 · Uppercase caption

public struct NoopSpecCaption: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = AuraPalette.textTertiary) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text.uppercased())
            .font(NoopSpecType.caption)
            .tracking(NoopSpecType.Tracking.caption)     // +1.2 pt — not optional, RULES §1
            .foregroundStyle(color)
    }
}

// MARK: - Screen scaffold
//
// Wraps the two things every screen in the app gets wrong when hand-rolled: the 116 pt bottom
// inset that clears the floating tab bar, and the 9 pt rise on enter.

public struct NoopSpecScreen<Content: View>: View {
    private let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        ScrollView {
            VStack(spacing: AuraPalette.cardGap) { content }
                .padding(.horizontal, AuraPalette.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, NoopSpecTokens.scrollBottomInset)   // 116, a literal
        }
        .background(AuraPalette.canvas)
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
