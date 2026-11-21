package com.transcriber.app

import android.content.ContentResolver
import android.content.res.AssetFileDescriptor
import android.database.MatrixCursor
import android.net.Uri
import android.os.CancellationSignal
import android.os.OperationCanceledException
import android.provider.OpenableColumns
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.mockito.ArgumentMatchers.any
import org.mockito.ArgumentMatchers.eq
import org.mockito.Mockito.doAnswer
import org.mockito.Mockito.doReturn
import org.mockito.Mockito.doThrow
import org.mockito.Mockito.mock
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.ByteArrayInputStream
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.util.concurrent.Executor

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class ShareAudioCacheTest {
    @get:Rule
    val temporary = TemporaryFolder()

    @Test
    fun contentImportUsesSafeProviderNameAndOwnedCachePath() {
        val fixture = fixture("../../nested\\voice.mp3", "audio/mpeg")
        val bytes = byteArrayOf(1, 2, 3, 4)
        fixture.input(ByteArrayInputStream(bytes))
        val result = fixture.copy()
        assertTrue(File(result!!).canonicalPath.startsWith(File(temporary.root, "shared").path))
        assertTrue(result.endsWith("_voice.mp3"))
        assertArrayEquals(bytes, File(result).readBytes())
        assertTrue(fixture.failures.isEmpty())
        assertTrue(fixture.cursor.isClosed)
    }

    @Test
    fun missingExtensionUsesNormalizedProviderOrIntentMime() {
        for (mime in listOf(" AUDIO/MP4; codecs=aac ", null)) {
            val fixture = fixture("voice", mime)
            fixture.input(ByteArrayInputStream(byteArrayOf(1)))
            val result = fixture.copy("audio/mp4")
            assertTrue(result!!.endsWith("_voice.mp4"))
        }
    }

    @Test
    fun unsupportedExtensionOrMimeCannotCreateCachedFile() {
        for (name in listOf("voice.exe", "voice")) {
            val fixture = fixture(name, "text/plain")
            assertNull(fixture.copy(null))
            assertTrue(fixture.files().isEmpty())
        }
    }

    @Test
    fun emptyProviderNameFallsBackToUriLeafAndFileUrisSkipQuery() {
        for (uri in listOf(Uri.parse("content://fixture/voice.wav"), Uri.parse("file:///voice.wav"))) {
            val fixture = fixture("", null, uri)
            fixture.input(ByteArrayInputStream(byteArrayOf(1)))
            assertTrue(fixture.copy()!!.endsWith("_voice.wav"))
        }
    }

    @Test
    fun absentDisplayNameColumnFallsBackToUriLeaf() {
        val fixture = fixture(null, "audio/wav")
        fixture.input(ByteArrayInputStream(byteArrayOf(1)))
        assertTrue(fixture.copy()!!.endsWith("_voice.wav"))
    }

    @Test
    fun rejectedOrMissingStreamLeavesNoPartialAudio() {
        for (failure in listOf(false, true)) {
            val fixture = fixture("voice.wav", "audio/wav")
            if (failure) {
                doThrow(SecurityException("fixture")).`when`(fixture.resolver)
                    .openAssetFileDescriptor(eq(fixture.uri), eq("r"), any(CancellationSignal::class.java))
            }
            assertNull(fixture.copy())
            assertTrue(fixture.files().isEmpty())
            assertEquals(if (failure) 1 else 0, fixture.failures.size)
        }
    }

    @Test
    fun rejectedMetadataAndCancelledProviderCannotLeaveCachedFiles() {
        val errors = listOf(
            SecurityException("fixture"),
            IllegalArgumentException("fixture"),
            OperationCanceledException()
        )
        for (error in errors) {
            val fixture = fixture("voice.wav", "audio/wav")
            doThrow(error).`when`(fixture.resolver).getType(fixture.uri)
            assertNull(fixture.copy())
            assertTrue(fixture.files().isEmpty())
            assertEquals(listOf(error), fixture.failures)
        }
    }

    @Test
    fun emptyOrInvalidReadAndOverLimitReadRemovePartialFiles() {
        for (read in listOf(-1, 0, 250 * 1024 * 1024 + 1)) {
            val fixture = fixture("voice.wav", "audio/wav")
            val input = mock(InputStream::class.java)
            doReturn(read).`when`(input).read(any(ByteArray::class.java))
            fixture.input(input)
            assertNull(fixture.copy())
            assertTrue(fixture.files().isEmpty())
        }
    }

    @Test
    fun cancellationDuringReadStopsBeforeWritingAndRemovesPartialFile() {
        val fixture = fixture("voice.wav", "audio/wav")
        val input = mock(InputStream::class.java)
        doAnswer {
            fixture.control.cancel()
            1
        }.`when`(input).read(any(ByteArray::class.java))
        fixture.input(input)
        assertNull(fixture.copy())
        assertTrue(fixture.files().isEmpty())
    }

    @Test
    fun cancellationBeforeImportDoesNotAcquireProviderResources() {
        val fixture = fixture("voice.wav", "audio/wav")
        fixture.control.cancel()
        assertNull(fixture.copy())
        assertFalse(File(temporary.root, "shared").exists())
    }

    @Test
    fun cancellationWhileOpeningClosesLateDescriptorAndRemovesPartialFile() {
        val fixture = fixture("voice.wav", "audio/wav")
        val descriptor = mock(AssetFileDescriptor::class.java)
        doAnswer {
            fixture.control.cancel()
            descriptor
        }.`when`(fixture.resolver)
            .openAssetFileDescriptor(eq(fixture.uri), eq("r"), any(CancellationSignal::class.java))
        assertNull(fixture.copy())
        assertTrue(fixture.files().isEmpty())
    }

    @Test
    fun failedDirectoryAndEscapingSymlinkCannotWriteOutsideCache() {
        val fixture = fixture("voice.wav", "audio/wav")
        File(temporary.root, "shared").writeText("occupied")
        assertNull(fixture.copy())
        assertEquals("occupied", File(temporary.root, "shared").readText())
        File(temporary.root, "shared").delete()
        val external = java.nio.file.Files.createTempDirectory("external-share-").toFile()
        try {
            java.nio.file.Files.createSymbolicLink(File(temporary.root, "shared").toPath(), external.toPath())
            assertNull(fixture.copy())
            assertTrue(external.listFiles()!!.isEmpty())
        } finally {
            external.delete()
        }
    }

    private fun fixture(
        name: String?,
        mime: String?,
        uri: Uri = Uri.parse("content://fixture/voice.wav"),
    ): Fixture {
        val cursor = MatrixCursor(if (name == null) arrayOf("other") else arrayOf(OpenableColumns.DISPLAY_NAME))
        cursor.addRow(arrayOf(name))
        val resolver = mock(ContentResolver::class.java)
        doReturn(mime).`when`(resolver).getType(uri)
        doReturn(cursor).`when`(resolver).query(eq(uri), any(), eq(null), eq(null), eq(null), any())
        return Fixture(resolver, uri, cursor)
    }

    private inner class Fixture(
        val resolver: ContentResolver,
        val uri: Uri,
        val cursor: MatrixCursor,
    ) {
        val control = ShareImportControl(Executor { it.run() })
        val failures = mutableListOf<Throwable>()

        fun input(input: InputStream) {
            val descriptor = mock(AssetFileDescriptor::class.java)
            val fileInput = mock(FileInputStream::class.java)
            doAnswer { input.read(it.getArgument<ByteArray>(0)) }.`when`(fileInput).read(any(ByteArray::class.java))
            doAnswer { input.close() }.`when`(fileInput).close()
            doReturn(fileInput).`when`(descriptor).createInputStream()
            doReturn(descriptor).`when`(resolver)
                .openAssetFileDescriptor(eq(uri), eq("r"), any(CancellationSignal::class.java))
        }

        fun copy(mime: String? = "audio/wav"): String? {
            return ShareAudioCache(temporary.root, resolver, failures::add).copy(uri, mime, control)
        }

        fun files(): List<File> = File(temporary.root, "shared").listFiles()?.toList().orEmpty()
    }
}
