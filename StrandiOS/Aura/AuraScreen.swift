#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura screens
//
// Aura's primary destinations plus the detail screens reached from them. Charge, Effort and Band remain
// routable, but the persistent bar follows the Act handoff: Today, Trends, a centre action, Rest and You.

enum AuraScreen: String, CaseIterable, Identifiable {
    case today
    case rest
    case charge
    case effort
    case trends
    case band
    case profile

    var id: String { rawValue }

    /// Navigation destinations in the persistent bar. The centre `+` is an action, not a fifth tab.
    static let tabs: [AuraScreen] = [.today, .trends, .rest, .profile]

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

/// The floating Aura bar. Every navigation destination keeps its label visible; the centre `+` is an
/// overlaid action that opens real quick actions and never changes the selected destination.
struct AuraTabBar: View {
    let selection: AuraScreen
    let onSelect: (AuraScreen) -> Void
    let onAction: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var motion = NoopMotionState.shared

    private var poseStill: Bool { motion.poseStill(reduceMotion) }
    private var visualSelection: AuraScreen {
        switch selection {
        case .charge: return .today
        case .band: return .profile
        default: return selection
        }
    }

    var body: some View {
        NoopSpecTabBar(
            items: [
                NoopSpecTabItem(id: AuraScreen.today, label: AuraScreen.today.tabLabel, glyph: .today),
                NoopSpecTabItem(id: AuraScreen.trends, label: AuraScreen.trends.tabLabel, glyph: .trends),
                NoopSpecTabItem(id: AuraScreen.rest, label: AuraScreen.rest.tabLabel, glyph: .moon),
                NoopSpecTabItem(id: AuraScreen.profile, label: AuraScreen.profile.tabLabel, glyph: .person),
            ],
            selection: visualSelection,
            activeHue: activeHue,
            activeInk: activeInk,
            onSelect: onSelect,
            onAction: onAction
        )
        .animation(NoopMotion.gated(NoopMotion.value, reduced: poseStill), value: selection)
    }

    private var activeHue: Color {
        switch visualSelection {
        case .rest: return NoopSpecTokens.lavender
        case .profile: return NoopSpecTokens.blush
        default: return NoopSpecTokens.aura
        }
    }

    private var activeInk: Color {
        switch visualSelection {
        case .rest: return Color(hex: "#0D1120")
        case .profile: return Color(hex: "#2A0E14")
        default: return NoopSpecTokens.onAura
        }
    }

    private func tab(_ screen: AuraScreen, width: CGFloat) -> some View {
        let isOn = screen == visualSelection
        let activeFill: Color = switch screen {
        case .profile: Color(hex: "#E08A9B")
        case .rest: AuraPalette.rest.opacity(0.90)
        default: AuraPalette.accent
        }
        let activeInk = screen == .profile ? Color(hex: "#2A0E14")
            : screen == .rest ? Color(hex: "#0D1120")
            : AuraPalette.onAccent
        return Button { onSelect(screen) } label: {
            HStack(spacing: 7) {
                Image(systemName: screen.symbol)
                    .font(.system(size: 15, weight: isOn ? .semibold : .regular))
                    .foregroundStyle(isOn ? activeInk : AuraPalette.textQuiet)
                if isOn {
                    Text(screen.tabLabel)
                        .font(AuraFont.ui(12.5, weight: .semibold))
                        .foregroundStyle(activeInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(width: width, height: 46)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(isOn ? AnyShapeStyle(activeFill) : AnyShapeStyle(Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(screen.tabLabel))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private var actionButton: some View {
        Button(action: onAction) {
            Text(verbatim: "+")
                .font(AuraFont.display(23, weight: .light))
                .foregroundStyle(AuraPalette.onAccent)
                .offset(y: -1)
                .frame(width: 44, height: 44)
                .background(Circle().fill(AuraPalette.accent))
                .shadow(color: AuraPalette.accent.opacity(0.40), radius: 7, y: 4)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 46)
        .accessibilityLabel(Text("Add or start"))
        .accessibilityHint(Text("Opens quick actions"))
    }
}

// MARK: - Header

/// The greeting, the headline, and the two controls that reach the screens the tab bar does not carry.
/// Shared by all seven screens, which is why it lives in the shell rather than in any one of them.
struct AuraHeader: View {
    let screen: AuraScreen
    let greeting: String
    let headline: String
    let dayLabel: String
    let dayPickerOpen: Bool
    let onToggleDayPicker: () -> Void
    let onBackToParent: () -> Void
    let onOpenBand: () -> Void
    let onOpenProfile: () -> Void

    var body: some View {
        Group {
            if screen == .charge || screen == .band {
                HStack(spacing: 12) {
                    Button(action: onBackToParent) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AuraPalette.textSecondary)
                            .offset(x: -1)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(AuraPalette.controlFill))
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.09), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    Text(screen == .band ? String(localized: "You") : String(localized: "Today"))
                        .font(AuraFont.ui(13.5))
                        .foregroundStyle(AuraPalette.textTertiary)
                    Spacer()
                }
                .frame(minHeight: 38)
            } else {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(AuraFont.ui(13.5))
                            .foregroundStyle(AuraPalette.textTertiary)

                        Text(headline)
                            .font(AuraFont.display(23, weight: .regular))
                            .tracking(-0.46)
                            .foregroundStyle(AuraPalette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 9) {
                        AuraLiveBatteryButton(action: onOpenBand)
                        if screen == .today {
                            AuraDayChip(label: dayLabel, isOpen: dayPickerOpen, action: onToggleDayPicker)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.top, 2)
                }
            }
        }
        .padding(.top, 0)
        .padding(.bottom, 4)
    }
}

private struct AuraDayChip: View {
    let label: String
    let isOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(AuraFont.ui(12, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isOpen ? Color(hex: "#9FE2FB") : AuraPalette.textSecondary)
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(Capsule().fill(isOpen ? AuraPalette.accent.opacity(0.12) : AuraPalette.controlFill))
            .overlay(
                Capsule().strokeBorder(
                    isOpen ? AuraPalette.accent.opacity(0.35) : Color.white.opacity(0.10),
                    lineWidth: 0.5
                )
            )
        }
        .buttonStyle(.plain)
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
                AuraBatteryGlyph(
                    fraction: Double(percent ?? 0) / 100,
                    available: percent != nil
                )
                    .frame(width: 21, height: 12)
                Text(verbatim: percent.map { "\($0)%" } ?? "—")
                    .font(AuraFont.ui(12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(batteryTint)
                if live.charging == true {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AuraPalette.effort)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 11)
            .frame(minWidth: 62, minHeight: 30, maxHeight: 30)
            .background(Capsule(style: .continuous).fill(batteryBackground))
            .overlay(Capsule(style: .continuous).strokeBorder(batteryBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(percent.map { Text("Band battery \($0) percent") } ?? Text("Band disconnected"))
    }

    private var batteryTint: Color {
        guard let percent else { return AuraPalette.textSecondary }
        if percent <= 10 { return Color(hex: "#F0742C") }
        if percent <= 20 { return Color(hex: "#F2B45C") }
        return AuraPalette.textSecondary
    }

    private var batteryBackground: Color {
        guard let percent, percent <= 20 else { return AuraPalette.controlFill }
        return batteryTint.opacity(0.12)
    }

    private var batteryBorder: Color {
        guard let percent, percent <= 20 else { return Color.white.opacity(0.10) }
        return batteryTint.opacity(0.34)
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
    var available: Bool = true

    var body: some View {
        let clamped = AuraGaugeMath.clampFraction(fraction)
        let tint: Color = !available
            ? AuraPalette.textQuiet
            : (clamped <= 0.10
                ? Color(hex: "#F0742C")
                : (clamped <= 0.20 ? Color(hex: "#F2B45C") : Color(hex: "#8FD3F5")))
        HStack(spacing: 1) {
            RoundedRectangle(cornerRadius: 3.4, style: .continuous)
                .strokeBorder(!available || clamped <= 0.20 ? tint : Color.white.opacity(0.40), lineWidth: 1)
                .frame(width: 21, height: 11)
                .overlay(alignment: .leading) {
                    if available {
                        RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                            .fill(tint)
                            .frame(width: max(0, (21 - 2.4) * clamped), height: 8.6)
                            .padding(.leading, 1.2)
                    }
                }
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 1.5,
                topTrailingRadius: 1.5,
                style: .continuous
            )
            .fill(!available || clamped <= 0.20 ? tint : Color.white.opacity(0.40))
            .frame(width: 1.6, height: 4.4)
        }
        .frame(width: 23.6, height: 11)
        .accessibilityHidden(true)
    }
}

struct AuraDayNavigator: View {
    let cells: [AuraTodayReading.DayCell]
    let selectedID: String?
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(cells) { cell in
                    let isSelected = cell.id == selectedID
                    Button { onSelect(cell.id) } label: {
                        VStack(spacing: 5) {
                            Text(cell.weekday)
                                .font(AuraFont.ui(9.5, weight: .semibold))
                                .tracking(0.55)
                                .textCase(.uppercase)
                                .foregroundStyle(isSelected ? Color(hex: "#9FE2FB") : AuraPalette.textQuiet)
                            Text(cell.number)
                                .font(AuraFont.display(17, weight: .regular))
                                .foregroundStyle(isSelected ? AuraPalette.textPrimary : AuraPalette.textSecondary)
                                .monospacedDigit()
                        }
                        .frame(width: 44, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(isSelected ? AuraPalette.accent.opacity(0.12) : Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(
                                            isSelected ? AuraPalette.accent.opacity(0.42) : Color.white.opacity(0.07),
                                            lineWidth: 0.5
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }
}

struct AuraPastDayBanner: View {
    let label: String
    let onReturnToday: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(AuraPalette.rest)
            Text(String(localized: "Looking back at \(label). Nothing here is live."))
                .font(AuraFont.ui(12.5))
                .foregroundStyle(Color(hex: "#C9D0EE"))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(String(localized: "Today"), action: onReturnToday)
                .font(AuraFont.ui(12, weight: .semibold))
                .foregroundStyle(AuraPalette.rest)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AuraPalette.rest.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(AuraPalette.rest.opacity(0.24), lineWidth: 0.5)
                )
        )
    }
}
#endif
