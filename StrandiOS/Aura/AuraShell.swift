import SwiftUI
import StrandDesign
import WhoopStore

// MARK: - AuraShell — the Aura app shell
//
// The design is a whole app, not a screen: five tabs (Today / Rest / Charge / Effort / Trends), its own
// floating pill tab bar, and the ambient state haze behind everything. Grafting one Aura screen into
// NOOP's existing four-tab shell is what made the first attempt read as "not the design" — the chrome
// around it was still the old app's.
//
// This hosts the Aura screens under the design's own bar, so the whole surface is the design. The data
// underneath is unchanged NOOP.
struct AuraShell: View {

    @EnvironmentObject var repo: Repository

    enum Tab: String, CaseIterable, Identifiable {
        case today, rest, charge, effort, trends
        var id: String { rawValue }

        var label: String {
            switch self {
            case .today:  return String(localized: "Today")
            case .rest:   return String(localized: "Rest")
            case .charge: return String(localized: "Charge")
            case .effort: return String(localized: "Effort")
            case .trends: return String(localized: "Trends")
            }
        }

        /// The design's glyph set, mapped to their closest SF Symbols.
        var symbol: String {
            switch self {
            case .today:  return "circle.circle"
            case .rest:   return "moon"
            case .charge: return "figure.stand"
            case .effort: return "flame"
            case .trends: return "chart.line.uptrend.xyaxis"
            }
        }
    }

    @State private var tab: Tab = .today

    private var day: DailyMetric? { repo.days.last(where: { $0.recovery != nil }) ?? repo.days.last }
    private var accent: Color { Aura.accent(forCharge: day?.recovery.map { $0 / 100 }) }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Page + the state-tinted ambient, drawn once for the whole shell rather than per screen —
            // the design puts it on the app container, above the scroll and behind every tab.
            Aura.page.ignoresSafeArea()
            ambient

            Group {
                switch tab {
                case .today:  AuraTodayView()
                case .rest:   AuraRestView()
                case .charge: AuraChargeView()
                case .effort: AuraEffortView()
                case .trends: AuraTrendsView()
                }
            }

            tabBar
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var ambient: some View {
        VStack {
            Ellipse()
                .fill(RadialGradient(colors: [accent.opacity(0.16), accent.opacity(0)],
                                     center: .center, startRadius: 0, endRadius: 230))
                .frame(width: 460, height: 400)
                .blur(radius: 18)
                .offset(y: -140)
            Spacer()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// The floating pill bar. The selected tab takes `flex: 1.7` against the others' `1` and fills with
    /// the state accent, so the bar itself carries the body state — the same accent as the orb.
    private var tabBar: some View {
        // The design's `flex: 1.7 1 0` on the selected tab against `1 1 0` on the rest. SwiftUI has no
        // flex-grow, and `layoutPriority` is NOT its equivalent — it decides who gets squeezed under
        // pressure, not how free space is shared, so using it collapsed the four idle tabs to their
        // glyphs. Widths are therefore computed from the same ratio the design uses: the selected tab
        // takes 1.7 / (1.7 + 4) of the row and the others split the remainder evenly.
        GeometryReader { geo in
            let inner = geo.size.width - 8                       // container padding
            let unit = inner / (1.7 + Double(Tab.allCases.count - 1))
            HStack(spacing: 0) {
                ForEach(Tab.allCases) { t in
                    let on = t == tab
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { tab = t }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: t.symbol)
                                .font(.system(size: 19, weight: .regular))
                                .foregroundStyle(on ? Aura.onAccent : Aura.inkMuted)
                            if on {
                                Text(t.label)
                                    .font(Aura.text(12.5, .semibold))
                                    .foregroundStyle(Aura.onAccent)
                                    .lineLimit(1).fixedSize()
                            }
                        }
                        .frame(width: unit * (on ? 1.7 : 1), height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(on ? accent : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color(hex: "#171C1A").opacity(0.82))
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.5), radius: 13, y: 8)
            )
        }
        .frame(height: 54)
        .padding(.horizontal, 14)
        .padding(.bottom, 6)
    }
}
