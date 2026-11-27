package com.transcriber.app

import java.io.IOException

/** Couples the WAV writer lifetime to the quota reservation for its output. */
internal class BoundedRecordingFile(private val reservation: AudioCacheQuota.Lease) {
    private val writer = BoundedWaveWriter(reservation.file, reservation.maximum)
    val dataBytes: Long get() = writer.dataBytes

    fun append(bytes: ByteArray): Boolean = writer.append(bytes)

    fun finish() {
        writer.finish()
        reservation.finishWriting()
    }

    fun close(preserve: Boolean) {
        try {
            if (preserve) writer.finish()
        } finally {
            try {
                writer.close()
            } finally {
                reservation.finishWriting()
            }
        }
    }

    companion object {
        fun withNewPath(reservation: AudioCacheQuota.Lease, start: () -> Unit) {
            var created = false
            var started = false
            try {
                created = reservation.file.createNewFile()
                if (!created) throw IOException("Recording path is already in use")
                start()
                started = true
            } finally {
                if (!started) discardFailedStart(reservation, created)
            }
        }

        private fun discardFailedStart(reservation: AudioCacheQuota.Lease, created: Boolean) {
            try {
                if (created) {
                    reservation.requestDiscard()
                    AudioCachePaths.delete(reservation.file)
                } else {
                    reservation.abandon()
                }
            } finally {
                reservation.finishWriting()
            }
        }
    }
}
