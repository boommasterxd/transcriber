package com.transcriber.app

import android.os.Build
import android.view.inputmethod.InputMethodManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Applies session-checked keyboard method calls to Android editor APIs. */
class ImeMethodHandler(
    private val service: TranscriberInputMethodService,
    messenger: BinaryMessenger,
    private val editor: ImeEditorContext,
    private val recorder: PcmAudioRecorder,
) {
    private val channel = MethodChannel(messenger, channelName)

    fun register() {
        channel.setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getEditorState" -> result.success(editor.state(recorder.hasPermission()))
            "startRecording" -> startRecording(call, result)
            "stopRecording" -> stopRecording(result)
            "setComposingText" -> editText(call, result, composing = true)
            "commitText" -> editText(call, result, composing = false)
            "clearComposingText" -> clearComposingText(call, result)
            "switchToPreviousInputMethod" -> result.success(switchBack())
            else -> result.notImplemented()
        }
    }

    private fun startRecording(call: MethodCall, result: MethodChannel.Result) {
        val sessionId = call.argument<String>("sessionId")
        val sampleRate = call.argument<Int>("sampleRate")
        when {
            !editor.accepts(sessionId) || sampleRate !in supportedSampleRates ->
                result.error("invalid_session", "The editor session is no longer active.", null)
            !recorder.hasPermission() ->
                result.error("microphone_denied", "Microphone permission is not granted.", null)
            recorder.start(checkNotNull(sampleRate)) -> result.success(true)
            else -> result.error("audio_start_failed", "Unable to start microphone capture.", null)
        }
    }

    private fun stopRecording(result: MethodChannel.Result) {
        recorder.stop()
        result.success(true)
    }

    private fun editText(call: MethodCall, result: MethodChannel.Result, composing: Boolean) {
        val sessionId = call.argument<String>("sessionId")
        val text = call.argument<String>("text") ?: ""
        val connection = service.currentInputConnection
        val changed = when {
            !editor.accepts(sessionId) -> false
            composing -> connection?.setComposingText(text, cursorPosition) ?: false
            else -> connection?.commitText(text, cursorPosition) ?: false
        }
        result.success(changed)
    }

    private fun clearComposingText(call: MethodCall, result: MethodChannel.Result) {
        val connection = service.currentInputConnection
        val changed = if (editor.accepts(call.argument("sessionId"))) {
            connection?.setComposingText("", cursorPosition)
            connection?.finishComposingText() ?: false
        } else {
            false
        }
        result.success(changed)
    }

    private fun switchBack(): Boolean = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        service.switchToPreviousInputMethod()
    } else {
        val token = service.window.window?.attributes?.token
        token != null && service.getSystemService(InputMethodManager::class.java)
            .switchToLastInputMethod(token)
    }

    private companion object {
        const val channelName = "app/keyboard/ime"
        const val cursorPosition = 1
        val supportedSampleRates = setOf(16_000, 24_000)
    }
}
