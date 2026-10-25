import Foundation
import Combine
import StrandAnalytics
import WhoopStore

/// Keeps the wearer's measured zone anchors current (`PersonalZones.swift`): the resting floor from the last
/// fourteen nights, and the held peak of every workout in the last six months, from which a higher maximum is
/// offered. Each workout's peak is read once and kept, so a refresh only reads sessions it has not seen.
@MainActor
final class PersonalZonesModel: ObservableObject {

    /// A higher maximum worth offering, and the first day it was reached.
    struct Offer: Equatable { let bpm: Int; let day: String }
    /// A workout's held peak, for the screen's line and its strip of recent sessions.
    struct Peak: Equatable { let bpm: Int; let day: String; let sport: String }

    @Published private(set) var offer: Offer?
    /// The highest pulse held for 30 seconds in the last six months, or nil with no traced workout.
    @Published private(set) var highest: Peak?
    /// Held peaks of the last six months, oldest first.
    @Published private(set) var peaks: [Peak] = []
    @Published private(set) var refreshing = false

    private let defaults: UserDefaults
    private static let cacheKey = "zones.heldPeaks.v1"
    private static let lookbackDays = 183
    /// A session shorter than this rarely holds anything, and reading it costs a trace read for nothing.
    private static let minimumSeconds = 5 * 60
    private var lastRefresh: Date?

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// Refresh at most every `minimumGap` unless forced (the zones screen forces it).
    func refresh(repo: Repository, profile: ProfileStore, force: Bool = false,
                 minimumGap: TimeInterval = 6 * 3600) async {
        if !force, let lastRefresh, Date().timeIntervalSince(lastRefresh) < minimumGap { return }
        guard repo.loaded, !refreshing else { return }
        refreshing = true
        defer { refreshing = false; lastRefresh = Date() }

        // The floor: the median resting pulse of the last fourteen scored nights.
        let nightly = repo.days.sorted { $0.day < $1.day }.compactMap(\.restingHr)
        let floor = ReserveZones.restingFloor(nightly: nightly) ?? 0
        if abs(floor - profile.zoneRestingFloor) >= 0.5 { profile.zoneRestingFloor = floor }

        // The ceiling: one held peak per workout, read once.
        var cache = defaults.dictionary(forKey: Self.cacheKey) as? [String: String] ?? [:]
        let now = Int(Date().timeIntervalSince1970)
        let since = now - Self.lookbackDays * 86_400
        let rows = await repo.workoutRows(days: Self.lookbackDays, reconcileHrCap: 0)
        var found: [Peak] = []
        for row in rows where row.startTs >= since && row.endTs - row.startTs >= Self.minimumSeconds {
            let key = "\(row.startTs)|\(row.sport)"
            let day = Repository.localDayKey(Date(timeIntervalSince1970: TimeInterval(row.startTs)))
            if let stored = cache[key] {
                if let bpm = Int(stored), bpm > 0 { found.append(Peak(bpm: bpm, day: day, sport: row.sport)) }
                continue
            }
            let samples = await repo.hrSamples(from: row.startTs, to: row.endTs, limit: 20_000)
            // No trace yet: the strap may not have handed it over. Read it again next time.
            guard !samples.isEmpty else { continue }
            let bpm = HeldPeak.heldPeak(samples) ?? 0
            // Only a session that ended a while ago is final: its trace can still grow at the next sync.
            if now - row.endTs > 6 * 3600 { cache[key] = String(bpm) }
            if bpm > 0 { found.append(Peak(bpm: bpm, day: day, sport: row.sport)) }
        }
        // Forget sessions that fell out of the window, so the cache stays the size of six months.
        cache = cache.filter { key, _ in (Int(key.split(separator: "|").first ?? "") ?? 0) >= since }
        defaults.set(cache, forKey: Self.cacheKey)

        #if DEBUG
        // `--noop-zones-sample`: six months of sessions whose hardest two days held 189 and 191, so the offer,
        // the chart and the "held at most" pin can be checked without a strap trace.
        if CommandLine.arguments.contains("--noop-zones-sample") {
            let cal = Calendar.current
            found = (0..<38).map { i in
                let date = cal.date(byAdding: .day, value: -(i * 4 + 2), to: Date()) ?? Date()
                let bpm = i == 5 ? 191 : i == 17 ? 189 : 118 + (i * 37) % 52
                return Peak(bpm: bpm, day: Repository.localDayKey(date), sport: "running")
            }
        }
        #endif
        peaks = found.sorted { $0.day < $1.day }
        highest = found.max { $0.bpm < $1.bpm }
        let declined = profile.hrMaxDeclined > 0 ? profile.hrMaxDeclined : nil
        if let bpm = MaxHRSuggestion.suggestion(peaks: found.map { .init(day: $0.day, bpm: $0.bpm) },
                                                current: profile.hrMax, declined: declined) {
            let first = found.filter { $0.bpm >= bpm }.map(\.day).min() ?? ""
            offer = Offer(bpm: bpm, day: first)
        } else {
            offer = nil
        }
    }

    /// The wearer took the offer.
    func accept(_ offer: Offer, profile: ProfileStore) {
        profile.acceptMeasuredMax(offer.bpm, day: offer.day)
        self.offer = nil
    }

    /// The wearer turned it down: not offered again until a higher level shows.
    func decline(_ offer: Offer, profile: ProfileStore) {
        profile.hrMaxDeclined = offer.bpm
        self.offer = nil
    }
}
