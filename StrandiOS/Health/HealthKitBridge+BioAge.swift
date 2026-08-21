#if os(iOS)
import Foundation
import HealthKit
import StrandAnalytics

// MARK: - The instruments a wrist strap cannot measure
//
// The five-domain Fitness Age scores things a WHOOP does not observe: stair speed, walking steadiness,
// gait asymmetry, daylight exposure, blood pressure, glucose, body composition. The iPhone and Apple
// Health already hold most of them, and every one is a HealthKit READ type.
//
// Two rules this file keeps:
//
//   • READ ONLY. Nothing here writes, and every identifier it touches is listed in the bridge's
//     `writeDenied` set, so none of them can reach a share request even by mistake. That guard exists
//     because asking to SHARE an Apple-reserved type raises an uncatchable ObjC exception and kills the
//     app on launch — a mistake this codebase has already made once and paid for.
//
//   • AN ABSENCE IS NOT A ZERO. A type the wearer has no data for resolves to nil, never 0. The scorer
//     renormalizes over the instruments that are present and reports a lower confidence; handing it a 0
//     would instead score the wearer at the bottom of that metric's curve for owning the wrong watch.
//
// Nothing here is required. With no phone data at all the strap alone still reaches the cardiovascular,
// activity and recovery domains — the reading just says so, honestly, through its confidence.

extension HealthKitBridge {

    /// Gather every phone-side instrument the Fitness Age domains can use.
    ///
    /// - Parameter days: how far back to look. Cumulative instruments (flights, stand time, daylight)
    ///   are averaged to a per-day figure over this window, matching the per-day shape the activity
    ///   curves expect. Point-in-time instruments (blood pressure, glucose, body composition, gait) take
    ///   the most recent sample, because the current value is the one that describes the wearer now.
    func bioAgePhoneMetrics(days: Int = 30) async -> BioAge.PhoneMetrics {
        guard auth == .authorized else { return BioAge.PhoneMetrics() }

        let end = Date()
        let start = end.addingTimeInterval(-Double(days) * 86_400)

        async let vo2Max = latestValue(.vo2Max, unit: HKUnit(from: "ml/kg*min"))
        async let systolic = latestValue(.bloodPressureSystolic, unit: .millimeterOfMercury())
        async let diastolic = latestValue(.bloodPressureDiastolic, unit: .millimeterOfMercury())
        async let glucose = latestValue(.bloodGlucose,
                                        unit: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)))
        async let walkingHR = latestValue(.walkingHeartRateAverage, unit: HKUnit.count().unitDivided(by: .minute()))
        async let bodyFat = latestValue(.bodyFatPercentage, unit: .percent())
        async let leanMass = latestValue(.leanBodyMass, unit: .gramUnit(with: .kilo))
        async let steadiness = latestValue(.appleWalkingSteadiness, unit: .percent())
        async let asymmetry = latestValue(.walkingAsymmetryPercentage, unit: .percent())
        async let doubleSupport = latestValue(.walkingDoubleSupportPercentage, unit: .percent())
        async let ascent = latestValue(.stairAscentSpeed, unit: HKUnit.meter().unitDivided(by: .second()))
        async let descent = latestValue(.stairDescentSpeed, unit: HKUnit.meter().unitDivided(by: .second()))
        async let sixMinute = latestValue(.sixMinuteWalkTestDistance, unit: .meter())

        async let flights = dailyAverage(.flightsClimbed, unit: .count(), start: start, end: end)
        async let standHours = dailyAverage(.appleStandTime, unit: .hour(), start: start, end: end)
        async let daylight = dailyAverage(.timeInDaylight, unit: .minute(), start: start, end: end)

        // HealthKit reports these three as fractions of 1; SuperAgeCore's curves are written against
        // 0...100 for asymmetry and double-support, and 0...1 for steadiness. Convert at the boundary so
        // no downstream reader has to remember which is which.
        let asymmetryPercent = await asymmetry.map { $0 * 100 }
        let doubleSupportPercent = await doubleSupport.map { $0 * 100 }
        let bodyFatPercent = await bodyFat.map { $0 * 100 }

        return await BioAge.PhoneMetrics(
            vo2Max: vo2Max,
            systolicBloodPressure: systolic,
            diastolicBloodPressure: diastolic,
            bloodGlucose: glucose,
            walkingHeartRateAverage: walkingHR,
            bodyFatPercentage: bodyFatPercent,
            leanBodyMass: leanMass,
            flightsClimbed: flights,
            standHours: standHours,
            sixMinuteWalkTestDistance: sixMinute,
            stairAscentSpeed: ascent,
            stairDescentSpeed: descent,
            walkingSteadiness: steadiness,
            walkingAsymmetry: asymmetryPercent,
            walkingDoubleSupport: doubleSupportPercent,
            timeInDaylight: daylight
        )
    }

    /// The most recent sample of a type, or nil if there is none. Not windowed: a body-fat reading from
    /// three months ago still describes the wearer better than no reading at all, and the scorer's
    /// confidence already accounts for thin evidence.
    private func latestValue(_ id: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1,
                                      sortDescriptors: [sort]) { _, samples, _ in
                // A query error and an empty result are the same answer here: we have nothing. Neither is
                // worth surfacing — an unauthorized or empty type is the normal case, not a fault.
                guard let sample = (samples?.first as? HKQuantitySample) else {
                    return continuation.resume(returning: nil)
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    /// A cumulative type summed per day and averaged over the days that actually have data.
    ///
    /// Averaging over days-with-data rather than over the whole window is deliberate: a wearer who left
    /// their phone at home for a fortnight has no flights-climbed data for those days, and dividing by
    /// the full window would report them as sedentary rather than as unobserved.
    private func dailyAverage(_ id: HKQuantityTypeIdentifier, unit: HKUnit,
                              start: Date, end: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let anchor = Calendar.current.startOfDay(for: start)
        return await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: type, quantitySamplePredicate: nil,
                options: .cumulativeSum, anchorDate: anchor,
                intervalComponents: DateComponents(day: 1))
            query.initialResultsHandler = { _, results, _ in
                guard let results else { return continuation.resume(returning: nil) }
                var total = 0.0
                var observedDays = 0
                results.enumerateStatistics(from: start, to: end) { statistics, _ in
                    guard let sum = statistics.sumQuantity() else { return }
                    total += sum.doubleValue(for: unit)
                    observedDays += 1
                }
                continuation.resume(returning: observedDays > 0 ? total / Double(observedDays) : nil)
            }
            store.execute(query)
        }
    }
}
#endif
