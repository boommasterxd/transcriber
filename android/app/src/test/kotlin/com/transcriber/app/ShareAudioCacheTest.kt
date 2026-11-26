package com.transcriber.app

import android.content.ContentResolver
import android.net.Uri
import android.os.CancellationSignal
import org.junit.Assert.assertNull
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
}
