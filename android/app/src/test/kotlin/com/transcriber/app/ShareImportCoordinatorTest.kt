package com.transcriber.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException

class ShareImportCoordinatorTest {
    @Test
    fun earlyChannelRequestWaitsForWorkerAndMainThreadDispatch() {
        val fixture = Fixture()
        val replies = mutableListOf<String?>()
        fixture.coordinator.start { "audio.mp3" }
        assertTrue(fixture.coordinator.awaitPath(replies::add))
        assertFalse(fixture.coordinator.awaitPath(replies::add))
        assertTrue(replies.isEmpty())
        fixture.worker.removeFirst().run()
        assertTrue(replies.isEmpty())
        fixture.main.removeFirst().invoke()
        assertEquals(listOf("audio.mp3"), replies)
        assertTrue(fixture.deadlineRemoved)
        assertTrue(fixture.coordinator.awaitPath(replies::add))
        assertEquals(listOf("audio.mp3", "audio.mp3"), replies)
    }

    @Test
    fun resultCompletedBeforeChannelRequestIsRetained() {
        val fixture = Fixture()
        fixture.coordinator.start { "ready.wav" }
        fixture.finishWorker()
        var result: String? = null
        fixture.coordinator.awaitPath { result = it }
        assertEquals("ready.wav", result)
    }

    @Test
    fun exceptionOrUnsupportedInputCompletesWithNull() {
        for (fail in listOf(false, true)) {
            val fixture = Fixture()
            val replies = mutableListOf<String?>()
            fixture.coordinator.start {
                if (fail) throw IllegalArgumentException("invalid fixture")
                null
            }
            fixture.coordinator.awaitPath(replies::add)
            fixture.finishWorker()
            assertEquals(listOf<String?>(null), replies)
            assertTrue(fixture.control.cancelled)
        }
    }

    @Test
    fun deadlineCompletesPendingReplyAndIgnoresLateWorkerSuccess() {
        val fixture = Fixture()
        val replies = mutableListOf<String?>()
        fixture.coordinator.start { "late.wav" }
        fixture.coordinator.awaitPath(replies::add)
        fixture.expire.invoke()
        assertTrue(fixture.control.cancelled)
        assertEquals(listOf<String?>(null), replies)
        fixture.finishWorker()
        assertEquals(listOf<String?>(null), replies)
        fixture.coordinator.awaitPath(replies::add)
        assertEquals(listOf<String?>(null, null), replies)
    }

    @Test
    fun lifecycleCancellationRemovesUnclaimedResultButPreservesHandedOffFile() {
        for (handoff in listOf(false, true)) {
            val fixture = Fixture()
            val file = File.createTempFile("share", ".wav")
            try {
                fixture.coordinator.start {
                    fixture.control.track(file)
                    file.path
                }
                fixture.finishWorker()
                if (handoff) fixture.coordinator.awaitPath { assertEquals(file.path, it) }
                fixture.coordinator.cancel()
                fixture.coordinator.cancel()
                assertEquals(handoff, file.exists())
                fixture.coordinator.awaitPath { assertNull(it) }
            } finally {
                file.delete()
            }
        }
    }

    @Test
    fun saturatedWorkerRejectsImmediatelyWithoutLeavingPendingReply() {
        val control = ShareImportControl(Executor { it.run() })
        var deadlineRemoved = false
        val coordinator = ShareImportCoordinator(
            Executor { throw RejectedExecutionException("busy") },
            { it() },
            { { deadlineRemoved = true } },
            control,
        )
        coordinator.start { error("must not run") }
        coordinator.awaitPath { assertNull(it) }
        assertTrue(control.cancelled)
        assertTrue(deadlineRemoved)
    }

    @Test(expected = IllegalStateException::class)
    fun secondStartCannotQueueAnotherImport() {
        val fixture = Fixture()
        fixture.coordinator.start { null }
        fixture.coordinator.start { null }
    }

    private class Fixture {
        val worker = ArrayDeque<Runnable>()
        val main = ArrayDeque<() -> Unit>()
        val control = ShareImportControl(Executor { it.run() })
        var expire: () -> Unit = {}
        var deadlineRemoved = false
        val coordinator = ShareImportCoordinator(
            Executor { worker.add(it) },
            { main.add(it) },
            {
                expire = it
                val remove: () -> Unit = { deadlineRemoved = true }
                remove
            },
            control,
        )

        fun finishWorker() {
            worker.removeFirst().run()
            main.removeFirst().invoke()
        }
    }
}
