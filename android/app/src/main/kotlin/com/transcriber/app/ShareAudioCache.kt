package com.transcriber.app

import android.content.ContentResolver
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
    private val cacheDirectory: File,
    private val contentResolver: ContentResolver,
    private val onFailure: (Throwable) -> Unit,
) {
    fun copy(uri: Uri, intentMimeType: String?, control: ShareImportControl): String? {
        var outputFile: File? = null
        var result: String? = null
        try {
            val signal = CancellationSignal()
            val candidate = if (control.register(Closeable { signal.cancel() })) {
                prepareOutput(uri, intentMimeType, signal, control)
            } else {
                null
            }
            outputFile = candidate
            if (candidate != null && control.track(candidate) && copyStream(uri, candidate, signal, control)) {
                result = candidate.canonicalPath
            }
        } catch (error: IOException) {
            onFailure(error)
        } catch (error: SecurityException) {
            onFailure(error)
        } catch (error: IllegalArgumentException) {
            onFailure(error)
        } catch (error: OperationCanceledException) {
            onFailure(error)
        } finally {
            if (result == null || control.cancelled) outputFile?.delete()
        }
        return result.takeUnless { control.cancelled }
    }

    private fun prepareOutput(
        uri: Uri,
        intentMimeType: String?,
        signal: CancellationSignal,
        control: ShareImportControl,
    ): File? {
        val directory = createSharedDirectory() ?: return null
        val mimeType = contentResolver.getType(uri) ?: intentMimeType
        val name = canonicalAudioName(
            ShareFileNamePolicy.sanitize(displayName(uri, signal)),
            mimeType,
        )
        return name?.takeUnless { control.cancelled }?.let { createOutputFile(directory, it) }
    }

    private fun copyStream(
        uri: Uri,
        outputFile: File,
        signal: CancellationSignal,
        control: ShareImportControl,
    ): Boolean {
        val descriptor = contentResolver.openAssetFileDescriptor(uri, "r", signal) ?: return false
        return descriptor.use {
            control.register(it) && copyInput(it.createInputStream(), outputFile, control)
        }
    }

    private fun copyInput(input: InputStream, outputFile: File, control: ShareImportControl): Boolean {
        return input.use {
            control.register(input) && outputFile.outputStream().use { output ->
                control.register(output) && copyWithinLimit(input, output, control) &&
                    outputFile.length() in 1..maximumAudioBytes
            }
        }
    }

    private fun copyWithinLimit(
        input: InputStream,
        output: OutputStream,
        control: ShareImportControl,
    ): Boolean {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0L
        var count = if (control.cancelled) -1 else input.read(buffer)
        while (count >= 0 && total <= maximumAudioBytes && !control.cancelled) {
            if (count == 0) throw IOException("Empty provider read")
            total += count
            val canContinue = total <= maximumAudioBytes && !control.cancelled
            if (canContinue) output.write(buffer, 0, count)
            count = if (canContinue) input.read(buffer) else -1
        }
        return !control.cancelled && total in 1..maximumAudioBytes
    }

    private fun createSharedDirectory(): File? {
        val directory = File(cacheDirectory, "shared")
        if (!directory.exists() && !directory.mkdirs()) return null
        return directory.takeIf { it.isDirectory }
    }

    private fun createOutputFile(directory: File, name: String): File? {
        val cacheRoot = cacheDirectory.canonicalFile
        val directoryRoot = directory.canonicalFile
        if (!isWithin(cacheRoot, directoryRoot)) return null
        val output = File(directory, "${System.currentTimeMillis()}_${UUID.randomUUID()}_$name")
        val outputPath = output.canonicalFile
        return output.takeIf {
            isWithin(directoryRoot, outputPath) && it.createNewFile()
        }
    }

    private fun isWithin(root: File, candidate: File): Boolean {
        val rootPath = root.path.trimEnd(File.separatorChar) + File.separator
        return candidate.path.startsWith(rootPath)
    }

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

    private companion object {
        const val maximumAudioBytes = 250L * 1024L * 1024L
        val supportedExtensions = setOf(
            "flac", "mp3", "mp4", "mpeg", "mpga", "m4a", "ogg", "opus", "wav", "webm",
        )
        val supportedMimeExtensions = mapOf(
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
