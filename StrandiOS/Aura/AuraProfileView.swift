#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura You
//
// Account plus the settings people reach most often. Every row owns one clear destination; none drops
// the wearer into the old all-in-one Settings screen unless they explicitly choose Advanced settings.

struct AuraProfileView: View {
    private let reading: AuraProfileReading
    let onEditProfile: () -> Void
    let onOpenNotifications: () -> Void
    let onOpenUnits: () -> Void
    let onOpenExport: () -> Void
    let onOpenMore: () -> Void
    let onOpenTracking: () -> Void
    let onOpenPrivacy: () -> Void
    let onOpenSettings: () -> Void

    init(
        reading: AuraProfileReading = .prototype,
        onEditProfile: @escaping () -> Void,
        onOpenNotifications: @escaping () -> Void,
        onOpenUnits: @escaping () -> Void,
        onOpenExport: @escaping () -> Void,
        onOpenMore: @escaping () -> Void,
        onOpenTracking: @escaping () -> Void,
        onOpenPrivacy: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.reading = reading
        self.onEditProfile = onEditProfile
        self.onOpenNotifications = onOpenNotifications
        self.onOpenUnits = onOpenUnits
        self.onOpenExport = onOpenExport
        self.onOpenMore = onOpenMore
        self.onOpenTracking = onOpenTracking
        self.onOpenPrivacy = onOpenPrivacy
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        VStack(spacing: AuraPalette.cardGap) {
            identityCard
            tiles
            settingsCard
        }
    }

    private var identityCard: some View {
        Button(action: onEditProfile) {
            HStack(spacing: 15) {
                AuraProfilePhoto(size: 60)
                VStack(alignment: .leading, spacing: 3) {
                    Text(reading.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AuraPalette.textPrimary)
                    Text(reading.memberSince)
                        .font(.system(size: 12.5))
                        .foregroundStyle(AuraPalette.textQuiet)
                }
                Spacer(minLength: 8)
                AuraChevron()
            }
            .padding(18)
            .auraCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Edit profile, \(reading.name)"))
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
                             action: onOpenNotifications)
            }
            HStack(spacing: 8) {
                AuraIconTile(symbol: "ruler", tint: AuraPalette.rest,
                             tag: reading.unitsTag,
                             title: String(localized: "Units"),
                             detail: reading.unitsDetail,
                             action: onOpenUnits)
                AuraIconTile(symbol: "square.and.arrow.down", tint: AuraPalette.textSecondary,
                             tag: reading.exportTag,
                             title: String(localized: "Export data"),
                             detail: reading.exportDetail,
                             action: onOpenExport)
            }
        }
    }

    private var settingsCard: some View {
        VStack(spacing: 0) {
            AuraListRow(key: String(localized: "Everything else in NOOP"),
                        subtitle: String(localized: "Coach, Live, Workouts, Health, Lab Book, Backup"),
                        showsDivider: true,
                        action: onOpenMore)
            AuraListRow(key: String(localized: "What Noop tracks"),
                        subtitle: String(localized: "Signals, estimates and Apple Health output"),
                        showsDivider: true,
                        action: onOpenTracking)
            AuraListRow(key: String(localized: "Privacy"),
                        subtitle: String(localized: "On-device by default · review permissions"),
                        showsDivider: true,
                        action: onOpenPrivacy)
            AuraListRow(key: String(localized: "Settings"),
                        subtitle: String(localized: "Your Aura preferences in one place"),
                        showsDivider: false,
                        action: onOpenSettings)
        }
        .padding(.horizontal, 17)
        .auraCard()
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
