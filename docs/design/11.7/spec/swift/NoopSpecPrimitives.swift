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
                .noopText(NoopSpecType.rowLabel)
                .foregroundStyle(NoopPalette.textPrimary)
            if let subline {
                Text(subline)
                    .noopText(
                        NoopSpecType.subline,
                        lineSpacing: NoopSpecType.lineSpacing(
                            size: 11.5, cssLineHeight: 1.45, face: NoopSpecType.Face.sansRegular
                        )
                    )
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
            }
            .buttonStyle(.plain)

            Text(parent)
                .noopText(NoopSpecType.rowLabel)
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
            .frame(width: 46, height: 28)
            .overlay(alignment: .leading) {
                Circle()
                    .fill(NoopPalette.textPrimary)
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
        kind == .primary ? NoopPalette.accent : NoopPalette.controlFill
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
// You. THE + IS A TAB AND IT COUNTS — an act with no log sheet of its own routes it to day/today
// with the sheet already up; it never does nothing. Three acts shipped it inert.
//
// The active tab is 1.7 × an inactive one, which is why this is a primitive and not an HStack: the
// ratio has to survive Dynamic Type, and `maxWidth: .infinity` on four of five plus a `layoutPriority`
// does not reproduce it.

public struct NoopSpecTabDestination: Identifiable {
    public let id: String
    public let label: String
    public let icon: Image
    public let action: () -> Void

    public init(id: String, label: String, icon: Image, action: @escaping () -> Void) {
        self.id = id
        self.label = label
        self.icon = icon
        self.action = action
    }
}

public struct NoopSpecTabBar: View {
    private let destinations: [NoopSpecTabDestination]   // exactly four: Today, Trends, Rest, You
    private let active: String
    private let onAdd: () -> Void

    /// - Parameters:
    ///   - destinations: the four tabs, in order. The + is inserted between the second and third.
    ///   - active: the id of the lit tab.
    ///   - onAdd: opens the log sheet. NEVER navigates, and never nil — see the header note.
    public init(destinations: [NoopSpecTabDestination], active: String, onAdd: @escaping () -> Void) {
        self.destinations = destinations
        self.active = active
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
    private static let plusBlock: CGFloat = 48
    private static let chrome: CGFloat = 12 + 12 + plusBlock

    public var body: some View {
        GeometryReader { geo in
            let usable = max(0, geo.size.width - Self.chrome)
            let unit = usable / 4.7
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

    private var barBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(NoopSpecTokens.tabBarFill)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func item(_ tab: NoopSpecTabDestination, width: CGFloat) -> some View {
        let on = tab.id == active
        return Button(action: tab.action) {
            HStack(spacing: 7) {
                tab.icon
                if on {
                    Text(tab.label)
                        .font(NoopSpecType.buttonLabel)
                        .foregroundStyle(NoopSpecTokens.onAura)
                }
            }
            .frame(width: width, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(on ? NoopPalette.accent : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    }
}

// MARK: 11 · The orb
//
// Five concentric layers on one 16 s box-breathing clock. THE WHOLE ORB IS A TAP TARGET, and it goes
// to day/charge — except on `today`, where a long press opens day/breathe (30-routes.md).
//
// THERE IS NO NUMERIC READOUT UNDER THE ORB. This was tried and removed. If the build has one,
// delete it.

public struct NoopSpecOrb: View {
    private let bpm: Int
    private let phaseWord: String
    private let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(bpm: Int, phaseWord: String, onTap: @escaping () -> Void) {
        self.bpm = bpm
        self.phaseWord = phaseWord
        self.onTap = onTap
    }

    // FOUR STOPS, NOT TWO — and the middle pair is the point.
    //
    // §11's keyframes hold at peak from 25 % to 50 %: .82 → 1.16 → 1.16 → .82 → .82. That plateau
    // IS the Hold of box breathing, and the phase word advances on its own 4 s cadence against it.
    // An `easeInOut.repeatForever(autoreverses: true)` gives the right 16 s round trip and no hold,
    // so the orb turns at the moment the word says Hold and the two desynchronise within a cycle.
    // Keyframes, therefore, not a two-phase approximation.
    private struct Breath {
        var orb: CGFloat = 0.82
        var glow: CGFloat = 0.86
        var glowOpacity: Double = 0.32
        var ring: CGFloat = 0.80
        var ringOpacity: Double = 0.55
    }

    // Each track below is 16 s in four 4 s segments: in · HOLD · out · HOLD. The hold segments are
    // `LinearKeyframe` at a constant value rather than absent — they have to occupy real time.

    public var body: some View {
        KeyframeAnimator(initialValue: Breath(), repeating: !reduceMotion) { b in
            orb(b)
        } keyframes: { _ in
            KeyframeTrack(\Breath.orb) {
                CubicKeyframe(1.16, duration: 4); LinearKeyframe(1.16, duration: 4)
                CubicKeyframe(0.82, duration: 4); LinearKeyframe(0.82, duration: 4)
            }
            KeyframeTrack(\Breath.glow) {
                CubicKeyframe(1.24, duration: 4); LinearKeyframe(1.24, duration: 4)
                CubicKeyframe(0.86, duration: 4); LinearKeyframe(0.86, duration: 4)
            }
            KeyframeTrack(\Breath.glowOpacity) {
                CubicKeyframe(0.8, duration: 4); LinearKeyframe(0.8, duration: 4)
                CubicKeyframe(0.32, duration: 4); LinearKeyframe(0.32, duration: 4)
            }
            KeyframeTrack(\Breath.ring) {
                CubicKeyframe(1.32, duration: 4); LinearKeyframe(1.32, duration: 4)
                CubicKeyframe(0.80, duration: 4); LinearKeyframe(0.80, duration: 4)
            }
            KeyframeTrack(\Breath.ringOpacity) {
                CubicKeyframe(0.12, duration: 4); LinearKeyframe(0.12, duration: 4)
                CubicKeyframe(0.55, duration: 4); LinearKeyframe(0.55, duration: 4)
            }
        }
    }

    // Reduce Motion: all three keyframe tracks stop and the orb HOLDS AT SCALE 1.0 — not at .82,
    // which is where the cycle starts. The phase word keeps advancing on its 4 s cadence, because
    // the pacing is the feature and only the movement is the accessibility problem.
    private func orb(_ b: Breath) -> some View {
        let scaleOrb: CGFloat = reduceMotion ? 1.0 : b.orb
        let scaleGlow: CGFloat = reduceMotion ? 1.0 : b.glow
        let scaleRing: CGFloat = reduceMotion ? 1.0 : b.ring
        let opGlow: Double = reduceMotion ? 0.56 : b.glowOpacity
        let opRing: Double = reduceMotion ? 0.34 : b.ringOpacity

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

            VStack(spacing: 6) {
                Text("\(bpm)")
                    .font(NoopSpecType.heroNumeral)
                    .foregroundStyle(Color(red: 246/255, green: 253/255, blue: 255/255))
                    .shadow(color: Color(red: 4/255, green: 30/255, blue: 48/255).opacity(0.55), radius: 8, y: 2)
                Text(phaseWord.uppercased())
                    .font(NoopSpecType.breathWord)
                    .tracking(1.375)
                    .foregroundStyle(Color(red: 246/255, green: 253/255, blue: 255/255).opacity(0.72))
            }
            .allowsHitTesting(false)
        }
        .frame(width: 306, height: 318)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

// MARK: 14 · Bottom sheet
//
// Enters from translateY(102 %) so its own shadow clears the screen edge. 102, not 100.
//
// TWO BEHAVIOURS THAT ARE NOT DECORATION:
//   * Swipe-back closes an open sheet BEFORE it walks the back map (30-routes.md, precedence 1).
//   * Filters inside a sheet PERSIST across open and close. They are screen state, not sheet state,
//     so the binding has to live above this modifier — not in it.

public struct NoopSpecSheet<SheetContent: View>: ViewModifier {
    @Binding private var isPresented: Bool
    private let sheetContent: () -> SheetContent
    @State private var height: CGFloat = 0

    public init(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> SheetContent) {
        self._isPresented = isPresented
        self.sheetContent = content
    }

    // 102 % HAS TO BE MEASURED. `.offset(y:)` takes points, so `.transition(.offset(y: 1.02))`
    // moves the sheet 1.02 pt and the entrance disappears — which is what this modifier did when
    // first written, twelve lines under a comment saying 102, not 100. The 2 % is what clears the
    // sheet's own shadow off the screen edge, and 2 % of nothing is nothing: the height is read
    // off the laid-out sheet and the offset derived from it.
    public func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 36, height: 4)
                        .padding(.top, 10)
                    sheetContent()
                }
                .frame(maxWidth: .infinity)
                .background(
                    UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                        .fill(NoopPalette.card)
                )
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26, style: .continuous)
                        .strokeBorder(NoopPalette.cardBorder, lineWidth: 0.5)
                )
                .background(
                    GeometryReader { g in
                        Color.clear.onAppear { height = g.size.height }
                            .onChange(of: g.size.height) { _, h in height = h }
                    }
                )
                .offset(y: isPresented ? 0 : height * 1.02)
                .animation(NoopSpecMotion.sheet, value: isPresented)
            }
            .clipped()
            .allowsHitTesting(isPresented)
        }
    }
}

public extension View {
    /// The app's only sheet presentation. Do not use `.sheet(isPresented:)` — the system sheet has
    /// its own radius, its own grabber and its own dismiss gesture, and the third of those breaks
    /// the swipe-back precedence above.
    func noopSheet<C: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> C) -> some View {
        modifier(NoopSpecSheet(isPresented: isPresented, content: content))
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
