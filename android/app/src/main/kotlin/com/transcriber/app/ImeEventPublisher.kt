package com.transcriber.app

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
    private var sink: EventChannel.EventSink? = null

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

    fun emitAudioChunk(bytes: ByteArray, level: Double) {
        val session = editor.sessionId
        mainHandler.post {
            if (editor.accepts(session)) {
                sink?.success(
                    mapOf("type" to "audio", "sessionId" to session, "pcm" to bytes, "level" to level),
                )
            }
        }
    }

    fun emitAudioFailure(code: String) {
        val session = editor.sessionId
        mainHandler.post {
            sink?.success(mapOf("type" to "error", "code" to code, "sessionId" to session))
        }
    }

    private companion object {
        const val channelName = "app/keyboard/audio"
    }
}
