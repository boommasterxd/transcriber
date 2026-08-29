package com.transcriber.app

import android.os.Build
import android.view.KeyEvent
import android.view.inputmethod.InputConnection
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
            "pauseRecording" -> changeRecording(call, result, recorder::pause)
            "resumeRecording" -> changeRecording(call, result, recorder::resume)
            "stopRecording" -> stopRecording(call, result)
            "setComposingText" -> editText(call, result, composing = true)
            "commitText" -> editText(call, result, composing = false)
            "clearComposingText" -> clearComposingText(call, result)
            "deleteBackward" -> deleteBackward(call, result)
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

    private fun stopRecording(call: MethodCall, result: MethodChannel.Result) {
        val current = editor.accepts(call.argument("sessionId"))
        if (current) recorder.stop()
        result.success(current)
    }

    private fun changeRecording(
        call: MethodCall,
        result: MethodChannel.Result,
        action: () -> Boolean,
    ) {
        val sessionId = call.argument<String>("sessionId")
        when {
            !editor.accepts(sessionId) ->
                result.error("invalid_session", "The editor session is no longer active.", null)
            action() -> result.success(true)
            else -> result.error("audio_state_failed", "Unable to change microphone capture.", null)
        }
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

    private fun deleteBackward(call: MethodCall, result: MethodChannel.Result) {
        val deletedCodePoints = if (editor.accepts(call.argument("sessionId"))) {
            service.currentInputConnection?.let(::deleteBackward) ?: 0
        } else {
            0
        }
        result.success(deletedCodePoints)
    }

    private fun deleteBackward(connection: InputConnection): Int {
        val selection = connection.getSelectedText(0)
        return when {
            !selection.isNullOrEmpty() && connection.commitText("", cursorPosition) ->
                Character.codePointCount(selection, 0, selection.length)
            connection.deleteSurroundingTextInCodePoints(1, 0) -> 1
            else -> {
                val down = connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_DEL))
                val up = connection.sendKeyEvent(KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_DEL))
                if (down || up) 1 else 0
            }
        }
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
