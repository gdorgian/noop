package com.noop.analytics

/**
 * Pure decision shared by the post-offload scorer and the idle backstop. HR's count/max timestamp is
 * the existing cheap watermark; [rrRevision] covers R-R-only inserts and transport relabels that can
 * change HRV/respiration without changing one HR row.
 */
internal object ScoringInvalidation {
    fun needsRun(
        hrFingerprint: String,
        analyzedHrFingerprint: String?,
        rrRevision: Long,
        analyzedRrRevision: Long,
    ): Boolean = hrFingerprint != analyzedHrFingerprint || rrRevision != analyzedRrRevision
}
