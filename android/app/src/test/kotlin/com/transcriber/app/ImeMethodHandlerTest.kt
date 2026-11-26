package com.transcriber.app

import android.text.InputType
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.verifyNoInteractions
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class ImeMethodHandlerTest {
    @Test
    fun lateCommitFromPreviousEditorCannotWriteIntoNewEditor() {
        val service = mock(TranscriberInputMethodService::class.java)
        val recorder = mock(PcmAudioRecorder::class.java)
        val editor = ImeEditorContext(service)
        val transport = NativeChannelHarness()
        val info = EditorInfo().apply { inputType = InputType.TYPE_CLASS_TEXT }
        val original = mock(InputConnection::class.java)
        val next = mock(InputConnection::class.java)
        `when`(service.currentInputEditorInfo).thenReturn(info)
        `when`(service.currentInputConnection).thenReturn(original)
        `when`(original.commitText("First transcript", 1)).thenReturn(true)
        ImeMethodHandler(service, transport, editor, recorder).register()
        editor.start(info)
        editor.setVisible(true)
        val first = mapOf("sessionId" to editor.sessionId, "text" to "First transcript")

        assertEquals(true, transport.call("app/keyboard/ime", "commitText", first))
        verify(original).commitText("First transcript", 1)

        `when`(service.currentInputConnection).thenReturn(next)
        editor.start(info)
        assertEquals(false, transport.call("app/keyboard/ime", "commitText", first))
        assertEquals(0, transport.call("app/keyboard/ime", "deleteBackward", first))
        verifyNoInteractions(next)
    }
}
