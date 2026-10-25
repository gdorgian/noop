#if os(iOS)
import SwiftUI
import StrandAnalytics
import WhoopStore

/// Every time this routine was run: volume, reps and time, as a trend over 3M / 1Y / All.
///
/// A run is a lift session started from the routine (`liftSession.programId`). Warm-ups and sets never
/// performed stay out, as everywhere else (`LiftMetrics`).
struct NoopFitnessRoutineProgress: View {
    let routineID: String

    enum Metric: String, CaseIterable { case volume = "Volume", reps = "Reps", time = "Time" }

    struct Run: Equatable {
        let id: String
        let startTs: Int
        let volumeKg: Double?
        let reps: Int
        let minutes: Double?
    }

    @EnvironmentObject private var repo: Repository
    @AppStorage(UnitPrefs.systemKey) private var unitSystemRaw = UnitSystem.metric.rawValue
    @State private var runs: [Run] = []
    @State private var loaded = false
    @State private var metric: Metric = .volume
    @State private var window: NoopExerciseSummary.Window = .year

    private var units: UnitSystem { UnitSystem(rawValue: unitSystemRaw) ?? .metric }

    var body: some View {
        VStack(alignment: .leading, spacing: NoopSpace.s) {
            HStack(alignment: .firstTextBaseline) {
                NoopSectionLabel("Progress")
                Spacer()
                if let last = runs.last {
                    Text("\(runs.count) \(runs.count == 1 ? "run" : "runs") · last \(Date(timeIntervalSince1970: Double(last.startTs)).formatted(.relative(presentation: .named)))")
                        .font(NoopHTMLFont.sans(NoopType.caption)).foregroundStyle(NoopHTMLColor.copy)
                }
            }
            if !loaded {
                Color.clear.frame(height: 1)
            } else if runs.isEmpty {
                NoopExerciseEmpty(text: "Start this routine to begin its progress line: volume, reps and time for every run.")
            } else {
                HStack(spacing: NoopSpace.xs) {
                    ForEach(Metric.allCases, id: \.self) { m in NoopChip(title: m.rawValue, isOn: metric == m) { metric = m } }
                }
                NoopTrendChartCard(points: NoopTrendPoint.within(window, points), label: label, tint: NoopHTMLColor.volt)
                    .animation(NoopMotion.swap, value: metric)
                    .animation(NoopMotion.swap, value: window)
                NoopTabs(options: NoopExerciseSummary.Window.allCases.map { ($0.rawValue, $0) }, selection: $window)
            }
        }
        .task(id: "\(routineID)-\(repo.refreshSeq)") { await load() }
    }

    private var points: [NoopTrendPoint] {
        runs.compactMap { r in
            let v: Double? = switch metric {
            case .volume: r.volumeKg.map { LiftFormat.display(fromKilograms: $0, system: units) }
            case .reps: r.reps > 0 ? Double(r.reps) : nil
            case .time: r.minutes
            }
            return v.map { NoopTrendPoint(id: r.id, ts: r.startTs, value: $0) }
        }
    }

    private func label(_ v: Double) -> String {
        switch metric {
        case .volume: "\(LiftFormat.trim(v.rounded())) \(LiftFormat.weightUnit(units))"
        case .reps: "\(Int(v.rounded())) reps"
        case .time: "\(Int(v.rounded())) min"
        }
    }

    private func load() async {
        guard let store = await repo.storeHandle() else { loaded = true; return }
        let sessions = ((try? await store.liftSessions(deviceId: repo.deviceId, fromTs: 0,
                                                      toTs: Int(Date().timeIntervalSince1970))) ?? [])
            .filter { $0.programId == routineID }
            .sorted { $0.startTs < $1.startTs }
        var out: [Run] = []
        for s in sessions {
            let sets = ((try? await store.liftSets(sessionId: s.id)) ?? [])
                .filter { !$0.isWarmup && LiftMetrics.isPerformed(reps: $0.reps) }
            guard !sets.isEmpty else { continue }
            out.append(Run(id: s.id, startTs: s.startTs, volumeKg: LiftMetrics.volumeLoadKg(sets),
                           reps: sets.compactMap(\.reps).reduce(0, +),
                           minutes: s.endTs.map { Double(max(0, $0 - s.startTs)) / 60 }))
        }
        runs = out
        loaded = true
    }
}
#endif
