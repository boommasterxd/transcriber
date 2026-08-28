package com.transcriber.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.sqrt

/** Streams bounded, in-memory PCM chunks. It never creates an audio file. */
class PcmAudioRecorder(
    private val context: Context,
    private val onChunk: (ByteArray, Double) -> Unit,
    private val onFailure: (String) -> Unit,
) {
    private val running = AtomicBoolean(false)
    private var recorder: AudioRecord? = null
    private var worker: Thread? = null

    fun hasPermission(): Boolean = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
        PackageManager.PERMISSION_GRANTED

    fun start(sampleRate: Int): Boolean {
        return if (!hasPermission() || !running.compareAndSet(false, true)) {
            false
        } else {
            val minimum = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
            )
            if (minimum <= 0) {
                running.set(false)
                false
            } else {
                createAndStart(sampleRate, minimum)
            }
        }
    }

    fun stop() {
        if (!running.getAndSet(false)) return
        try {
            recorder?.stop()
        } catch (_: IllegalStateException) {
            // The recorder may already have stopped after an Android audio error.
        }
        worker?.interrupt()
        worker = null
        recorder?.release()
        recorder = null
    }

    private fun createAndStart(sampleRate: Int, minimum: Int): Boolean {
        return try {
            val audioRecord = AudioRecord(
                MediaRecorder.AudioSource.VOICE_RECOGNITION,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                maxOf(minimum, sampleRate / bufferSlicesPerSecond * bytesPerSample),
            )
            if (audioRecord.state != AudioRecord.STATE_INITIALIZED) {
                audioRecord.release()
                running.set(false)
                false
            } else {
                recorder = audioRecord
                audioRecord.startRecording()
                worker = Thread({ readLoop(audioRecord, sampleRate) }, workerName).also { it.start() }
                true
            }
        } catch (_: SecurityException) {
            running.set(false)
            false
        } catch (_: IllegalArgumentException) {
            running.set(false)
            false
        }
    }

    private fun readLoop(audioRecord: AudioRecord, sampleRate: Int) {
        val buffer = ByteArray(sampleRate / chunksPerSecond * bytesPerSample)
        while (running.get()) {
            val count = audioRecord.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
            if (count > 0) {
                val chunk = buffer.copyOf(count)
                onChunk(chunk, normalizedLevel(chunk))
            } else if (count < 0) {
                onFailure("audio_read_failed")
                running.set(false)
            }
        }
    }

    private fun normalizedLevel(bytes: ByteArray): Double {
        if (bytes.size < bytesPerSample) return 0.0
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
        return sqrt(sum / (bytes.size / bytesPerSample)).coerceIn(0.0, 1.0)
    }

    private companion object {
        const val chunksPerSecond = 10
        const val bufferSlicesPerSecond = 5
        const val bytesPerSample = 2
        const val bitsPerByte = 8
        const val unsignedByteMask = 0xff
        const val workerName = "transcriber-pcm-recorder"
    }
}
