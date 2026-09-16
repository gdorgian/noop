import Foundation
import Combine

// MARK: - UpdateItem
//
// One entry in the "Updates inbox" — the bell in the Today header collects these. An item is either
// purely informational (a What's New note, a "new data" reading) or actionable (a deep link to a
// screen, or a dismissed Today card the user can restore). Everything stays on-device; nothing here
// is medical, identifying, or a verdict — just a calm log of what's new in the app and the data.

struct UpdateItem: Identifiable, Codable, Equatable {
    /// The flavour of update — the fine-grained icon within a `Category`.
    enum Kind: String, Codable {
        case dismissedCard   // a Today info-card the user swiped into the inbox (restorable)
        case whatsNew        // a release note (seeded from AppChangelog on first run after an update)
        case reading         // new data arrived (e.g. "N days backfilled") — links to Trends
        case strapAlert      // a strap-side heads-up (low battery, sync) — informational
        /// A NEWER RELEASE exists that this install does not have (#1659). Deliberately not `.whatsNew`:
        /// that one means "here is what you just got", this one means "here is what you have not got yet",
        /// and giving them the same row would make the bell ambiguous at the moment it matters most.
        case newVersion

        /// The category used when decoding a row written before categories existed.
        var defaultCategory: Category {
            switch self {
            case .dismissedCard, .strapAlert: return .statusReminder
            case .whatsNew, .reading, .newVersion: return .informative
            }
        }
    }

    /// What kind of attention an item wants. This drives actions, retention, and layout.
    enum Category: String, Codable {
        case actionable
        case informative
        case statusReminder
    }

    enum Priority: String, Codable {
        case low, normal, high
    }

    let id: UUID
    var kind: Kind
    var title: String
    var message: String
    var date: Date
    var read: Bool
    /// Optional route key the inbox can navigate to when tapped (nil = purely informational). Matches a
    /// `NavRouter.Destination.rawValue` (e.g. "trends", "labBook"); unknown keys just dismiss the sheet.
    var deepLink: String?
    /// For `.dismissedCard` only: the Today card id to restore (the `@AppStorage` dismissed-flag key's
    /// stable suffix). Tapping "Restore to Today" in the inbox flips that flag back so the card reappears.
    var restorePayload: String?
    var category: Category
    var priority: Priority
    var expiresAt: Date?
    var alertKey: String?
    var actionRequired: Bool
    var planProposalId: UUID?
    var showOnToday: Bool

    init(id: UUID = UUID(), kind: Kind, title: String, message: String,
         date: Date = Date(), read: Bool = false,
         deepLink: String? = nil, restorePayload: String? = nil,
         category: Category? = nil, priority: Priority = .normal,
         expiresAt: Date? = nil, alertKey: String? = nil, actionRequired: Bool = false,
         planProposalId: UUID? = nil, showOnToday: Bool = false) {
        self.id = id
        self.kind = kind
        self.title = title
        self.message = message
        self.date = date
        self.read = read
        self.deepLink = deepLink
        self.restorePayload = restorePayload
        self.category = category ?? kind.defaultCategory
        self.priority = priority
        self.expiresAt = expiresAt
        self.alertKey = alertKey
        self.actionRequired = actionRequired
        self.planProposalId = planProposalId
        self.showOnToday = showOnToday
    }

    /// Rows persisted by older versions have none of the richer inbox fields. Decode those rows using
    /// defaults rather than discarding the entire on-device inbox during an upgrade.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(Kind.self, forKey: .kind)
        title = try c.decode(String.self, forKey: .title)
        message = try c.decode(String.self, forKey: .message)
        date = try c.decode(Date.self, forKey: .date)
        read = try c.decode(Bool.self, forKey: .read)
        deepLink = try c.decodeIfPresent(String.self, forKey: .deepLink)
        restorePayload = try c.decodeIfPresent(String.self, forKey: .restorePayload)
        category = try c.decodeIfPresent(Category.self, forKey: .category) ?? kind.defaultCategory
        priority = try c.decodeIfPresent(Priority.self, forKey: .priority) ?? .normal
        expiresAt = try c.decodeIfPresent(Date.self, forKey: .expiresAt)
        alertKey = try c.decodeIfPresent(String.self, forKey: .alertKey)
        actionRequired = try c.decodeIfPresent(Bool.self, forKey: .actionRequired) ?? false
        planProposalId = try c.decodeIfPresent(UUID.self, forKey: .planProposalId)
        showOnToday = try c.decodeIfPresent(Bool.self, forKey: .showOnToday) ?? false
    }
}

// MARK: - UpdateStore
//
// The bell's backing store: a single-user, on-device inbox of `UpdateItem`s persisted as JSON in
// UserDefaults — the same lightweight `@Published`-with-`didSet` persistence ProfileStore/BehaviorStore
// use, just over an array instead of scalars (Codable round-trips the whole list under one key on every
// mutation). A shared singleton like the other stores so any surface (Today cards, the import path) can
// `UpdateStore.shared.post(...)` without threading an instance through.
//
// First-run seeding: posts the current What's New (AppChangelog.releases.first) once, tracking
// `lastSeededVersion` so the same version is never double-posted across launches.
@MainActor
final class UpdateStore: ObservableObject {

    /// The app-wide instance (injected as an `@EnvironmentObject` at both app roots, alongside the other
    /// stores). A singleton so non-View code (an import-complete path) can post to the SAME inbox the UI
    /// observes.
    static let shared = UpdateStore()

    /// Newest-first is computed at read time (`sortedItems`); the stored array preserves insertion order.
    @Published private(set) var items: [UpdateItem] {
        didSet { persist() }
    }

    /// A restore signal TodayView observes: set to a card id when "Restore to Today" is tapped, so the
    /// Today screen (which owns the `@AppStorage` dismissed flags) can flip the matching flag back to
    /// false. Cleared by the observer once handled. (The inbox also clears the flag directly via the
    /// shared key, so this is belt-and-braces for an already-mounted Today.)
    @Published var restoreRequest: String?

    private let d = UserDefaults.standard
    private enum K {
        static let items = "updates.items"
        static let lastSeededVersion = "updates.lastSeededWhatsNewVersion"
    }

    /// Inbox guard-rails (#521). Informational items (`.reading`/`.whatsNew`) are posted by background
    /// recompute ticks, so without a cap + dedup the list grows unbounded and re-posts the same row on a
    /// loop. We collapse an identical informational post (same kind + deepLink) landing within
    /// `dedupWindow` into the existing row (just refresh its date) instead of appending, and we evict the
    /// oldest informational rows beyond `maxItems`. Actionable rows (`.dismissedCard`, `.strapAlert`) are
    /// never auto-evicted — the user owns those.
    private static let maxItems = 50
    private static let dedupWindow: TimeInterval = 30 * 60   // 30 minutes

    private init() {
        if let data = d.data(forKey: K.items),
           let decoded = try? JSONDecoder().decode([UpdateItem].self, from: data) {
            items = decoded
        } else {
            items = []
        }
        pruneExpired()
    }

    // MARK: Derived

    /// Items newest-first (the inbox list order).
    var sortedItems: [UpdateItem] { items.sorted { $0.date > $1.date } }

    /// How many unread — drives the bell badge.
    var unreadCount: Int { items.lazy.filter { !$0.read }.count }

    // MARK: Mutations

    /// Add a new item to the inbox (unread). Informational rows (`.reading`/`.whatsNew`) are deduped and
    /// capped (#521): an identical informational post (same kind + deepLink) within `dedupWindow` of an
    /// existing one just refreshes that row's date (and re-arms its unread badge) instead of appending a
    /// duplicate, and the informational backlog is trimmed to `maxItems` newest. Actionable rows
    /// (`.dismissedCard`, `.strapAlert`) always append and are never auto-evicted.
    func post(_ item: UpdateItem) {
        if Self.isEvictable(item),
           let i = items.firstIndex(where: {
               $0.kind == item.kind && $0.deepLink == item.deepLink
                   && item.date.timeIntervalSince($0.date) < Self.dedupWindow
                   && item.date.timeIntervalSince($0.date) >= 0
           }) {
            // Collapse into the existing row: bump its date + message, re-mark unread so the badge shows.
            items[i].date = item.date
            items[i].title = item.title
            items[i].message = item.message
            items[i].read = false
        } else {
            items.append(item)
        }
        evictOverflow()
        pruneExpired()
    }

    /// Add or refresh one recent local alert. Stable keys keep a repeated event to one inbox row.
    func postOrRefreshAlert(key: String, title: String, message: String,
                            deepLink: String? = nil, expiresAt: Date,
                            now: Date = Date()) {
        pruneExpired(now: now)
        if let i = items.firstIndex(where: { $0.alertKey == key }) {
            items[i].title = title
            items[i].message = message
            items[i].date = now
            items[i].read = false
            items[i].deepLink = deepLink
            items[i].expiresAt = expiresAt
        } else {
            items.append(UpdateItem(
                kind: .strapAlert,
                title: title,
                message: message,
                date: now,
                deepLink: deepLink,
                category: .statusReminder,
                expiresAt: expiresAt,
                alertKey: key
            ))
        }
        pruneExpired(now: now)
    }

    private static func isEvictable(_ item: UpdateItem) -> Bool {
        item.category == .informative
    }

    /// Trim the informational backlog to the newest `maxItems`. Actionable rows (`.dismissedCard`,
    /// `.strapAlert`) are exempt — only `.reading`/`.whatsNew` are auto-evicted, oldest first.
    private func evictOverflow() {
        let informationalCount = items.lazy.filter { Self.isEvictable($0) }.count
        guard informationalCount > Self.maxItems else { return }
        var toRemove = informationalCount - Self.maxItems
        // Oldest first: ascending by date, drop the leading informational rows.
        let orderedOldest = items.enumerated().sorted { $0.element.date < $1.element.date }
        var removeIDs = Set<UUID>()
        for (_, item) in orderedOldest where toRemove > 0 {
            if Self.isEvictable(item) {
                removeIDs.insert(item.id)
                toRemove -= 1
            }
        }
        if !removeIDs.isEmpty { items.removeAll { removeIDs.contains($0.id) } }
    }

    /// Expired information/status rows disappear, but an undecided action never vanishes silently.
    func pruneExpired(now: Date = Date()) {
        let expiredIDs = Set(items.compactMap { item -> UUID? in
            guard item.category != .actionable,
                  let expiresAt = item.expiresAt,
                  expiresAt <= now else { return nil }
            return item.id
        })
        guard !expiredIDs.isEmpty else { return }
        items.removeAll { expiredIDs.contains($0.id) }
    }

    /// Refresh an existing row without producing another inbox entry.
    func refresh(_ id: UUID, message: String) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].message = message
        items[i].date = Date()
        items[i].read = false
    }

    /// Mark one item read (no-op if already read / not found).
    func markRead(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }), !items[i].read else { return }
        items[i].read = true
    }

    /// Mark every item read.
    func markAllRead() {
        guard items.contains(where: { !$0.read }) else { return }
        for i in items.indices { items[i].read = true }
    }

    /// Remove one item (e.g. after restoring a dismissed card).
    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    /// Empty the inbox.
    func clearAll() {
        guard !items.isEmpty else { return }
        items.removeAll()
    }

    /// Ask Today to restore a dismissed card (flips its `@AppStorage` flag). Also removes the inbox item.
    func requestRestore(_ item: UpdateItem) {
        if let payload = item.restorePayload {
            restoreRequest = payload
        }
        remove(item.id)
    }

    // MARK: Seeding

    /// Post the current What's New as a `.whatsNew` item ONCE per version. Idempotent: tracks the last
    /// version it seeded in UserDefaults, so a relaunch on the same version never double-posts. Call on
    /// app appear (both shells), after the changelog version is known. `current` defaults to the live
    /// `AppChangelog`, but is injectable for tests.
    func seedWhatsNewIfNeeded(version: String = AppChangelog.currentVersion,
                              title: String = AppChangelog.releases.first?.title ?? "",
                              summary: String? = nil) {
        guard !version.isEmpty else { return }
        guard d.string(forKey: K.lastSeededVersion) != version else { return }
        // Mark seeded first so a re-entrant call (or a crash mid-post) can't double-post this version.
        d.set(version, forKey: K.lastSeededVersion)

        let message = summary ?? String(localized: "NOOP \(version) is here. Tap to read what's new.")
        post(UpdateItem(
            kind: .whatsNew,
            title: title.isEmpty ? String(localized: "What's new in NOOP \(version)") : title,
            message: message
        ))
    }

    // MARK: Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        d.set(data, forKey: K.items)
    }
}
