#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura You
//
// Account, the four settings that matter daily, and the one control that is genuinely part of the design
// language: how much Noop says. That verbosity choice is the direction's escape hatch — it lets someone
// who wants every number have them without making the default screen carry them.
//
// The "Everything else in NOOP" row is the seam back to the app's full surface (Coach, Live, Workouts,
// Health, Lab Book, Backup, Settings …). Aura does not reimplement those, and none of them should become
// unreachable because the home screen was redesigned.

struct AuraProfileView: View {
    private let reading: AuraProfileReading
    let onOpenMore: () -> Void
    let onOpenSettings: () -> Void

    @AppStorage(AuraVerbosity.storageKey) private var verbosityRaw = AuraVerbosity.plain.rawValue

    init(
        reading: AuraProfileReading = .prototype,
        onOpenMore: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.reading = reading
        self.onOpenMore = onOpenMore
        self.onOpenSettings = onOpenSettings
    }

    private var verbosity: AuraVerbosity { AuraVerbosity.resolve(verbosityRaw) }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            identityCard
            tiles
            verbosityCard
            settingsCard
        }
    }

    private var identityCard: some View {
        HStack(spacing: 15) {
            Text(reading.initial)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(AuraPalette.textPrimary.opacity(0.85))
                .frame(width: 60, height: 60)
                .background(
                    Circle().fill(LinearGradient(
                        colors: [Color(hex: "#3A4340"), Color(hex: "#242B29")],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .overlay(Circle().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 3) {
                Text(reading.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AuraPalette.textPrimary)
                Text(reading.memberSince)
                    .font(.system(size: 12.5))
                    .foregroundStyle(AuraPalette.textQuiet)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .auraCard()
        .accessibilityElement(children: .combine)
    }

    /// A 2×2 grid. Two `HStack`s rather than a `LazyVGrid` so both tiles in a row share one height
    /// without the grid having to measure them.
    private var tiles: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                AuraIconTile(symbol: "target", tint: AuraPalette.accent,
                             tag: String(localized: "Auto"),
                             title: String(localized: "Your baselines"),
                             detail: String(localized: "Recalculated monthly"))
                AuraIconTile(symbol: "bell", tint: AuraPalette.effort,
                             tag: String(localized: "1/day"),
                             title: String(localized: "Notifications"),
                             detail: String(localized: "Morning only"),
                             action: onOpenSettings)
            }
            HStack(spacing: 8) {
                AuraIconTile(symbol: "ruler", tint: AuraPalette.rest,
                             tag: String(localized: "EU"),
                             title: String(localized: "Units"),
                             detail: String(localized: "Metric · 24-hour"),
                             action: onOpenSettings)
                AuraIconTile(symbol: "square.and.arrow.down", tint: AuraPalette.textSecondary,
                             tag: String(localized: "Any time"),
                             title: String(localized: "Export data"),
                             detail: String(localized: "CSV or Apple Health"),
                             action: onOpenMore)
            }
        }
    }

    private var verbosityCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(String(localized: "How much Noop says")).auraOverline()
            VStack(spacing: 6) {
                ForEach(AuraVerbosity.allCases) { option in
                    AuraRadioRow(title: option.title, detail: option.detail,
                                 isOn: option == verbosity) {
                        withAnimation(NoopMotion.value) { verbosityRaw = option.rawValue }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.top, 17)
        .padding(.bottom, 14)
        .auraCard()
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            AuraListRow(key: String(localized: "Everything else in NOOP"),
                        subtitle: String(localized: "Coach, Live, Workouts, Health, Lab Book, Backup"),
                        showsDivider: true,
                        action: onOpenMore)
            AuraListRow(key: String(localized: "What Noop tracks"),
                        subtitle: String(localized: "Rest, charge, effort, stress"),
                        showsDivider: true,
                        action: onOpenSettings)
            AuraListRow(key: String(localized: "Privacy"),
                        subtitle: String(localized: "Nothing leaves the band unencrypted"),
                        showsDivider: false,
                        action: onOpenSettings)
        }
        .padding(.horizontal, 17)
        .auraCard()
    }
}

// MARK: - Verbosity

/// How much the app says by default. The direction's one genuine preference: the screens above stay
/// spare, and someone who wants the receipts turns them on here rather than everyone paying for them.
enum AuraVerbosity: String, CaseIterable, Identifiable {
    case plain
    case reason
    case everything

    var id: String { rawValue }

    /// Shared with any future Android twin, so the key is the contract, not the symbol name.
    static let storageKey = "aura.verbosity"

    static func resolve(_ raw: String) -> AuraVerbosity { AuraVerbosity(rawValue: raw) ?? .plain }

    var title: String {
        switch self {
        case .plain:      return String(localized: "One line a day")
        case .reason:     return String(localized: "Add the reason")
        case .everything: return String(localized: "Show me everything")
        }
    }

    var detail: String {
        switch self {
        case .plain:      return String(localized: "A verdict and an instruction. Nothing else.")
        case .reason:     return String(localized: "The verdict, plus what drove it.")
        case .everything: return String(localized: "Every number, every baseline, on tap.")
        }
    }
}

// MARK: - Reading

struct AuraProfileReading {
    let name: String
    let initial: String
    let memberSince: String

    static let prototype = AuraProfileReading(
        name: "Gabriel D.",
        initial: "G",
        memberSince: String(localized: "Member since Mar 2025 · 34, male")
    )
}
#endif
