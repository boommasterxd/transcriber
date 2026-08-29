package com.transcriber.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PcmLevelMeterTest {
    @Test
    fun silenceUsesVisibleMinimumLevel() {
        assertEquals(0.05, PcmLevelMeter.normalizedLevel(ByteArray(320)), tolerance)
        assertEquals(0.05, PcmLevelMeter.normalizedLevel(byteArrayOf(1)), tolerance)
    }

    @Test
    fun speechAmplitudeUsesPerceptualDecibelScale() {
        val quiet = PcmLevelMeter.normalizedLevel(pcm(sample = 330, count = 160))
        val normal = PcmLevelMeter.normalizedLevel(pcm(sample = 3_277, count = 160))
        val loud = PcmLevelMeter.normalizedLevel(pcm(sample = 16_384, count = 160))

        assertTrue(quiet < normal)
        assertTrue(normal < loud)
        assertEquals(0.56, normal, 0.02)
        assertEquals(0.87, loud, 0.02)
    }

    private fun pcm(sample: Int, count: Int): ByteArray = ByteArray(count * 2).also { bytes ->
        repeat(count) { index ->
            bytes[index * 2] = sample.toByte()
            bytes[index * 2 + 1] = (sample shr 8).toByte()
        }
    }

    private companion object {
        const val tolerance = 0.000_001
    }
}
