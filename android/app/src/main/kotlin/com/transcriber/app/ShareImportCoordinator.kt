package com.transcriber.app

import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException

/** Main-thread state machine: an early channel call waits for the worker result. */
internal class ShareImportCoordinator(
    private val worker: Executor,
    private val dispatch: (() -> Unit) -> Unit,
    private val scheduleDeadline: (() -> Unit) -> (() -> Unit),
    private val control: ShareImportControl,
) {
    private var complete = false
    private var path: String? = null
    private var pending: ((String?) -> Unit)? = null
    private var cancelDeadline: (() -> Unit)? = null

    fun start(importAudio: () -> String?) {
        check(cancelDeadline == null && !complete)
        cancelDeadline = scheduleDeadline(::cancel)
        try {
            worker.execute {
                val imported = try {
                    importAudio()
                } catch (_: Exception) {
                    null
                }
                dispatch { finish(imported) }
            }
        } catch (_: RejectedExecutionException) {
            cancel()
        }
    }

    /** Reject duplicate pending calls instead of retaining unbounded callbacks. */
    fun awaitPath(reply: (String?) -> Unit): Boolean {
        if (pending != null) return false
        if (complete) deliver(reply) else pending = reply
        return true
    }

    fun cancel() {
        path = null
        control.cancel()
        finish(null)
    }

    private fun finish(imported: String?) {
        if (complete) return
        complete = true
        path = imported
        cancelDeadline?.invoke()
        cancelDeadline = null
        if (imported == null) control.cancel()
        pending?.let {
            pending = null
            deliver(it)
        }
    }

    private fun deliver(reply: (String?) -> Unit) {
        if (path != null) control.handoff()
        reply(path)
    }
}
