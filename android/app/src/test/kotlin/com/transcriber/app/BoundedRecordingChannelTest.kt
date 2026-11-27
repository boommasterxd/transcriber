package com.transcriber.app

import io.flutter.plugin.common.FlutterException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.mockConstruction
import org.mockito.Mockito.never
import org.mockito.Mockito.times
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.File
import java.io.IOException

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class BoundedRecordingChannelTest {
    private val context get() = RuntimeEnvironment.getApplication()
    private val transport = NativeChannelHarness()
    private lateinit var chunk: (ByteArray, Double) -> Unit
    private lateinit var failure: (String) -> Unit

    private fun call(method: String, arguments: Any? = null) = transport.call("app/recording", method, arguments)
    private fun progress() = call("progress") as Map<*, *>
    private fun destination() = File(context.cacheDir, "audio/recording/recording_1_$recordingId.wav").also {
        it.parentFile?.mkdirs()
    }
    private fun start(file: File = destination(), maxBytes: Long = 48) =
        call("start", mapOf("path" to file.path, "maxBytes" to maxBytes))

    private fun capture() = mockConstruction(PcmAudioRecorder::class.java) { recorder, construction ->
        @Suppress("UNCHECKED_CAST")
        chunk = construction.arguments()[1] as (ByteArray, Double) -> Unit
        @Suppress("UNCHECKED_CAST")
        failure = construction.arguments()[2] as (String) -> Unit
        `when`(recorder.start(16_000)).thenReturn(true)
        `when`(recorder.pause()).thenReturn(true)
        `when`(recorder.resume()).thenReturn(true)
    }

    @Test
    fun resumedCaptureEnforcesNativeCapWithoutPollingAndPreservesAudioUntilExplicitStop() {
        capture().use { captures ->
            val channel = BoundedRecordingChannel(context, transport).also { it.register() }
            val recorder = captures.constructed().single()
            val file = destination()
            assertTrue("app/recording" in transport.backgroundChannels)
            assertEquals(file.path, start(file))
            chunk(byteArrayOf(1, 2), 0.5)
            assertTrue(call("pause") as Boolean)
            assertEquals(46L, file.length())
            assertTrue(call("resume") as Boolean)
            chunk(byteArrayOf(3, 4, 5, 6), 0.7)
            assertEquals(48L, file.length())
            assertEquals(true, progress()["limited"])
            assertEquals(true, progress()["stopped"])
            chunk(byteArrayOf(7, 8), 1.0)
            assertEquals(48L, file.length())
            assertFalse(call("resume") as Boolean)
            verify(recorder).pause()
            verify(recorder).resume()
            verify(recorder).stop()
            assertEquals(file.path, call("stop"))
            assertEquals(file.path, call("stop"))
            assertTrue(file.exists())
            channel.dispose()
        }
    }

    @Test
    fun invalidPathsBudgetsAndDuplicateStartsFailBeforeCapture() {
        capture().use { captures ->
            val channel = BoundedRecordingChannel(context, transport).also { it.register() }
            val external = File(context.cacheDir, "outside.wav").apply { writeText("external audio") }
            assertThrows(FlutterException::class.java) { start(external) }
            assertEquals("external audio", external.readText())
            assertThrows(FlutterException::class.java) { start(maxBytes = 45) }
            verify(captures.constructed().single(), never()).start(16_000)
            start()
            assertThrows(FlutterException::class.java) { start() }
            channel.dispose()
        }
    }

    @Test
    fun deniedCaptureAndReadFailureReleaseHardwareAndPreserveCompletedAudio() {
        capture().use { captures ->
            val channel = BoundedRecordingChannel(context, transport).also { it.register() }
            val recorder = captures.constructed().single()
            `when`(recorder.start(16_000)).thenReturn(false)
            assertThrows(FlutterException::class.java) { start() }
            assertFalse(destination().exists())
            `when`(recorder.start(16_000)).thenReturn(true)
            start()
            chunk(byteArrayOf(1, 2), 0.1)
            failure("audio_read_failed")
            assertEquals(true, progress()["failed"])
            assertEquals(true, progress()["stopped"])
            assertEquals(destination().path, call("stop"))
            assertEquals(46L, destination().length())
            channel.dispose()
        }
    }

    @Test
    fun failedWaveFinalizationStopsCaptureAndAllowsRestartAfterCancel() {
        capture().use { captures ->
            mockConstruction(BoundedWaveWriter::class.java).use { writers ->
                val channel = BoundedRecordingChannel(context, transport).also { it.register() }
                val recorder = captures.constructed().single()
                val file = destination()
                try {
                    assertEquals(file.path, start(file))
                    val failedWriter = writers.constructed().single()
                    doAnswer { throw IOException("Synthetic WAV finalization failure") }
                        .`when`(failedWriter).finish()

                    val error = assertThrows(FlutterException::class.java) { call("stop") }
                    assertEquals("recording_failed", error.code)
                    assertEquals(true, progress()["failed"])
                    assertEquals(true, progress()["stopped"])
                    verify(recorder).stop()

                    call("cancel")
                    verify(failedWriter).close()
                    val retry = File(file.parentFile, "recording_2_$recordingId.wav")
                    assertEquals(retry.path, start(retry))
                    assertEquals(false, progress()["failed"])
                    assertEquals(retry.path, call("stop"))
                    verify(recorder, times(2)).start(16_000)
                } finally {
                    channel.dispose()
                }
            }
        }
    }

    @Test
    fun staleQueuedCallsCannotRestartCaptureAfterDisposal() {
        capture().use { captures ->
            val channel = BoundedRecordingChannel(context, transport).also { it.register() }
            val recorder = captures.constructed().single()
            start()
            assertTrue(call("pause") as Boolean)
            val staleResume = transport.captureCall("app/recording", "resume")
            val staleStart = transport.captureCall(
                "app/recording",
                "start",
                mapOf("path" to destination().path, "maxBytes" to 48),
            )
            channel.dispose()
            verify(recorder).stop()
            org.mockito.Mockito.clearInvocations(recorder)
            assertThrows(FlutterException::class.java) { staleResume() }
            assertThrows(FlutterException::class.java) { staleStart() }
            verify(recorder, never()).resume()
            verify(recorder, never()).start(16_000)
        }
    }

    private companion object {
        const val recordingId = "00000000-0000-0000-0000-000000000001"
    }
}
