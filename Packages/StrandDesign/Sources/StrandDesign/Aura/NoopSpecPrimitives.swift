import SwiftUI
#if canImport(UIKit)
import UIKit          // UIBlurEffect for the tab bar's 20 pt gaussian (§10)
#endif

// WHERE THIS FILE GOES: Packages/StrandDesign/Sources/StrandDesign/Aura/
//
// Inside the StrandDesign package, beside NoopPalette.swift. Commit 1ecb5712 deleted the old Aura
// layer — AuraPalette.swift with it — so the palette now travels with this pack as NoopPalette:
// a palette-only file, no components and no body-state type. `import SwiftUI` is then complete and no target dependency or
// project.yml entry is needed (SPM globs Sources/StrandDesign/). Compiled into an app target instead,
// every `NoopPalette` reference fails with "cannot find in scope", which looks exactly like a missing
// palette file. See spec/13-branch-corrected-foundation.md, then spec/12-palette-bindings.md.

// MARK: - Noop redesign primitives
//
// FIFTEEN primitives account for roughly nine tenths of all 69 screens. Build them once; a screen
// is then a list of these plus its content. Anatomy and the reasoning for each is in
// spec/20-primitives.md — this file is the implementation, not the spec.
//
// The count is fifteen everywhere in this pack. It read "fourteen" here and in two other places
// while §20 said fifteen, which is how a build ships fourteen and nobody notices which one is
// missing. The index below is the reconciliation: every primitive, its §, and the file it is in.
//
//   §   Primitive                Type                          File
//   1   Card                     NoopSpecCard                  this file
//   2   List card + row          NoopSpecRow                   this file
//   3   Screen header            NoopSpecHeader                this file
//   4   Toggle                   NoopSpecToggle                this file
//   5   Segmented control        NoopSpecSegmented             this file
//   6   Chip                     NoopSpecChip                  this file
//   7   Buttons                  NoopSpecButton                this file
//   8   Uppercase caption        NoopSpecCaption               this file
//   9   Strap battery chip       NoopStrapBatteryChip          NoopChargeGauge.swift
//  10   Tab bar                  NoopSpecTabBar                this file
//  11   The orb                  NoopSpecOrb                   this file
//  12   Charge gauge             NoopChargeGauge               NoopChargeGauge.swift
//  13   Charge bar               NoopChargeBar                 NoopChargeGauge.swift
//  14   Bottom sheet             .noopSheet(...)               this file
//  15   Confidence chip          NoopSpecConfidenceChip        this file
//
// AND FIVE SHARED VISUAL TREATMENTS, at the foot of this file. They are not numbered primitives —
// they are the recurring gradient and pulse compositions the act sources build screens out of, and
// they had no implementation anywhere, so each one was being hand-rolled per screen with slightly
// different numbers:
//
//   A   Ambient hero glow        NoopAmbientGlow               this file
//   B   158° directional card    NoopAccentCard                this file
//   C   The pulse, two tracks    NoopHeartbeat / NoopHeartglow this file
//   D   Live-session glow        NoopLiveSessionGlow           this file
//   E   Effort pulse variant     NoopPulseTone.effort          this file
//
// The + bloom and the tab bar's glass already existed here approximately; they are kept and
// screenshot-matched rather than rewritten.
//
// Every shape is `.continuous` and every border is `.strokeBorder` at 0.5 pt (RULES §3, §4).
// Nothing here carries a shadow EXCEPT the tab bar (§10), which is one of the app's three.

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
            .background(shape.fill(tint.map { NoopSpecTokens.tint($0) } ?? NoopPalette.card))
            .overlay(
                shape.strokeBorder(
                    tint.map { NoopSpecTokens.tintBorder($0) } ?? NoopPalette.cardBorder,
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
                .noopText(NoopSpecType.Role.rowLabel)
                .foregroundStyle(NoopPalette.textPrimary)
            if let subline {
                Text(subline)
                    .noopText(NoopSpecType.Role.subline)
                    .foregroundStyle(NoopPalette.textQuiet)
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
                .stroke(NoopPalette.textPrimary, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
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
                    .fill(NoopPalette.controlFill)
                    .overlay(Circle().strokeBorder(NoopSpecTokens.controlBorder, lineWidth: NoopSpecTokens.hairlineWidth))
                    .frame(width: 34, height: 34)
                    .overlay { NoopSpecBackChevron() }
                    // 34 pt CIRCLE, 44 pt TARGET. The visual stays 34 — it is drawn that size in
                    // every act source — and the tappable area is padded out to the 44 pt floor
                    // RULES §11 sets for everything else. Without this the app's most-used control
                    // is its smallest target, which is the one place this design would fail HIG.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityValue(parent)
            // The 44 pt frame adds 5 pt a side to a 34 pt circle, so cancel it in layout: the
            // header's 18 pt leading inset and its 12 pt gap are both measured off the CIRCLE.
            .padding(.horizontal, -5)

            Text(parent)
                .noopText(NoopSpecType.Role.rowLabel)
                .foregroundStyle(NoopPalette.textSecondary)

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
//
// THE TWO CURVES HAVE TO BE ATTACHED TO THE TWO LAYERS. This struct stacked both `.animation`
// modifiers on the whole control:
//
//     .animation(NoopSpecMotion.toggleTrack, value: isOn)
//     .animation(NoopSpecMotion.toggleKnob, value: isOn)
//
// The outer modifier governs the entire subtree, so the knob's overshoot curve drove the track fill
// too and the split timing — the whole character of the control — silently did not ship. Track
// animation on the track, knob animation on the knob.

public struct NoopSpecToggle: View {
    @Binding private var isOn: Bool
    private let hue: Color

    public init(isOn: Binding<Bool>, hue: Color = NoopPalette.accent) {
        self._isOn = isOn
        self.hue = hue
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(isOn ? hue : NoopPalette.track)
            .animation(NoopSpecMotion.toggleTrack, value: isOn)          // TRACK only
            .frame(width: 46, height: 28)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(NoopPalette.textPrimary)
                    .frame(width: 24, height: 24)
                    .offset(x: isOn ? 20 : 2)                            // 2 pt inset + 18 pt travel
                    .animation(NoopSpecMotion.toggleKnob, value: isOn)   // KNOB only
            }
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
        hue: Color = NoopPalette.accent,
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
                    .foregroundStyle(on ? hueText : NoopPalette.textSecondary)
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

    public init(_ text: String, hue: Color = NoopPalette.accent, hueText: Color = NoopSpecTokens.auraPale) {
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
//
// THREE DEFAULTS, NOT THREE BUTTONS. The app's real buttons are 42 / 14 (the review summary bar),
// 44 / 15 (secondary, and Act 7's test in lavender), 48 / 17 (primary aura), 52 / 18 (`goal/set`'s
// commit) and 54 / 18 in amber on `#1E1405` (`goal/picker`'s camera). One blue 48 pt button with a
// hardcoded accent cannot represent them, and a build that ships one has redrawn five screens. So
// height, radius, fill and ink are all parameters, and `Kind` only supplies their defaults.
//
// AND THE PRESSED STATE IS REAL: a white overlay from 7 % to 10 % over 120 ms. No scale. It cannot
// be done from the `Button` body — `isPressed` only exists inside a `ButtonStyle` — which is why the
// `@State private var pressed` this struct used to declare was never written to and the state never
// shipped.

public struct NoopSpecButton: View {
    public enum Kind {
        case primary, secondary, destructive

        var height: CGFloat { self == .primary ? 48 : 44 }
        var radius: CGFloat {
            self == .primary ? NoopSpecTokens.Radius.buttonPrimary : NoopSpecTokens.Radius.buttonSecondary
        }
        var fill: Color { self == .primary ? NoopPalette.accent : NoopPalette.controlFill }
        var ink: Color {
            switch self {
            case .primary: return NoopSpecTokens.onAura
            case .secondary: return NoopSpecTokens.textBody
            case .destructive: return NoopSpecTokens.hot
            }
        }
        var bordered: Bool { self != .primary }
    }

    private let title: String
    private let kind: Kind
    private let height: CGFloat
    private let radius: CGFloat
    private let accent: Color
    private let ink: Color
    private let action: () -> Void

    /// - Parameters:
    ///   - kind: supplies the defaults for the four values below. It is not the set of buttons.
    ///   - height/radius/accent/ink: override any of them. `goal/picker`'s camera button is
    ///     `.primary` at height 54, radius 18, accent `#F2B45C`, ink `#1E1405`.
    public init(_ title: String,
                kind: Kind = .primary,
                height: CGFloat? = nil,
                radius: CGFloat? = nil,
                accent: Color? = nil,
                ink: Color? = nil,
                action: @escaping () -> Void) {
        self.title = title
        self.kind = kind
        self.height = height ?? kind.height
        self.radius = radius ?? kind.radius
        self.accent = accent ?? kind.fill
        self.ink = ink ?? kind.ink
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .noopText(NoopSpecType.Role.buttonLabel)
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: height)
        }
        .buttonStyle(NoopSpecButtonStyle(radius: radius, fill: accent, bordered: kind.bordered))
    }
}

/// The pressed state, which only a `ButtonStyle` can see: **white 7 % → 10 %, 120 ms, no scale.**
/// Use it directly for the buttons that are not `NoopSpecButton` — rows of two, the per-row
/// Confirm / Fix / Discard triad, the tab bar's +.
public struct NoopSpecButtonStyle: ButtonStyle {
    private let radius: CGFloat
    private let fill: Color
    private let bordered: Bool

    public init(radius: CGFloat, fill: Color, bordered: Bool = false) {
        self.radius = radius
        self.fill = fill
        self.bordered = bordered
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        // Secondary/destructive controls already ARE white at 7 % through controlFill; adding
        // another 7 % layer at rest makes them almost twice as bright. Move that existing surface
        // one rung toward 10 % only while pressed. A filled primary has no white wash at rest.
        let pressedOverlay = configuration.isPressed ? (bordered ? 0.03 : 0.10) : 0
        return configuration.label
            .background(shape.fill(fill))
            .overlay(shape.fill(Color.white.opacity(pressedOverlay)))
            .overlay(
                shape.strokeBorder(bordered ? NoopSpecTokens.controlBorder : .clear,
                                   lineWidth: NoopSpecTokens.hairlineWidth)
            )
            .clipShape(shape)
            .animation(NoopSpecMotion.buttonPress, value: configuration.isPressed)
    }
}

// MARK: 8 · Uppercase caption

public struct NoopSpecCaption: View {
    private let text: String
    private let color: Color

    public init(_ text: String, color: Color = NoopPalette.textTertiary) {
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
            VStack(spacing: NoopPalette.cardGap) { content }
                .padding(.horizontal, NoopPalette.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, NoopSpecTokens.scrollBottomInset)   // 116, a literal
        }
        .background(NoopPalette.canvas)
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

// MARK: 10 · Tab bar
//
// Floating, over the content, on home screens only. Five destinations: Today · Trends · + · Rest ·
// You. THE + IS A TAB AND IT COUNTS — and it is **contextual**: it adds the thing the act is about.
// It is NOT "open Today's log". That sentence was written into this file and three spec pages as a
// universal rule; it is true of Act 2 alone. The nine actions, read off the act sources:
//
//   1 night · rest         the act's own Journal sheet, presented in place
//   2 day · today          the act's own Log sheet, presented in place
//   3 effort · session     effort/pick — the session picker
//   4 picture · trends     the act's own logged / recovery sheet, in place
//   5 plumbing · you       the act's own Add sheet, in place
//   6 ages · ages          plumbing/record — "Add to your record"
//   7 svea · coach         FOCUS the Ask field — in place, no navigation at all
//   8 goals · goal/labs    goal/picker — "Add lab results"
//   9 instrument · index   plumbing/history
//
// Four present a sheet without leaving the screen, four navigate, one moves focus. It never does
// nothing. spec/30-routes.md §The + is the table; `onAdd` below carries whichever of the nine the
// host act owns, and this component neither knows nor cares which.
//
// The active tab is 1.7 × an inactive one, which is why this is a primitive and not an HStack: the
// ratio has to survive Dynamic Type, and `maxWidth: .infinity` on four of five plus a `layoutPriority`
// does not reproduce it.

public struct NoopSpecTabDestination: Identifiable {
    public let id: String
    public let label: String
    public let icon: Image
    public let action: () -> Void

    /// `icon` must be a TEMPLATE image — the glyphs are 24 × 24 stroked paths lifted from each act's
    /// GLYPH map, and the bar tints them. A rendered-colour asset arrives grey inside a lit tab.
    public init(id: String, label: String, icon: Image, action: @escaping () -> Void) {
        self.id = id
        self.label = label
        self.icon = icon.renderingMode(.template)
        self.action = action
    }
}

public struct NoopSpecTabBar: View {
    private let destinations: [NoopSpecTabDestination]   // exactly four: Today, Trends, Rest, You
    private let active: String?
    private let accent: Color
    private let onAccent: Color
    private let onAdd: () -> Void

    // THE LIT TAB TAKES THE ACT'S HUE, NOT THE BRAND'S. This struct hardcoded `NoopPalette.accent`,
    // which paints a blue Rest tab across Act 1's lavender night and a blue You tab across Act 5's
    // blush — in the one component that is on screen in every act. Nor can the hue be derived from
    // the tab: the SAME destination is a different colour in two acts. Trends is green on
    // `picture/trends` and lavender on `instrument/index`. It belongs to the act, so it is passed in.
    //
    // Read off the nine act sources, which are the specification:
    //
    //   Act · home screen         lit tab   accent                  onAccent
    //   1 night · rest            Rest      rgba(139,153,214,.9)    #0D1120
    //   2 day · today             Today     #17A2E6                 #04121A
    //   3 effort · session        Today     #17A2E6                 #04121A
    //   4 picture · trends        Trends    #2ECC80                 #04140C
    //   5 plumbing · you          You       #E08A9B                 #2A0E14
    //   6 ages · ages   (via Trends)  Trends #2ECC80                #04140C
    //   6 ages · health (via You)     You    #F2B45C                #1E1405
    //   7 svea · coach            Svea      #8B99D6                 #0C1024
    //   8 goals · goal · labs     You       #F2B45C                 #1E1405
    //   9 instrument · index      Trends    rgba(139,153,214,.9)     #0B0E1A
    //
    // ACT 6 IS NOT THE "NOTHING LIT" CASE, and this file said it was. Act 6 lights the tab it was
    // ENTERED THROUGH: `ages` arrives from Trends and shows an active Trends tab in the act's green;
    // `health` arrives from You and shows an active You tab in amber. The source renders a 1.7 ×
    // pill either way, so the width arithmetic below always divides by 4.7. NO SHIPPING ACT PASSES
    // A NIL ACTIVE TAB — `nil` is kept only as a defined behaviour for a screen that is genuinely
    // none of the five, and if you find yourself passing it, check the act source first.
    //
    // Acts 7 and 9 are the other irregularity — the lit slot reads *Svea* and *Trends* in the act's
    // own hue. Build what the act source shows.
    //
    // THE INK APPLIES TO THE ICON AS WELL AS THE LABEL. An inactive glyph is `#7F8A85`; a lit tab's
    // glyph is that act's ink, the same colour as its label. This struct tinted the label only, so a
    // lit tab shipped with a grey icon sitting inside a saturated pill.
    //
    // THE + IS AURA IN ALL NINE ACTS. Verified in every source: a 44 pt #17A2E6 circle with #04121A
    // ink, on `rest`, on `you`, on `coach`, everywhere. It is the app's one fixed point of colour;
    // it does not follow the act and it takes no parameter.

    /// - Parameters:
    ///   - destinations: the four tabs, in order. The + is inserted between the second and third.
    ///   - active: the id of the lit tab. Every shipping act lights one — including Act 6, which
    ///     lights the tab it was entered through. `nil` is a defined behaviour, not a normal one.
    ///   - accent: **the act's hue** — the table above. No default value on purpose: a default is
    ///     how one blue tab ended up specified for eight differently-coloured acts.
    ///   - onAccent: the ink on the lit tab, applied to its ICON as well as its label. Every hue has
    ///     its own, and none of them is `onAura`.
    ///   - onAdd: **the act's own add action** — one of the nine in the header note. It may present
    ///     a sheet, navigate, or move focus. It is never nil, and it is never "open Today's log"
    ///     unless the host act is Act 2.
    public init(destinations: [NoopSpecTabDestination],
                active: String?,
                accent: Color,
                onAccent: Color,
                onAdd: @escaping () -> Void) {
        self.destinations = destinations
        self.active = active
        self.accent = accent
        self.onAccent = onAccent
        self.onAdd = onAdd
    }

    // The active tab is 1.7 × an inactive one and the ratio has to be MEASURED, not implied.
    // `layoutPriority` orders who gets ideal size first; it is not a proportional grow, so four
    // `maxWidth: .infinity` tabs plus a priority render five equal widths and §10's `flex: 1.7`
    // silently does not ship. The arithmetic:
    //
    //   container padding   6 + 6                    = 12
    //   gaps                4 × 3                    = 12   (five children: tab tab + tab tab)
    //   the +               44 + 2 + 2               = 48
    //   left for four tabs  width − 72
    //   shares              1.7 : 1 : 1 : 1          = 4.7 total
    //
    // 4.7 in every shipping act, Act 6 included — the 4.0 case only applies to a nil active tab,
    // which no act passes.
    private static let plusBlock: CGFloat = 48
    private static let chrome: CGFloat = 12 + 12 + plusBlock

    // SwiftUI does not mirror CSS pointer-events inheritance: disabling the outer view also
    // disables every button below it, and a descendant cannot opt back in. The padding has no
    // drawing or content shape of its own, so it already passes taps through; only the painted bar
    // and its controls participate in hit testing.
    public var body: some View {
        GeometryReader { geo in
            let usable = max(0, geo.size.width - Self.chrome)
            let unit = usable / (active == nil ? 4.0 : 4.7)
            HStack(spacing: 3) {
                ForEach(Array(destinations.enumerated()), id: \.element.id) { index, tab in
                    item(tab, width: unit * (tab.id == active ? 1.7 : 1))
                    if index == 1 { plus }
                }
            }
            .padding(6)
            .background(barBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(NoopSpecTokens.tabBarBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.5), radius: 13, x: 0, y: 8)   // 0 8 26 → radius = 26/2
            .frame(width: geo.size.width, alignment: .center)
        }
        .frame(height: 58)                      // 46 + 6 + 6
        .padding(.horizontal, 14)
        .padding(.bottom, 26)
    }

    // The blur is now applied. This read `.background(.ultraThinMaterial, in:)` while the token it
    // was supposed to implement says, in as many words, *not `.ultraThinMaterial`* — a declared,
    // documented 20 pt backdrop that nothing consumed. §10a below is what replaced it and why.
    private var barBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(NoopSpecTokens.tabBarFill)
            .background(NoopGlass(radius: NoopSpecTokens.tabBarBlurRadius))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func item(_ tab: NoopSpecTabDestination, width: CGFloat) -> some View {
        let on = tab.id == active
        return Button(action: tab.action) {
            HStack(spacing: 7) {
                tab.icon
                    .foregroundStyle(on ? onAccent : NoopPalette.textDim)   // ICON takes the ink too
                if on {
                    Text(tab.label)
                        .noopText(NoopSpecType.Role.buttonLabel)
                        .foregroundStyle(onAccent)
                }
            }
            .frame(width: width, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(on ? accent : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        // The lit tab is 1.7 wide, and it STILL has to move: from an act reached inside another
        // act's tab it pops to that act's root; from the root it leaves for the tab's real root.
        // Act 3 trapped users by returning to its own root from its own root.
    }

    private var plus: some View {
        Button(action: onAdd) {
            Text("+")
                .font(.custom(NoopSpecType.Face.outfitLight, size: 23))
                .foregroundStyle(NoopSpecTokens.onAura)
                .offset(y: -2)
                .frame(width: 44, height: 44)
                .background(Circle().fill(NoopPalette.accent))
                .shadow(color: NoopPalette.accent.opacity(0.4), radius: 7, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 2)
        .accessibilityLabel("Add")
    }
}

// MARK: 10a · The glass behind the bar
//
// The prototype is `backdrop-filter: blur(20px)` under `rgba(23,28,26,.82)`, identical in all nine
// act sources. **Public UIKit does not accept a blur radius.** `UIBlurEffect` takes a named style
// and nothing else, and SwiftUI's `Material` takes no parameter either — so no public API can
// implement "20 pt" as a number, and this file will not pretend otherwise.
//
// What ships is therefore an APPROXIMATION, stated plainly: a `UIVisualEffectView` on
// `.systemUltraThinMaterialDark`. Its radius is whatever the platform picks. Two reasons it is the
// right approximation rather than a compromise: it does not re-tint on top of the fill (which is
// the visible error `.ultraThinMaterial` in SwiftUI introduces, and what shipped here under a token
// comment saying not to), and at a 26 pt corner over a dark scene the residual difference in radius
// is not perceptible.
//
// The declared 20 pt is a MEASUREMENT OF THE PROTOTYPE to check against, not a parameter. If the
// bar ever looks wrong beside the HTML, the adjustable value is `tabBarFill`'s 82 % opacity — it is
// public, it is in the token file, and it is already the compensating value. Do not reach for a
// private API to close the gap: an exact radius is only available through a private `CAFilter` on
// the effect view's backdrop layer, that is not a route this pack recommends or documents, and
// nothing in the design depends on it.

public struct NoopGlass: View {
    private let radius: CGFloat

    /// - Parameter radius: the prototype's measured 20 pt. It is **not** applied — see the note
    ///   above — and this initialiser is its one reader, so the DEBUG assert fires if someone edits
    ///   the token expecting the blur to follow it.
    public init(radius: CGFloat) {
        self.radius = radius
        #if DEBUG
        assert(radius == 20, """
        The tab bar's backdrop is measured at 20 pt (backdrop-filter: blur(20px), every act \
        source). This is \(radius). Public UIKit cannot take a radius, so changing this token \
        changes nothing on screen — fix the token or the HTML, not this assert, and adjust \
        tabBarFill's opacity if the bar needs to match again.
        """)
        #endif
    }

    public var body: some View {
        #if canImport(UIKit)
        NoopBlurBackdrop()
        #else
        Rectangle().fill(.ultraThinMaterial)
        #endif
    }
}

#if canImport(UIKit)
/// `.systemUltraThinMaterialDark`, with no SwiftUI vibrancy layered over it.
private struct NoopBlurBackdrop: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    }
    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
    }
}
#endif

// MARK: 11 · The orb
//
// SEVEN layers on one 16 s box-breathing clock, and TWO TAP TARGETS. Read off
// `Noop Act 2 - The Day.dc.html`, which is the specification:
//
//   1  glow          Ø 268  aura, blurred 6, `boxGlow`
//   2  ring          Ø 224  1 pt `auraPale` 50 %, `boxRing`
//   3  body          Ø 176  the aura sphere + its inner shade, `boxOrb`
//   4  charge glow   Ø 268  the LEVEL's warm hue, blurred 6 — absent below 3 % heat
//   5  charge core   Ø 176  the level's warm sphere over the aura one — absent below 3 % heat
//   6  sheen         Ø 176  conic white 32 %, `mix-blend-mode: overlay`, 24 s linear drift
//   7  the numerals  —      bpm + phase word, hit testing off
//
// THE ROUTING, and this file had it backwards. The 176 pt SPHERE opens `day/breathe`. The SURROUND
// — gauge ticks, ring, glow, and the 318 pt block they sit in — opens `day/charge`. Both are plain
// taps. THERE IS NO LONG PRESS: `32-nav-addendum.md` says nothing in Noop is long-press-only, and
// a long press on the orb was specified here and exists nowhere in the app.
//
// LAYERS 4 AND 5 ARE NOT DECORATION. They are how the orb reports Charge: the sphere itself walks
// blue → blush → amber → hot as the level falls, on the same ramp as the ticks and the numeral. An
// orb built without them is permanently blue and the screen's whole signal is gone. Both come from
// `NoopSpecTokens` — ONE ramp evaluation per render, per the note at the top of `NoopChargeGauge`.
//
// THERE IS NO NUMERIC READOUT UNDER THE ORB. This was tried and removed. If the build has one,
// delete it.

// MARK: 11a · The breath pacer — ONE clock for three outputs
//
// The phase word, the bpm and the animation are three readings of the same 16 s box-breathing
// cycle, and they used to come from three places: the word and the bpm were passed in by the host
// screen while the scale ran on a `KeyframeAnimator` started `onAppear`. Nothing tied those
// together, so a re-render, a tab switch or a slow first frame offset one against the others and
// the orb turned while the word said Hold — the exact failure the keyframes exist to avoid, arrived
// at from the other direction.
//
// So: one value type, one start date, and every output a pure function of the elapsed time. They
// cannot drift, because there is nothing to drift against.

public struct NoopBreathPacer {
    /// 16 s, four 4 s phases: In · Hold · Out · Hold. Also in `NoopSpecMotion`.
    public static let period: Double = NoopSpecMotion.breathDuration
    public static let phase: Double = NoopSpecMotion.breathPhase
    public static let words = ["In", "Hold", "Out", "Hold"]

    public let start: Date
    public init(start: Date = .now) { self.start = start }

    public func elapsed(at now: Date) -> Double { max(0, now.timeIntervalSince(start)) }
    /// Position in the cycle, 0…1.
    public func t(at now: Date) -> Double {
        elapsed(at: now).truncatingRemainder(dividingBy: Self.period) / Self.period
    }
    public func phaseIndex(at now: Date) -> Int { min(3, Int(t(at: now) * 4)) }
    public func word(at now: Date) -> String { Self.words[phaseIndex(at: now)] }
    public func cycles(at now: Date) -> Double { elapsed(at: now) / Self.period }

    /// §11's pulse `[formula]`, modelled on respiratory sinus arrhythmia:
    /// `70 − min(7, floor(cycles) × 1.5) + [3, 1, −3, −1][phase]`.
    public func bpm(at now: Date) -> Int {
        let settle = min(7.0, (cycles(at: now)).rounded(.down) * 1.5)
        return 70 - Int(settle) + [3, 1, -3, -1][phaseIndex(at: now)]
    }

    /// The sheen's 24 s linear rotation, off the SAME clock — incommensurate with the breath on
    /// purpose, so the two never resynchronise into a visible beat.
    public func sheenAngle(at now: Date) -> Double {
        (elapsed(at: now) / NoopSpecMotion.sheenDuration).truncatingRemainder(dividingBy: 1) * 360
    }

    // FOUR STOPS, NOT TWO — and the middle pair is the point. §11's keyframes hold at peak from
    // 25 % to 50 %: .82 → 1.16 → 1.16 → .82 → .82. That plateau IS the Hold of box breathing.
    // An `easeInOut.repeatForever(autoreverses: true)` gives the right round trip and no hold.
    private static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 2 * x * x : 1 - pow(-2 * x + 2, 2) / 2
    }

    /// One keyframe track: rise over the first quarter, hold, fall over the third quarter, hold.
    public static func track(_ t: Double, from lo: Double, to hi: Double) -> Double {
        switch t {
        case ..<0.25:  return lo + (hi - lo) * easeInOut(t / 0.25)
        case ..<0.50:  return hi
        case ..<0.75:  return hi + (lo - hi) * easeInOut((t - 0.50) / 0.25)
        default:       return lo
        }
    }

    public func orbScale(at now: Date) -> CGFloat { CGFloat(Self.track(t(at: now), from: 0.82, to: 1.16)) }
    public func glowScale(at now: Date) -> CGFloat { CGFloat(Self.track(t(at: now), from: 0.86, to: 1.24)) }
    public func glowOpacity(at now: Date) -> Double { Self.track(t(at: now), from: 0.32, to: 0.80) }
    public func ringScale(at now: Date) -> CGFloat { CGFloat(Self.track(t(at: now), from: 0.80, to: 1.32)) }
    public func ringOpacity(at now: Date) -> Double { Self.track(t(at: now), from: 0.55, to: 0.12) }
}

public struct NoopSpecOrb: View {
    private let pacer: NoopBreathPacer
    private let bpmOverride: Int?
    private let charge: Double
    private let onSphere: () -> Void
    private let onSurround: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - pacer: the one clock. Create it when the screen appears and hold it — the word, the bpm
    ///     and every scale come out of it, so passing a word or a bpm in separately is what
    ///     reintroduces drift.
    ///   - bpmOverride: a MEASURED pulse, when one exists. The RSA phase drift is not added to it —
    ///     a real reading is not adjusted to look like the formula.
    ///   - charge: the authoritative Charge level, 0–100 — drives layers 4 and 5. `[bound]`, and
    ///     precomputed: this view does no charge arithmetic (see `NoopCharge`).
    ///   - onSphere: the Ø 176 sphere. `day/breathe`.
    ///   - onSurround: everything outside it. `day/charge`.
    public init(pacer: NoopBreathPacer,
                bpmOverride: Int? = nil,
                charge: Double,
                onSphere: @escaping () -> Void,
                onSurround: @escaping () -> Void) {
        self.pacer = pacer
        self.bpmOverride = bpmOverride
        self.charge = charge
        self.onSphere = onSphere
        self.onSurround = onSurround
    }

    // ONE TIMELINE, TWO CADENCES. Reduce Motion does not stop the clock — it slows the reads to one
    // every 4 s, which is exactly the phase cadence, so the WORD keeps advancing while every scale
    // is held at 1.0. The pacing is the feature; only the movement is the accessibility problem.
    public var body: some View {
        if reduceMotion {
            TimelineView(.periodic(from: pacer.start, by: NoopBreathPacer.phase)) { ctx in
                orb(at: ctx.date)
            }
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { ctx in
                orb(at: ctx.date)
            }
        }
    }

    private func orb(at now: Date) -> some View {
        let scaleOrb: CGFloat = reduceMotion ? NoopSpecMotion.breathHeldScale : pacer.orbScale(at: now)
        let scaleGlow: CGFloat = reduceMotion ? NoopSpecMotion.breathHeldScale : pacer.glowScale(at: now)
        let scaleRing: CGFloat = reduceMotion ? NoopSpecMotion.breathHeldScale : pacer.ringScale(at: now)
        let opGlow: Double = reduceMotion ? 0.56 : pacer.glowOpacity(at: now)
        let opRing: Double = reduceMotion ? 0.34 : pacer.ringOpacity(at: now)
        let bpm: String
        if let bpmOverride {
            bpm = String(bpmOverride)
        } else {
            // The pacer's sinusoid is a visual demo, not a pulse measurement. It is available only
            // behind both fixture gates; release and ordinary Debug builds show the absent state.
            #if DEBUG
            bpm = NoopCharge.isDemoSeeded ? String(pacer.bpm(at: now)) : "—"
            #else
            bpm = "—"
            #endif
        }
        let word = pacer.word(at: now)

        return ZStack {
            Circle()                                            // glow, Ø 268
                .fill(RadialGradient(colors: [NoopPalette.accent.opacity(0.4), NoopPalette.accent.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 91))
                .frame(width: 268, height: 268)
                .blur(radius: 6)
                .scaleEffect(scaleGlow)
                .opacity(opGlow)

            Circle()                                            // ring, Ø 224 — one of two 1 pt strokes
                .strokeBorder(NoopSpecTokens.auraPale.opacity(0.5), lineWidth: 1)
                .frame(width: 224, height: 224)
                .scaleEffect(scaleRing)
                .opacity(opRing)

            Circle()                                            // body, Ø 176
                .fill(RadialGradient(stops: NoopPalette.orbStops,
                                     center: UnitPoint(x: 0.38, y: 0.32),
                                     startRadius: 0, endRadius: 108))
                .frame(width: 176, height: 176)
                .overlay(                                       // inner shade
                    Ellipse()
                        .fill(Color(red: 4/255, green: 42/255, blue: 66/255).opacity(0.5))
                        .frame(width: 176, height: 60)
                        .offset(y: 96)
                        .blur(radius: 12)
                        .mask(Circle().frame(width: 176, height: 176))
                )
                .scaleEffect(scaleOrb)

            // 4 and 5 — the level, over the aura sphere. `chargeCoreStops` is empty below 3 % heat,
            // which is the "healthy day is unambiguously blue" rule, so this whole branch drops out.
            if !coreStops.isEmpty {
                Circle()                                        // charge glow, Ø 268
                    .fill(RadialGradient(
                        colors: [levelColour.opacity(0.42 * heat + 0.1), levelColour.opacity(0)],
                        center: .center, startRadius: 0, endRadius: 91))
                    .frame(width: 268, height: 268)
                    .blur(radius: 6)
                    .scaleEffect(scaleGlow)
                    // THE WARM GLOW BREATHES WITH THE AURA ONE. `opGlow` was computed and applied to
                    // layer 1 only, so the two Ø 268 glows sat on top of each other with one
                    // pulsing and one flat — which reads as a static warm halo the breath cannot
                    // shift, and is most visible at the very charge levels the layer exists for.
                    .opacity(opGlow)
                    .allowsHitTesting(false)

                Circle()                                        // charge core, Ø 176
                    .fill(RadialGradient(stops: coreStops,
                                         center: UnitPoint(x: 0.38, y: 0.32),
                                         startRadius: 0, endRadius: 108))
                    .frame(width: 176, height: 176)
                    .shadow(color: levelColour.opacity(0.42), radius: 26, x: 0, y: 18)
                    .opacity(min(1, heat * 1.15))
                    .scaleEffect(scaleOrb)
                    .allowsHitTesting(false)
            }

            Circle()                                            // 6 · sheen, Ø 176
                .fill(AngularGradient(stops: [
                    .init(color: .white.opacity(0), location: 0),
                    .init(color: .white.opacity(0.32), location: 0.29),
                    .init(color: .white.opacity(0), location: 0.58),
                    .init(color: .white.opacity(0), location: 1),
                ], center: .center, angle: .degrees(200)))
                .frame(width: 176, height: 176)
                .blendMode(.overlay)
                // Off the same clock as everything else. Under Reduce Motion the timeline reads
                // every 4 s rather than every frame, so the sheen steps instead of gliding — hold
                // it still instead.
                .rotationEffect(.degrees(reduceMotion ? 0 : pacer.sheenAngle(at: now)))
                .allowsHitTesting(false)

            VStack(spacing: 6) {                                // 7 · the numerals
                Text(bpm)
                    .noopText(NoopSpecType.Role.heroNumeral)
                    .foregroundStyle(Color(red: 246/255, green: 253/255, blue: 255/255))
                    .shadow(color: Color(red: 4/255, green: 30/255, blue: 48/255).opacity(0.55), radius: 8, y: 2)
                Text(word.uppercased())
                    .noopText(NoopSpecType.Role.breathWord)
                    .foregroundStyle(Color(red: 246/255, green: 253/255, blue: 255/255).opacity(0.72))
            }
            .allowsHitTesting(false)
        }
        .frame(width: 306, height: 318)
        // TWO TARGETS, MUTUALLY EXCLUSIVE BY CONSTRUCTION. This used to be a tap on the whole block
        // with a clear circle laid over it, which works only as long as nothing ever reorders the
        // overlay or adds a gesture above it — the correctness lived in z-order, invisibly. Now the
        // surround's own hit region has the sphere SUBTRACTED from it (even-odd), so the two
        // regions do not overlap at all and neither can shadow the other.
        .contentShape(.rect)                                    // draw + layout unaffected
        .overlay {
            Circle()
                .fill(.clear)
                .frame(width: 176, height: 176)
                .contentShape(Circle())
                .onTapGesture(perform: onSphere)
                .accessibilityElement()
                .accessibilityLabel("Breathe")
                .accessibilityHint("Opens the breathing player")
                .accessibilityAddTraits(.isButton)
        }
        .background {
            SurroundHitRegion()
                .fill(.clear, style: FillStyle(eoFill: true))
                .contentShape(SurroundHitRegion(), eoFill: true)
                .onTapGesture(perform: onSurround)
                .accessibilityElement()
                .accessibilityLabel("Charge")
                .accessibilityValue("\(Int(charge)) percent")
                .accessibilityHint("Opens where your charge went")
                .accessibilityAddTraits(.isButton)
        }
        // BOTH ACTIONS ARE EXPOSED. This carried `accessibilityElement(children: .ignore)` with a
        // single "Breathe" label and Charge only mentioned in the hint, so the surround tap — the
        // route to the screen that explains the app's central number — was unreachable by
        // VoiceOver. Two elements, two labels, in reading order: Charge (the block) then Breathe
        // (the sphere inside it).
        .accessibilityElement(children: .contain)
    }

    private var heat: Double { NoopSpecTokens.heat(charge: charge) }
    private var levelColour: Color { NoopSpecTokens.chargeColor(charge: charge) }
    private var coreStops: [Gradient.Stop] { NoopSpecTokens.chargeCoreStops(charge: charge) }
}

/// The orb's surround: the 306 × 318 block with the Ø 176 sphere punched out of it. Even-odd, so
/// the sphere is genuinely not part of this shape rather than merely covered by another view.
public struct SurroundHitRegion: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        var p = Path(rect)
        p.addEllipse(in: CGRect(x: rect.midX - 88, y: rect.midY - 88, width: 176, height: 176))
        return p
    }
    public var animatableData: EmptyAnimatableData { EmptyAnimatableData() }
}

// MARK: 14 · Bottom sheet
//
// FOUR PRESENTATIONS, not one. The log sheet plus THREE distinct panel variants, and the caps are
// measured rather than shared. §20 once carried a third set of numbers — radius 26, a 36 × 4 handle
// at white 18 % — that matches no source. Read off the act files:
//
//                    log (Acts 1, 2 — the +)   panel74 (Act 4)   panel76 (Act 9)   add (Act 5)
//   radius           30                        28                28                28
//   top hairline     white 10 %                white 9 %         white 9 %         white 9 %
//   handle           38 × 4, white 20 %        white 16 %        white 16 %        white 16 %
//   padding          12 / 20 / 30              12 / 18 / 30      12 / 18 / 30      12 / 18 / 30
//   scrim            rgba(4,6,6,.62)           rgba(4,6,5,.66), faded in .22 s ease
//   backdrop blur    3 pt                      3 pt              3 pt              3 pt
//   shadow           0 −20 50 black 50 %       0 −14 44 black 60 %
//   height           its content               capped 74 %       capped 76 %       ITS CONTENT
//   scrolls inside   no                        YES               YES               no
//
// The two caps are different numbers in the two sources, and Act 5's Add sheet has no cap at all.
// One 76 %-capped padded layout for all four — which is what this file used to offer — is wrong on
// three screens out of four: it gives the Add sheet a scroll view it never fills and moves Act 4's
// list two points under the tab bar.
//
// Both enter from translateY(102 %) on `sheetUp` — **.30 s** cubic-bezier(.22,.61,.36,1), which is
// what every act source says and what the token now says (it read .34). 102, not 100, so the
// sheet's own upward shadow clears the screen edge.
//
// FIVE THINGS THAT ARE NOT DECORATION:
//   * THE SCRIM — and it is not a dim. There is a 3 pt blur of the screen under it. Without it the
//     sheet is a card floating over fully legible content, which is exactly the "broken + popups"
//     in the review. The panel family's scrim is on its OWN clock, .22 s, under a .30 s sheet.
//   * AN OUTSIDE TAP DISMISSES. The scrim is the target. It is the only dismissal besides the
//     sheet's own buttons and the swipe.
//   * THE UPWARD SHADOW. Negative y. It is the thing the 102 % entrance exists to clear.
//   * NO ZERO-HEIGHT FLASH ON THE FIRST PRESENT — see `measured` below.
//   * Swipe-back closes an open sheet BEFORE it walks the back map (30-routes.md, precedence 1).
//
// And one that was already here and stays: filters inside a sheet PERSIST across open and close.
// They are screen state, not sheet state, so the binding lives above this modifier — never in it.
// Which is also why the dismissed sheet stays mounted, and therefore why it has to be hidden from
// accessibility rather than merely moved off screen.

public enum NoopSheetKind {
    /// The + sheet: Acts 1 and 2. Radius 30, its content's own height.
    case log
    /// A **structured** panel — pinned header, list scrolling under it. Act 4's *Everything you
    /// logged*, capped at 74 % of the screen.
    case panel74
    /// The same structure at Act 9's cap: 76 %.
    case panel76
    /// Act 5's simple **Add** panel: panel chrome, **no cap and no scroll view** — four rows and a
    /// footnote, as tall as they are.
    case add

    var isLog: Bool { self == .log }

    var radius: CGFloat { isLog ? 30 : 28 }
    var hairline: Double { isLog ? 0.10 : 0.09 }
    var handleOpacity: Double { isLog ? 0.20 : 0.16 }
    var horizontalPadding: CGFloat { isLog ? 20 : 18 }
    var scrim: Color {
        isLog
            ? Color(red: 4/255, green: 6/255, blue: 6/255).opacity(0.62)
            : Color(red: 4/255, green: 6/255, blue: 5/255).opacity(0.66)
    }
    /// CSS blur radius is twice SwiftUI's, so 50 → 25 and 44 → 22.
    var shadow: (radius: CGFloat, y: CGFloat, opacity: Double) {
        isLog ? (25, -20, 0.5) : (22, -14, 0.6)
    }
    /// `nil` — the sheet is as tall as its content. **Two of the four are nil**, and forcing them
    /// through a cap gives them a scroll view they never fill.
    var maxHeightFraction: CGFloat? {
        switch self {
        case .log, .add: return nil
        case .panel74: return 0.74
        case .panel76: return 0.76
        }
    }
    /// A capped panel scrolls INSIDE itself. Required, not optional: Act 4's log runs to weeks of
    /// rows and Act 9's to every metric.
    var scrollsInside: Bool { maxHeightFraction != nil }
    /// The panel family's scrim fades in over .22 s (`scrimIn`); the log sheet's is there with the
    /// sheet.
    var scrimFadesIn: Bool { !isLog }
}

public struct NoopSpecSheet<SheetContent: View>: ViewModifier {
    @Binding private var isPresented: Bool
    private let kind: NoopSheetKind
    private let sheetContent: () -> SheetContent
    @State private var height: CGFloat = 0
    @State private var measured = false

    public init(isPresented: Binding<Bool>,
                kind: NoopSheetKind = .log,
                @ViewBuilder content: @escaping () -> SheetContent) {
        self._isPresented = isPresented
        self.kind = kind
        self.sheetContent = content
    }

    // 102 % HAS TO BE MEASURED. `.offset(y:)` takes points, so `.transition(.offset(y: 1.02))`
    // moves the sheet 1.02 pt and the entrance disappears — which is what this modifier did when
    // first written, twelve lines under a comment saying 102, not 100. The 2 % is what clears the
    // sheet's own shadow off the screen edge, and 2 % of nothing is nothing: the height is read
    // off the laid-out sheet and the offset derived from it.
    //
    // AND THAT CREATES A FLASH ON THE FIRST PRESENT, which is what `measured` is for. Before the
    // GeometryReader has reported once, `height` is 0, so the resting offset is 0 too — the sheet
    // renders at its final position for a frame and then does not travel. Held at zero opacity
    // until it has been measured, the first open animates like every subsequent one.
    //
    // THE 3 PT BACKDROP BLUR is on `content` itself. CSS blurs what is behind the scrim; SwiftUI
    // has no backdrop filter, but it does not need one here — the sheet owns the whole screen
    // behind it, so blurring that screen IS the effect, in public API, on the real content.
    public func body(content: Content) -> some View {
        content
            .blur(radius: isPresented ? 3 : 0)
            .animation(NoopSpecMotion.sheet, value: isPresented)
            .overlay {
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        if isPresented {
                            kind.scrim
                                .contentShape(Rectangle())
                                .onTapGesture { isPresented = false }   // OUTSIDE TAP DISMISSES
                                .transition(.opacity)
                                .animation(kind.scrimFadesIn ? NoopSpecMotion.sheetScrim : nil,
                                           value: isPresented)
                        }
                        sheet(cap: kind.maxHeightFraction.map { geo.size.height * $0 })
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                }
                .ignoresSafeArea()
                .allowsHitTesting(isPresented)
                // A DISMISSED SHEET IS NOT ONLY OFF SCREEN. It stays mounted so its filters survive
                // open and close, which means its buttons stay in the accessibility tree — VoiceOver
                // reading a closed sheet's Save over the screen behind it. Hidden means hidden.
                .accessibilityHidden(!isPresented)
            }
    }

    private func sheet(cap: CGFloat?) -> some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.white.opacity(kind.handleOpacity))
                .frame(width: 38, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 2)
            // REQUIRED INTERNAL SCROLLING on the two capped panels, and none on the two that are
            // their content's height. A ScrollView inside an uncapped sheet is a bouncing four-row
            // list; a capped sheet without one clips.
            if kind.scrollsInside {
                ScrollView {
                    sheetContent()
                        .padding(.horizontal, kind.horizontalPadding)
                        .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            } else {
                sheetContent()
                    .padding(.horizontal, kind.horizontalPadding)
                    .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: cap)                                  // nil → the content's own height
        .background(
            UnevenRoundedRectangle(topLeadingRadius: kind.radius,
                                   topTrailingRadius: kind.radius,
                                   style: .continuous)
                .fill(NoopPalette.card)
        )
        .overlay(alignment: .top) {                             // a top hairline, not a full border
            Rectangle()
                .fill(Color.white.opacity(kind.hairline))
                .frame(height: 0.5)
        }
        .shadow(color: .black.opacity(kind.shadow.opacity),      // UPWARD — negative y
                radius: kind.shadow.radius, x: 0, y: kind.shadow.y)
        .background(
            GeometryReader { g in
                Color.clear
                    .onAppear { height = g.size.height; measured = height > 0 }
                    .onChange(of: g.size.height) { h in height = h; if h > 0 { measured = true } }
            }
        )
        .offset(y: isPresented ? 0 : height * 1.02)
        .opacity(measured ? 1 : 0)
        .animation(NoopSpecMotion.sheet, value: isPresented)
    }
}

public extension View {
    /// The app's only sheet presentation. Do not use `.sheet(isPresented:)` — the system sheet has
    /// its own radius, its own grabber, its own scrim and its own dismiss gesture, and the last of
    /// those breaks the swipe-back precedence above.
    ///
    /// `kind` is not cosmetic. **Four presentations:** `.log` (the + sheet, radius 30, content
    /// height), `.panel74` (Act 4, structured, capped, scrolls), `.panel76` (Act 9, the same at its
    /// own cap) and `.add` (Act 5, panel chrome, no cap, no scroll). Picking the wrong one is
    /// visible — and putting all four through one 76 %-capped padded layout, which is what this
    /// modifier used to offer, is visible on three screens out of four.
    func noopSheet<C: View>(isPresented: Binding<Bool>,
                            kind: NoopSheetKind = .log,
                            @ViewBuilder content: @escaping () -> C) -> some View {
        modifier(NoopSpecSheet(isPresented: isPresented, kind: kind, content: content))
    }
}

// MARK: 15 · Confidence chip
//
// The one visual treatment every latent engine needs before its number can be shown at all
// (20-primitives.md §15, 60-parity.md Part 5 §C ¶1). Drawn at true size in
// `Noop Confidence - D Hue Ramp`.
//
// TWO RUNGS, NOT THREE. `.solid` returns nothing — no chip. A permanent "Solid" chip would be noise
// on every screen a long-term user sees, and 47-act8-goals.md already sets the precedent (a read
// marker is plain when confident, chipped when uncertain).
//
// THE HUE IS PASSED IN, NEVER PICKED. §6's rule. Amber (`effort`) is reserved for needs-attention
// and `hot` for critical, so a calibrating score can borrow neither: there is nothing to act on, and
// an amber chip would read as a warning about the user's body rather than a note about the app's
// arithmetic. This matters most on day/charge, where the illness signal is amber on the same screen.
//
// THE LABEL NAMES THE REASON, NOT THE RUNG — "3 of 4 nights", never "Calibrating". The rung is
// carried by the ramp; the number is what the person can act on.
//
// IT IS NOT A LICENCE. It qualifies a number the app HAS. It cannot make an unevidenced sentence
// honest — that is the evidence gate's job (41-act2-day.md §2.2), and where there is no evidence the
// words are omitted rather than chipped.

public enum NoopConfidence: Equatable {
    case calibrating   // hue @ 7 %, border 22 %, dot 42 %, label textTertiary
    case building      // hue @ 12 %, border 30 %, dot 75 %, label the hue's own light text
    case solid         // no chip

    var fill: Double? {
        switch self {
        case .calibrating: return 0.07
        case .building:    return 0.12
        case .solid:       return nil
        }
    }
    var border: Double { self == .calibrating ? 0.22 : 0.30 }
    var dot: Double { self == .calibrating ? 0.42 : 0.75 }
}

public struct NoopSpecConfidenceChip: View {
    private let confidence: NoopConfidence
    private let reason: String
    private let hue: Color
    private let labelColor: Color
    private let compact: Bool
    private let onTap: (() -> Void)?

    /// - Parameters:
    ///   - reason: the count, not the rung. "3 of 4 nights".
    ///   - hue: the HOST SCREEN's hue. Lavender on night/rest, aura on day/charge, blush on the ages.
    ///   - labelColor: the hue's own light text variant, used at `.building` only.
    ///   - compact: on a card too small for a label, the chip shrinks to THE DOT ALONE, same corner.
    ///   - onTap: the screen that explains the arithmetic. Today only ages/method exists; until the
    ///     others do, pass nil — the chip is then INERT RATHER THAN DISHONEST, and it draws no
    ///     chevron. Never a dead tap target with a chevron on it.
    public init(_ confidence: NoopConfidence,
                reason: String,
                hue: Color,
                labelColor: Color,
                compact: Bool = false,
                onTap: (() -> Void)? = nil) {
        self.confidence = confidence
        self.reason = reason
        self.hue = hue
        self.labelColor = labelColor
        self.compact = compact
        self.onTap = onTap
    }

    public var body: some View {
        if let fill = confidence.fill {
            let chip = HStack(spacing: 6) {
                Circle()
                    .fill(hue.opacity(confidence.dot))
                    .frame(width: 5, height: 5)
                if !compact {
                    Text(reason)
                        .font(.custom(NoopSpecType.Face.sansSemiBold, size: 10))
                        .tracking(0.5)                                  // +0.05 em at 10 pt
                        .monospacedDigit()
                        .foregroundStyle(confidence == .calibrating ? NoopPalette.textTertiary : labelColor)
                }
            }
            .padding(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 9))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hue.opacity(fill))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(hue.opacity(confidence.border), lineWidth: 0.5)
            )

            if let onTap {
                Button(action: onTap) { chip }.buttonStyle(.plain)
            } else {
                chip
            }
        }
    }
}

// MARK: - A · Ambient hero glow
//
// The wash behind the top of a home screen. Every act source has the same construction and its own
// measured geometry, and it was being redrawn per screen — so it is one view with a table.
//
//   act            size        top     hue                       animated
//   1 night        470 × 430   −170    139,153,214 @ .20         YES — glowPulse 9s, .55 ↔ .9
//   2 day          470 × 410   −150    23,162,230  @ .17         no
//   3 effort       —           —       — none at all —           —
//   4 picture      470 × 410   −150    46,204,128  @ .15         no
//   5 plumbing     —           —       — none at all —           —
//   6 ages         480 × 420   −170    46,204,128  @ .15         no
//   7 svea         480 × 420   −170    139,153,214 @ .16         no
//   8 goals        480 × 420   −170    242,180,92  @ .15         no
//   9 instrument   470 × 410   −150    139,153,214 @ .16         no
//
// Acts 3 and 5 have NO ambient glow, deliberately: `session` opens on a decision and `you` on a
// hub, and neither wants a hero. Do not add one for consistency.
//
// Act 1's is the only animated one — everywhere else the glow is depth, not motion.

public struct NoopAmbientGlow: View {
    private let hue: Color
    private let opacity: Double
    private let size: CGSize
    private let top: CGFloat
    private let pulses: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lifted = false

    /// - Parameters:
    ///   - top: negative, and it is a real offset off the top of the screen — most of the ellipse
    ///     is outside the frame, which is what makes it read as a wash rather than a shape.
    ///   - pulses: Act 1 only.
    public init(hue: Color, opacity: Double, size: CGSize, top: CGFloat, pulses: Bool = false) {
        self.hue = hue
        self.opacity = opacity
        self.size = size
        self.top = top
        self.pulses = pulses
    }

    public var body: some View {
        Ellipse()
            .fill(RadialGradient(
                colors: [hue.opacity(opacity), hue.opacity(0)],
                center: .center, startRadius: 0, endRadius: size.width * 0.35))   // tail at 70 %
            .frame(width: size.width, height: size.height)
            .blur(radius: 18)
            .opacity(pulses && !reduceMotion ? (lifted ? 0.9 : 0.55) : 1)
            .offset(y: top)
            .allowsHitTesting(false)              // pointer-events: none, in every source
            .onAppear {
                guard pulses, !reduceMotion else { return }
                withAnimation(.easeInOut(duration: NoopSpecMotion.ambientGlowPulse / 2)
                    .repeatForever(autoreverses: true)) { lifted = true }
            }
    }
}

// MARK: - B · The 158° directional accent card
//
// The app's one card treatment that is not the flat standard card: a directional tint at 158°, hue
// at 16 % falling to hue at 3 %, over a 0.5 pt border of the same hue at 30 %. It carries `today`'s
// Svea prompt (radius 20), Act 7's own rows (radius 24) and `consent`'s *what leaves the phone*
// card (aura, .10 → .02, border .24). `svea/coach`'s brief card is its 160° sibling at .14 → .03,
// radius 26.
//
// THIS IS WHAT `coachSurfaceTop → coachSurfaceBottom` WAS SUPPOSED TO BE, and was not: those two
// tokens named a near-black vertical ramp (#18211E → #121615) that appears in no source. They are
// deleted from `NoopPalette`; this is the treatment the screens actually draw.

public struct NoopAccentCard<Content: View>: View {
    private let hue: Color
    private let radius: CGFloat
    private let angle: Double
    private let stops: (from: Double, to: Double)
    private let border: Double
    private let insets: EdgeInsets
    private let content: Content

    /// Defaults are the canonical card. `.brief` below is the 160° variant.
    public init(hue: Color,
                radius: CGFloat = 24,
                angle: Double = 158,
                stops: (from: Double, to: Double) = (0.16, 0.03),
                border: Double = 0.30,
                insets: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16),
                @ViewBuilder content: () -> Content) {
        self.hue = hue
        self.radius = radius
        self.angle = angle
        self.stops = stops
        self.border = border
        self.insets = insets
        self.content = content()
    }

    /// `svea/coach`'s brief card: 160°, .14 → .03, radius 26.
    public static func brief(hue: Color, @ViewBuilder content: () -> Content) -> NoopAccentCard<Content> {
        NoopAccentCard(hue: hue, radius: 26, angle: 160, stops: (0.14, 0.03),
                       insets: EdgeInsets(top: 16, leading: 16, bottom: 15, trailing: 16),
                       content: content)
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content
            .padding(insets)
            .background {
                GeometryReader { proxy in
                    shape.fill(cssGradient(in: proxy.size))
                }
            }
            .overlay(shape.strokeBorder(hue.opacity(border), lineWidth: NoopSpecTokens.hairlineWidth))
    }

    /// CSS angles live in physical screen space. Converting directly to UnitPoint skews the angle
    /// whenever a card is not square. Projecting the rectangle's corners onto the CSS direction
    /// preserves the measured 158° (or 160°) on every card aspect ratio.
    private func cssGradient(in size: CGSize) -> LinearGradient {
        let radians = angle * .pi / 180
        let directionX = CGFloat(sin(radians))
        let directionY = CGFloat(-cos(radians))
        let width = max(size.width, 1)
        let height = max(size.height, 1)
        let halfLength = (abs(width * directionX) + abs(height * directionY)) / 2
        let unitX = directionX * halfLength / width
        let unitY = directionY * halfLength / height

        return LinearGradient(
            colors: [hue.opacity(stops.from), hue.opacity(stops.to)],
            startPoint: UnitPoint(x: 0.5 - unitX, y: 0.5 - unitY),
            endPoint: UnitPoint(x: 0.5 + unitX, y: 0.5 + unitY)
        )
    }
}

// MARK: - C, D, E · The pulse — two six-stop tracks, three speeds, and a freeze
//
// `heartbeat` (scale) and `heartglow` (opacity) are DIFFERENT six-stop curves on one clock:
// 0 / 9 / 18 / 27 / 42 / 100 %. The two beats at 9 % and 27 % are systole and its echo; the flat
// run from 42 % to 100 % is the diastolic gap, and it is more than half the cycle. A two-stop
// approximation throbs; this does not.
//
// The tone is DIMMER on the effort screens, measured: `today` and `day/heart` peak at scale 1.05 and
// glow .80 from a .45 floor, while `effort/live` peaks at 1.045 and .78 from a .40 floor. It reads
// as the same organ under a darker screen rather than the same animation reused.
//
// PAUSED FREEZES. `effort/live` paused sets `animation: none`, which holds both tracks where they
// stand — the glow stays on screen at full size. It does NOT hide: a paused session still has a
// heart rate, and the frozen glow is what says the screen is holding rather than finished. Reduce
// Motion does the same thing at the trough.

public enum NoopPulseTone {
    /// `today`'s heart tile, `day/heart`'s hero. 1.05 s.
    case resting
    /// `effort/live` and `effort/intervals` — dimmer, and shallower.
    case effort

    /// scale, at 0 / 9 / 18 / 27 / 42 %.
    var beat: [CGFloat] {
        self == .resting ? [1, 1.05, 1.01, 1.035, 1] : [1, 1.045, 1.01, 1.03, 1]
    }
    /// opacity, at the same five stops.
    var glow: [Double] {
        self == .resting ? [0.45, 0.80, 0.55, 0.72, 0.45] : [0.40, 0.78, 0.50, 0.68, 0.40]
    }
    var trough: Double { self == .resting ? NoopSpecMotion.pulseHeldGlowResting : NoopSpecMotion.pulseHeldGlowEffort }
}

/// The two tracks as functions of cycle position, so a caller can drive both off one date.
public enum NoopHeartbeat {
    /// Stop positions, as fractions of the period. The sixth stop repeats the fifth: everything from
    /// 42 % to 100 % is the gap.
    public static let stops: [Double] = [0, 0.09, 0.18, 0.27, 0.42, 1]

    public static func value(_ t: Double, over keys: [CGFloat]) -> CGFloat {
        let full = keys + [keys[0]]                       // … and back to rest for the tail
        for i in 0..<(stops.count - 1) where t < stops[i + 1] {
            let span = stops[i + 1] - stops[i]
            let f = span <= 0 ? 0 : (t - stops[i]) / span
            let eased = f < 0.5 ? 2 * f * f : 1 - pow(-2 * f + 2, 2) / 2      // ease-in-out
            return full[i] + (full[i + 1] - full[i]) * CGFloat(eased)
        }
        return keys[0]
    }

    public static func scale(_ t: Double, tone: NoopPulseTone) -> CGFloat { value(t, over: tone.beat) }
}

public enum NoopHeartglow {
    public static func opacity(_ t: Double, tone: NoopPulseTone) -> Double {
        Double(NoopHeartbeat.value(t, over: tone.glow.map { CGFloat($0) }))
    }
}

/// Wraps a live figure so it beats, and its glow with it. The two tracks come out of one date, so
/// they cannot slip against each other.
public struct NoopPulse<Content: View>: View {
    private let period: Double
    private let tone: NoopPulseTone
    private let paused: Bool
    private let glowSize: CGSize?
    private let glowHue: Color
    private let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()
    @State private var pausedAt: Date?
    @State private var accumulatedPause: TimeInterval = 0

    /// - Parameters:
    ///   - period: `NoopSpecMotion.pulseResting` 1.05 · `.pulseLive` 0.52 · `.pulseInterval` 0.44.
    ///   - paused: freezes both tracks. Never hides them.
    ///   - glowSize: the radial glow behind the figure, when there is one. `nil` for the numeral
    ///     alone (`effort/intervals`).
    public init(period: Double,
                tone: NoopPulseTone = .resting,
                paused: Bool = false,
                glowSize: CGSize? = nil,
                glowHue: Color = NoopPalette.accent,
                @ViewBuilder content: () -> Content) {
        self.period = period
        self.tone = tone
        self.paused = paused
        self.glowSize = glowSize
        self.glowHue = glowHue
        self.content = content()
    }

    public var body: some View {
        if reduceMotion {
            frame(scale: 1.0, glow: tone.trough)          // FROZEN, and still on screen
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { ctx in
                let now = pausedAt ?? ctx.date
                let elapsed = max(0, now.timeIntervalSince(start) - accumulatedPause)
                let cycle = max(period, 0.001)
                let t = elapsed.truncatingRemainder(dividingBy: cycle) / cycle
                frame(scale: NoopHeartbeat.scale(t, tone: tone),
                      glow: NoopHeartglow.opacity(t, tone: tone))
            }
            .onAppear {
                if paused, pausedAt == nil { pausedAt = .now }
            }
            .onChange(of: paused) { isPaused in
                if isPaused {
                    if pausedAt == nil { pausedAt = .now }
                } else if let pauseStarted = pausedAt {
                    accumulatedPause += Date.now.timeIntervalSince(pauseStarted)
                    pausedAt = nil
                }
            }
        }
    }

    private func frame(scale: CGFloat, glow: Double) -> some View {
        content
            .scaleEffect(scale)
            .background(alignment: .center) {
                if let glowSize {
                    Ellipse()
                        .fill(RadialGradient(colors: [glowHue.opacity(0.30), glowHue.opacity(0)],
                                             center: .center, startRadius: 0,
                                             endRadius: glowSize.width * 0.35))     // tail at 70 %
                        .frame(width: glowSize.width, height: glowSize.height)
                        .opacity(glow)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// D · `effort/live`'s glow, at its measured size and speed: **210 × 150, .52 s**, aura while in
/// zone and `#F2B45C` at 30 % when the session is off its target. Not a scaled copy of `day/heart`'s
/// 120 × 90 — the live screen's figure is bigger and the glow is wider than it is tall by more.
public struct NoopLiveSessionGlow<Content: View>: View {
    private let paused: Bool
    private let offTarget: Bool
    private let content: Content

    public init(paused: Bool, offTarget: Bool = false, @ViewBuilder content: () -> Content) {
        self.paused = paused
        self.offTarget = offTarget
        self.content = content()
    }

    public var body: some View {
        NoopPulse(period: NoopSpecMotion.pulseLive,
                  tone: .effort,
                  paused: paused,
                  glowSize: CGSize(width: 210, height: 150),
                  glowHue: offTarget ? NoopPalette.effort : NoopPalette.accent) {
            content
        }
    }
}
