import Foundation

/// The seven, user-facing Svea data boundaries from the native HTML redesign.
///
/// These deliberately do not map onto `CoachPurpose`: those older buckets combine categories such as
/// sleep + vitals and journal + Lab Book. Reusing them would make it impossible to revoke one of the
/// seven without accidentally leaving another route open.
enum SveaDataGrant: String, CaseIterable, Codable, Hashable {
    case sleep
    case effort
    case vitals
    case journal
    case tender
    case ages
    case labs
}

struct SveaDataGrants: Equatable {
    static let storageKey = "noop.html.svea-granted-purpose-ids"
    private static let lastProviderVisibleKey = "noop.svea.last-provider-visible-grants"
    private static let providerHistoryCutoffKey = "noop.svea.provider-history-cutoff"

    /// Matches the HTML's Personal preset. This is used only when the key has never existed. A present
    /// empty string is an explicit choice to share nothing and must remain empty across relaunches.
    static let personalDefault = SveaDataGrants(
        allowed: [.sleep, .effort, .vitals, .journal, .ages]
    )

    static let none = SveaDataGrants(allowed: [])
    static let all = SveaDataGrants(allowed: Set(SveaDataGrant.allCases))

    var allowed: Set<SveaDataGrant>

    func allows(_ grant: SveaDataGrant) -> Bool { allowed.contains(grant) }
    func allowsAll(_ required: Set<SveaDataGrant>) -> Bool { required.isSubset(of: allowed) }

    /// Strict parsing: a malformed value or even one unknown id fails closed as an empty grant set.
    /// Accepting the known subset would make a typo look like a partially successful privacy change.
    static func parse(_ raw: String) -> SveaDataGrants? {
        if raw.isEmpty { return .none }
        let pieces = raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard !pieces.contains(where: { $0.isEmpty }) else { return nil }
        let typed = pieces.compactMap(SveaDataGrant.init(rawValue:))
        guard typed.count == pieces.count, Set(typed).count == typed.count else { return nil }
        return SveaDataGrants(allowed: Set(typed))
    }

    static func load(defaults: UserDefaults = .standard) -> SveaDataGrants {
        guard defaults.object(forKey: storageKey) != nil else { return .personalDefault }
        guard let raw = defaults.string(forKey: storageKey), let parsed = parse(raw) else { return .none }
        return parsed
    }

    func save(defaults: UserDefaults = .standard) {
        defaults.set(canonicalValue, forKey: Self.storageKey)
    }

    var canonicalValue: String {
        allowed.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// A provider may have echoed previously granted health data into an assistant turn. When any
    /// grant is revoked, the next request must not resend those old turns even though the local transcript
    /// remains visible. An absent receipt is treated as a migration boundary and also resets once.
    func requiresFreshProviderHistory(defaults: UserDefaults = .standard) -> Bool {
        guard let raw = defaults.string(forKey: Self.lastProviderVisibleKey),
              let previous = Self.parse(raw),
              defaults.object(forKey: Self.providerHistoryCutoffKey) != nil else { return true }
        return !previous.allowed.subtracting(allowed).isEmpty
    }

    func markProviderHistoryBoundary(_ date: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(date.timeIntervalSince1970, forKey: Self.providerHistoryCutoffKey)
    }

    static func providerHistoryCutoff(defaults: UserDefaults = .standard) -> Date? {
        guard defaults.object(forKey: providerHistoryCutoffKey) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: providerHistoryCutoffKey))
    }

    func recordProviderVisibility(defaults: UserDefaults = .standard) {
        defaults.set(canonicalValue, forKey: Self.lastProviderVisibleKey)
    }
}

enum SveaDataGrantPolicy {
    /// Tools with a fixed, single-purpose result. Mixed tools list every grant their current output can
    /// expose. Dynamic tools are checked again against their arguments at execution time.
    static func fixedRequirements(for tool: CoachTool) -> Set<SveaDataGrant>? {
        switch tool {
        case .sleepDetail:
            return [.sleep]
        case .recentWorkouts, .zoneMinutes:
            return [.effort]
        case .trainingPreferences, .planAdherence:
            return [.effort, .journal, .tender]
        case .stressIndex:
            return [.vitals]
        case .logCaffeine:
            return [.journal]
        case .logLabMarker:
            return [.labs]
        case .sensitiveLogs:
            return [.tender]
        case .sessionOutlook, .estimateSessionEffort:
            return [.effort, .vitals]
        case .simulateDay, .rangeReport:
            return [.sleep, .effort, .vitals]
        case .biometricSummary:
            return [.sleep, .effort, .vitals, .ages]
        case .readiness:
            return [.sleep, .effort, .vitals, .journal, .tender]
        case .chargeDrivers:
            return [.sleep, .effort, .vitals, .journal, .tender]
        case .personalPatterns:
            return Set(SveaDataGrant.allCases)

        // Their result depends on a runtime kind/metric. The dispatcher performs the strict check.
        case .myLogs, .logJournal, .metricHistory, .plotMetric:
            return nil

        // Catalog merges every store, while these planning/memory operations can expose goals, saved
        // facts, or past provider text that has no honest one-to-one place among the seven HTML grants.
        // They stay unavailable rather than being squeezed into a coarse legacy bucket.
        case .dataCatalog, .rememberFact, .updateFact, .forgetFact, .searchPastConversations,
             .proposePlan, .proposeGoalSetup:
            return Set(SveaDataGrant.allCases).union([.sleep]) // handled as explicitly blocked below
        }
    }

    static func isExplicitlyBlocked(_ tool: CoachTool) -> Bool {
        switch tool {
        case .dataCatalog, .rememberFact, .updateFact, .forgetFact, .searchPastConversations,
             .proposePlan, .proposeGoalSetup:
            return true
        default:
            return false
        }
    }

    static func mayOffer(_ tool: CoachTool, grants: SveaDataGrants) -> Bool {
        guard !isExplicitlyBlocked(tool) else { return false }
        if let required = fixedRequirements(for: tool) { return grants.allowsAll(required) }
        switch tool {
        case .myLogs:
            return !grants.allowed.intersection([.journal, .tender, .labs]).isEmpty
        case .logJournal:
            return grants.allows(.journal) || grants.allows(.tender)
        case .metricHistory, .plotMetric:
            return !grants.allowed.intersection([.sleep, .effort, .vitals, .ages, .labs]).isEmpty
        default:
            return false
        }
    }

    static func grantForMetric(_ raw: String) -> SveaDataGrant? {
        let metric = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        switch metric {
        case "sleep", "sleep_minutes", "sleep_total_min", "asleep_min", "rest", "rest_score", "sleep_score",
             "sleep_efficiency", "deep_sleep", "rem_sleep", "sleep_debt":
            return .sleep
        case "effort", "strain", "strain_load", "workout", "workouts", "zone_minutes", "active_kcal",
             "active_energy", "steps", "distance", "calories":
            return .effort
        case "hrv", "heart_rate_variability", "avg_hrv", "resting_hr", "resting_heart_rate", "rhr",
             "heart_rate", "respiration", "respiratory_rate", "resp_rate", "spo2", "blood_oxygen",
             "skin_temp", "skin_temperature", "charge", "recovery", "stress", "vo2max":
            return .vitals
        case "body_age", "fitness_age", "vitality", "pace_of_aging":
            return .ages
        default:
            // Lab marker keys are open-ended. They may only use the Lab Book route when the caller
            // explicitly names that source; an unknown generic metric fails closed.
            return nil
        }
    }
}
