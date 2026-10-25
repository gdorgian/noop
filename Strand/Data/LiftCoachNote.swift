import Foundation
import StrandTraining

/// What to aim for on an exercise today, read from the last session of it through the training package's
/// progression rules — the same rules a routine's progression setting names. Advice, never an instruction:
/// the numbers the lifter types are what is saved.
///
/// Only working sets that carried both a weight and reps count. With nothing to read there is no note, which
/// is the honest answer for a first time.
struct LiftCoachNote: Equatable {
    enum Advice: Equatable {
        /// Every set reached the top of the range: the next weight up, back at the bottom of the range.
        case addWeight(toKg: Double, byKg: Double, reps: Int)
        /// Every set was good but not yet at the top: the same weight, one more rep.
        case addRep(weightKg: Double, reps: Int)
        /// A set fell short: the same weight and the same target again.
        case repeatTarget(weightKg: Double, reps: Int)
    }

    let advice: Advice
    /// The reps of last time's sets, in order, for "8, 8, 7 last time".
    let lastReps: [Int]

    static func make(lastSession: [Int: LiftSetCarry], item: LiftPlanItem, incrementKg: Double) -> LiftCoachNote? {
        let sets = lastSession.sorted { $0.key < $1.key }.map(\.value)
            .filter { ($0.weightKg ?? 0) > 0 && ($0.reps ?? 0) > 0 }
        guard let top = sets.compactMap(\.weightKg).max() else { return nil }
        // The sets at the top weight are the ones the progression is about; lighter ones were ramps or drops.
        let working = sets.filter { abs(($0.weightKg ?? 0) - top) < 0.01 }
        let reps = working.compactMap(\.reps)
        guard !reps.isEmpty else { return nil }

        let configured = item.routinePlan?.progression.flatMap { $0.policy == .off ? nil : $0 }
        // With no target to read, the lifter's own last time sets the range: what they did, up to two more
        // reps, then the weight goes up. A fixed 8–12 would call a deliberate set of five a failure.
        let low = item.targetRepsLow ?? configured?.repsMin ?? (reps.min() ?? 8)
        let high = max(low, item.targetRepsHigh ?? configured?.repsMax ?? low + 2)
        let config: ProgressionConfiguration
        if let configured {
            config = configured
        } else {
            config = ProgressionConfiguration(policy: .doubleProgression, weightIncrementKg: incrementKg,
                                              repsMin: low, repsMax: high)
        }
        let target = Array(repeating: low, count: reps.count)
        let prescription = TrainingProgressionEngine.next(
            configuration: config,
            history: [ProgressionSession(weightKg: top, completedReps: reps, targetReps: target)],
            mode: .weightReps, currentWeightKg: top, currentReps: low)

        let weight = prescription.weightKg ?? top
        let advice: Advice
        switch prescription.reason {
        case .topOfRepRange, .successfulSession, .exceptionalAMRAP:
            guard weight > top + 0.001 else { return nil }
            advice = .addWeight(toKg: weight, byKg: weight - top, reps: prescription.reps ?? config.repsMin)
        case .addRepetition:
            advice = .addRep(weightKg: top, reps: prescription.reps ?? (reps.min() ?? low) + 1)
        case .repeatTarget, .stalledDeload:
            advice = .repeatTarget(weightKg: weight, reps: max(low, prescription.reps ?? low))
        default:
            return nil
        }
        return LiftCoachNote(advice: advice, lastReps: reps)
    }
}
