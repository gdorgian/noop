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
    let greeting: String
    let headline: String
    let batteryPercent: Int?
    let initial: String
    let onOpenBand: () -> Void
    let onOpenProfile: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(StrandFont.subhead)
                    .foregroundStyle(AuraPalette.textSecondary)
                Text(headline)
                    .font(.system(size: 23, weight: .regular, design: .rounded))
                    .foregroundStyle(AuraPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Button(action: onOpenBand) {
                    VStack(spacing: 1) {
                        AuraBatteryGlyph(fraction: Double(batteryPercent ?? 0) / 100)
                        // `verbatim` — a bare number needs no String Catalog entry.
                        Text(verbatim: batteryPercent.map(String.init) ?? "—")
                            .font(.system(size: 8.5, weight: .semibold, design: .rounded).monospacedDigit())
                            .foregroundStyle(AuraPalette.textSecondary)
                    }
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(AuraPalette.controlFill))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(
                    batteryPercent.map { Text("Band battery \($0) percent") }
                        ?? Text("Band disconnected")
                )

                Button(action: onOpenProfile) {
                    Text(initial)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(AuraPalette.textPrimary.opacity(0.85))
                        .frame(width: 38, height: 38)
                        .background(
                            Circle().fill(LinearGradient(
                                colors: [Color(hex: "#3A4340"), Color(hex: "#242B29")],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                        )
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Account"))
            }
            .padding(.top, 2)
        }
        .padding(.top, 12)
    }
}

/// The band's charge at header size, where SF Symbols' own battery glyphs read as either empty or full
/// and nothing in between.
struct AuraBatteryGlyph: View {
    let fraction: Double

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .strokeBorder(AuraPalette.accent, lineWidth: 1.2)
            .frame(width: 13, height: 7)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(AuraPalette.accent)
                    .padding(1)
                    .frame(width: 13 * AuraGaugeMath.clampFraction(fraction))
            }
            .accessibilityHidden(true)
    }
}
#endif
