#if os(iOS)
import SwiftUI
import StrandDesign

// MARK: - Aura You

/// Act 5's body-clock profile hub. The handoff's example values are intentionally absent here: every
/// figure comes from the saved profile, the latest decoded sleep, or the connected strap.
struct AuraProfileView: View {
    @EnvironmentObject private var profile: ProfileStore
    @EnvironmentObject private var live: LiveState

    private let reading: AuraProfileReading
    private let restReading: AuraRestReading
    let onEditProfile: () -> Void
    let onOpenNotifications: () -> Void
    let onOpenUnits: () -> Void
    let onOpenExport: () -> Void
    let onOpenMore: () -> Void
    let onOpenTracking: () -> Void
    let onOpenPrivacy: () -> Void
    let onOpenSettings: () -> Void
    let onOpenAge: () -> Void
    let onOpenBand: () -> Void
    let onOpenComingSoon: (AuraUpcomingFeature) -> Void

    init(
        reading: AuraProfileReading,
        restReading: AuraRestReading,
        onEditProfile: @escaping () -> Void,
        onOpenNotifications: @escaping () -> Void,
        onOpenUnits: @escaping () -> Void,
        onOpenExport: @escaping () -> Void,
        onOpenMore: @escaping () -> Void,
        onOpenTracking: @escaping () -> Void,
        onOpenPrivacy: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenAge: @escaping () -> Void,
        onOpenBand: @escaping () -> Void,
        onOpenComingSoon: @escaping (AuraUpcomingFeature) -> Void
    ) {
        self.reading = reading
        self.restReading = restReading
        self.onEditProfile = onEditProfile
        self.onOpenNotifications = onOpenNotifications
        self.onOpenUnits = onOpenUnits
        self.onOpenExport = onOpenExport
        self.onOpenMore = onOpenMore
        self.onOpenTracking = onOpenTracking
        self.onOpenPrivacy = onOpenPrivacy
        self.onOpenSettings = onOpenSettings
        self.onOpenAge = onOpenAge
        self.onOpenBand = onOpenBand
        self.onOpenComingSoon = onOpenComingSoon
    }

    private var latestNight: AuraRestReading.NightReading? { restReading.nights.last }

    var body: some View {
        VStack(spacing: 0) {
            identityClock

            VStack(spacing: 9) {
                recordStrip
                sectionLabel(String(localized: "The three numbers everything runs on"))
                    .padding(.top, 8)
                coreCards
                hub
                Text(String(localized: "Every figure on this page comes from your saved profile, recorded sleep, or live strap state."))
                    .font(AuraFont.ui(11.5))
                    .lineSpacing(4)
                    .foregroundStyle(AuraPalette.textDim)
                    .padding(.horizontal, 2)
            }
            .padding(.top, 18)
        }
    }

    private var identityClock: some View {
        VStack(spacing: 7) {
            AuraBodyClock(
                sleepWindow: latestNight?.window,
                initial: reading.initial,
                profileImage: profile.avatarImage
            )
            .frame(height: 250)

            Text(reading.name)
                .font(AuraFont.display(27, weight: .light))
                .tracking(-0.81)
                .foregroundStyle(AuraPalette.textPrimary)

            Text(clockLine)
                .font(AuraFont.ui(12.5))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(AuraPalette.textLabel)
                .frame(maxWidth: 280)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 2)
    }

    private var clockLine: String {
        guard let latestNight else {
            return String(localized: "Record a sleep to draw your latest sleep window.")
        }
        return String(localized: "Latest recorded sleep \(latestNight.window) · \(duration(latestNight.hours))")
    }

    private var recordStrip: some View {
        Button(action: onEditProfile) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Your record"))
                        .font(AuraFont.ui(10, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color(hex: "#C08E98"))
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        recordValue(reading.ageText)
                        recordValue(reading.heightText)
                        recordValue(reading.weightText)
                        recordValue(reading.sexText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                AuraInlineArrow(tint: Color(hex: "#C08E98"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(hex: "#E08A9B").opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color(hex: "#E08A9B").opacity(0.22), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func recordValue(_ value: String) -> some View {
        Text(value)
            .font(AuraFont.display(16.5, weight: .regular))
            .tracking(-0.32)
            .foregroundStyle(Color(hex: "#F6D3DA"))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
    }

    private var coreCards: some View {
        VStack(spacing: 9) {
            profileNumberCard(
                label: String(localized: "Your sleep need"),
                value: duration(restReading.sleepNeedMinutes / 60),
                tag: restReading.sleepNeedIsPersonalized ? String(localized: "Learned") : String(localized: "Building"),
                note: restReading.sleepNeedIsPersonalized
                    ? String(localized: "Population-anchored and personalized from \(restReading.sleepNeedSampleCount) recorded nights using your upper-quartile sleep duration.")
                    : String(localized: "Uses the population target until at least seven scorable nights are available; it never learns a lower need from chronic short sleep.")
            )
            profileNumberCard(
                label: String(localized: "Latest sleep window"),
                value: latestNight?.window ?? "—",
                tag: latestNight == nil ? String(localized: "Unavailable") : String(localized: "Recorded"),
                note: latestNight == nil
                    ? String(localized: "A recorded onset and wake time are needed before this appears.")
                    : String(localized: "The onset and wake time of your latest decoded sleep, not a learned bedtime recommendation.")
            )
            profileNumberCard(
                label: String(localized: "Your zones"),
                value: reading.zonesText,
                tag: reading.zonesAvailable ? String(localized: "Profile") : String(localized: "Not set"),
                note: reading.zonesAvailable
                    ? String(localized: "Five display bands resolved from your saved maximum heart rate. Changing them does not rewrite history.")
                    : String(localized: "Confirm your date of birth or set a measured maximum heart rate before zones are presented as yours."),
                action: onOpenSettings
            )
        }
    }

    private func profileNumberCard(
        label: String,
        value: String,
        tag: String,
        note: String,
        action: (() -> Void)? = nil
    ) -> some View {
        Button(action: { action?() }) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(AuraFont.ui(12.5))
                            .foregroundStyle(AuraPalette.textTertiary)
                        Text(value)
                            .font(AuraFont.display(27, weight: .light))
                            .tracking(-0.81)
                            .foregroundStyle(AuraPalette.textPrimary)
                            .monospacedDigit()
                            .minimumScaleFactor(0.72)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text(tag)
                        .font(AuraFont.ui(10.5, weight: .semibold))
                        .foregroundStyle(Color(hex: "#F6D3DA"))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(hex: "#E08A9B").opacity(0.15)))
                }
                Text(note)
                    .font(AuraFont.ui(12))
                    .lineSpacing(3)
                    .foregroundStyle(AuraPalette.textQuiet)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .auraCard(cornerRadius: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private var hub: some View {
        VStack(spacing: 0) {
            hubRow("person.crop.circle.badge.clock", Color(hex: "#E08A9B"),
                   String(localized: "Your ages"), String(localized: "Body Age, Fitness Age, and their measured drivers"), onOpenAge)
            hubRow("target", AuraPalette.rest,
                   String(localized: "Goals and labs"), String(localized: "Open your existing goals and biomarker tools"), onOpenMore)
            hubRow("sensor.tag.radiowave.forward", AuraPalette.accent,
                   String(localized: "Your strap"), strapSummary, onOpenBand)
            hubRow("clock.arrow.circlepath", AuraPalette.rest,
                   String(localized: "Everything you logged"), String(localized: "Sessions, sleeps, and journal entries"), onOpenMore)
            hubRow("shield.lefthalf.filled", AuraPalette.rest,
                   String(localized: "Data and permissions"), String(localized: "What is kept, and what leaves"), onOpenTracking)
            hubRow("slider.horizontal.3", AuraPalette.textSecondary,
                   String(localized: "Settings"), String(localized: "Units, notifications, export, and app preferences"), onOpenSettings, divider: false)
        }
        .padding(.horizontal, 16)
        .auraCard()
    }

    private var strapSummary: String {
        guard live.connected else { return String(localized: "Not connected") }
        let battery = live.batteryPct.map { " · \(Int($0.rounded()))%" } ?? ""
        return String(localized: "Connected and reading") + battery
    }

    private func hubRow(
        _ symbol: String,
        _ tint: Color,
        _ title: String,
        _ subtitle: String,
        _ action: @escaping () -> Void,
        divider: Bool = true
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 23)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(AuraFont.ui(13.5)).foregroundStyle(AuraPalette.textPrimary)
                    Text(subtitle).font(AuraFont.ui(11.5)).foregroundStyle(AuraPalette.textQuiet)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                AuraInlineArrow(tint: AuraPalette.textDim)
            }
            .frame(minHeight: 62)
            .overlay(alignment: .bottom) {
                if divider { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 0.5).padding(.leading, 36) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(AuraFont.ui(10, weight: .semibold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(AuraPalette.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }

    private func duration(_ hours: Double) -> String {
        let minutes = max(0, Int((hours * 60).rounded()))
        return String(localized: "\(minutes / 60)h \(minutes % 60)m")
    }
}

private struct AuraInlineArrow: View {
    let tint: Color
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
    }
}

private struct AuraBodyClock: View {
    let sleepWindow: String?
    let initial: String
    let profileImage: Image?

    private let blush = Color(hex: "#E08A9B")

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [blush.opacity(0.24), blush.opacity(0)], center: .center, startRadius: 42, endRadius: 143))
                .frame(width: 286, height: 286)
                .blur(radius: 18)

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.055), lineWidth: 17)
                    .frame(width: 184, height: 184)

                ForEach(Array(sleepArcs.enumerated()), id: \.offset) { _, arc in
                    Circle()
                        .trim(from: arc.lowerBound, to: arc.upperBound)
                        .stroke(
                            AngularGradient(colors: [AuraPalette.rest, blush, Color(hex: "#F2C4CE")], center: .center),
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 184, height: 184)
                        .shadow(color: blush.opacity(0.6), radius: 7)
                }

                ForEach(0..<24, id: \.self) { hour in
                    Capsule()
                        .fill(hour % 6 == 0 ? AuraPalette.textTertiary : Color.white.opacity(0.22))
                        .frame(width: hour % 6 == 0 ? 2 : 1, height: hour % 6 == 0 ? 8 : 5)
                        .offset(y: -104)
                        .rotationEffect(.degrees(Double(hour) * 15))
                }

                nowMarker
                avatar
            }
            .frame(width: 230, height: 230)

            clockLabel("00", x: 0, y: -116)
            clockLabel("06", x: 116, y: 0)
            clockLabel("12", x: 0, y: 116)
            clockLabel("18", x: -116, y: 0)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(sleepWindow.map { Text("Latest recorded sleep window \($0)") }
                            ?? Text("No recorded sleep window"))
    }

    private var avatar: some View {
        Group {
            if let profileImage {
                profileImage
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: "#4A3239"), Color(hex: "#1B1D1C")], center: UnitPoint(x: 0.38, y: 0.32), startRadius: 3, endRadius: 74))
                    .overlay(
                        Text(initial)
                            .font(AuraFont.display(42, weight: .light))
                            .foregroundStyle(Color(hex: "#F6D3DA"))
                    )
            }
        }
        .frame(width: 112, height: 112)
        .overlay(Circle().strokeBorder(blush.opacity(0.4), lineWidth: 0.5))
        .shadow(color: blush.opacity(0.24), radius: 17)
    }

    private var nowMarker: some View {
        let fraction = currentTimeFraction
        return Circle()
            .fill(blush)
            .frame(width: 7, height: 7)
            .shadow(color: blush.opacity(0.7), radius: 5)
            .offset(y: -92)
            .rotationEffect(.degrees(fraction * 360))
    }

    private func clockLabel(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(verbatim: text)
            .font(AuraFont.ui(9.5, weight: .medium))
            .foregroundStyle(AuraPalette.textDim)
            .offset(x: x, y: y)
    }

    private var currentTimeFraction: Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return (Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60) / 24
    }

    private var sleepArcs: [ClosedRange<Double>] {
        guard let sleepWindow else { return [] }
        let chunks = sleepWindow
            .replacingOccurrences(of: "→", with: "–")
            .replacingOccurrences(of: "-", with: "–")
            .split(separator: "–")
        guard chunks.count >= 2,
              let startHour = clockHour(String(chunks[0])),
              let endHour = clockHour(String(chunks[1])) else { return [] }
        let start = startHour / 24
        let end = endHour / 24
        if end > start { return [start...end] }
        return [start...1, 0...end]
    }

    private func clockHour(_ value: String) -> Double? {
        let pieces = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard pieces.count == 2,
              let hour = Double(pieces[0]),
              let minuteToken = pieces[1].split(whereSeparator: { !$0.isNumber }).first,
              let minute = Double(minuteToken) else { return nil }
        return hour + minute / 60
    }
}

// MARK: - Reading

struct AuraProfileReading {
    let name: String
    let initial: String
    let memberSince: String
    let ageText: String
    let heightText: String
    let weightText: String
    let sexText: String
    let zonesText: String
    let zonesAvailable: Bool
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
        ageConfirmed: Bool,
        sex: String,
        sexConfirmed: Bool,
        heightCm: Double,
        heightConfirmed: Bool,
        weightKg: Double,
        weightConfirmed: Bool,
        hrMax: Int,
        hrMaxConfirmed: Bool,
        earliestDay: String?,
        unitSystem: UnitSystem,
        temperature: TemperatureUnit
    ) -> AuraProfileReading {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? String(localized: "You") : trimmed
        let initial = name.first.map { String($0).uppercased() } ?? "Y"
        let sexToken = sex.trimmingCharacters(in: .whitespacesAndNewlines)
        let sexLabel = sexConfirmed && !sexToken.isEmpty ? sexToken.lowercased() : String(localized: "Not set")
        let ageLabel = ageConfirmed && age > 0 ? String(localized: "\(age) years") : String(localized: "Not set")
        let tracking = earliestDay.flatMap(monthYear).map { String(localized: "Tracking since \($0)") } ?? ""

        let systemLabel = unitSystem == .metric ? String(localized: "Metric") : String(localized: "Imperial")
        let distance = unitSystem == .metric ? "km" : "mi"
        let mass = unitSystem == .metric ? "kg" : "lb"
        let temp = temperature == .celsius ? "°C" : "°F"
        let formattedHeight = unitSystem == .metric
            ? "\(Int(heightCm.rounded())) cm"
            : Self.imperialHeight(heightCm)
        let formattedWeight = unitSystem == .metric
            ? "\(weightKg.formatted(.number.precision(.fractionLength(1)))) kg"
            : "\((weightKg * 2.20462).formatted(.number.precision(.fractionLength(0)))) lb"
        let height = heightConfirmed ? formattedHeight : String(localized: "Not set")
        let weight = weightConfirmed ? formattedWeight : String(localized: "Not set")

        return AuraProfileReading(
            name: name,
            initial: initial,
            memberSince: tracking,
            ageText: ageLabel,
            heightText: height,
            weightText: weight,
            sexText: sexLabel,
            zonesText: hrMaxConfirmed ? String(localized: "5 zones · max \(hrMax)") : String(localized: "Not set"),
            zonesAvailable: hrMaxConfirmed,
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

    private static func imperialHeight(_ centimetres: Double) -> String {
        let inches = max(0, Int((centimetres / 2.54).rounded()))
        return "\(inches / 12)′ \(inches % 12)″"
    }

    private static func monthYear(_ day: String) -> String? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.calendar = Calendar(identifier: .gregorian)
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: day) else { return nil }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    #if DEBUG
    static let prototype = AuraProfileReading(
        name: "Gabriel D.", initial: "G", memberSince: "",
        ageText: "34 years", heightText: "178 cm", weightText: "74.0 kg", sexText: "male",
        zonesText: "5 zones · max 184", zonesAvailable: true,
        baselineTag: String(localized: "On-device"), baselineDetail: String(localized: "Updates with new nights"),
        notificationsTag: String(localized: "Settings"), notificationsDetail: String(localized: "Reminders and alerts"),
        unitsTag: String(localized: "Metric"), unitsDetail: "kg · km · °C",
        exportTag: String(localized: "Local"), exportDetail: String(localized: "Backup or Apple Health")
    )
    #endif
}
#endif
