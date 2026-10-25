import SwiftUI
import StrandAnalytics
import WhoopStore

// MARK: - Today's small tiles
//
// Half-width tiles for Today, two to a row (25 Oct 2026). Each shows one figure from data the app
// already measures and opens the page that explains it. A tile with nothing to show yet says so in its
// own words rather than guessing; the seeded shell (`day == nil`) draws the design's example person.

enum NoopTodayTile: String, CaseIterable {
    case heart, effort, steps, calories, stress, bedtime, debt, workout, weight, cycle, breathe

    var id: String { "tile-" + rawValue }

    var section: NoopPageSection {
        switch self {
        case .heart: .init(id: id, title: "Heart rate now", detail: "Your pulse, live while the strap is on", onByDefault: false, half: true)
        case .effort: .init(id: id, title: "Effort today", detail: "Today's effort against your target", onByDefault: false, half: true)
        case .steps: .init(id: id, title: "Steps", detail: "Today's steps against your usual", onByDefault: false, half: true)
        case .calories: .init(id: id, title: "Calories", detail: "What the day has burned so far", onByDefault: false, half: true)
        case .stress: .init(id: id, title: "Stress now", detail: "Where the last scored hour sat", onByDefault: false, half: true)
        case .bedtime: .init(id: id, title: "Bedtime", detail: "When to be asleep to meet tonight's need", half: true)
        case .debt: .init(id: id, title: "Sleep debt", detail: "What you owe your sleep right now", onByDefault: false, half: true)
        case .workout: .init(id: id, title: "Next workout", detail: "Today's planned routine, or a rest day", onByDefault: false, half: true)
        case .weight: .init(id: id, title: "Body weight", detail: "Your latest weight and where it is heading", onByDefault: false, half: true)
        case .cycle: .init(id: id, title: "Cycle", detail: "Your phase, read from skin temperature", onByDefault: false, half: true)
        case .breathe: .init(id: id, title: "Breathe", detail: "One tap to a minute of breathing", onByDefault: false, half: true)
        }
    }

    init?(sectionID: String) {
        guard sectionID.hasPrefix("tile-") else { return nil }
        self.init(rawValue: String(sectionID.dropFirst(5)))
    }

    var symbol: String {
        switch self {
        case .heart: "heart.fill"
        case .effort: "bolt.fill"
        case .steps: "figure.walk"
        case .calories: "flame.fill"
        case .stress: "waveform.path"
        case .bedtime: "moon.fill"
        case .debt: "hourglass"
        case .workout: "dumbbell.fill"
        case .weight: "scalemass.fill"
        case .cycle: "circle.circle.fill"
        case .breathe: "wind"
        }
    }

    var tint: (Color, Color) {
        switch self {
        case .heart: (Color(hex: 0xFF8A98), Color(hex: 0xD93A55))
        case .effort: (Color(hex: 0xFFE3A3), Color(hex: 0xE89A2E))
        case .steps: (Color(hex: 0xD4F27A), Color(hex: 0x7AA81E))
        case .calories: (Color(hex: 0xFFB56E), Color(hex: 0xE0622A))
        case .stress: (Color(hex: 0x7FE6D6), Color(hex: 0x1F9C8F))
        case .bedtime: (Color(hex: 0xB7C0FF), Color(hex: 0x5B52E0))
        case .debt: (Color(hex: 0xD2B3FF), Color(hex: 0x7B4FD6))
        case .workout: (Color(hex: 0x8FE39B), Color(hex: 0x2F9A47))
        case .weight: (Color(hex: 0x8FDCEB), Color(hex: 0x2A8FB0))
        case .cycle: (Color(hex: 0xFFA3CC), Color(hex: 0xD2468C))
        case .breathe: (Color(hex: 0x9BE7FF), Color(hex: 0x1E9BD7))
        }
    }
}

/// One of Today's small tiles, reading its own figure.
struct NoopTodayTileView: View {
    let tile: NoopTodayTile
    @ObservedObject var navigation: NoopNavigation
    let day: NoopDayRecord?
    let liveBPM: Int?

    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var fitness: NoopFitnessSettings
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    @State private var weights: [BodyMeasurementRow] = []

    private var seeded: Bool { day == nil }

    var body: some View {
        let face = face
        NoopSlotPill(symbol: tile.symbol, tint: face.tint ?? tile.tint, title: face.title, subtitle: face.subtitle,
                     accessory: face.accessory, accessibility: "\(tile.section.title), \(face.title), \(face.subtitle)") {
            NoopHaptics.play(.tick)
            open()
        }
        .task(id: tile == .weight ? repo.refreshSeq : -1) {
            guard tile == .weight, !seeded, let store = await repo.storeHandle() else { return }
            weights = ((try? await store.bodyMeasurements(deviceId: repo.deviceId)) ?? [])
                .filter { $0.kind == .weight }.sorted { $0.ts < $1.ts }
        }
    }

    private struct Face {
        var title: String
        var subtitle: String
        var accessory: NoopSlotPill.Accessory = .chevron
        var tint: (Color, Color)? = nil
    }

    private var face: Face {
        switch tile {
        case .heart: heartFace
        case .effort: effortFace
        case .steps: stepsFace
        case .calories: caloriesFace
        case .stress: stressFace
        case .bedtime: bedtimeFace
        case .debt: debtFace
        case .workout: workoutFace
        case .weight: weightFace
        case .cycle: cycleFace
        case .breathe: Face(title: "Breathe", subtitle: "One minute")
        }
    }

    private func open() {
        switch tile {
        case .heart: navigation.push(.heart)
        case .effort: navigation.push(.strain)
        case .steps: navigation.push(.day)
        case .calories: navigation.push(.energy)
        case .stress: navigation.push(.stress)
        case .bedtime: navigation.push(.tonight)
        case .debt: navigation.push(.debt)
        case .workout: navigation.reset(to: .fitness)
        case .weight: navigation.push(.fitnessBody)
        case .cycle: navigation.reset(to: .you)
        case .breathe: navigation.push(.breathe)
        }
    }

    // MARK: Faces

    private var heartFace: Face {
        if seeded { return Face(title: "64 bpm", subtitle: "Heart rate", accessory: .live) }
        if let liveBPM, liveBPM > 0 { return Face(title: "\(liveBPM) bpm", subtitle: "Heart rate", accessory: .live) }
        if let last = day?.dayHRPoints.last {
            let at = Date(timeIntervalSince1970: TimeInterval(last.ts))
            return Face(title: "\(Int(last.bpm.rounded())) bpm", subtitle: "At " + Self.time.string(from: at))
        }
        return Face(title: "—", subtitle: "Strap not on")
    }

    private var effortFace: Face {
        let rings = seeded ? NoopAct2Screens.demoRings : (day?.rings ?? NoopRingValues())
        guard let strain = rings.strain else { return Face(title: "—", subtitle: "Effort today") }
        guard let target = rings.strainTarget else {
            return Face(title: "\(Int(strain.rounded()))", subtitle: "Effort today", accessory: .progress(strain / 100))
        }
        let low = Int((target.lowerBound * 100).rounded()), high = Int((target.upperBound * 100).rounded())
        let line = strain >= target.lowerBound * 100 && strain <= target.upperBound * 100 ? "On target"
            : strain < target.lowerBound * 100 ? "Target \(low)–\(high)" : "Past target"
        return Face(title: "\(Int(strain.rounded()))", subtitle: line,
                    accessory: .progress(strain / (target.upperBound * 100)))
    }

    private var stepsFace: Face {
        if seeded { return Face(title: "6,240", subtitle: "Steps", accessory: .progress(6240 / 7900)) }
        let today = Repository.localDayKey(Date())
        guard let steps = repo.days.last(where: { $0.day == today })?.steps else {
            return Face(title: "—", subtitle: "Steps today")
        }
        let recent = repo.days.filter { $0.day != today }.suffix(14).compactMap(\.steps).filter { $0 > 0 }.sorted()
        guard recent.count >= 3 else { return Face(title: steps.formatted(), subtitle: "Steps today") }
        let usual = recent[recent.count / 2]
        // The ring closes at your usual day: the middle of the last two weeks.
        return Face(title: steps.formatted(), subtitle: "Steps",
                    accessory: .progress(Double(steps) / Double(max(1, usual))))
    }

    private var caloriesFace: Face {
        if seeded { return Face(title: "1,420", subtitle: "kcal so far") }
        guard let burned = day?.energy?.totalBurnedSoFar else { return Face(title: "—", subtitle: "kcal today") }
        return Face(title: Int(burned.rounded()).formatted(), subtitle: "kcal so far")
    }

    private var stressFace: Face {
        let level: Double? = seeded ? 0.6 : day?.stressLevel
        guard let level else { return Face(title: "—", subtitle: "Stress now") }
        let step = NoopDayRecord.stressStep(level)
        let tints: [(Color, Color)] = [
            (Color(hex: 0x7FE6D6), Color(hex: 0x1F9C8F)),
            (Color(hex: 0x8FC2FF), Color(hex: 0x2F6FD6)),
            (Color(hex: 0xFFD47A), Color(hex: 0xD9921A)),
            (Color(hex: 0xFF8A7A), Color(hex: 0xC83A3A))
        ]
        return Face(title: NoopDayRecord.stressNames[step], subtitle: "Stress now", tint: tints[step])
    }

    private var bedtimeFace: Face {
        if seeded { return Face(title: "22:40", subtitle: "Bedtime") }
        guard let rest = day?.rest, rest.needMin > 0 else {
            return Face(title: "—", subtitle: "After a night")
        }
        // The hour you usually wake, from the last week's nights; tonight's need counted back from it.
        let wakes = rest.slots.compactMap { $0?.endDate }.map { Self.minuteOfDay($0) }.sorted()
        guard !wakes.isEmpty else { return Face(title: "—", subtitle: "After a night") }
        let wake = wakes[wakes.count / 2]
        let bed = ((wake - Int(rest.needMin.rounded())) % 1440 + 1440) % 1440
        let clock = Calendar.current.date(bySettingHour: bed / 60, minute: bed % 60, second: 0, of: Date()) ?? Date()
        return Face(title: Self.time.string(from: clock), subtitle: "Bedtime")
    }

    private var debtFace: Face {
        if seeded { return Face(title: "1h 20m", subtitle: "Sleep debt") }
        guard let debt = day?.rest.debt.last?.minutes else { return Face(title: "—", subtitle: "Sleep debt") }
        if debt < 10 { return Face(title: "None", subtitle: "Sleep debt") }
        return Face(title: Self.duration(debt), subtitle: "Sleep debt")
    }

    private var workoutFace: Face {
        if seeded { return Face(title: "Upper body", subtitle: "Today") }
        if let plan = fitness.plans(on: Date()).first { return Face(title: plan.routineName, subtitle: "Today") }
        return Face(title: "Rest day", subtitle: "No plan today")
    }

    private var weightFace: Face {
        let units = UnitSystem(rawValue: unitSystemRaw) ?? .metric
        if seeded { return Face(title: UnitFormatter.massFromKilograms(78.4, system: units), subtitle: "−0.6 in 30d") }
        guard let latest = weights.last else { return Face(title: "—", subtitle: "Log a weight") }
        let monthAgo = latest.ts - 30 * 86_400
        let title = UnitFormatter.massFromKilograms(latest.value, system: units)
        guard let then = weights.last(where: { $0.ts <= monthAgo }) ?? weights.first, then.ts < latest.ts else {
            return Face(title: title, subtitle: "Body weight")
        }
        let change = latest.value - then.value
        let shown = units == .imperial ? change * 2.20462 : change
        let sign = shown > 0.05 ? "+" : shown < -0.05 ? "−" : "±"
        return Face(title: title, subtitle: "\(sign)\(String(format: "%.1f", abs(shown))) in 30d")
    }

    private var cycleFace: Face {
        if seeded { return Face(title: "Follicular", subtitle: "Day 8–10") }
        guard app.cycleAwarenessEnabled else { return Face(title: "Cycle", subtitle: "Set up in You") }
        guard let result = app.cyclePhase else { return Face(title: "Learning", subtitle: "Cycle") }
        let name: String = switch result.phase {
        case .follicular: "Follicular"
        case .periOvulatory: "Ovulation"
        case .luteal: "Luteal"
        case .unknown: "Unclear"
        case .learning: "Learning"
        }
        if let low = result.cycleDayLow, let high = result.cycleDayHigh {
            return Face(title: name, subtitle: low == high ? "Day \(low)" : "Day \(low)–\(high)")
        }
        return Face(title: name, subtitle: "Cycle")
    }

    // MARK: Formatting

    private static func minuteOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private static func duration(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m)m"
    }

    private static let time: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("jj:mm"); return f
    }()
}
