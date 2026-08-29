package com.transcriber.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/** Streams bounded, in-memory PCM chunks. It never creates an audio file. */
class PcmAudioRecorder(
    private val context: Context,
    private val onChunk: (ByteArray, Double) -> Unit,
    private val onFailure: (String) -> Unit,
) {
    private val running = AtomicBoolean(false)
    private val generation = AtomicInteger(0)
    private var recorder: AudioRecord? = null
    private var worker: Thread? = null
    private var configuredSampleRate: Int? = null
    private var paused = false

    fun hasPermission(): Boolean = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
        PackageManager.PERMISSION_GRANTED

    fun start(sampleRate: Int): Boolean {
        paused = false
        configuredSampleRate = sampleRate
        return startCapture(sampleRate)
    }

    fun pause(): Boolean {
        if (!running.get()) return false
        paused = true
        stopCapture()
        return true
    }

    fun resume(): Boolean {
        val sampleRate = configuredSampleRate
        val resumed = if (paused && sampleRate != null) startCapture(sampleRate) else false
        if (resumed) paused = false
        return resumed
    }

    fun stop() {
        paused = false
        configuredSampleRate = null
        stopCapture()
    }

    private fun startCapture(sampleRate: Int): Boolean {
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
                createAndStart(sampleRate, minimum, generation.incrementAndGet())
            }
        }
    }

    private fun stopCapture() {
        if (!running.getAndSet(false)) return
        generation.incrementAndGet()
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

    private fun createAndStart(sampleRate: Int, minimum: Int, captureGeneration: Int): Boolean {
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
                worker = Thread(
                    { readLoop(audioRecord, sampleRate, captureGeneration) },
                    workerName,
                ).also { it.start() }
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

    private fun readLoop(audioRecord: AudioRecord, sampleRate: Int, captureGeneration: Int) {
        val buffer = ByteArray(sampleRate / chunksPerSecond * bytesPerSample)
        while (running.get() && generation.get() == captureGeneration) {
            val count = audioRecord.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
            if (count > 0 && running.get() && generation.get() == captureGeneration) {
                val chunk = buffer.copyOf(count)
                onChunk(chunk, PcmLevelMeter.normalizedLevel(chunk))
            } else if (count < 0 && running.get() && generation.get() == captureGeneration) {
                onFailure("audio_read_failed")
                running.set(false)
            }
        }
    }

    private companion object {
        const val chunksPerSecond = 10
        const val bufferSlicesPerSecond = 5
        const val bytesPerSample = 2
        const val workerName = "transcriber-pcm-recorder"
    }
}
