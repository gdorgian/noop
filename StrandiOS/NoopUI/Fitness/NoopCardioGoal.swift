#if os(iOS)
import SwiftUI

// MARK: - Words for a goal

/// How a goal is written, in the app and on the Lock Screen banner (which ships no strings of its own).
enum NoopCardioGoalText {
    static func clock(_ seconds: Int) -> String {
        let h = seconds / 3600, m = seconds % 3600 / 60, s = seconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    /// Kilometres with one decimal under ten and none needed past it, the way a runner says them.
    static func km(_ meters: Double) -> String {
        let k = max(0, meters) / 1000
        return k >= 10 && k.rounded() == k ? String(format: "%.0f", k) : String(format: "%.1f", k)
    }

    /// "30 min" / "5 km" — a goal on a chip or a line.
    static func short(_ goal: CardioGoal) -> String {
        switch goal {
        case .time(let s): s % 3600 == 0 ? "\(s / 3600) h" : s >= 3600 ? "\(s / 3600) h \(s % 3600 / 60) min" : "\(s / 60) min"
        case .distance(let m): "\(km(m)) km"
        }
    }
}

// MARK: - Goal sheet

/// "Set a goal or just go": open, a length of time, or a distance (for sports with a route), and the
/// heart-rate zone the strap coaches toward. Used before a session starts (from a long press on a sport) and
/// during one (from the live screen), so the same choices look the same in both places.
struct NoopCardioGoalSheet: View {
    enum Mode { case start, edit }
    private enum Kind: Hashable { case open, time, distance }

    let sport: String
    var mode: Mode = .start
    let commit: (CardioGoal?, Int?) -> Void

    @EnvironmentObject private var profile: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var kind: Kind
    @State private var minutes: Int
    /// Tenths of a kilometre, so every step is exact.
    @State private var tenths: Int
    @State private var zone: Int?

    private static let minuteSteps = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90, 105, 120, 150, 180, 240]
    private static let minutePresets = [15, 20, 30, 45, 60, 90]
    private static let kmPresets = [10, 30, 50, 100, 211]

    init(sport: String, mode: Mode = .start, goal: CardioGoal? = nil, zone: Int? = nil,
         commit: @escaping (CardioGoal?, Int?) -> Void) {
        self.sport = sport
        self.mode = mode
        self.commit = commit
        switch goal {
        case .time(let s)?:
            _kind = State(initialValue: .time); _minutes = State(initialValue: max(5, s / 60)); _tenths = State(initialValue: 50)
        case .distance(let m)?:
            _kind = State(initialValue: .distance); _minutes = State(initialValue: 30); _tenths = State(initialValue: max(1, Int((m / 100).rounded())))
        case nil:
            _kind = State(initialValue: .open); _minutes = State(initialValue: 30); _tenths = State(initialValue: 50)
        }
        _zone = State(initialValue: zone)
    }

    private var hasRoute: Bool { WorkoutCatalog.sport(named: sport)?.isDistanceSport ?? false }
    private var zonesTrusted: Bool { NoopZoneSource.current(profile).trusted }
    private var zones: [(Int, Int)] {
        profile.hrZoneSet.zones.map { (Int($0.lower.rounded()), Int($0.upper.rounded())) }
    }

    private var goal: CardioGoal? {
        switch kind {
        case .open: nil
        case .time: .time(seconds: minutes * 60)
        case .distance: .distance(meters: Double(tenths) * 100)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(NoopHTMLColor.inkSoft)
                            .frame(width: 36, height: 36).background(Color.white.opacity(0.07), in: Circle())
                            .noopHitTarget()
                    }
                    .accessibilityLabel("Close")
                }
                hero.padding(.bottom, NoopSpace.xl)

                NoopTabs(options: hasRoute || kind == .distance
                         ? [("Open", Kind.open), ("Time", .time), ("Distance", .distance)]
                         : [("Open", Kind.open), ("Time", .time)],
                         selection: $kind)
                    .padding(.bottom, NoopSpace.l)

                ZStack {
                    switch kind {
                    case .open: openNote.transition(.opacity)
                    case .time:
                        dial(value: "\(minutes)", unit: "min",
                             minus: { step(&minutes, in: Self.minuteSteps, by: -1) },
                             plus: { step(&minutes, in: Self.minuteSteps, by: 1) },
                             presets: Self.minutePresets.map { p in ("\(p)", p == minutes, { minutes = p }) })
                            .transition(.opacity)
                    case .distance:
                        dial(value: NoopCardioGoalText.km(Double(tenths) * 100), unit: "km",
                             minus: { tenths = max(1, tenths - (tenths > 100 ? 10 : 5)) },
                             plus: { tenths = min(4220, tenths + (tenths >= 100 ? 10 : 5)) },
                             presets: Self.kmPresets.map { p in (NoopCardioGoalText.km(Double(p) * 100), p == tenths, { tenths = p }) })
                            .transition(.opacity)
                    }
                }
                .frame(minHeight: 196, alignment: .top)
                .animation(NoopMotion.swap, value: kind)

                zonePicker.padding(.top, NoopSpace.m)
            }
            .padding(.horizontal, NoopSpace.l)
            .padding(.top, NoopSpace.m)
            .padding(.bottom, NoopSpace.xl)
        }
        .safeAreaInset(edge: .bottom) {
            NoopActionButton(title: mode == .start ? "Start \(sport.lowercased())" : "Save goal",
                             systemImage: mode == .start ? "play.fill" : nil) {
                commit(goal, zonesTrusted ? zone : nil)
                dismiss()
            }
            .padding(.horizontal, NoopSpace.l)
            .padding(.bottom, NoopSpace.xs)
            .background(NoopHTMLColor.canvas.opacity(0.92).ignoresSafeArea())
        }
        .background(NoopHTMLColor.canvas.ignoresSafeArea())
        .environment(\.noopAccent, NoopAccent(fill: NoopHTMLColor.blueLight, ink: NoopHTMLColor.blueInk))
        .sensoryFeedback(.selection, trigger: minutes)
        .sensoryFeedback(.selection, trigger: tenths)
        .sensoryFeedback(.selection, trigger: zone)
    }

    private var hero: some View {
        VStack(spacing: NoopSpace.s) {
            ZStack {
                Circle().fill(RadialGradient(colors: [NoopHTMLColor.blueLight.opacity(0.32), .clear], center: .center,
                                             startRadius: 10, endRadius: 58))
                    .frame(width: 116, height: 116)
                Circle().fill(NoopHTMLColor.blueLight.opacity(0.14))
                    .overlay(Circle().strokeBorder(NoopHTMLColor.blueLight.opacity(0.28), lineWidth: 0.6))
                    .frame(width: 68, height: 68)
                Image(systemName: NoopFitnessCardioLive.symbol(for: sport))
                    .font(.system(size: 29, weight: .medium)).foregroundStyle(NoopHTMLColor.blueLight)
                    .symbolEffect(.bounce, value: kind)
            }
            .frame(height: 96)
            Text(sport).font(NoopHTMLFont.outfit(NoopType.title2, weight: .light)).foregroundStyle(NoopHTMLColor.ink)
            Text(mode == .start ? "Set a goal, or just go" : "Change what this session is aiming for")
                .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
        }
    }

    private var openNote: some View {
        VStack(spacing: NoopSpace.xs) {
            Image(systemName: "infinity").font(.system(size: 30, weight: .light)).foregroundStyle(NoopHTMLColor.blueLight)
                .frame(height: 64)
            Text("No finish line").font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
            Text("The clock runs until you finish. Heart rate, Effort\(hasRoute ? " and route" : "") are kept either way.")
                .font(NoopHTMLFont.sans(NoopType.footnote)).foregroundStyle(NoopHTMLColor.copy)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, NoopSpace.m)
        .frame(maxWidth: .infinity)
    }

    /// The figure, large and light, between a minus and a plus; presets under it for the usual answers.
    private func dial(value: String, unit: String, minus: @escaping () -> Void, plus: @escaping () -> Void,
                      presets: [(String, Bool, () -> Void)]) -> some View {
        VStack(spacing: NoopSpace.m) {
            HStack(spacing: NoopSpace.m) {
                stepButton("minus", label: "Less", action: minus)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(value).font(NoopHTMLFont.outfit200(76)).monospacedDigit().foregroundStyle(NoopHTMLColor.ink)
                        .contentTransition(.numericText())
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(unit).font(NoopHTMLFont.sans(NoopType.subhead, weight: .semibold)).foregroundStyle(NoopHTMLColor.blueLight)
                }
                .frame(maxWidth: .infinity)
                .animation(.snappy(duration: 0.22), value: value)
                .accessibilityElement(children: .combine)
                stepButton("plus", label: "More", action: plus)
            }
            HStack(spacing: NoopSpace.xs) {
                ForEach(Array(presets.enumerated()), id: \.offset) { _, p in
                    NoopChip(title: p.0, isOn: p.1, action: p.2)
                }
            }
        }
        .padding(.vertical, NoopSpace.m)
        .frame(maxWidth: .infinity)
        .background(NoopHTMLColor.card, in: RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: NoopRadius.card, style: .continuous).strokeBorder(NoopHTMLColor.border, lineWidth: 0.5))
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button { withAnimation(.snappy(duration: 0.22)) { action() } } label: {
            Image(systemName: symbol).font(.system(size: 17, weight: .semibold)).foregroundStyle(NoopHTMLColor.ink)
                .frame(width: 48, height: 48).background(Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(NoopHTMLPressStyle())
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }

    private func step(_ value: inout Int, in steps: [Int], by direction: Int) {
        if direction > 0 { value = steps.first { $0 > value } ?? value }
        else { value = steps.last { $0 < value } ?? value }
    }

    private var zonePicker: some View {
        VStack(alignment: .leading, spacing: NoopSpace.s) {
            NoopSectionLabel("Heart-rate zone")
            HStack(spacing: NoopSpace.xs) {
                NoopChip(title: "Off", isOn: zone == nil) { zone = nil }
                ForEach(1...5, id: \.self) { z in
                    NoopChip(title: "\(z)", dot: NoopFitnessZonesCard.colors[z - 1], isOn: zone == z) { zone = z }
                }
            }
            .disabled(!zonesTrusted)
            .opacity(zonesTrusted ? 1 : 0.4)
            Group {
                if !zonesTrusted {
                    Text("Confirm your age or set your max heart rate in You, and the strap can coach you by zone.")
                } else if let zone, zones.indices.contains(zone - 1) {
                    Text("Zone \(zone) · \(zones[zone - 1].0)–\(zones[zone - 1].1) bpm. The strap nudges you up when you drift under it and eases you off above it.")
                } else {
                    Text("Pick a zone and the strap nudges you back into it. Off, it stays quiet.")
                }
            }
            .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
            .fixedSize(horizontal: false, vertical: true)
            .animation(nil, value: zone)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
