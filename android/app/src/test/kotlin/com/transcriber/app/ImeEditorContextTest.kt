package com.transcriber.app

import android.view.inputmethod.InputConnection
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
}
