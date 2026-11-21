package com.transcriber.app

import java.io.Closeable
import java.io.File
import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException

/** Owns import resources until the path is handed to Dart. */
internal class ShareImportControl(private val cleanupExecutor: Executor) {
    @Volatile
    var cancelled = false
        private set

    private val resources = mutableListOf<Closeable>()
    private var output: File? = null

    @Synchronized
    fun track(file: File): Boolean {
        if (cancelled) {
            file.delete()
            return false
        }
        output = file
        return true
    }

    fun register(resource: Closeable): Boolean {
        synchronized(this) {
            if (!cancelled) {
                resources.add(resource)
                return true
            }
        }
        closeQuietly(resource)
        return false
    }

    @Synchronized
    fun handoff() {
        output = null
        resources.clear()
    }

    fun cancel() {
        val cleanup: () -> Unit
        val file: File?
        synchronized(this) {
            if (cancelled) return
            cancelled = true
            // Unlink before closing: a provider's close implementation may stall.
            file = output
            val owned = resources.toList()
            output = null
            resources.clear()
            cleanup = {
                file?.delete()
                owned.forEach(::closeQuietly)
            }
        }
        try {
            cleanupExecutor.execute(cleanup)
        } catch (_: RejectedExecutionException) {
            // The bounded cleanup worker is occupied by uncooperative providers.
            // A single local unlink still prevents an unclaimed ready-file leak.
            // Provider/stream callbacks remain off the main thread; active work
            // observes cancelled and releases its resources in finally.
            file?.delete()
        }
    }

    private fun closeQuietly(resource: Closeable) {
        try {
            resource.close()
        } catch (_: Exception) {
            // Cancellation is best effort; no provider data is logged.
        }
    }
}
