package com.transcriber.app

import kotlin.math.log10
import kotlin.math.sqrt

/** Maps signed 16-bit little-endian PCM to a perceptual waveform level. */
internal object PcmLevelMeter {
    fun normalizedLevel(bytes: ByteArray): Double {
        if (bytes.size < bytesPerSample) return minimumLevel
        var sum = 0.0
        var index = 0
        while (index + 1 < bytes.size) {
            val sample = (
                (bytes[index + 1].toInt() shl bitsPerByte) or
                    (bytes[index].toInt() and unsignedByteMask)
                ).toShort()
            val normalized = sample.toDouble() / Short.MAX_VALUE
            sum += normalized * normalized
            index += bytesPerSample
        }
        val rms = sqrt(sum / (bytes.size / bytesPerSample))
        return if (rms <= 0.0) {
            minimumLevel
        } else {
            val decibels = decibelsPerAmplitude * log10(rms)
            ((decibels - noiseFloorDb) / -noiseFloorDb).coerceIn(minimumLevel, 1.0)
        }
    }

    private const val bytesPerSample = 2
    private const val bitsPerByte = 8
    private const val unsignedByteMask = 0xff
    private const val decibelsPerAmplitude = 20.0
    private const val noiseFloorDb = -45.0
    private const val minimumLevel = 0.05
}
