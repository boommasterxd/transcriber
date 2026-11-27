package com.transcriber.app

import android.content.ContentResolver
import android.net.Uri
import android.os.CancellationSignal
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.eq
import org.mockito.Mockito.doReturn
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.verify
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.util.concurrent.Executor

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ShareAudioCacheTest {
    @get:Rule
    val temporary = TemporaryFolder()

    @Test
    fun sharedDirectorySymlinkCannotWriteOutsidePrivateCache() {
        val privateCache = temporary.newFolder("cache")
        val external = temporary.newFolder("external")
        Files.createSymbolicLink(File(privateCache, "shared").toPath(), external.toPath())
        val uri = Uri.parse("content://fixture/voice.wav")
        val resolver = mock(ContentResolver::class.java)
        doReturn("audio/wav").`when`(resolver).getType(uri)
        val cache = ShareAudioCache(privateCache, resolver) { throw AssertionError(it) }
        val control = ShareImportControl(Executor { it.run() })

        assertNull(cache.copy(uri, "audio/wav", control))
        verify(resolver, never()).openAssetFileDescriptor(eq(uri), eq("r"), any(CancellationSignal::class.java))
        assertTrue(external.listFiles()!!.isEmpty())
    }

    @Test
    fun anotherEngineCountsProtectedBytesAndCannotReclaimThemUntilTeardown() {
        val cache = temporary.newFolder("quota")
        val shared = File(cache, "shared").apply { mkdir() }
        val quota = AudioCacheQuota(maximumBytes = 100)
        val first = quota.owner(cache)
        val second = quota.owner(cache)
        val prefix = "00000000-0000-0000-0000-000000000001"
        val audio = File(shared, "1_${prefix}_audio.wav")
        val next = File(shared, "2_${prefix}_next.wav")

        val lease = first.reserve(audio, 70)
        audio.writeBytes(ByteArray(40))
        assertTrue(audio.setLastModified(1))
        assertThrows(IOException::class.java) { second.reserve(next, 60) }
        lease.finishWriting()
        second.reserve(next, 60)
        assertTrue(first.owns(audio.path))
        assertFalse(second.discard(audio.path))
        second.cleanup(enforceQuota = true)
        assertTrue(audio.exists())
        first.close()
        second.cleanup(enforceQuota = true)
        assertFalse(audio.exists())
    }
}
