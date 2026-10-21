package com.transcriber.app

import android.view.inputmethod.InputConnection
import io.flutter.plugin.common.FlutterException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers.any
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class ImeMethodHandlerTest {
    private val service = mock(TranscriberInputMethodService::class.java)
    private val editor = mock(ImeEditorContext::class.java)
    private val recorder = mock(PcmAudioRecorder::class.java)
    private val connection = mock(InputConnection::class.java)
    private val transport = NativeChannelHarness()
    private val arguments = mapOf("sessionId" to "active", "sampleRate" to 16_000, "text" to "hello")

    private fun call(method: String, values: Map<String, Any> = arguments): Any? =
        transport.call("app/keyboard/ime", method, values)

    private fun register() {
        `when`(editor.accepts("active")).thenReturn(true)
        `when`(service.currentInputConnection).thenReturn(connection)
        ImeMethodHandler(service, transport, editor, recorder).register()
    }

    @Test
    fun recordingValidatesSessionRatePermissionAndProviderOutcome() {
        register()
        val invalid = assertThrows(FlutterException::class.java) { call("startRecording", emptyMap()) }
        assertEquals("invalid_session", invalid.code)
        assertEquals(
            "invalid_session",
            assertThrows(FlutterException::class.java) {
                call("startRecording", arguments + ("sampleRate" to 44_100))
            }.code
        )
        assertEquals(
            "microphone_denied",
            assertThrows(FlutterException::class.java) {
                call("startRecording")
            }.code
        )
        `when`(recorder.hasPermission()).thenReturn(true)
        assertEquals(
            "audio_start_failed",
            assertThrows(FlutterException::class.java) {
                call("startRecording")
            }.code
        )
        `when`(recorder.start(16_000)).thenReturn(true)
        assertEquals(true, call("startRecording"))
        assertEquals(true, call("stopRecording"))
        verify(recorder).stop()
        assertEquals(false, call("stopRecording", emptyMap()))
        assertEquals(null, call("unknown"))
    }

    @Test
    fun pauseAndResumePropagateFailuresAndRejectStaleSessions() {
        register()
        for (method in listOf("pauseRecording", "resumeRecording")) {
            assertEquals(
                "invalid_session",
                assertThrows(FlutterException::class.java) {
                    call(method, emptyMap())
                }.code
            )
            assertEquals(
                "audio_state_failed",
                assertThrows(FlutterException::class.java) {
                    call(method)
                }.code
            )
        }
        `when`(recorder.pause()).thenReturn(true)
        `when`(recorder.resume()).thenReturn(true)
        assertEquals(true, call("pauseRecording"))
        assertEquals(true, call("resumeRecording"))
        `when`(editor.state(false)).thenReturn(mapOf("visible" to true))
        assertEquals(mapOf("visible" to true), call("getEditorState"))
        `when`(service.switchToPreviousInputMethod()).thenReturn(true)
        assertEquals(true, call("switchToPreviousInputMethod"))
    }

    @Test
    fun editsRequireActiveSessionAndReturnInputConnectionResults() {
        register()
        `when`(connection.setComposingText("hello", 1)).thenReturn(true)
        `when`(connection.commitText("hello", 1)).thenReturn(true)
        `when`(connection.finishComposingText()).thenReturn(true)
        assertEquals(true, call("setComposingText"))
        assertEquals(true, call("commitText"))
        assertEquals(true, call("clearComposingText"))
        for (method in listOf("setComposingText", "commitText", "clearComposingText")) {
            assertEquals(false, call(method, emptyMap()))
        }
        `when`(service.currentInputConnection).thenReturn(null)
        for (method in listOf("setComposingText", "commitText", "clearComposingText")) {
            assertEquals(false, call(method))
        }
    }

    @Test
    fun deletionCountsSelectedCodePointsAndFallsBackToKeyEvents() {
        register()
        `when`(connection.getSelectedText(0)).thenReturn("a\uD83D\uDE00")
        `when`(connection.commitText("", 1)).thenReturn(true)
        assertEquals(2, call("deleteBackward"))
        `when`(connection.getSelectedText(0)).thenReturn("")
        `when`(connection.deleteSurroundingTextInCodePoints(1, 0)).thenReturn(true)
        assertEquals(1, call("deleteBackward"))
        `when`(connection.getSelectedText(0)).thenReturn("selected")
        `when`(connection.commitText("", 1)).thenReturn(false)
        assertEquals(1, call("deleteBackward"))
        `when`(connection.getSelectedText(0)).thenReturn(null)
        `when`(connection.deleteSurroundingTextInCodePoints(1, 0)).thenReturn(false)
        `when`(connection.sendKeyEvent(any())).thenReturn(true)
        assertEquals(1, call("deleteBackward"))
        `when`(connection.sendKeyEvent(any())).thenReturn(false)
        assertEquals(0, call("deleteBackward"))
        assertEquals(0, call("deleteBackward", emptyMap()))
        `when`(service.currentInputConnection).thenReturn(null)
        assertEquals(0, call("deleteBackward"))
    }

    @Test
    @Config(sdk = [27])
    fun legacySwitchUsesTheWindowTokenAndRejectsMissingToken() {
        val legacyService = mock(TranscriberInputMethodService::class.java, org.mockito.Mockito.RETURNS_DEEP_STUBS)
        val legacyEditor = mock(ImeEditorContext::class.java)
        ImeMethodHandler(legacyService, transport, legacyEditor, recorder).register()
        val window = legacyService.window.window!!
        val attributes = android.view.WindowManager.LayoutParams()
        `when`(window.attributes).thenReturn(attributes)
        assertEquals(false, call("switchToPreviousInputMethod"))
        val token = android.os.Binder()
        attributes.token = token
        val manager = mock(android.view.inputmethod.InputMethodManager::class.java)
        `when`(legacyService.getSystemService(android.view.inputmethod.InputMethodManager::class.java))
            .thenReturn(manager)
        `when`(manager.switchToLastInputMethod(token)).thenReturn(true)
        assertEquals(true, call("switchToPreviousInputMethod"))
    }
}
