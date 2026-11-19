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
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class ImeEditorContextTest {
    @Test
    fun sessionRequiresVisibleSupportedCurrentEditor() {
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
        verify(connection, never()).finishComposingText()
        assertFalse(editor.accepts(session))
        assertEquals(false, editor.state(false)["visible"])
        `when`(service.currentInputConnection).thenReturn(null)
        editor.invalidate()
    }

    @Test
    fun invalidationClearsOnlyTrackedCompositionOnOriginalConnection() {
        val service = mock(TranscriberInputMethodService::class.java)
        val original = mock(InputConnection::class.java)
        val next = mock(InputConnection::class.java)
        val editor = ImeEditorContext(service)
        `when`(original.setComposingText("speech", 1)).thenReturn(true)
        `when`(original.setComposingText("", 1)).thenReturn(true)
        assertTrue(editor.setComposition(original, "speech"))
        editor.updateSelection(13, 13, 7, 13)
        `when`(service.currentInputConnection).thenReturn(next)
        editor.invalidate()
        verify(original).setComposingText("", 1)
        verify(original).finishComposingText()
        verify(next, never()).setComposingText("", 1)
    }

    @Test
    fun missingOrChangedSpanAndCommittedTextAreNeverCleared() {
        val service = mock(TranscriberInputMethodService::class.java)
        val connection = mock(InputConnection::class.java)
        val editor = ImeEditorContext(service)
        `when`(connection.setComposingText("speech", 1)).thenReturn(true)
        `when`(connection.commitText("complete", 1)).thenReturn(true)
        assertTrue(editor.setComposition(connection, "speech"))
        editor.updateSelection(0, 5, -1, -1)
        editor.start(null)
        assertTrue(editor.setComposition(connection, "speech"))
        assertTrue(editor.commitComposition(connection, "complete"))
        editor.invalidate()
        verify(connection, never()).setComposingText("", 1)
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
