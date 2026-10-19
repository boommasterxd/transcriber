package com.transcriber.app

import android.text.InputType
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class ImeEditorContextTest {
    @Test
    fun sessionRequiresVisibleSupportedCurrentEditorAndInvalidationFinishesComposition() {
        val service = mock(TranscriberInputMethodService::class.java)
        val connection = mock(InputConnection::class.java)
        val info = EditorInfo().apply { inputType = InputType.TYPE_CLASS_TEXT }
        `when`(service.currentInputEditorInfo).thenReturn(info)
        `when`(service.currentInputConnection).thenReturn(connection)
        val editor = ImeEditorContext(service)
        assertFalse(editor.accepts(editor.sessionId))
        editor.start(info)
        editor.setVisible(true)
        val session = editor.sessionId
        assertTrue(editor.accepts(session))
        assertFalse(editor.accepts("stale"))
        assertEquals(true, editor.state(true)["microphoneGranted"])
        assertEquals(true, editor.state(false)["supported"])
        info.inputType = InputType.TYPE_CLASS_NUMBER
        assertFalse(editor.accepts(session))
        assertEquals(false, editor.state(false)["supported"])
        editor.invalidate()
        verify(connection).finishComposingText()
        assertFalse(editor.accepts(session))
        assertEquals(false, editor.state(false)["visible"])
        `when`(service.currentInputConnection).thenReturn(null)
        editor.invalidate()
    }

    @Test
    fun editorPolicyRejectsMissingAndSensitiveEditorMetadata() {
        assertFalse(EditorFieldPolicy.isSupported(null))
        val info = EditorInfo().apply { inputType = InputType.TYPE_CLASS_TEXT }
        assertTrue(EditorFieldPolicy.isSupported(info))
        info.imeOptions = EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING
        assertFalse(EditorFieldPolicy.isSupported(info))
    }
}
