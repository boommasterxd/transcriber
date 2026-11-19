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
    private val createCaptureEvents: () -> PcmCaptureEvents,
) {
    constructor(
        context: Context,
        onChunk: (ByteArray, Double) -> Unit,
        onFailure: (String) -> Unit,
    ) : this(
        context,
        {
            PcmCaptureEvents(
                offer = { bytes, level ->
                    onChunk(bytes, level)
                    true
                },
                fail = onFailure,
            )
        },
    )

    private val running = AtomicBoolean(false)
    private val generation = AtomicInteger(0)
    private var recorder: AudioRecord? = null
    private var worker: Thread? = null
    private var captureEvents: PcmCaptureEvents? = null
    private var configuredSampleRate: Int? = null
    private var paused = false

    fun hasPermission(): Boolean = context.checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
        PackageManager.PERMISSION_GRANTED

    @Synchronized
    fun start(sampleRate: Int): Boolean {
        if (running.get()) return false
        paused = false
        configuredSampleRate = sampleRate
        return startCapture(sampleRate)
    }

    @Synchronized
    fun pause(): Boolean {
        if (!running.get()) return false
        paused = true
        stopCapture()
        return true
    }

    @Synchronized
    fun resume(): Boolean {
        val sampleRate = configuredSampleRate
        val resumed = if (paused && sampleRate != null) startCapture(sampleRate) else false
        if (resumed) paused = false
        return resumed
    }

    @Synchronized
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
        val wasRunning = running.getAndSet(false)
        generation.incrementAndGet()
        captureEvents?.cancel?.invoke()
        captureEvents = null
        if (!wasRunning) return
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
        var audioRecord: AudioRecord? = null
        return try {
            audioRecord = AudioRecord(
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
                audioRecord.startRecording()
                val events = createCaptureEvents()
                captureEvents?.cancel?.invoke()
                captureEvents = events
                recorder = audioRecord
                worker = Thread(
                    { readLoop(audioRecord, sampleRate, captureGeneration, events) },
                    workerName,
                ).also { it.start() }
                true
            }
        } catch (_: RuntimeException) {
            try {
                audioRecord?.stop()
            } catch (_: IllegalStateException) {
                // Capture may have failed before Android entered recording state.
            }
            audioRecord?.release()
            captureEvents?.cancel?.invoke()
            captureEvents = null
            if (recorder === audioRecord) recorder = null
            running.set(false)
            false
        }
    }

    private fun readLoop(
        audioRecord: AudioRecord,
        sampleRate: Int,
        captureGeneration: Int,
        events: PcmCaptureEvents,
    ) {
        val buffer = ByteArray(sampleRate / chunksPerSecond * bytesPerSample)
        fun isCurrent(): Boolean = running.get() && generation.get() == captureGeneration
        try {
            while (isCurrent()) {
                val count = audioRecord.read(buffer, 0, buffer.size, AudioRecord.READ_BLOCKING)
                if (!isCurrent() || !events.dispatchRead(buffer, count)) break
            }
        } catch (_: IllegalStateException) {
            if (isCurrent()) {
                events.fail("audio_read_failed")
            }
        } finally {
            releaseCompletedCapture(audioRecord, captureGeneration)
        }
    }

    @Synchronized
    private fun releaseCompletedCapture(audioRecord: AudioRecord, captureGeneration: Int) {
        if (!generation.compareAndSet(captureGeneration, captureGeneration + 1)) return
        running.set(false)
        try {
            audioRecord.stop()
        } catch (_: IllegalStateException) {
            // Android may already have stopped capture after an audio error.
        }
        audioRecord.release()
        if (recorder === audioRecord) recorder = null
        if (worker === Thread.currentThread()) worker = null
    }

    private companion object {
        const val chunksPerSecond = 10
        const val bufferSlicesPerSecond = 5
        const val bytesPerSample = 2
        const val workerName = "transcriber-pcm-recorder"
    }
}

class PcmCaptureEvents(
    val offer: (ByteArray, Double) -> Boolean,
    val fail: (String) -> Unit,
    val cancel: () -> Unit = {},
) {
    internal fun dispatchRead(buffer: ByteArray, count: Int): Boolean = when {
        count < 0 -> {
            fail("audio_read_failed")
            false
        }
        count > 0 -> {
            val chunk = buffer.copyOf(count)
            offer(chunk, PcmLevelMeter.normalizedLevel(chunk))
        }
        else -> true
    }
}
