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
                             tag: reading.baselineTag,
                             title: String(localized: "Your baselines"),
                             detail: reading.baselineDetail)
                AuraIconTile(symbol: "bell", tint: AuraPalette.effort,
                             tag: reading.notificationsTag,
                             title: String(localized: "Notifications"),
                             detail: reading.notificationsDetail,
                             action: onOpenSettings)
            }
            HStack(spacing: 8) {
                AuraIconTile(symbol: "ruler", tint: AuraPalette.rest,
                             tag: reading.unitsTag,
                             title: String(localized: "Units"),
                             detail: reading.unitsDetail,
                             action: onOpenSettings)
                AuraIconTile(symbol: "square.and.arrow.down", tint: AuraPalette.textSecondary,
                             tag: reading.exportTag,
                             title: String(localized: "Export data"),
                             detail: reading.exportDetail,
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
                        subtitle: String(localized: "Health, units and score preferences"),
                        showsDivider: true,
                        action: onOpenSettings)
            AuraListRow(key: String(localized: "Privacy"),
                        subtitle: String(localized: "On-device by default · review permissions"),
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
    let baselineTag: String
    let baselineDetail: String
    let notificationsTag: String
    let notificationsDetail: String
    let unitsTag: String
    let unitsDetail: String
    let exportTag: String
    let exportDetail: String

    static func live(
        displayName: String,
        age: Int,
        sex: String,
        earliestDay: String?,
        unitSystem: UnitSystem,
        temperature: TemperatureUnit
    ) -> AuraProfileReading {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? String(localized: "You") : trimmed
        let initial = name.first.map { String($0).uppercased() } ?? "Y"
        let sexLabel = sex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let details = [String(localized: "\(age) years"), sexLabel].filter { !$0.isEmpty }
        let tracking = earliestDay.flatMap(monthYear).map { String(localized: "Tracking since \($0)") }
        let memberSince = ([tracking] + details.map(Optional.some)).compactMap { $0 }.joined(separator: " · ")

        let systemLabel = unitSystem == .metric ? String(localized: "Metric") : String(localized: "Imperial")
        let distance = unitSystem == .metric ? "km" : "mi"
        let mass = unitSystem == .metric ? "kg" : "lb"
        let temp = temperature == .celsius ? "°C" : "°F"

        return AuraProfileReading(
            name: name,
            initial: initial,
            memberSince: memberSince,
            baselineTag: String(localized: "On-device"),
            baselineDetail: String(localized: "Updates with new nights"),
            notificationsTag: String(localized: "Settings"),
            notificationsDetail: String(localized: "Reminders and alerts"),
            unitsTag: systemLabel,
            unitsDetail: "\(mass) · \(distance) · \(temp)",
            exportTag: String(localized: "Local"),
            exportDetail: String(localized: "Backup or Apple Health")
        )
    }

    private static func monthYear(_ day: String) -> String? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = Calendar(identifier: .gregorian)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: day) else { return nil }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    static let prototype = AuraProfileReading(
        name: "Gabriel D.",
        initial: "G",
        memberSince: String(localized: "Member since Mar 2025 · 34, male"),
        baselineTag: String(localized: "On-device"),
        baselineDetail: String(localized: "Updates with new nights"),
        notificationsTag: String(localized: "Settings"),
        notificationsDetail: String(localized: "Reminders and alerts"),
        unitsTag: String(localized: "Metric"),
        unitsDetail: "kg · km · °C",
        exportTag: String(localized: "Local"),
        exportDetail: String(localized: "Backup or Apple Health")
    )
}
#endif
