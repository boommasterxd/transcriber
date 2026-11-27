package com.transcriber.app

import android.content.ContentResolver
import android.content.res.AssetFileDescriptor
import android.net.Uri
import android.os.CancellationSignal
import android.os.OperationCanceledException
import android.provider.OpenableColumns
import java.io.Closeable
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.Locale
import java.util.UUID

/** Worker-only import of one external audio URI into app-private storage. */
internal class ShareAudioCache(
    cacheDirectory: File,
    private val contentResolver: ContentResolver,
    private val owner: AudioCacheQuota.Owner = AudioCacheQuota.shared.owner(cacheDirectory),
    private val onFailure: (Throwable) -> Unit,
) {
    private val paths = AudioCachePaths(cacheDirectory)

    fun copy(uri: Uri, intentMimeType: String?, control: ShareImportControl): String? {
        var result: String? = null
        try {
            val signal = CancellationSignal()
            val candidate = if (control.register(Closeable { signal.cancel() })) {
                prepareOutput(uri, intentMimeType, signal, control)
            } else {
                null
            }
            if (candidate != null) result = copyStream(uri, candidate, signal, control)
        } catch (error: IOException) {
            onFailure(error)
        } catch (error: SecurityException) {
            onFailure(error)
        } catch (error: IllegalArgumentException) {
            onFailure(error)
        } catch (error: OperationCanceledException) {
            onFailure(error)
        } finally {
            if (result == null || control.cancelled) control.discardLocalOutput()
        }
        return result.takeUnless { control.cancelled }
    }

    private fun prepareOutput(
        uri: Uri,
        intentMimeType: String?,
        signal: CancellationSignal,
        control: ShareImportControl,
    ): File? {
        val directory = paths.sharedDirectory() ?: return null
        val mimeType = contentResolver.getType(uri) ?: intentMimeType
        val name = canonicalAudioName(
            ShareFileNamePolicy.sanitize(displayName(uri, signal)),
            mimeType,
        )
        return name?.takeUnless { control.cancelled }?.let { destination(directory, it) }
    }

    private fun copyStream(
        uri: Uri,
        outputFile: File,
        signal: CancellationSignal,
        control: ShareImportControl,
    ): String? {
        val descriptor = contentResolver.openAssetFileDescriptor(uri, "r", signal) ?: return null
        return descriptor.use {
            if (control.register(it)) copyToCache(it, outputFile, control) else null
        }
    }

    private fun copyToCache(descriptor: AssetFileDescriptor, output: File, control: ShareImportControl): String? {
        val declared = descriptor.declaredLength
        if (control.cancelled || declared == 0L || declared > AudioCacheQuota.maximumImportBytes) return null
        val lease = if (declared > 0) {
            owner.reserve(output, declared)
        } else {
            owner.reserve(output, AudioCacheQuota.maximumImportBytes, unknownImportMinimumBytes)
        }
        try {
            val copied = copyInput(descriptor.createInputStream(), lease, control)
            return lease.file.path.takeIf { copied && !control.cancelled }
        } finally {
            if (!lease.file.exists()) lease.abandon()
            lease.finishWriting()
        }
    }

    private fun copyInput(input: InputStream, lease: AudioCacheQuota.Lease, control: ShareImportControl): Boolean =
        input.use {
            if (!control.register(input)) return@use false
            control.openOutput(lease.file, lease::requestDiscard)?.use {
                copyWithinLimit(input, it, control, lease.maximum)
            } ?: false
        }

    private fun copyWithinLimit(
        input: InputStream,
        output: OutputStream,
        control: ShareImportControl,
        maximumBytes: Long,
    ): Boolean {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0L
        var count = if (control.cancelled) -1 else input.read(buffer)
        while (count >= 0 && total <= maximumBytes && !control.cancelled) {
            if (count == 0) throw IOException("Empty provider read")
            total += count
            val canContinue = total <= maximumBytes && !control.cancelled
            if (canContinue) output.write(buffer, 0, count)
            count = if (canContinue) input.read(buffer) else -1
        }
        return !control.cancelled && total in 1..maximumBytes
    }

    private fun destination(directory: File, name: String): File =
        File(directory, "${System.currentTimeMillis()}_${UUID.randomUUID()}_$name")

    private fun displayName(uri: Uri, signal: CancellationSignal): String? {
        val providerName = if (uri.scheme.equals("file", ignoreCase = true)) {
            null
        } else {
            val projection = arrayOf(OpenableColumns.DISPLAY_NAME)
            contentResolver.query(uri, projection, null, null, null, signal)?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
            }
        }
        return providerName.takeUnless { it.isNullOrEmpty() } ?: uri.lastPathSegment
    }

    private fun canonicalAudioName(name: String, mimeType: String?): String? {
        val extension = name.substringAfterLast('.', missingDelimiterValue = "")
            .lowercase(Locale.ROOT)
        if (extension.isNotEmpty()) return name.takeIf { extension in supportedExtensions }
        val normalizedMimeType = mimeType?.substringBefore(';')?.trim()?.lowercase(Locale.ROOT)
        return supportedMimeExtensions[normalizedMimeType]?.let { "$name.$it" }
    }

    companion object {
        fun displayNameFromPath(path: String): String = File(path).name.split('_', limit = 3).last()

        private const val unknownImportMinimumBytes = 1024L * 1024L
        private val supportedExtensions = setOf(
            "flac", "mp3", "mp4", "mpeg", "mpga", "m4a", "ogg", "opus", "wav", "webm",
        )
        private val supportedMimeExtensions = mapOf(
            "audio/flac" to "flac",
            "audio/m4a" to "m4a",
            "audio/mp3" to "mp3",
            "audio/mp4" to "mp4",
            "audio/mpeg" to "mp3",
            "audio/mpga" to "mpga",
            "audio/ogg" to "ogg",
            "audio/opus" to "opus",
            "audio/wav" to "wav",
            "audio/webm" to "webm",
            "audio/x-m4a" to "m4a",
            "audio/x-wav" to "wav",
        )
    }
}
