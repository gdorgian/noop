import SwiftUI

// MARK: - Charge: the gauge, the orb, the bar, the strap chip
//
// THE ONE THING TO GET RIGHT: Charge is a DEPLETING BUDGET, not a score. `charge = wake − Σ drains`.
// Everything below exists to make that legible, and the detail that carries it is the GHOST tick —
// the headroom you woke with and have already spent. A build without ghost ticks has shipped a score.
//
// One scalar drives the orb, the ticks, the hero numeral, the state chip and the bar: compute
// `NoopSpecTokens.chargeColor(charge:)` ONCE per render and pass the colour down. Recomputing it per
// component is how five elements end up a shade apart.

// MARK: - Model

/// One entry in the drain ledger. `[bound]` — every field comes from real sessions, stress minutes
/// and step counts. The prototype's four named drains are placeholders.
public struct NoopDrain: Identifiable, Hashable {
    public let id: UUID
    public let label: String
    public let subtitle: String
    public let startedAt: Date
    public let cost: Int

    public init(id: UUID = UUID(), label: String, subtitle: String, startedAt: Date, cost: Int) {
        self.id = id; self.label = label; self.subtitle = subtitle
        self.startedAt = startedAt; self.cost = cost
    }
}

public struct NoopCharge {
    /// The charge the user woke with, 0–100, from the night's recovery. `[bound]`
    public let wake: Double
    /// The end of the sleep session. `[bound]`
    public let wakeTime: Date
    public let drains: [NoopDrain]

    public init(wake: Double, wakeTime: Date, drains: [NoopDrain]) {
        self.wake = wake; self.wakeTime = wakeTime; self.drains = drains
    }

    /// `clamp(wake − Σ cost where startedAt <= now, 4, 100)`. A drain counts only once its start
    /// time has passed, and only if its cost is greater than zero.
    public func charge(at now: Date = .now) -> Double {
        let spent = drains
            .filter { $0.startedAt <= now && $0.cost > 0 }
            .reduce(0) { $0 + Double($1.cost) }
        return min(max(wake - spent, 4), 100)
    }

    public func visibleDrains(at now: Date = .now) -> [NoopDrain] {
        drains.filter { $0.startedAt <= now && $0.cost > 0 }.sorted { $0.startedAt < $1.startedAt }
    }
}

// MARK: - The gauge

/// The tick ring around the orb. 306 × 306, centred in a 318 pt block.
public struct NoopChargeGauge: View {
    private let charge: Double
    private let wake: Double
    private let animated: Bool

    /// `animated` drives the arrival drain — wake → charge over 1150 ms. Pass `true` ONLY on arrival
    /// at Today, never on a value change and never when returning from a pushed screen.
    public init(charge: Double, wake: Double, animated: Bool = false) {
        self.charge = charge; self.wake = wake; self.animated = animated
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Double = 0

    private static let count = 41
    private static let span: Double = 250        // degrees of arc
    private static let start: Double = -125      // so the gap is centred at the BOTTOM
    private static let radius: CGFloat = 142     // tick ring
    private static let markerRadius: CGFloat = 131

    public var body: some View {
        let level = shown
        let lit = Int((level / 100 * 40).rounded())
        let ghost = Int((wake / 100 * 40).rounded())
        let colour = NoopSpecTokens.chargeColor(charge: level)

        ZStack {
            ForEach(0..<Self.count, id: \.self) { i in
                tick(i, lit: lit, ghost: ghost, colour: colour)
            }
            marker(lit: lit)
        }
        .frame(width: 306, height: 306)
        .frame(height: 318)
        .onAppear {
            shown = animated ? wake : charge
            guard animated else { return }
            if reduceMotion {
                shown = charge      // final value; the fade is applied by the caller
            } else {
                withAnimation(NoopSpecMotion.chargeDrain) { shown = charge }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Charge")
        .accessibilityValue("\(Int(charge)) of \(Int(wake))")
    }

    private func angle(_ i: Int) -> Double {
        Self.start + Self.span * Double(i) / Double(Self.count - 1)
    }

    @ViewBuilder
    private func tick(_ i: Int, lit: Int, ghost: Int, colour: Color) -> some View {
        // Every 5th tick is taller — the ring's own scale marks.
        let tall = i % 5 == 0
        let isLit = i <= lit
        let isGhost = !isLit && i <= ghost
        // Lit ticks ramp 0.32 → 1.0 from the start of the arc to the marker, so the ring reads as
        // filling from one end rather than as a uniform block of colour.
        let litOpacity = lit > 0 ? 0.32 + 0.68 * (Double(i) / Double(max(lit, 1))) : 0.32

        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(isLit ? colour.opacity(min(litOpacity, 1))
                  : isGhost ? NoopSpecTokens.auraPale.opacity(0.28)   // spent headroom — keep it
                  : Color.white.opacity(0.13))
            .frame(width: 2, height: tall ? 15 : 9)
            .offset(y: -Self.radius)
            .rotationEffect(.degrees(angle(i)))
            .animation(NoopSpecMotion.gaugeTick, value: isLit)
    }

    private func marker(lit: Int) -> some View {
        Triangle()
            .fill(AuraPalette.textPrimary)
            .frame(width: 12, height: 9)
            .shadow(color: .black.opacity(0.5), radius: 6)
            .offset(y: -Self.markerRadius)
            .rotationEffect(.degrees(angle(lit)))
    }
}

/// The gauge marker. A 12 × 9 isoceles triangle pointing inward.
public struct Triangle: Shape {
    public init() {}
    public func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - The charge bar
//
// Three layers, in this order: track, ghost fill to `wake`, live fill to `charge`. Both fills,
// always — the pale stretch behind the live fill is the same "spent headroom" idea as the ghost ticks.

public struct NoopChargeBar: View {
    private let charge: Double
    private let wake: Double
    private let height: CGFloat

    public init(charge: Double, wake: Double, height: CGFloat = 12) {
        self.charge = charge; self.wake = wake; self.height = height
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(Color.white.opacity(0.06))
                Capsule(style: .continuous)
                    .fill(NoopSpecTokens.auraPale.opacity(0.16))
                    .frame(width: w * min(wake, 100) / 100)
                Capsule(style: .continuous)
                    .fill(NoopSpecTokens.chargeColor(charge: charge))
                    .frame(width: w * min(charge, 100) / 100)
                    .animation(NoopSpecMotion.chargeBar, value: charge)
            }
        }
        .frame(height: height)
    }
}

// MARK: - The strap battery chip
//
// DEVICE battery, not Charge. Deliberately quiet — a status indicator, not a feature. No chevron.

public struct NoopStrapBatteryChip: View {
    /// 0–1. `[bound]` — ONE value feeds Acts 1, 2, 3, 4 and the strap page ring.
    private let level: Double
    private let action: () -> Void

    public init(level: Double, action: @escaping () -> Void) {
        self.level = level; self.action = action
    }

    /// ≤ 20 % amber, ≤ 10 % hot — border, nub, fill and label together, and the pill tints too.
    private var hue: Color? {
        if level <= 0.10 { return NoopSpecTokens.hot }
        if level <= 0.20 { return AuraPalette.effort }
        return nil
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                HStack(spacing: 1) {
                    RoundedRectangle(cornerRadius: 3.4, style: .continuous)
                        .strokeBorder(hue ?? Color(hex: "#EDF1EF").opacity(0.4),
                                      lineWidth: NoopSpecTokens.glyphStrokeWidth)   // the 1 pt exception
                        .frame(width: 21, height: 11)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                                .fill(hue ?? NoopSpecTokens.auraLight)
                                .frame(width: (21 - 2.4) * level, height: 11 - 2.4)
                                .padding(.leading, 1.2)
                        }
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 1.5, topTrailingRadius: 1.5, style: .continuous
                    )
                    .fill(hue ?? Color(hex: "#EDF1EF").opacity(0.4))
                    .frame(width: 1.6, height: 4.4)
                }
                Text("\(Int((level * 100).rounded()))%")
                    .font(NoopSpecType.chipValue)
                    .foregroundStyle(hue ?? NoopSpecTokens.textBody)
            }
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(hue.map { $0.opacity(0.12) } ?? AuraPalette.controlFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(hue.map { $0.opacity(0.34) } ?? NoopSpecTokens.controlBorderStrong,
                                  lineWidth: NoopSpecTokens.hairlineWidth)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Strap battery")
        .accessibilityValue("\(Int(level * 100)) percent")
    }
}
