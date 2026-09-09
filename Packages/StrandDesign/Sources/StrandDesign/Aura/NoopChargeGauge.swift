import SwiftUI
// No UIKit and no CoreText here on purpose: SwiftUI is complete for this file. Only
// NoopSpecType.swift needs either, and it imports both explicitly.

// WHERE THIS FILE GOES: Packages/StrandDesign/Sources/StrandDesign/Aura/
//
// Inside the StrandDesign package, beside NoopPalette.swift. Commit 1ecb5712 deleted the old Aura
// layer — AuraPalette.swift with it — so the palette now travels with this pack as NoopPalette:
// a palette-only file, no components and no body-state type. `import SwiftUI` is then complete and no target dependency or
// project.yml entry is needed (SPM globs Sources/StrandDesign/). Compiled into an app target instead,
// every `NoopPalette` reference fails with "cannot find in scope", which looks exactly like a missing
// palette file. See spec/13-branch-corrected-foundation.md, then spec/12-palette-bindings.md.

// MARK: - Charge: the gauge, the orb, the bar, the strap chip
//
// THE ONE THING TO GET RIGHT: Charge is a DEPLETING BUDGET, not a score. Everything below exists to
// make that legible, and the detail that carries it is the GHOST tick — the headroom you woke with
// and have already spent. A build without ghost ticks has shipped a score.
//
// AND THE ONE THING NOT TO DO: DERIVE IT HERE. `50-wiring.md` Part 1 §1 is unambiguous — an intraday
// Charge engine does not exist. `RecoveryScorer.recovery(...)` gives the MORNING number,
// `chargeDrivers(...)` explains it, `ActivityCostEngine` prices a sport as a historical average.
// Nothing owns "the level, right now". So `wake − Σ drains` in a design file is not an
// implementation of the model; it IS a model, invented in a view layer, unreviewed, and it would
// have shipped as the product's number. This file therefore ACCEPTS the level and never computes
// it. The arithmetic survives in ONE place — a `#if DEBUG` demo seed, so the prototype's screens
// still animate — and it cannot be reached from a release build.
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
    /// The charge the user woke with, 0–100 — `RecoveryScorer.recovery(...)`. `[bound]`
    public let wake: Double
    /// The end of the sleep session. `[bound]`
    public let wakeTime: Date
    /// **The level now, 0–100, PRECOMPUTED by the authoritative engine.** `[bound]`
    ///
    /// There is deliberately no `charge(at:)` on this type. A view that can compute the number will
    /// compute it, and then two answers exist. If the engine has no value for right now, the screen
    /// has no number — which is a state the act spec covers (`41-act2-day.md`), not a gap to fill
    /// with arithmetic.
    public let charge: Double
    /// The ledger the screen lists under the gauge. Display data: it does NOT add up to `charge`,
    /// and nothing here should make it look as though it must.
    public let drains: [NoopDrain]

    public init(wake: Double, wakeTime: Date, charge: Double, drains: [NoopDrain]) {
        self.wake = wake; self.wakeTime = wakeTime
        self.charge = charge; self.drains = drains
    }

    /// The rows the ledger shows: started, and priced. Filtering for display — the only arithmetic
    /// in this type, and it touches no level.
    public func visibleDrains(at now: Date = .now) -> [NoopDrain] {
        drains.filter { $0.startedAt <= now && $0.cost > 0 }.sorted { $0.startedAt < $1.startedAt }
    }
}

#if DEBUG
public extension NoopCharge {
    /// **The prototype's seed, and it is not the product's model.** `clamp(wake − Σ cost where
    /// startedAt <= now, 4, 100)`. It exists so previews and the demo build have a plausible falling
    /// number to animate.
    ///
    /// **TWO GATES, AND BOTH ARE REQUIRED.** `#if DEBUG` keeps it out of the release binary;
    /// `--demo-seed` keeps it out of a debug build handed to a reviewer, who must see the real
    /// absent states because those are what a new user sees. `isDemoSeeded` is the runtime half and
    /// this method returns `nil` without it — a caller that force-unwraps has removed the gate.
    ///
    /// Do not promote this to the shipping initialiser "temporarily". If the level is not available
    /// yet, the screen renders its no-number state.
    static var isDemoSeeded: Bool {
        ProcessInfo.processInfo.arguments.contains("--demo-seed")
    }

    static func demoSeed(wake: Double,
                         wakeTime: Date,
                         drains: [NoopDrain],
                         at now: Date = .now) -> NoopCharge? {
        guard isDemoSeeded else { return nil }
        let spent = drains
            .filter { $0.startedAt <= now && $0.cost > 0 }
            .reduce(0) { $0 + Double($1.cost) }
        return NoopCharge(wake: wake,
                          wakeTime: wakeTime,
                          charge: min(max(wake - spent, 4), 100),
                          drains: drains)
    }
}
#endif

// NO RELEASE FALLBACK INVENTS A VALUE. There is deliberately no `NoopCharge.placeholder`, no
// `.preview`, no default `charge: 50`, and no non-DEBUG path to the arithmetic above — not for
// charge, not for pulse, not for a health score, not for a session measurement. Every word,
// measurement and derived value on a release screen has a real source or a defensible calculation;
// where the source is absent the screen renders its absent state, which is specified
// (`41-act2-day.md` §2.2, and `NoopSpecTokens.ChargeEvidence`). If you need a number to look at
// while building, pass `--demo-seed` to a debug build.

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
    @State private var latestCharge: Double = 0
    @State private var arrived = false

    private static let count = 41
    private static let span: Double = 250        // degrees of arc
    private static let start: Double = -125      // so the gap is centred at the BOTTOM
    private static let radius: CGFloat = 142     // tick ring
    private static let markerRadius: CGFloat = 131

    /// CLAMPED AT BOTH ENDS, and both ends are real. 0 is a flat battery and 100 is a full one; a
    /// level above 100 puts the marker past the end of the arc and a negative one puts it under the
    /// gap, and the ring is a fixed 41 ticks either way. `min` alone — which is what the bar and
    /// the battery chip had — clamps the top and lets the bottom through.
    private static func clamped(_ v: Double) -> Double { min(max(v, 0), 100) }

    public var body: some View {
        let level = Self.clamped(shown)
        let lit = Int((level / 100 * 40).rounded())
        let ghost = Int((Self.clamped(wake) / 100 * 40).rounded())
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
            latestCharge = charge
            shown = animated ? wake : charge
            guard animated else { arrived = true; return }
            if reduceMotion {
                shown = charge      // final value; the fade is applied by the caller
                arrived = true
            } else {
                withAnimation(NoopSpecMotion.chargeDrain) { shown = charge }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
                    arrived = true
                    guard shown != latestCharge else { return }
                    withAnimation(NoopSpecMotion.chargeBar) { shown = latestCharge }
                }
            }
        }
        // THE GAUGE HAS TO FOLLOW ITS INPUT AFTER THE FIRST FRAME. `shown` was set in `onAppear`
        // and nowhere else, so a charge that changed while Today was up — a sync landing, a session
        // being priced, the demo slider moving — left the ring, the marker and the colour on the
        // old value while the sentence beside them read the new one.
        //
        // And it must NOT replay the arrival drain to get there: that animation means "this is what
        // you have spent since you woke", and running it on an update tells the same story twice.
        // A value change moves on `chargeBar`'s 500 ms, which is the same curve the bar uses.
        .onChange(of: charge) { new in
            latestCharge = new
            guard arrived else { return }               // still draining; the drain owns `shown`
            if reduceMotion {
                shown = new
            } else {
                withAnimation(NoopSpecMotion.chargeBar) { shown = new }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Charge")
        .accessibilityValue("\(Int(Self.clamped(charge))) of \(Int(Self.clamped(wake)))")
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
            .fill(NoopPalette.textPrimary)
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
            // CLAMPED AT BOTH ENDS. `min(charge, 100)` was clamping the top only, so a negative or
            // absent-then-defaulted level produced a negative frame width — which SwiftUI resolves
            // as zero on the live fill and as a layout warning on the ghost.
            let ghost = min(max(wake, 0), 100) / 100
            let live = min(max(charge, 0), 100) / 100
            ZStack(alignment: .leading) {
                Capsule(style: .continuous).fill(Color.white.opacity(0.06))
                Capsule(style: .continuous)
                    .fill(NoopSpecTokens.auraPale.opacity(0.16))
                    .frame(width: w * ghost)
                Capsule(style: .continuous)
                    .fill(NoopSpecTokens.chargeColor(charge: min(max(charge, 0), 100)))
                    .frame(width: w * live)
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
    private let level: Double?
    private let action: () -> Void

    /// Pass `nil` (or the CoreBluetooth disconnected sentinel −1) when no reading exists. The chip
    /// then shows an em dash; absence must never be converted into a fabricated zero-percent strap.
    public init(level: Double?, action: @escaping () -> Void) {
        self.level = level; self.action = action
    }

    private var pct: Double? {
        guard let level, level >= 0 else { return nil }
        return min(level, 1)
    }

    /// ≤ 20 % amber, ≤ 10 % hot — border, nub, fill and label together, and the pill tints too.
    private var hue: Color? {
        guard let pct else { return nil }
        if pct <= 0.10 { return NoopSpecTokens.hot }
        if pct <= 0.20 { return NoopPalette.effort }
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
                                .frame(width: (21 - 2.4) * (pct ?? 0), height: 11 - 2.4)
                                .padding(.leading, 1.2)
                        }
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0, bottomLeadingRadius: 0,
                        bottomTrailingRadius: 1.5, topTrailingRadius: 1.5, style: .continuous
                    )
                    .fill(hue ?? Color(hex: "#EDF1EF").opacity(0.4))
                    .frame(width: 1.6, height: 4.4)
                }
                Text(pct.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                    .noopText(NoopSpecType.Role.chipValue)
                    .foregroundStyle(pct == nil ? NoopPalette.textDim : (hue ?? NoopSpecTokens.textBody))
            }
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(hue.map { $0.opacity(0.12) } ?? NoopPalette.controlFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(hue.map { $0.opacity(0.34) } ?? NoopSpecTokens.controlBorderStrong,
                                  lineWidth: NoopSpecTokens.hairlineWidth)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Strap battery")
        .accessibilityValue(pct.map { "\(Int(($0 * 100).rounded())) percent" } ?? "Unavailable")
    }
}
