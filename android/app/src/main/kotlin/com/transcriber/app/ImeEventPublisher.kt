package com.transcriber.app

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/** Publishes editor and PCM events to the keyboard Flutter engine. */
class ImeEventPublisher(
    messenger: BinaryMessenger,
    private val editor: ImeEditorContext,
) {
    private val channel = EventChannel(messenger, channelName)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val audioLock = Any()
    private var sink: EventChannel.EventSink? = null
    private var capture: AudioCapture? = null
    private var drainScheduled = false

    fun createRecorder(context: Context): PcmAudioRecorder = PcmAudioRecorder(context, ::openCapture)

    fun register(recorder: PcmAudioRecorder) {
        channel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    sink = events
                    emitEditorState(recorder)
                }

                override fun onCancel(arguments: Any?) {
                    sink = null
                    recorder.stop()
                    synchronized(audioLock) { capture = null }
                    editor.invalidate()
                }
            },
        )
    }

    fun emitEditorState(recorder: PcmAudioRecorder) {
        mainHandler.post {
            sink?.success(mapOf("type" to "editor", "editor" to editor.state(recorder.hasPermission())))
        }
    }

    internal fun openCapture(): PcmCaptureEvents {
        val current = AudioCapture(editor.sessionId)
        synchronized(audioLock) { capture = current }
        return PcmCaptureEvents(
            offer = { bytes, level -> enqueue(current, bytes, level) },
            fail = { code -> fail(current, code) },
            cancel = { cancel(current) },
        )
    }

    private fun cancel(current: AudioCapture) = synchronized(audioLock) {
        if (capture === current) capture = null
        current.chunks.clear()
        current.failure = null
    }

    private fun enqueue(current: AudioCapture, bytes: ByteArray, level: Double): Boolean = synchronized(audioLock) {
        if (capture !== current || current.failure != null) return@synchronized false
        val fits = bytes.size <= maxChunkBytes && current.chunks.size < maxPendingChunks
        if (fits) {
            current.chunks.addLast(AudioChunk(bytes, level))
        } else {
            current.chunks.clear()
            current.failure = "audio_buffer_overflow"
        }
        scheduleDrain()
        fits && capture === current
    }

    private fun fail(current: AudioCapture, code: String) = synchronized(audioLock) {
        if (capture === current && current.failure == null) {
            current.failure = code
            scheduleDrain()
        }
    }

    private fun scheduleDrain() {
        if (!drainScheduled) {
            drainScheduled = mainHandler.post(::drain)
            if (!drainScheduled) capture = null
        }
    }

    private fun drain() {
        try {
            val current = synchronized(audioLock) { capture } ?: return
            if (!editor.accepts(current.session)) {
                cancel(current)
            } else {
                publishPending(current)
            }
        } finally {
            synchronized(audioLock) {
                drainScheduled = false
                if (capture?.hasPending == true) scheduleDrain()
            }
        }
    }

    private fun publishPending(current: AudioCapture) {
        repeat(maxPendingChunks) {
            val next = synchronized(audioLock) { current.takeEvent() } ?: return
            sink?.success(next)
        }
    }

    private class AudioCapture(val session: String) {
        val chunks = ArrayDeque<AudioChunk>()
        var failure: String? = null
        private var failureSent = false

        val hasPending: Boolean
            get() = chunks.isNotEmpty() || (failure != null && !failureSent)

        fun takeEvent(): Map<String, Any>? {
            val chunk = chunks.removeFirstOrNull()
            if (chunk != null) {
                return mapOf(
                    "type" to "audio",
                    "sessionId" to session,
                    "pcm" to chunk.bytes,
                    "level" to chunk.level,
                )
            }
            val code = failure
            return if (code == null || failureSent) {
                null
            } else {
                failureSent = true
                mapOf("type" to "error", "code" to code, "sessionId" to session)
            }
        }
    }

    private data class AudioChunk(val bytes: ByteArray, val level: Double)

    private companion object {
        const val channelName = "app/keyboard/audio"
        const val maxPendingChunks = 12
        const val maxChunkBytes = 4_800
    }
}
