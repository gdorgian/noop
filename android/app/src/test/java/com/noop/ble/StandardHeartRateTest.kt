package com.noop.ble

import com.noop.protocol.RrSourceChannel
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pure 0x2A37 parser contract — mirrors the Swift StandardHeartRate parser behaviour. No
 * android.bluetooth: [StandardHeartRate.parse] is a pure function over the raw notification bytes.
 *
 * Byte layout under test (Bluetooth SIG Heart Rate Measurement):
 *   flags bit0 → u16 HR (else u8); bit3 → Energy-Expended field (2 bytes, skipped); bit4 → R-R list.
 */
class StandardHeartRateTest {

    private fun bytes(vararg v: Int): ByteArray = ByteArray(v.size) { v[it].toByte() }

    @Test
    fun eightBitHrNoRr() {
        // flags=0x00 (8-bit HR, no R-R), HR=72.
        val r = StandardHeartRate.parse(bytes(0x00, 72))!!
        assertEquals(72, r.hr)
        assertTrue(r.rr.isEmpty())
    }

    @Test
    fun sixteenBitHr() {
        // flags=0x01 (16-bit HR), HR = 0x0140 = 320 (little-endian 0x40,0x01).
        val r = StandardHeartRate.parse(bytes(0x01, 0x40, 0x01))!!
        assertEquals(320, r.hr)
        assertTrue(r.rr.isEmpty())
    }

    @Test
    fun rrPresentConvertedToMs() {
        // flags=0x10 (8-bit HR + R-R present), HR=60, one R-R raw=1024 (1/1024 s units) → 1000 ms.
        val r = StandardHeartRate.parse(bytes(0x10, 60, 0x00, 0x04))!!
        assertEquals(60, r.hr)
        assertEquals(listOf(1000), r.rr)
    }

    @Test
    fun multipleRrIntervals() {
        // flags=0x10, HR=58, two R-R: raw=512 → 500 ms, raw=1024 → 1000 ms.
        val r = StandardHeartRate.parse(bytes(0x10, 58, 0x00, 0x02, 0x00, 0x04))!!
        assertEquals(58, r.hr)
        assertEquals(listOf(500, 1000), r.rr)
    }

    @Test
    fun energyExpendedFieldIsSkippedBeforeRr() {
        // flags=0x18 (bit3 energy-expended + bit4 R-R), HR=65, EE=0x00FF (2 bytes skipped),
        // then R-R raw=1024 → 1000 ms. Proves the EE bytes don't leak into the R-R parse.
        val r = StandardHeartRate.parse(bytes(0x18, 65, 0xFF, 0x00, 0x00, 0x04))!!
        assertEquals(65, r.hr)
        assertEquals(listOf(1000), r.rr)
    }

    @Test
    fun whoopPersistenceLabelsStandardBleTransport() {
        // Same two raw tick values held in the real historical v18 fixture. The standard parser and the
        // v18 decoder must land on identical rounded milliseconds, but with different durable transport
        // labels so the scoring read can prefer history over this receive-time copy.
        val reading = StandardHeartRate.parse(bytes(0x10, 102, 0x5A, 0x02, 0x65, 0x02))!!
        assertEquals(listOf(588, 599), reading.rr)

        val rows = whoopStandardRrRows(1_780_916_152L, listOf(200) + reading.rr + 3_001)
        assertEquals(listOf(588, 599), rows.map { it.rrMs })
        assertEquals(
            listOf(RrSourceChannel.WHOOP_STANDARD_BLE, RrSourceChannel.WHOOP_STANDARD_BLE),
            rows.map { it.srcChannel },
        )
    }

    @Test
    fun emptyOrTruncatedReturnsNull() {
        assertNull(StandardHeartRate.parse(ByteArray(0)))
        // flags claim a 16-bit HR but only one HR byte follows → truncated → null.
        assertNull(StandardHeartRate.parse(bytes(0x01, 0x40)))
    }
}
