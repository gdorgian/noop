#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura screens
//
// The seven screens of the Aura direction, and the floating pill bar that moves between five of them.
// Band and You are NOT tabs — they hang off the header's two controls, which is what keeps the bar down
// to the five things a user opens daily.

enum AuraScreen: String, CaseIterable, Identifiable {
    case today
    case rest
    case charge
    case effort
    case trends
    case band
    case profile

    var id: String { rawValue }

    /// The five that appear in the tab bar, in order.
    static let tabs: [AuraScreen] = [.today, .rest, .charge, .effort, .trends]

    #if DEBUG
    /// Simulator-only visual regression seam. Launch with `--aura-screen rest` (or another raw value)
    /// to inspect a screen without adding production navigation or mock-data controls.
    static var debugLaunchScreen: AuraScreen {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "--aura-screen"),
              arguments.indices.contains(flag + 1),
              let screen = AuraScreen(rawValue: arguments[flag + 1]) else { return .today }
        return screen
    }
    #endif

    /// The quiet line above the headline.
    var greeting: String {
        switch self {
        case .today:   return String(localized: "Hi, Gabriel")
        case .rest:    return String(localized: "Last night")
        case .charge:  return String(localized: "Right now")
        case .effort:  return String(localized: "Saturday")
        case .trends:  return String(localized: "Your own normal")
        case .band:    return String(localized: "Your band")
        case .profile: return String(localized: "Account")
        }
    }

    /// The screen's one-line statement. Every screen opens with a sentence, never with a number.
    var headline: String {
        switch self {
        case .today:   return String(localized: "Here’s your morning read")
        case .rest:    return String(localized: "You slept 7h 12m")
        case .charge:  return String(localized: "Your body is settled")
        case .effort:  return String(localized: "Effort so far today")
        case .trends:  return String(localized: "Where you’re trending")
        case .band:    return String(localized: "Synced 4 minutes ago")
        case .profile: return String(localized: "Gabriel D.")
        }
    }

    var tabLabel: String {
        switch self {
        case .today:   return String(localized: "Today")
        case .rest:    return String(localized: "Rest")
        case .charge:  return String(localized: "Charge")
        case .effort:  return String(localized: "Effort")
        case .trends:  return String(localized: "Trends")
        case .band:    return String(localized: "Band")
        case .profile: return String(localized: "You")
        }
    }

    var symbol: String {
        switch self {
        case .today:   return "sun.max"
        case .rest:    return "moon"
        case .charge:  return "figure.stand"
        case .effort:  return "bolt"
        case .trends:  return "chart.bar"
        case .band:    return "sensor.tag.radiowave.forward"
        case .profile: return "person"
        }
    }
}

// MARK: - Tab bar

/// The floating pill bar. The active tab is filled with the accent and is the ONLY one that shows a
/// label — the fill carries the selection, so five labels would be five things to read for one bit of
/// information.
struct AuraTabBar: View {
    let selection: AuraScreen
    let onSelect: (AuraScreen) -> Void
    @State private var dragOriginIndex: Int?

    /// Width of an inactive, icon-only pill. The active pill takes whatever is left, which reproduces the
    /// direction's wide-active proportion without a layout pass to measure it.
    private static let inactiveWidth: CGFloat = 56

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AuraScreen.tabs) { screen in
                tab(screen)
            }
        }
        .padding(6)
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
        .padding(.horizontal, 14)
        .animation(NoopMotion.value, value: selection)
        .simultaneousGesture(tabSwipeGesture)
    }

    /// Liquid-Glass-style scrubbing: keep a finger down on the bar and slide across destinations. The
    /// ordinary buttons remain available, so this gesture is an enhancement rather than the only path.
    private var tabSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let current = AuraScreen.tabs.firstIndex(of: selection) ?? 0
                if dragOriginIndex == nil { dragOriginIndex = current }
                guard let origin = dragOriginIndex else { return }
                let steps = Int((value.translation.width / Self.inactiveWidth).rounded())
                let target = min(max(origin + steps, 0), AuraScreen.tabs.count - 1)
                guard target != current else { return }
                onSelect(AuraScreen.tabs[target])
            }
            .onEnded { _ in dragOriginIndex = nil }
    }

    private func tab(_ screen: AuraScreen) -> some View {
        let isOn = screen == selection
        return Button { onSelect(screen) } label: {
            HStack(spacing: 7) {
                Image(systemName: screen.symbol)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(isOn ? AuraPalette.onAccent : AuraPalette.textQuiet)
                if isOn {
                    Text(screen.tabLabel)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(AuraPalette.onAccent)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .frame(height: 46)
            .frame(maxWidth: isOn ? .infinity : Self.inactiveWidth)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isOn ? AnyShapeStyle(AuraPalette.accent) : AnyShapeStyle(Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(screen.tabLabel))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Header

/// The greeting, the headline, and the two controls that reach the screens the tab bar does not carry.
/// Shared by all seven screens, which is why it lives in the shell rather than in any one of them.
struct AuraHeader: View {
    let screen: AuraScreen
    let greeting: String
    let headline: String
    let initial: String
    let onOpenBand: () -> Void
    let onOpenProfile: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(screen == .today
                          ? .system(size: 30, weight: .regular, design: .rounded)
                          : StrandFont.subhead)
                    .foregroundStyle(screen == .today ? AuraPalette.textPrimary : AuraPalette.textSecondary)
                if screen == .today {
                    EmptyView()
                } else if screen == .band {
                    AuraBandConnectionHeadline()
                } else {
                    Text(headline)
                        .font(.system(size: 23, weight: .regular, design: .rounded))
                        .foregroundStyle(AuraPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 122)

            HStack(spacing: 8) {
                AuraLiveBatteryButton(action: onOpenBand)

                AuraProfileHeaderButton(action: onOpenProfile)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.top, 2)
        }
        .padding(.top, 12)
    }
}

/// LiveState publishes heart rate and R-R packets around once per second. Keeping that observation in
/// these two tiny leaves prevents the whole Aura shell from being invalidated by data only the header uses.
private struct AuraLiveBatteryButton: View {
    @EnvironmentObject private var live: LiveState
    let action: () -> Void

    private var percent: Int? {
        live.connected ? live.batteryPct.map { Int($0.rounded()) } : nil
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                AuraBatteryGlyph(fraction: Double(percent ?? 0) / 100)
                    .frame(width: 21, height: 12)
                Text(verbatim: percent.map { "\($0)%" } ?? "—")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(AuraPalette.textPrimary)
                if live.charging == true {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AuraPalette.effort)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 10)
            .frame(minWidth: 62, minHeight: 38)
            .background(Capsule(style: .continuous).fill(AuraPalette.controlFill))
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(percent.map { Text("Band battery \($0) percent") } ?? Text("Band disconnected"))
    }
}

private struct AuraProfileHeaderButton: View {
    @EnvironmentObject private var profile: ProfileStore
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AuraProfilePhoto(size: 38)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("Account"))
    }
}

private struct AuraBandConnectionHeadline: View {
    @EnvironmentObject private var live: LiveState

    var body: some View {
        Text(live.connected ? String(localized: "Connected and reading") : String(localized: "Not connected"))
            .font(.system(size: 23, weight: .regular, design: .rounded))
            .foregroundStyle(AuraPalette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The band's charge at header size, where SF Symbols' own battery glyphs read as either empty or full
/// and nothing in between.
struct AuraBatteryGlyph: View {
    let fraction: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .strokeBorder(AuraPalette.accent, lineWidth: 1.2)
            .frame(width: 19, height: 10)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(AuraPalette.accent)
                    .padding(1)
                    .frame(width: 19 * AuraGaugeMath.clampFraction(fraction))
            }
            .accessibilityHidden(true)
    }
}
#endif
