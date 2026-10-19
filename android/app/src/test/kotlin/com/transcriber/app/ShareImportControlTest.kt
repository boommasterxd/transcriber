package com.transcriber.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.Closeable
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException

class ShareImportControlTest {
    @Test
    fun cancellationDispatchesCleanupAndUnlinksBeforeClosingResources() {
        val queued = ArrayDeque<Runnable>()
        val control = ShareImportControl(Executor { queued.add(it) })
        val file = File.createTempFile("share", ".wav")
        try {
            assertTrue(control.track(file))
            val closed = mutableListOf<Int>()
            control.register(Closeable {
                assertFalse(file.exists())
                closed.add(1)
                throw IllegalStateException("close fixture")
            })
            control.register(Closeable { closed.add(2) })
            control.cancel()
            control.cancel()
            assertTrue(control.cancelled)
            assertTrue(file.exists())
            assertTrue(closed.isEmpty())
            assertEquals(1, queued.size)
            queued.removeFirst().run()
            assertEquals(listOf(1, 2), closed)
        } finally {
            file.delete()
        }
    }

    @Test
    fun resourcesAcquiredAfterCancellationAreImmediatelyReleasedByWorker() {
        val control = ShareImportControl(Executor { it.run() })
        control.cancel()
        var closed = false
        assertFalse(control.register(Closeable { closed = true }))
        assertTrue(closed)
        val file = File.createTempFile("share", ".wav")
        assertFalse(control.track(file))
        assertFalse(file.exists())
    }

    @Test
    fun handoffTransfersFileAndClearsClosedResourceReferences() {
        val control = ShareImportControl(Executor { it.run() })
        val file = File.createTempFile("share", ".wav")
        var closed = false
        try {
            control.track(file)
            assertTrue(control.register(Closeable { closed = true }))
            control.handoff()
            control.cancel()
            assertTrue(file.exists())
            assertFalse(closed)
        } finally {
            file.delete()
        }
    }

    @Test
    fun busyCleanupWorkerDoesNotBlockCancellationState() {
        val control = ShareImportControl(Executor { throw RejectedExecutionException("busy") })
        val file = File.createTempFile("share", ".wav")
        control.track(file)
        control.cancel()
        assertTrue(control.cancelled)
        assertFalse(file.exists())
        assertFalse(control.register(Closeable { throw IllegalStateException("close fixture") }))
    }
}
