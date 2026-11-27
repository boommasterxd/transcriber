package com.transcriber.app

import java.io.Closeable
import java.io.File
import java.io.OutputStream
import java.nio.file.Files
import java.nio.file.StandardOpenOption
import java.util.concurrent.Executor
import java.util.concurrent.RejectedExecutionException

/** Owns import resources until the path is handed to Dart. */
internal class ShareImportControl(private val cleanupExecutor: Executor) {
    @Volatile
    var cancelled = false
        private set

    private val resources = mutableListOf<Closeable>()
    private var output: Output? = null
    private var stream: OutputStream? = null

    @Synchronized
    fun track(file: File, onDiscard: () -> Unit = {}): Boolean {
        val candidate = Output(file, onDiscard)
        if (cancelled) {
            candidate.delete()
            return false
        }
        output = candidate
        return true
    }

    @Synchronized
    fun openOutput(file: File, onDiscard: () -> Unit): OutputStream? {
        if (cancelled) return null
        val opened = Files.newOutputStream(file.toPath(), StandardOpenOption.CREATE_NEW, StandardOpenOption.WRITE)
        stream = opened
        track(file, onDiscard)
        return opened
    }

    fun discardLocalOutput() {
        val candidate = synchronized(this) {
            val file = output
            output = null
            stream = null
            file
        }
        candidate?.delete()
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
        stream = null
        resources.clear()
    }

    fun cancel() {
        val cleanup: () -> Unit
        val file: Output?
        val localStream: OutputStream?
        synchronized(this) {
            if (cancelled) return
            cancelled = true
            // Unlink before closing: a provider's close implementation may stall.
            file = output
            localStream = stream
            val owned = resources.toList()
            output = null
            stream = null
            resources.clear()
            cleanup = {
                file?.delete()
                localStream?.let(::closeQuietly)
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
            localStream?.let(::closeQuietly)
        }
    }

    private class Output(val file: File, private val onDiscard: () -> Unit) {
        fun delete() {
            onDiscard()
            if (file.canonicalFile == file.absoluteFile) file.delete()
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
