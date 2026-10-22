import SwiftUI
import StrandAnalytics
import WhoopStore

/// Aura's opt-in confirmation boundary. An offer is not a saved or classified workout.
struct NoopActivityOffer: View {
    @EnvironmentObject private var repo: Repository
    @EnvironmentObject private var model: AppModel
    @AppStorage(PuffinExperiment.autoDetectWorkoutsKey) private var enabled = false
    @State private var candidate: DetectedWorkout?
    @State private var review: ActivityReview?
    @State private var saving = false
    @State private var saveFailed = false
    @State private var previewHandled = false

    private struct LoadKey: Equatable {
        let sequence: Int
        let device: String
        let enabled: Bool
    }

    private struct ActivityReview: Identifiable {
        let candidate: DetectedWorkout
        let device: String
        var id: String { "\(device):\(candidate.startSec):\(candidate.endSec)" }
        var draft: WorkoutRow {
            // No inferred sport, calories or distance. HR stays empty in the editor because the
            // wearer may change the window; the normal enrichment pass can fill the saved span.
            WorkoutRow(startTs: candidate.startSec, endTs: candidate.endSec, sport: "", source: "manual",
                       durationS: Double(candidate.endSec - candidate.startSec), energyKcal: nil,
                       avgHr: nil, maxHr: nil, strain: nil, distanceM: nil, zonesJSON: nil, notes: nil, steps: nil)
        }
    }

    private var preview: Bool {
        #if DEBUG
        NoopContentPolicy.allowsPrototypeContent && CommandLine.arguments.contains("--noop-activity-offer-preview")
        #else
        false
        #endif
    }

    private var loadKey: LoadKey {
        LoadKey(sequence: repo.refreshSeq, device: repo.deviceId, enabled: enabled || preview)
    }

    var body: some View {
        Group {
            if loadKey.enabled, let candidate {
                NoopHTMLCard(radius: 20, padding: 16) {
                    VStack(alignment: .leading, spacing: 11) {
                        NoopSectionLabel("Possible activity", color: NoopHTMLColor.warm)
                        Text(windowLabel(candidate))
                            .font(NoopHTMLFont.sans(14.5, weight: .semibold))
                            .foregroundStyle(NoopHTMLColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Elevated heart rate was recorded. Review the time and choose an activity before saving.")
                            .font(NoopHTMLFont.sans(12))
                            .foregroundStyle(NoopHTMLColor.copy)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 16) {
                            Button {
                                review = ActivityReview(candidate: candidate, device: repo.deviceId)
                            } label: {
                                Text(saving ? "Saving…" : "Review").frame(minWidth: 44, minHeight: 44)
                            }
                            .foregroundStyle(NoopHTMLColor.warm)
                            Button {
                                if preview { previewHandled = true } else { repo.dismissDetectedSuggestion(candidate) }
                                self.candidate = nil
                            } label: {
                                Text("Dismiss").frame(minWidth: 44, minHeight: 44)
                            }
                            .foregroundStyle(NoopHTMLColor.copy)
                            Spacer(minLength: 0)
                        }
                        .font(NoopHTMLFont.sans(13, weight: .semibold))
                        .buttonStyle(NoopPlainHitStyle())
                        .disabled(saving)
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
        .task(id: loadKey) {
            let requested = loadKey
            guard requested.enabled else { candidate = nil; review = nil; return }
            guard !saving else { return }
            let next: DetectedWorkout?
            if preview {
                let end = Int(Date().timeIntervalSince1970) - 3600
                next = previewHandled ? nil : DetectedWorkout(startSec: end - 28 * 60, endSec: end,
                                                              avgBpm: 125, peakBpm: 150, durationMin: 28)
            } else {
                next = await repo.autoDetectCandidate()
            }
            guard !Task.isCancelled, requested == loadKey else { return }
            candidate = next
        }
        .onChange(of: repo.deviceId) { _, _ in candidate = nil; review = nil }
        .sheet(item: $review) { selection in
            ManualWorkoutSheet(editing: selection.draft, reviewingSuggestion: true) { row, _ in
                // This draft was never stored: passing it as `replacing` would edit a phantom row.
                save(row, selection: selection)
            }
            .environmentObject(repo)
        }
        .alert("Activity wasn’t saved", isPresented: $saveFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your suggestion is still available. Check the active strap and try again.")
        }
    }

    private func save(_ row: WorkoutRow, selection: ActivityReview) {
        guard !saving else { return }
        saving = true
        Task { @MainActor in
            let success: Bool
            if preview {
                previewHandled = true
                success = true
            } else {
                success = await repo.saveReviewedDetectedWorkout(selection.candidate, row: row,
                                                                 expectedDeviceId: selection.device)
            }
            if success {
                candidate = nil
                if !preview, repo.deviceId == selection.device {
                    await model.intelligence.analyzeRecent()
                    await repo.refresh()
                }
            } else {
                saveFailed = true
            }
            saving = false
        }
    }

    private func windowLabel(_ candidate: DetectedWorkout) -> String {
        let start = Date(timeIntervalSince1970: TimeInterval(candidate.startSec))
        let end = Date(timeIntervalSince1970: TimeInterval(candidate.endSec))
        let day: String
        if Calendar.current.isDateInToday(start) { day = "Today" }
        else if Calendar.current.isDateInYesterday(start) { day = "Yesterday" }
        else { day = DateFormatter.localizedString(from: start, dateStyle: .medium, timeStyle: .none) }
        return "\(day) · \(AppClock.hourMinuteFormatter().string(from: start))–\(AppClock.hourMinuteFormatter().string(from: end)) · \(candidate.durationMin) min"
    }
}
