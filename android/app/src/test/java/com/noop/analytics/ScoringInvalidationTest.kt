package com.noop.analytics

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ScoringInvalidationTest {
    @Test
    fun rrOnlyMutationForcesRunWhenHrFingerprintIsUnchanged() {
        assertTrue(
            ScoringInvalidation.needsRun(
                hrFingerprint = "28559:1781863200",
                analyzedHrFingerprint = "28559:1781863200",
                rrRevision = 4,
                analyzedRrRevision = 3,
            ),
        )
    }

    @Test
    fun completedPassSkipsOnlyWhenBothWatermarksMatch() {
        assertFalse(
            ScoringInvalidation.needsRun(
                hrFingerprint = "28559:1781863200",
                analyzedHrFingerprint = "28559:1781863200",
                rrRevision = 4,
                analyzedRrRevision = 4,
            ),
        )
        assertTrue(
            ScoringInvalidation.needsRun(
                hrFingerprint = "28560:1781863201",
                analyzedHrFingerprint = "28559:1781863200",
                rrRevision = 4,
                analyzedRrRevision = 4,
            ),
        )
    }

    @Test
    fun revisionCapturedBeforeRunCannotHideANewerConcurrentMutation() {
        // The completed pass records revision 4. If another R-R commit raised current to 5 during that
        // pass, the next gate still runs; a boolean pending flag could have been cleared accidentally.
        assertTrue(
            ScoringInvalidation.needsRun(
                hrFingerprint = "same",
                analyzedHrFingerprint = "same",
                rrRevision = 5,
                analyzedRrRevision = 4,
            ),
        )
    }
}
