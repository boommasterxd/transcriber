package com.transcriber.app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.mock
import org.mockito.Mockito.mockConstruction
import org.mockito.Mockito.mockStatic
import org.mockito.Mockito.verify
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class PcmAudioRecorderTest {
    private val context = mock(Context::class.java)

    private fun allowMicrophone() {
        `when`(context.checkSelfPermission(Manifest.permission.RECORD_AUDIO))
            .thenReturn(PackageManager.PERMISSION_GRANTED)
    }

    private fun audioMinimum(minimum: Int): org.mockito.MockedStatic<AudioRecord> =
        mockStatic(AudioRecord::class.java).also { audio ->
            audio.`when`<Int> {
                AudioRecord.getMinBufferSize(16_000, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
            }.thenReturn(minimum)
        }

    @Test
    fun deniedPermissionPreventsOpeningMicrophone() {
        `when`(context.checkSelfPermission(Manifest.permission.RECORD_AUDIO))
            .thenReturn(PackageManager.PERMISSION_DENIED)
        val recorder = PcmAudioRecorder(context, { _, _ -> error("No audio expected") }, { error(it) })
        audioMinimum(320).use {
            mockConstruction(AudioRecord::class.java).use { records ->
                assertFalse(recorder.start(16_000))
                assertTrue(records.constructed().isEmpty())
            }
        }
    }

    @Test
    fun successfulCaptureDeliversBoundedChunksReportsReadFailureAndReleasesHardware() {
        allowMicrophone()
        val released = CountDownLatch(1)
        val chunks = mutableListOf<ByteArray>()
        val failures = mutableListOf<String>()
        audioMinimum(320).use {
            mockConstruction(AudioRecord::class.java) { record, _ ->
                `when`(record.state).thenReturn(AudioRecord.STATE_INITIALIZED)
                `when`(record.read(any(ByteArray::class.java), anyInt(), anyInt(), anyInt()))
                    .thenAnswer { invocation ->
                        val buffer = invocation.getArgument<ByteArray>(0)
                        buffer[0] = 1
                        2
                    }.thenReturn(-1)
                doAnswer {
                    released.countDown()
                    null
                }.`when`(record).release()
            }.use { records ->
                val recorder = PcmAudioRecorder(context, { bytes, _ -> chunks.add(bytes) }, failures::add)
                assertTrue(recorder.start(16_000))
                assertTrue(released.await(5, TimeUnit.SECONDS))
                assertEquals(listOf("audio_read_failed"), failures)
                assertEquals(1, chunks.size)
                assertEquals(listOf<Byte>(1, 0), chunks.single().toList())
                assertFalse(recorder.pause())
                recorder.stop()
                verify(records.constructed().single()).startRecording()
            }
        }
    }
}
