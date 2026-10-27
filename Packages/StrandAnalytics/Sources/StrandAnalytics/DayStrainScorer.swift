import Foundation
import WhoopProtocol

/// The shared daily Effort resolver for calendar days, sleep-onset days and live day readouts.
/// Workout bouts deliberately keep using `StrainScorer` directly.
public enum DayStrainScorer {
    /// Resolve WHOOP's local-table recipe when it has a usable HRmax; otherwise retain the
    /// independent scorer and its existing data-sufficiency gate. A WHOOP day without usable HR
    /// stays unknown rather than being reinterpreted as an independent measured zero.
    public static func score(_ hr: [HRSample],
                             maxHR: Double? = nil,
                             restingHR: Double = StrainScorer.defaultRestingHR,
                             method: StrainScorer.Method = .edwards,
                             sex: String = "male",
                             diag: ((String) -> Void)? = nil,
                             day: String = "",
                             tables: WhoopStrain.Tables? = WhoopStrain.tables) -> Double? {
        let fallbackReason: String
        if tables == nil {
            fallbackReason = "tables absent"
        } else if maxHR == nil {
            fallbackReason = "HRmax unavailable"
        } else if let maxHR, !maxHR.isFinite || !restingHR.isFinite || maxHR <= restingHR {
            fallbackReason = "invalid HRmax/resting HR"
        } else if let maxHR {
            let strain21 = WhoopStrain.dayStrain21(hr, restingHR: restingHR,
                                                  hrMax: maxHR, tables: tables)
            if let strain21 {
                diag?("effort method: whoop (WHOOP tables bundled)")
                return StrainScorer.effortValue(fromWhoopStrain: strain21)
            }
            diag?("effort method: whoop (no usable HR)")
            return nil
        } else {
            fallbackReason = "HRmax unavailable"
        }
        let result = StrainScorer.strain(hr, maxHR: maxHR, restingHR: restingHR,
                                         method: method, sex: sex, diag: diag, day: day)
        diag?("effort method: \(methodName(method)) (fallback: \(fallbackReason))")
        return result
    }

    /// Stable identity for persisted and in-memory analysis caches. Bump the recipe version
    /// whenever daily arithmetic changes. Table identity uses FNV-1a over explicitly ordered
    /// numeric bytes, independent of Swift's randomized hash and of JSON whitespace.
    public static func cacheIdentity(method: StrainScorer.Method = .edwards,
                                     tables: WhoopStrain.Tables? = WhoopStrain.tables) -> String {
        let prefix = "day-strain-v2:fallback=\(methodName(method))"
        guard let tables else { return prefix + ":tables=absent" }
        var hash: UInt64 = 14_695_981_039_346_656_037
        func append(_ bits: UInt64) {
            for shift in stride(from: 0, to: 64, by: 8) {
                hash = (hash ^ ((bits >> shift) & 0xff)) &* 1_099_511_628_211
            }
        }
        append(UInt64(tables.scale.count))
        for row in tables.scale {
            append(row.raw.bitPattern)
            append(row.strain.bitPattern)
        }
        if let targets = tables.targets {
            append(1)
            append(UInt64(targets.count))
            for row in targets {
                append(UInt64(bitPattern: Int64(row.recovery)))
                append(row.lower.bitPattern)
                append(row.target.bitPattern)
                append(row.upper.bitPattern)
            }
        } else {
            append(0)
        }
        return prefix + ":tables=" + String(hash, radix: 16)
    }

    private static func methodName(_ method: StrainScorer.Method) -> String {
        switch method {
        case .edwards: return "edwards"
        case .banister: return "banister"
        }
    }
}
