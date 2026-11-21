package com.transcriber.app

import android.os.Looper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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
        val capture = publisher.openCapture()
        assertTrue(capture.offer(byteArrayOf(1, 2), 0.5))
        capture.fail("audio_read_failed")
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf("editor", "audio", "error"), transport.events.map { (it as Map<*, *>)["type"] })
        transport.call("app/keyboard/audio", "cancel")
        verify(recorder).stop()
        verify(editor).invalidate()
        `when`(editor.accepts("active")).thenReturn(false)
        assertFalse(capture.offer(byteArrayOf(3), 0.1))
        publisher.emitEditorState(recorder)
        capture.fail("late")
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(3, transport.events.size)
    }

    @Test
    fun stalledDeliveryStopsTheCaptureAndTheNextCaptureCanSendAudio() {
        val transport = NativeChannelHarness()
        val editor = mock(ImeEditorContext::class.java)
        val recorder = mock(PcmAudioRecorder::class.java)
        `when`(editor.sessionId).thenReturn("active")
        `when`(editor.accepts("active")).thenReturn(true)
        val publisher = ImeEventPublisher(transport, editor)
        publisher.register(recorder)
        transport.call("app/keyboard/audio", "listen")
        val stalled = publisher.openCapture()

        repeat(12) {
            assertTrue(stalled.offer(ByteArray(4_800), 0.25))
        }
        assertFalse(stalled.offer(byteArrayOf(2), 0.25))
        assertFalse(stalled.offer(byteArrayOf(3), 0.25))
        stalled.fail("late")
        val mainLooper = shadowOf(Looper.getMainLooper())
        mainLooper.idle()

        assertEquals(
            mapOf("type" to "error", "sessionId" to "active", "code" to "audio_buffer_overflow"),
            transport.events[1],
        )
        assertEquals(2, transport.events.size)

        stalled.cancel()
        val resumed = publisher.openCapture()
        assertFalse(stalled.offer(byteArrayOf(4), 0.25))
        stalled.fail("late")
        assertTrue(resumed.offer(byteArrayOf(5), 0.25))
        mainLooper.idle()

        val audio = transport.events.last() as Map<*, *>
        assertEquals(3, transport.events.size)
        assertEquals("audio", audio["type"])
        assertEquals(listOf<Byte>(5), (audio["pcm"] as ByteArray).toList())
    }

    @Test
    fun queuedAudioAndFailuresRetainTheEndingEditorSession() {
        val transport = NativeChannelHarness()
        val editor = mock(ImeEditorContext::class.java)
        val recorder = mock(PcmAudioRecorder::class.java)
        `when`(editor.sessionId).thenReturn("previous")
        val publisher = ImeEventPublisher(transport, editor)
        publisher.register(recorder)
        transport.call("app/keyboard/audio", "listen")
        val previous = publisher.openCapture()
        assertTrue(previous.offer(byteArrayOf(1), 0.25))
        previous.fail("audio_read_failed")

        `when`(editor.sessionId).thenReturn("next")
        `when`(editor.accepts("next")).thenReturn(true)
        val mainLooper = shadowOf(Looper.getMainLooper())
        mainLooper.idle()
        assertEquals(1, transport.events.size)

        val next = publisher.openCapture()
        assertTrue(next.offer(byteArrayOf(2), 0.25))
        mainLooper.idle()
        assertEquals("next", (transport.events.last() as Map<*, *>)["sessionId"])
    }
}
