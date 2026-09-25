import SwiftUI
import UIKit

// MARK: - Canonical HTML tokens

/// Native equivalents of the values used by the canonical eight HTML Acts.
/// Keep these fixed: appearance settings must not recolour this UI.
enum NoopHTMLColor {
    static let canvas = Color(hex: 0x0A0C0B)
    static let card = Color(hex: 0x141817)
    static let cardRaised = Color(hex: 0x171C1A)
    static let ink = Color(hex: 0xEDF1EF)
    static let inkSoft = Color(hex: 0xC6CEC9)
    static let copy = Color(hex: 0x939C97)
    static let muted = Color(hex: 0x6C7570)
    /// Quiet ink, #7F8A85 (5.5:1 on canvas). Carries captions and every other former use of #57605C
    /// since design's 20 September contrast pass retired #57605C for type. The name is kept so the
    /// ~190 call sites did not churn; it no longer means "dimmer than quiet".
    static let faint = Color(hex: 0x7F8A85)
    /// #57605C, 3.0:1 — legal only for graphical marks the final HTML still draws in it: the row
    /// chevron's 1.5–1.6 pt stroke, Act 6's bullet dot and optional-input tick, and the faded
    /// checkbox on "What we will not ask". Never type.
    static let chevronDim = Color(hex: 0x57605C)
    static let blue = Color(hex: 0x17A2E6)
    static let blueLight = Color(hex: 0x8FD3F5)
    static let blueDeep = Color(hex: 0x0E6E9C)
    static let blueInk = Color(hex: 0x04121A)
    static let night = Color(hex: 0x8B99D6)
    static let nightLight = Color(hex: 0x9AA7E0)
    static let amber = Color(hex: 0xF0742C)
    static let warm = Color(hex: 0xF2B45C)
    static let warmInk = Color(hex: 0x1E1405)
    static let blush = Color(hex: 0xE08A9B)
    static let blushInk = Color(hex: 0x2A0E14)
    static let green = Color(hex: 0x2ECC80)
    static let red = Color(hex: 0xE66F62)
    static let gold = Color(hex: 0xD5AE62)
    static let border = Color.white.opacity(0.06)
    static let borderStrong = Color.white.opacity(0.09)
}

/// A native linear gradient whose angle follows CSS conventions exactly.
/// SwiftUI's `.topLeading` → `.bottomTrailing` shortcut is 135°, while the
/// canonical Noop featured surfaces consistently use `linear-gradient(158deg, …)`.
struct NoopCSSLinearGradient: View {
    let gradient: Gradient
    let degrees: Double

    init(colors: [Color], degrees: Double = 158) {
        self.gradient = Gradient(colors: colors)
        self.degrees = degrees
    }

    init(stops: [Gradient.Stop], degrees: Double = 158) {
        self.gradient = Gradient(stops: stops)
        self.degrees = degrees
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(1, proxy.size.width)
            let height = max(1, proxy.size.height)
            let radians = degrees * .pi / 180
            let dx = CGFloat(sin(radians))
            let dy = CGFloat(-cos(radians))
            let halfLine = (width * abs(dx) + height * abs(dy)) / 2
            let start = UnitPoint(
                x: 0.5 - halfLine * dx / width,
                y: 0.5 - halfLine * dy / height
            )
            let end = UnitPoint(
                x: 0.5 + halfLine * dx / width,
                y: 0.5 + halfLine * dy / height
            )
            LinearGradient(gradient: gradient, startPoint: start, endPoint: end)
        }
    }
}

enum NoopHTMLFont {
    static func outfit(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Outfit", size: size).weight(weight)
    }

    /// CSS `font-weight: 200` for the variable Outfit face.
    /// SwiftUI's `.thin` is weight 200; `.ultraLight` would incorrectly select 100.
    static func outfit200(_ size: CGFloat) -> Font {
        .custom("Outfit", size: size).weight(.thin)
    }

    /// Act 1's large numerals use CSS Outfit 200. Select the variable font's named
    /// ExtraLight instance directly so CoreText does not resolve it to Outfit Thin (100).
    static func act1Outfit200(_ size: CGFloat) -> Font {
        .custom("Outfit-Thin_ExtraLight", size: size)
    }

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Instrument Sans", size: size).weight(weight)
    }

    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        .custom(italic ? "Instrument Serif Italic" : "Instrument Serif", size: size)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: alpha
        )
    }
}

// MARK: - Shared screen chrome

/// 52 pt while a session is running: the live bar's 46 pt plus its 6 pt gap. Set once by the shell.
private struct NoopLiveBarInsetKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var noopLiveBarInset: CGFloat {
        get { self[NoopLiveBarInsetKey.self] }
        set { self[NoopLiveBarInsetKey.self] = newValue }
    }
}

struct NoopScreen<Content: View>: View {
    var bottomInset: CGFloat = 116
    var topInset: CGFloat = 10
    var horizontalInset: CGFloat = 20
    /// Optional deterministic launch anchor used by Debug visual-parity fixtures. Production
    /// screens leave this nil and always arrive at the top.
    var initialScrollID: String? = nil
    @ViewBuilder var content: Content

    @Environment(\.noopLiveBarInset) private var liveBarInset

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            ScrollViewReader { scrollProxy in
                ScrollView {
                    content
                        .frame(width: max(0, viewportWidth - horizontalInset * 2), alignment: .topLeading)
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, topInset)
                        .padding(.bottom, bottomInset + liveBarInset)
                        .id("noop-screen-top")
                }
                .scrollIndicators(.hidden)
                .onAppear {
                    DispatchQueue.main.async {
                        if let initialScrollID {
                            scrollProxy.scrollTo(initialScrollID, anchor: .center)
                        } else {
                            scrollProxy.scrollTo("noop-screen-top", anchor: .top)
                        }
                    }
                }
            }
            // The shell paints the canvas. Keep the scrolling layer transparent so the
            // canonical HTML's ambient aura remains visible behind the page content.
            .background(Color.clear)
        }
        .frame(width: UIScreen.main.bounds.width)
        .background(Color.clear)
    }
}

struct NoopScreenHeader<Trailing: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: Trailing

    init(_ title: String, eyebrow: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.eyebrow = eyebrow
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(NoopHTMLFont.sans(13.5))
                    .foregroundStyle(NoopHTMLColor.copy)
                Text(title)
                    .font(NoopHTMLFont.outfit(23, weight: .regular))
                    .tracking(-0.45)
                    .foregroundStyle(NoopHTMLColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.top, 2)
        .padding(.bottom, 16)
    }
}

extension NoopScreenHeader where Trailing == EmptyView {
    init(_ title: String, eyebrow: String) {
        self.init(title, eyebrow: eyebrow) { EmptyView() }
    }
}

struct NoopBackHeader: View {
    let label: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .overlay(Circle().stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5))
                    NoopFixedChevron(direction: .left, color: NoopHTMLColor.inkSoft)
                        .offset(x: -1)
                }
                .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)

            Text(label)
                .font(NoopHTMLFont.sans(13.5))
                .foregroundStyle(NoopHTMLColor.copy)
            Spacer()
        }
        .padding(.top, 2)
        .padding(.bottom, 14)
    }
}

struct NoopBatteryChip: View {
    /// The active device's reported charge. Nil when nothing has reported one: the chip keeps its
    /// place and its door to the strap screen, and prints an em dash over an empty cell — absent is
    /// never drawn as 0% or as a remembered number (copy law rule 11).
    var percent: Int?
    var action: (() -> Void)?

    private var isLow: Bool { percent.map { $0 <= 20 } ?? false }
    private var fillFraction: CGFloat {
        CGFloat(max(0, min(100, percent ?? 0))) / 100
    }
    private var tint: Color {
        guard let percent else { return NoopHTMLColor.blueLight }
        if percent <= 10 { return NoopHTMLColor.amber }
        if percent <= 20 { return NoopHTMLColor.warm }
        return NoopHTMLColor.blueLight
    }

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 7) {
                // CSS uses gap:1 plus a 1pt left margin on the nub.
                HStack(spacing: 2) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3.4)
                            .strokeBorder(
                                isLow ? tint : NoopHTMLColor.ink.opacity(0.4),
                                lineWidth: 1
                            )
                            .frame(width: 21, height: 11)
                        RoundedRectangle(cornerRadius: 2.2)
                            .fill(tint)
                            .frame(width: 18.6 * fillFraction, height: 8.6)
                            .offset(x: 1.2)
                    }
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 1.5,
                        topTrailingRadius: 1.5
                    )
                    .fill(isLow ? tint : NoopHTMLColor.ink.opacity(0.4))
                    .frame(width: 1.6, height: 4.4)
                }
                Text(percent.map { "\($0)%" } ?? "\u{2014}")
                    .font(NoopHTMLFont.sans(12, weight: .semibold))
                    .tracking(-0.12)
                    .monospacedDigit()
                    .foregroundStyle(isLow ? tint : NoopHTMLColor.inkSoft)
            }
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                isLow ? NoopHTMLColor.warm.opacity(0.12) : Color.white.opacity(0.06),
                in: Capsule()
            )
            .overlay(
                Capsule().stroke(
                    isLow ? NoopHTMLColor.warm.opacity(0.34) : Color.white.opacity(0.10),
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Cards, rows and controls

struct NoopHTMLCard<Content: View>: View {
    var radius: CGFloat = 22
    var padding: CGFloat = 16
    var tint: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(tint?.opacity(0.09) ?? NoopHTMLColor.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(tint?.opacity(0.22) ?? NoopHTMLColor.border, lineWidth: 0.5)
            )
    }
}

struct NoopSectionLabel: View {
    let text: String
    var color: Color = NoopHTMLColor.muted

    init(_ text: String, color: Color = NoopHTMLColor.muted) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text.uppercased())
            .font(NoopHTMLFont.sans(10, weight: .semibold))
            .tracking(1.2)
            .foregroundStyle(color)
    }
}

struct NoopChevron: View {
    var color: Color = NoopHTMLColor.chevronDim

    var body: some View {
        NoopFixedChevron(direction: .right, color: color)
    }
}

struct NoopFixedChevron: View {
    enum Direction { case left, right }
    let direction: Direction
    let color: Color

    var body: some View {
        Canvas { context, size in
            var path = Path()
            if direction == .left {
                path.move(to: CGPoint(x: 8.2, y: 2.2))
                path.addLine(to: CGPoint(x: 3.2, y: 7))
                path.addLine(to: CGPoint(x: 8.2, y: 11.8))
            } else {
                path.move(to: CGPoint(x: 3.8, y: 2.2))
                path.addLine(to: CGPoint(x: 8.8, y: 7))
                path.addLine(to: CGPoint(x: 3.8, y: 11.8))
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.45, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 12, height: 14)
    }
}

struct NoopIconDisc: View {
    let symbol: String
    var color: Color = NoopHTMLColor.blue
    var size: CGFloat = 38

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.38, weight: .medium))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.11), in: Circle())
            .overlay(Circle().stroke(color.opacity(0.22), lineWidth: 0.5))
    }
}

struct NoopHTMLRow: View {
    let title: String
    var detail: String? = nil
    var symbol: String? = nil
    var tint: Color = NoopHTMLColor.blue
    var value: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                if let symbol { NoopIconDisc(symbol: symbol, color: tint, size: 36) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                        .foregroundStyle(NoopHTMLColor.ink)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(2)
                    }
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(NoopHTMLFont.sans(12.5, weight: .medium))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
                NoopChevron()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(NoopHTMLColor.border, lineWidth: 0.5))
        }
        .buttonStyle(NoopHTMLPressStyle())
    }
}

struct NoopMetricTile: View {
    let value: String
    var unit: String = ""
    let label: String
    var color: Color = NoopHTMLColor.ink

    var body: some View {
        NoopHTMLCard(radius: 18, padding: 14) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(NoopHTMLFont.outfit(25, weight: .light))
                        .tracking(-0.6)
                        .monospacedDigit()
                        .foregroundStyle(color)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(NoopHTMLFont.sans(10.5))
                            .foregroundStyle(NoopHTMLColor.muted)
                    }
                }
                Text(label)
                    .font(NoopHTMLFont.sans(11))
                    .foregroundStyle(NoopHTMLColor.copy)
            }
        }
    }
}

struct NoopPill: View {
    let text: String
    var color: Color = NoopHTMLColor.blue
    var filled = false

    var body: some View {
        Text(text)
            .font(NoopHTMLFont.sans(11, weight: .semibold))
            .foregroundStyle(filled ? NoopHTMLColor.blueInk : color)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(filled ? color : color.opacity(0.11), in: Capsule())
            .overlay(Capsule().stroke(color.opacity(filled ? 0 : 0.26), lineWidth: 0.5))
    }
}

struct NoopHTMLButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet, destructive }
    let kind: Kind
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        let foreground: Color = {
            switch kind {
            case .primary: NoopHTMLColor.blueInk
            case .destructive: NoopHTMLColor.red
            default: NoopHTMLColor.inkSoft
            }
        }()
        let background: Color = {
            switch kind {
            case .primary: NoopHTMLColor.blue
            case .destructive: NoopHTMLColor.red.opacity(0.11)
            case .secondary: Color.white.opacity(0.065)
            case .quiet: .clear
            }
        }()

        configuration.label
            .font(NoopHTMLFont.sans(13, weight: .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 15)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: 44)
            .background(background, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(kind == .primary || kind == .quiet ? .clear : foreground.opacity(0.2), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct NoopHTMLPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.988 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct NoopHTMLToggle: View {
    let isOn: Bool
    var color: Color = NoopHTMLColor.blue
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Capsule()
                .fill(isOn ? color : Color.white.opacity(0.13))
                .frame(width: 46, height: 28)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(NoopHTMLColor.ink)
                        .frame(width: 24, height: 24)
                        .padding(2)
                        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct NoopSegmentedControl: View {
    let items: [String]
    let selection: String
    var action: (String) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button { action(item) } label: {
                    Text(item)
                        .font(NoopHTMLFont.sans(11.5, weight: item == selection ? .semibold : .regular))
                        .foregroundStyle(item == selection ? NoopHTMLColor.blueLight : NoopHTMLColor.copy)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(item == selection ? NoopHTMLColor.blue.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(item == selection ? NoopHTMLColor.blue.opacity(0.42) : .clear, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(NoopHTMLColor.border, lineWidth: 0.5))
    }
}

// MARK: - Graphic primitives

struct NoopOrb: View {
    var value: String
    var label: String
    var color: Color = NoopHTMLColor.blue
    var diameter: CGFloat = 232
    var progress: Double = 0.78

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.42), color.opacity(0.11), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: diameter * 0.68
                    )
                )
                .frame(width: diameter * 1.27, height: diameter * 1.27)
                .blur(radius: 13)
            Circle()
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 17, lineCap: .round))
                .frame(width: diameter, height: diameter)
            Circle()
                .trim(from: 0.045, to: max(0.046, min(0.96, progress)))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.35), color, NoopHTMLColor.blueLight, color.opacity(0.5)], center: .center),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: diameter, height: diameter)
                .shadow(color: color.opacity(0.7), radius: 9)
            VStack(spacing: 8) {
                Text(value)
                    .font(NoopHTMLFont.outfit(diameter * 0.198, weight: .ultraLight))
                    .tracking(-1.8)
                    .monospacedDigit()
                    .foregroundStyle(NoopHTMLColor.ink)
                Text(label.uppercased())
                    .font(NoopHTMLFont.sans(10.5, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(NoopHTMLColor.copy)
            }
        }
        .frame(height: diameter * 1.08)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - App-icon artwork shared with the live orbs

/// The cyan sphere used by Breathe. The screen and icon use one drawing primitive; the icon's
/// palette is the flattened, top-of-inhale treatment specified by the final five-icon sheet.
struct NoopBreatheSphereArtwork: View {
    enum Treatment { case screen, icon }

    let treatment: Treatment
    let diameter: CGFloat
    var shadowBlur: CGFloat = 0
    var shadowY: CGFloat = 0
    var shadowOpacity: Double = 0

    var body: some View {
        let icon = treatment == .icon
        let center = icon ? UnitPoint(x: 0.42, y: 0.36) : UnitPoint(x: 0.38, y: 0.32)
        let farthestX = max(center.x, 1 - center.x)
        let farthestY = max(center.y, 1 - center.y)
        let farthestCorner = diameter * sqrt(farthestX * farthestX + farthestY * farthestY)

        Circle()
            .fill(
                RadialGradient(
                    stops: icon
                        ? [
                            .init(color: Color(hex: 0xE4F6FF), location: 0),
                            .init(color: NoopHTMLColor.blueLight, location: 0.50),
                            .init(color: NoopHTMLColor.blue, location: 1)
                        ]
                        : [
                            .init(color: Color(hex: 0x9FE2FB), location: 0),
                            .init(color: Color(hex: 0x2FB2F0), location: 0.55),
                            .init(color: Color(hex: 0x0A5F92), location: 1)
                        ],
                    center: center,
                    startRadius: 0,
                    endRadius: farthestCorner
                )
            )
            .frame(width: diameter, height: diameter)
            .shadow(
                color: Color(hex: 0x0B6FA8).opacity(shadowOpacity),
                radius: shadowBlur / 2,
                y: shadowY
            )
    }
}

/// Svea's small lit blob. The alternate icon scales this same source and composes the bloom inside
/// the tile; the gate's large hollow aura remains its own, deliberately different drawing.
struct NoopSveaBlobArtwork: View {
    let diameter: CGFloat
    var shadowRadius: CGFloat = 0

    var body: some View {
        let center = UnitPoint(x: 0.44, y: 0.38)
        let farthestX = max(center.x, 1 - center.x)
        let farthestY = max(center.y, 1 - center.y)

        NoopA4BlobShape(radii: .init(
            tlx: 0.58, tly: 0.49,
            trx: 0.42, try_: 0.55,
            brx: 0.46, bry: 0.45,
            blx: 0.54, bly: 0.51
        ))
        .fill(
            RadialGradient(
                stops: [
                    .init(color: Color(hex: 0xDDE3F6), location: 0),
                    .init(color: NoopHTMLColor.night, location: 0.58),
                    .init(color: Color(hex: 0x4A56A8), location: 1)
                ],
                center: center,
                startRadius: 0,
                endRadius: diameter * sqrt(farthestX * farthestX + farthestY * farthestY)
            )
        )
        .frame(width: diameter, height: diameter)
        .shadow(color: NoopHTMLColor.night.opacity(0.55), radius: shadowRadius)
    }
}

enum NoopAppIconChoice: String, CaseIterable, Identifiable {
    case titanium = "Titanium"
    case aura = "Aura"
    case navy = "Navy"
    case breathe = "Breathe"
    case orb = "Orb"

    var id: String { rawValue }

    var alternateIconName: String? {
        switch self {
        case .titanium: "AppIcon-Titanium"
        case .aura: nil
        case .navy: "AppIcon-Navy"
        case .breathe: "AppIcon-Breathe"
        case .orb: "AppIcon-Orb"
        }
    }

    var detail: String {
        switch self {
        case .titanium: "Titanium · the one that matches the strap"
        case .aura: "Aura · the default, on the app’s own ground with the bloom"
        case .navy: "Navy · the blue alternate you already had"
        case .breathe: "Breathe · the today orb, caught mid-breath"
        case .orb: "Orb · Svea, rendered from the app’s own drawing"
        }
    }

    static var current: Self {
        switch UIApplication.shared.alternateIconName {
        case "AppIcon-Titanium": .titanium
        case "AppIcon-Navy": .navy
        case "AppIcon-Breathe": .breathe
        case "AppIcon-Orb": .orb
        default: .aura
        }
    }
}

enum NoopAppIconAppearance: CaseIterable {
    case standard
    case dark

    var exportSuffix: String {
        switch self {
        case .standard: ""
        case .dark: "-Dark"
        }
    }
}

/// The exact five-up artwork used by Settings and by the DEBUG asset exporter. Breathe and Orb
/// compose the same sphere/blob primitives as their in-app counterparts, which prevents a second
/// hand-maintained orb from drifting away from the app.
struct NoopAppIconArtwork: View {
    let choice: NoopAppIconChoice
    var appearance: NoopAppIconAppearance = .standard

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                ground(size)
                switch choice {
                case .titanium, .aura:
                    instrument(size)
                case .navy:
                    if appearance == .dark {
                        instrument(size)
                    } else {
                        Image("NavyTitanium")
                            .resizable()
                            .interpolation(.high)
                            .frame(width: size, height: size)
                    }
                case .breathe:
                    breathingOrb(size)
                case .orb:
                    sveaOrb(size)
                }
            }
            .frame(width: size, height: size)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func ground(_ size: CGFloat) -> some View {
        if appearance == .dark {
            // iOS supplies the dark Home Screen ground. Keeping our variant transparent lets that
            // system surface show through while the icon's identity and exact geometry stay ours.
            Color.clear
        } else {
            switch choice {
            case .titanium:
                NoopCSSLinearGradient(
                    stops: [
                        .init(color: Color(hex: 0xE7E3DA), location: 0),
                        .init(color: Color(hex: 0xC2BCB0), location: 0.38),
                        .init(color: Color(hex: 0xDAD5CA), location: 0.58),
                        .init(color: Color(hex: 0xA49E92), location: 1)
                    ],
                    degrees: 147
                )
            case .aura:
                iconRadial(
                    size: size,
                    center: UnitPoint(x: 0.40, y: 0.34),
                    stops: [
                        .init(color: Color(hex: 0x1D2E38), location: 0),
                        .init(color: Color(hex: 0x0C1216), location: 0.46),
                        .init(color: Color(hex: 0x060808), location: 1)
                    ]
                )
            case .navy:
                Color.clear
            case .breathe:
                iconRadial(
                    size: size,
                    center: UnitPoint(x: 0.44, y: 0.36),
                    stops: [
                        .init(color: Color(hex: 0x0E2430), location: 0),
                        .init(color: Color(hex: 0x071016), location: 0.52),
                        .init(color: Color(hex: 0x04080B), location: 1)
                    ]
                )
            case .orb:
                iconRadial(
                    size: size,
                    center: UnitPoint(x: 0.44, y: 0.36),
                    stops: [
                        .init(color: Color(hex: 0x161B28), location: 0),
                        .init(color: Color(hex: 0x0A0C12), location: 0.52),
                        .init(color: Color(hex: 0x06070A), location: 1)
                    ]
                )
            }
        }
    }

    private func iconRadial(size: CGFloat, center: UnitPoint, stops: [Gradient.Stop]) -> some View {
        let farthestX = max(center.x, 1 - center.x)
        let farthestY = max(center.y, 1 - center.y)
        return Rectangle()
            .fill(
                RadialGradient(
                    stops: stops,
                    center: center,
                    startRadius: 0,
                    endRadius: size * sqrt(farthestX * farthestX + farthestY * farthestY)
                )
            )
            .frame(width: size, height: size)
    }

    private func instrument(_ size: CGFloat) -> some View {
        let glow = choice == .aura
        return ZStack {
            NoopInstrumentArc(choice: choice, appearance: appearance)
                .frame(width: size, height: size)
                .shadow(
                    color: glow ? NoopHTMLColor.blue.opacity(appearance == .dark ? 0.56 : 0.70) : .clear,
                    radius: glow ? size * 0.045 : 0
                )

            Circle()
                .fill(instrumentCoreColor)
                .frame(width: size * 0.18, height: size * 0.18)
                .shadow(
                    color: glow ? NoopHTMLColor.blue.opacity(appearance == .dark ? 0.56 : 0.70) : .clear,
                    radius: glow ? size * 0.045 : 0
                )
        }
    }

    private var instrumentCoreColor: Color {
        switch (choice, appearance) {
        case (.aura, _): NoopHTMLColor.blueLight
        case (.navy, .dark): Color(hex: 0xE8B84B)
        case (.titanium, .dark): Color(hex: 0xDAD5CA)
        default: NoopHTMLColor.blue
        }
    }

    private func breathingOrb(_ size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: NoopHTMLColor.blue.opacity(0.50), location: 0),
                            .init(color: NoopHTMLColor.blue.opacity(0), location: 0.68),
                            .init(color: .clear, location: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.66 / 2 * sqrt(2)
                    )
                )
                .frame(width: size * 0.66, height: size * 0.66)

            Circle()
                .stroke(NoopHTMLColor.blueLight, lineWidth: max(2, size * 0.055))
                .frame(width: size * 0.78, height: size * 0.78)

            NoopBreatheSphereArtwork(treatment: .icon, diameter: size * 0.40)
        }
    }

    private func sveaOrb(_ size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: NoopHTMLColor.night.opacity(0.42), location: 0),
                            .init(color: NoopHTMLColor.night.opacity(0), location: 0.66),
                            .init(color: .clear, location: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.84 / 2 * sqrt(2)
                    )
                )
                .frame(width: size * 0.84, height: size * 0.84)

            NoopSveaBlobArtwork(diameter: size * 0.50)
        }
    }
}

private struct NoopInstrumentArc: View {
    let choice: NoopAppIconChoice
    let appearance: NoopAppIconAppearance

    var body: some View {
        Canvas(rendersAsynchronously: false) { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let stroke = side * 0.135
            let centerRadius = side * 0.39 - stroke / 2
            let dabRadius = stroke / 2
            let steps = max(240, Int(side * 1.65))
            let palette: [UInt32]
            switch (choice, appearance) {
            case (.aura, _):
                palette = [0x9BDDF8, 0x17A2E6, 0x0B6591]
            case (.navy, .dark):
                palette = [0xFCEBA8, 0xE8B84B, 0xC8902F]
            case (.titanium, .dark):
                palette = [0xF4F0E6, 0xB8B0A2, 0x736E66]
            default:
                palette = [0x4A453C, 0x2A2720, 0x171510]
            }

            for index in 0...steps {
                let t = Double(index) / Double(steps)
                // The repo generator's exact family geometry: 302° of ink with round caps, the
                // 58° cap-centre gap symmetrical about twelve o'clock.
                let degrees = 241 - 302 * t
                let radians = degrees * Double.pi / 180
                let point = CGPoint(
                    x: center.x + centerRadius * cos(radians),
                    y: center.y + centerRadius * sin(radians)
                )
                let color = interpolate(palette, t)
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: point.x - dabRadius,
                        y: point.y - dabRadius,
                        width: stroke,
                        height: stroke
                    )),
                    with: .color(color)
                )
            }
        }
    }

    private func interpolate(_ colors: [UInt32], _ t: Double) -> Color {
        let segment = min(colors.count - 2, Int(t * Double(colors.count - 1)))
        let local = t * Double(colors.count - 1) - Double(segment)
        func channel(_ hex: UInt32, _ shift: UInt32) -> Double {
            Double((hex >> shift) & 0xff) / 255
        }
        let a = colors[segment]
        let b = colors[segment + 1]
        func mix(_ x: Double, _ y: Double) -> Double { x + (y - x) * local }
        return Color(
            .sRGB,
            red: mix(channel(a, 16), channel(b, 16)),
            green: mix(channel(a, 8), channel(b, 8)),
            blue: mix(channel(a, 0), channel(b, 0)),
            opacity: 1
        )
    }
}

#if DEBUG
@MainActor
enum NoopAppIconAssetExporter {
    static func exportIfRequested() {
        guard CommandLine.arguments.contains("--export-noop-icons") else { return }
        DispatchQueue.main.async {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("NoopIconExports", isDirectory: true)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for choice in NoopAppIconChoice.allCases {
                for appearance in NoopAppIconAppearance.allCases {
                    let view = NoopAppIconArtwork(choice: choice, appearance: appearance)
                        .frame(width: 1024, height: 1024)
                        .environment(\.colorScheme, appearance == .dark ? .dark : .light)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 1
                    renderer.isOpaque = appearance == .standard
                    renderer.proposedSize = ProposedViewSize(width: 1024, height: 1024)
                    guard let data = renderer.uiImage?.pngData() else { continue }
                    let name = "AppIcon-\(choice.rawValue)\(appearance.exportSuffix)-1024.png"
                    try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
                }
            }
        }
    }
}
#endif

struct NoopSparkline: View {
    var values: [Double]
    var color: Color = NoopHTMLColor.blue
    var height: CGFloat = 92
    var band: ClosedRange<Double>? = nil

    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                guard values.count > 1,
                      let low = values.min(), let high = values.max() else { return }
                let span = max(0.001, high - low)
                if let band {
                    let y1 = size.height - CGFloat((band.upperBound - low) / span) * size.height
                    let y2 = size.height - CGFloat((band.lowerBound - low) / span) * size.height
                    context.fill(Path(CGRect(x: 0, y: min(y1, y2), width: size.width, height: abs(y2 - y1))), with: .color(color.opacity(0.13)))
                }
                var path = Path()
                for (index, value) in values.enumerated() {
                    let x = CGFloat(index) / CGFloat(values.count - 1) * size.width
                    let y = size.height - CGFloat((value - low) / span) * size.height
                    index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: geo.size.width, height: height)
        }
        .frame(height: height)
    }
}

struct NoopBarStrip: View {
    let values: [Double]
    var color: Color = NoopHTMLColor.blue
    var height: CGFloat = 92

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(color.opacity(0.32 + 0.68 * max(0, min(1, value))))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(4, height * value))
            }
        }
        .frame(height: height, alignment: .bottom)
    }
}

struct NoopProgressBar: View {
    var progress: Double
    var color: Color = NoopHTMLColor.blue
    var height: CGFloat = 7
    var trackOpacity: Double = 0.06

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(trackOpacity))
                Capsule().fill(color).frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: height)
    }
}

// MARK: - Bottom-sheet surface

/// Low-intensity visual-effect blur matching CSS `backdrop-filter: blur(3px)` without
/// cross-fading the sharp background back over the blur.
struct NoopBackdropBlur: UIViewRepresentable {
    let style: UIBlurEffect.Style
    let intensity: CGFloat

    final class Coordinator {
        var animator: UIViewPropertyAnimator?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: nil)
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
            view.effect = UIBlurEffect(style: style)
        }
        animator.fractionComplete = min(max(intensity, 0), 1)
        context.coordinator.animator = animator
        return view
    }

    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        context.coordinator.animator?.fractionComplete = min(max(intensity, 0), 1)
    }

    static func dismantleUIView(_ view: UIVisualEffectView, coordinator: Coordinator) {
        coordinator.animator?.stopAnimation(true)
        coordinator.animator = nil
    }
}

struct NoopBottomSheet<Content: View>: View {
    let title: String
    let dismiss: () -> Void
    let showsDone: Bool
    @ViewBuilder var content: Content

    init(
        title: String,
        dismiss: @escaping () -> Void,
        showsDone: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.dismiss = dismiss
        self.showsDone = showsDone
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let viewportWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            ZStack(alignment: .bottom) {
                NoopBackdropBlur(style: .regular, intensity: 0.18)
                Color(hex: 0x040605, alpha: 0.66)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: dismiss)

                VStack(spacing: 16) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 38, height: 4)
                        .padding(.top, 10)
                    HStack {
                        Text(title)
                            .font(NoopHTMLFont.outfit(22, weight: .regular))
                            .foregroundStyle(NoopHTMLColor.ink)
                        Spacer()
                        if showsDone {
                            Button("Done", action: dismiss)
                                .font(NoopHTMLFont.sans(13, weight: .semibold))
                                .foregroundStyle(NoopHTMLColor.blue)
                        }
                    }
                    content
                }
                .frame(width: max(0, viewportWidth - 40))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .background(NoopHTMLColor.card, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .overlay(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .stroke(NoopHTMLColor.borderStrong, lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.6), radius: 22, y: -8)
            }
            .frame(width: viewportWidth, height: proxy.size.height)
        }
        // Extend the dimmer and sheet through the device chrome, but continue respecting the
        // keyboard so goal fields and their save action cannot be covered while editing.
        .ignoresSafeArea(.container, edges: .all)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
