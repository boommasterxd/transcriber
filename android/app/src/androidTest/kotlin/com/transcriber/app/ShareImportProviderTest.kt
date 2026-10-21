package com.transcriber.app

import android.content.ContentProvider
import android.content.ContentResolver
import android.content.ContentValues
import android.content.pm.ProviderInfo
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Build
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import java.io.File
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Real Android resolver/descriptor contracts, independent of real user audio. */
@RunWith(AndroidJUnit4::class)
class ShareImportProviderTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext

    @get:Rule
    val temporary = TemporaryFolder(context.cacheDir)

    @Before
    fun requireWrappedResolverApi() {
        assumeTrue(Build.VERSION.SDK_INT >= 29)
    }

    @Test
    fun delayedProviderDoesNotBlockMainThreadAndCancellationCompletesReadiness() {
        val provider = provider().apply { delayQuery = true }
        withImport(provider) { fixture ->
            await(provider.queryEntered)
            instrumentation.runOnMainSync {
                assertFalse(fixture.replied)
                fixture.coordinator.cancel()
            }
            await(fixture.replyReady)
            await(provider.cancelled)
            await(fixture.workerFinished)
            assertNull(fixture.path)
            assertTrue(fixture.files().isEmpty())
            assertTrue(provider.offMainThread)
        }
    }

    @Test
    fun deadlineClosesStalledDescriptorAndRemovesUnclaimedCacheFile() {
        val provider = provider().apply { pipeInput = true }
        withImport(provider) { fixture ->
            await(provider.openEntered)
            assertEquals(1, fixture.files().size)
            instrumentation.runOnMainSync { fixture.expire() }
            await(fixture.replyReady)
            await(provider.cancelled)
            await(fixture.workerFinished)
            assertNull(fixture.path)
            assertTrue(fixture.files().isEmpty())
            assertTrue(provider.offMainThread)
        }
    }

    @Test
    fun successfulWorkerImportHandsOffOwnedFileAndPreservesSource() {
        val provider = provider()
        withImport(provider) { fixture ->
            await(fixture.replyReady)
            val imported = File(fixture.path!!)
            assertArrayEquals(provider.source.readBytes(), imported.readBytes())
            instrumentation.runOnMainSync { fixture.coordinator.cancel() }
            assertTrue(imported.exists())
            assertTrue(provider.source.exists())
            assertTrue(provider.offMainThread)
        }
    }

    private fun provider(): FixtureProvider {
        val source = temporary.newFile("source.wav").apply { writeBytes(byteArrayOf(1, 2, 3, 4)) }
        return FixtureProvider(source).also {
            it.attachInfo(
                context,
                ProviderInfo().apply {
                    authority = "com.transcriber.test.share"
                    applicationInfo = context.applicationInfo
                    exported = false
                }
            )
        }
    }

    private fun withImport(provider: FixtureProvider, verify: (Fixture) -> Unit) {
        val fixture = Fixture(provider)
        try {
            instrumentation.runOnMainSync { fixture.start() }
            verify(fixture)
        } finally {
            instrumentation.runOnMainSync { fixture.coordinator.cancel() }
            provider.releaseQuery.countDown()
            provider.pipeWriter?.close()
            fixture.worker.shutdownNow()
            fixture.cleanup.shutdownNow()
            assertTrue(fixture.worker.awaitTermination(5, TimeUnit.SECONDS))
            assertTrue(fixture.cleanup.awaitTermination(5, TimeUnit.SECONDS))
        }
    }

    private fun await(latch: CountDownLatch) {
        assertTrue("Android import fixture timed out", latch.await(5, TimeUnit.SECONDS))
    }

    private inner class Fixture(private val provider: FixtureProvider) {
        val worker = Executors.newSingleThreadExecutor()
        val cleanup = Executors.newSingleThreadExecutor()
        val replyReady = CountDownLatch(1)
        val workerFinished = CountDownLatch(1)
        var replied = false
        var path: String? = null
        var expire: () -> Unit = {}
        private val root = temporary.newFolder("cache")
        private val control = ShareImportControl(cleanup)
        lateinit var coordinator: ShareImportCoordinator

        fun start() {
            val handler = Handler(Looper.getMainLooper())
            coordinator = ShareImportCoordinator(worker, { handler.post(it) }, {
                expire = it
                val remove: () -> Unit = {}
                remove
            }, control)
            coordinator.start {
                try {
                    ShareAudioCache(root, ContentResolver.wrap(provider)) {}.copy(
                        Uri.parse("content://com.transcriber.test.share/source.wav"),
                        "audio/wav",
                        control,
                    )
                } finally {
                    workerFinished.countDown()
                }
            }
            coordinator.awaitPath {
                assertEquals(Looper.getMainLooper(), Looper.myLooper())
                replied = true
                path = it
                replyReady.countDown()
            }
        }

        fun files(): List<File> = File(root, "shared").listFiles()?.toList().orEmpty()
    }

    private class FixtureProvider(val source: File) : ContentProvider() {
        val queryEntered = CountDownLatch(1)
        val releaseQuery = CountDownLatch(1)
        val openEntered = CountDownLatch(1)
        val cancelled = CountDownLatch(1)
        var delayQuery = false
        var pipeInput = false
        var offMainThread = true
        var pipeWriter: ParcelFileDescriptor? = null

        override fun onCreate(): Boolean = true
        override fun getType(uri: Uri): String {
            offMainThread = offMainThread && Looper.myLooper() != Looper.getMainLooper()
            return "audio/wav"
        }

        override fun query(
            uri: Uri,
            projection: Array<out String>?,
            selection: String?,
            selectionArgs: Array<out String>?,
            sortOrder: String?,
            cancellationSignal: CancellationSignal?,
        ): Cursor {
            offMainThread = offMainThread && Looper.myLooper() != Looper.getMainLooper()
            queryEntered.countDown()
            if (delayQuery) {
                cancellationSignal!!.setOnCancelListener {
                    cancelled.countDown()
                    releaseQuery.countDown()
                }
                assertTrue(releaseQuery.await(5, TimeUnit.SECONDS))
                cancellationSignal.throwIfCanceled()
            }
            return MatrixCursor(arrayOf(OpenableColumns.DISPLAY_NAME)).apply { addRow(arrayOf("source.wav")) }
        }

        override fun query(
            uri: Uri,
            projection: Array<out String>?,
            selection: String?,
            selectionArgs: Array<out String>?,
            sortOrder: String?,
        ): Cursor = query(uri, projection, selection, selectionArgs, sortOrder, null)

        override fun openAssetFile(uri: Uri, mode: String, signal: CancellationSignal?): AssetFileDescriptor {
            offMainThread = offMainThread && Looper.myLooper() != Looper.getMainLooper()
            val descriptor = if (pipeInput) {
                val pipe = ParcelFileDescriptor.createPipe()
                pipeWriter = pipe[1]
                signal!!.setOnCancelListener {
                    pipe[1].close()
                    cancelled.countDown()
                }
                pipe[0]
            } else {
                ParcelFileDescriptor.open(source, ParcelFileDescriptor.MODE_READ_ONLY)
            }
            openEntered.countDown()
            return AssetFileDescriptor(descriptor, 0, AssetFileDescriptor.UNKNOWN_LENGTH)
        }

        override fun insert(uri: Uri, values: ContentValues?): Uri? = null
        override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
        override fun update(
            uri: Uri,
            values: ContentValues?,
            selection: String?,
            selectionArgs: Array<out String>?
        ): Int = 0
    }
}
