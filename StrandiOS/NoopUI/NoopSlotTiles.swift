import SwiftUI

// MARK: - Slot tiles
//
// The small tiles a page can hold two to a row: a glossy symbol pill, one figure, the line under it,
// and an accessory at the end. Every tile shares this chrome, so a row of two reads as a pair whatever
// they show.

/// A pill in its own colour, lit from the top, with a symbol in white.
struct NoopGlossTile: View {
    let symbol: String
    /// The light and deep ends of its colour.
    let tint: (Color, Color)
    /// The pill's height; it is a little wider than tall.
    var side: CGFloat = 34
    /// A pulse to beat the symbol at, in beats a minute.
    var beat: Int? = nil
    /// Nothing to show yet: the colour drains and the pill steps back.
    var dimmed = false

    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [tint.0, tint.1], startPoint: .top, endPoint: .bottom))
            .overlay {
                // A soft sheen on the upper half, and a fine light rim.
                Capsule().fill(LinearGradient(colors: [.white.opacity(0.28), .white.opacity(0)], startPoint: .top, endPoint: .center))
                    .padding(1.5)
                Capsule().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.75).blendMode(.plusLighter)
            }
            .overlay {
                NoopBeatingSymbol(symbol: symbol, size: side * 0.44, beat: dimmed ? nil : beat)
            }
            .frame(width: side * 1.18, height: side)
            .saturation(dimmed ? 0 : 1)
            .opacity(dimmed ? 0.5 : 1)
            .shadow(color: tint.1.opacity(dimmed ? 0 : 0.45), radius: 7, y: 3)
    }
}

/// The tile's symbol, which beats like a pulse when given one: a quick swell, a smaller echo, rest.
private struct NoopBeatingSymbol: View {
    let symbol: String
    let size: CGFloat
    let beat: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let glyph = Image(systemName: symbol).font(.system(size: size, weight: .semibold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.22), radius: 1, y: 1)
        if let beat, beat > 0, !reduceMotion {
            let period = 60 / Double(min(200, max(30, beat)))
            glyph.keyframeAnimator(initialValue: 1.0, repeating: true) { content, scale in
                content.scaleEffect(scale)
            } keyframes: { _ in
                CubicKeyframe(1.16, duration: period * 0.12)
                CubicKeyframe(1.0, duration: period * 0.14)
                CubicKeyframe(1.08, duration: period * 0.10)
                CubicKeyframe(1.0, duration: period * 0.16)
                LinearKeyframe(1.0, duration: period * 0.48)
            }
        } else {
            glyph
        }
    }
}

/// One slot tile.
struct NoopSlotPill: View {
    /// What sits at the tile's end.
    enum Accessory {
        case none
        /// Opens a page.
        case chevron
        /// Opens a picker in place.
        case menu
        /// How far along something is, 0 to 1, in the tile's colour.
        case progress(Double)
        /// How far along against a target band, both 0 to 1 of the ring: the band drawn lighter on the
        /// track, a white tick at its middle.
        case target(Double, ClosedRange<Double>)
        /// A reading that is live right now.
        case live
    }

    static let height: CGFloat = 60

    let symbol: String
    let tint: (Color, Color)
    let title: String
    let subtitle: String
    var accessory: Accessory = .chevron
    var accessibility: String? = nil
    /// Beats the symbol at this pulse.
    var beat: Int? = nil
    /// Nothing to show yet.
    var dimmed = false
    /// Lit up: something here wants attention soon.
    var glow = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                NoopGlossTile(symbol: symbol, tint: tint, side: 36, beat: beat, dimmed: dimmed)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold))
                        .foregroundStyle(dimmed ? NoopHTMLColor.faint : NoopHTMLColor.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .animation(.smooth(duration: 0.45), value: title)
                    Text(subtitle)
                        .font(NoopHTMLFont.sans(NoopType.caption))
                        .foregroundStyle(NoopHTMLColor.copy)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .layoutPriority(1)
                Spacer(minLength: 0)
                accessoryView
            }
            .padding(.leading, 9).padding(.trailing, 13).padding(.vertical, 4)
            .frame(maxWidth: .infinity, minHeight: Self.height)
            .background {
                Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.075), Color.white.opacity(0.045)],
                                              startPoint: .top, endPoint: .bottom))
            }
            .overlay(Capsule().strokeBorder(glow ? tint.0.opacity(0.55) : NoopHTMLColor.borderStrong, lineWidth: glow ? 1 : 0.5))
            .background {
                if glow {
                    Capsule().fill(tint.1.opacity(0.18)).blur(radius: 14)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility ?? "\(subtitle), \(title)")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .chevron:
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                .foregroundStyle(NoopHTMLColor.faint)
        case .menu:
            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                .foregroundStyle(NoopHTMLColor.faint)
        case .progress(let value):
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
                Circle().trim(from: 0, to: max(0.001, min(1, value)))
                    .stroke(tint.0, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 20, height: 20)
            .animation(.smooth(duration: 0.6), value: value)
        case .target(let value, let band):
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
                Circle().trim(from: band.lowerBound, to: band.upperBound)
                    .stroke(Color.white.opacity(0.22), lineWidth: 3)
                    .rotationEffect(.degrees(-90))
                Circle().trim(from: 0, to: max(0.001, min(1, value)))
                    .stroke(tint.0, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Capsule().fill(.white).frame(width: 1.6, height: 6)
                    .offset(y: -8.5)
                    .rotationEffect(.degrees(360 * (band.lowerBound + band.upperBound) / 2))
            }
            .frame(width: 20, height: 20)
            .animation(.smooth(duration: 0.6), value: value)
        case .live:
            NoopLiveDot(color: tint.0)
        }
    }
}

/// A small dot that breathes while a reading is live.
struct NoopLiveDot: View {
    let color: Color
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.28)).frame(width: 14, height: 14)
                .scaleEffect(on ? 1 : 0.5).opacity(on ? 0 : 1)
            Circle().fill(color).frame(width: 7, height: 7)
        }
        .frame(width: 16, height: 16)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { on = true }
        }
    }
}
