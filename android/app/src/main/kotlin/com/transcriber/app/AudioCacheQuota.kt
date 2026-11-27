package com.transcriber.app

import java.io.File
import java.io.IOException

/** Shared by every Flutter engine. Call all filesystem operations on worker threads. */
internal class AudioCacheQuota(private val maximumBytes: Long = defaultMaximumBytes) {
    private val leases = linkedMapOf<File, Lease>()

    fun owner(cacheDirectory: File) = Owner(cacheDirectory)

    inner class Owner(cacheDirectory: File) {
        internal val paths = AudioCachePaths(cacheDirectory)

        @Volatile internal var closed = false
            private set

        fun reserve(file: File, maximum: Long, minimum: Long = maximum): Lease =
            this@AudioCacheQuota.reserve(this, file, maximum, minimum)

        fun reserveRecording(file: File, maximum: Long): Lease =
            this@AudioCacheQuota.reserve(this, file, maximum, maximum, recordingOnly = true)

        fun owns(path: String): Boolean = this@AudioCacheQuota.owns(this, path)

        fun discard(path: String): Boolean = this@AudioCacheQuota.discard(this, path)

        fun cleanup(enforceQuota: Boolean) = this@AudioCacheQuota.cleanup(this, enforceQuota)

        fun close() {
            closed = true
        }
    }

    class Lease(val owner: Owner, val file: File, val maximum: Long) {
        @Volatile var pendingDiscard = false
            private set

        @Volatile var writing = true
            private set

        @Volatile var abandoned = false
            private set

        fun finishWriting() {
            writing = false
        }

        fun abandon() {
            abandoned = true
        }

        fun requestDiscard() {
            pendingDiscard = true
        }
    }

    @Synchronized
    private fun reserve(
        owner: Owner,
        file: File,
        maximum: Long,
        minimum: Long,
        recordingOnly: Boolean = false,
    ): Lease {
        require(minimum in 1L..maximum && maximum <= maximumImportBytes)
        val destination = availableDestination(owner, file, recordingOnly)
        val usage = scan(owner)
        if (destination in leases) throw IOException("Audio cache destination is already reserved")
        val available = maximumBytes - usage.reclaim(maximumBytes - minimum)
        if (available < minimum || owner.closed) throw IOException("Not enough space in the audio cache")
        return Lease(owner, destination, minOf(maximum, available)).also { leases[destination] = it }
    }

    private fun availableDestination(owner: Owner, file: File, recordingOnly: Boolean): File {
        val destination = owner.paths.managedFile(file, recordingOnly)
            ?: throw IOException("Invalid audio cache destination")
        if (owner.closed || destination.exists()) throw IOException("Audio cache destination is unavailable")
        return destination
    }

    @Synchronized
    private fun owns(owner: Owner, path: String): Boolean {
        val file = owner.paths.managedFile(File(path)) ?: return false
        val lease = leases[file]
        return lease != null && lease.owner === owner && !owner.closed &&
            !lease.abandoned && !lease.pendingDiscard && !lease.writing && file.isFile
    }

    @Synchronized
    private fun discard(owner: Owner, path: String): Boolean {
        val file = owner.paths.managedFile(File(path)) ?: return false
        val lease = leases[file]
        return when {
            lease == null -> !file.exists()
            lease.owner !== owner || lease.writing || owner.closed -> false
            else -> {
                lease.requestDiscard()
                AudioCachePaths.delete(file).also { deleted -> if (deleted) leases.remove(file) }
            }
        }
    }

    @Synchronized
    private fun cleanup(owner: Owner, enforceQuota: Boolean) {
        if (owner.closed) return
        val usage = scan(owner)
        if (enforceQuota) usage.reclaim(maximumBytes)
    }

    private fun scan(owner: Owner): Usage {
        retryPendingDiscards()
        leases.values.removeAll { !it.writing && !it.pendingDiscard && (it.abandoned || it.owner.closed) }
        // Snapshot reservations before stat calls. A writer finishing during the
        // scan can only make the snapshot more conservative.
        val remaining = leases.values.associate { it.file to if (it.writing) it.maximum else 0L }.toMutableMap()
        val eligible = mutableListOf<CacheEntry>()
        val expiredBefore = System.currentTimeMillis() - temporaryTtlMillis
        var used = 0L
        for (file in owner.paths.files()) {
            val reserved = remaining.remove(file)
            val size = file.length()
            if (reserved == null) {
                val modified = file.lastModified()
                if (modified < expiredBefore && AudioCachePaths.delete(file)) continue
                eligible.add(CacheEntry(file, size, modified))
            }
            used += maxOf(size, reserved ?: 0L)
        }
        used += remaining.values.sum()
        return Usage(used, eligible)
    }

    private fun retryPendingDiscards() {
        val pending = leases.values.asSequence()
            .filter { it.pendingDiscard && !it.writing }
            .take(maximumDiscardRetries)
            .toList()
        for (lease in pending) {
            leases.remove(lease.file)
            if (!tryDeletePending(lease)) leases[lease.file] = lease
        }
    }

    private fun tryDeletePending(lease: Lease): Boolean = try {
        lease.owner.paths.managedFile(lease.file) == lease.file && AudioCachePaths.delete(lease.file)
    } catch (_: IOException) {
        false
    } catch (_: SecurityException) {
        false
    }

    private class Usage(private var used: Long, private val eligible: List<CacheEntry>) {
        fun reclaim(target: Long): Long {
            if (used <= target) return used
            for (entry in eligible.sortedBy { it.modified }) {
                if (AudioCachePaths.delete(entry.file)) used -= entry.size
                if (used <= target) break
            }
            return used
        }
    }

    private data class CacheEntry(val file: File, val size: Long, val modified: Long)

    companion object {
        private const val defaultMaximumBytes = 512L * 1024 * 1024
        const val maximumImportBytes = 250L * 1024 * 1024
        private const val maximumDiscardRetries = 16
        private const val temporaryTtlMillis = 24L * 60 * 60 * 1000
        val shared = AudioCacheQuota()
    }
}
