package com.transcriber.app

import android.os.Looper
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class ImeEventPublisherTest {
    @Test
    fun streamDeliversStateAudioAndFailureAndRejectsStaleAudioAfterCancellation() {
        val transport = NativeChannelHarness()
        val editor = mock(ImeEditorContext::class.java)
        val recorder = mock(PcmAudioRecorder::class.java)
        `when`(editor.sessionId).thenReturn("active")
        `when`(editor.accepts("active")).thenReturn(true)
        `when`(editor.state(false)).thenReturn(mapOf("visible" to true))
        val publisher = ImeEventPublisher(transport, editor)
        publisher.register(recorder)
        transport.call("app/keyboard/audio", "listen")
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals("editor", (transport.events.single() as Map<*, *>)["type"])
        publisher.emitAudioChunk(byteArrayOf(1, 2), 0.5)
        publisher.emitAudioFailure("audio_read_failed")
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf("editor", "audio", "error"), transport.events.map { (it as Map<*, *>)["type"] })
        transport.call("app/keyboard/audio", "cancel")
        verify(recorder).stop()
        verify(editor).invalidate()
        `when`(editor.accepts("active")).thenReturn(false)
        publisher.emitAudioChunk(byteArrayOf(3), 0.1)
        publisher.emitEditorState(recorder)
        publisher.emitAudioFailure("late")
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(3, transport.events.size)
    }
}
