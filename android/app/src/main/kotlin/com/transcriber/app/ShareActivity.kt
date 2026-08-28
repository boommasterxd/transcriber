package com.transcriber.app

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.BadParcelableException
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.Locale
import java.util.UUID

/** Translucent share target that copies shared audio into the application cache. */
class ShareActivity : FlutterActivity() {
    private val channelName = "app/share"
    private var sharedPath: String? = null
    private val audioCache by lazy {
        ShareAudioCache(cacheDir, contentResolver, ::logShareFailure)
    }

    // shareMain is a top-level @pragma('vm:entry-point') function in the main
    // library (lib/main.dart), so the default entrypoint-library resolution
    // finds it in AOT/release builds.
    override fun getDartEntrypointFunctionName(): String = "shareMain"

    // Transparent window is required so the source app shows through.
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        // Cache the share synchronously before Flutter can request it through
        // the method channel. Otherwise a fast Dart startup can observe null
        // and close the translucent activity before the copy finishes.
        sharedPath = extractSharedAudio(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // The generic sharing plugin is registered with every Flutter engine.
        // Hide this already-consumed intent while plugins attach so it cannot
        // duplicate the file outside the bounded, managed share cache.
        val sharedIntent = intent
        setIntent(Intent())
        try {
            super.configureFlutterEngine(flutterEngine)
        } finally {
            setIntent(sharedIntent)
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedPath" -> result.success(sharedPath)
                    "finish" -> {
                        result.success(true)
                        finish()
                        overridePendingTransition(0, 0)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun extractSharedAudio(intent: Intent?): String? {
        val uri = intent?.takeIf(::isSupportedShareIntent)?.let {
            try {
                extractSharedUri(it)
            } catch (e: BadParcelableException) {
                logShareFailure(e)
                null
            }
        }
        return uri?.takeIf(::isSupportedUri)?.let(audioCache::copy)
    }

    private fun isSupportedShareIntent(intent: Intent): Boolean {
        val actionSupported = intent.action == Intent.ACTION_SEND ||
            intent.action == Intent.ACTION_SEND_MULTIPLE
        val type = intent.type?.trim()?.lowercase(Locale.ROOT)
        return actionSupported && type?.startsWith("audio/") == true
    }

    private fun extractSharedUri(intent: Intent): Uri? {
        val stream = intent.extras?.get(Intent.EXTRA_STREAM)
        return when (intent.action) {
            Intent.ACTION_SEND -> stream as? Uri
            Intent.ACTION_SEND_MULTIPLE ->
                (stream as? ArrayList<*>)?.firstOrNull() as? Uri
            else -> null
        }
    }

    private fun isSupportedUri(uri: Uri): Boolean {
        return when (uri.scheme?.lowercase(Locale.ROOT)) {
            "content" -> !uri.authority.isNullOrBlank()
            "file" -> !uri.path.isNullOrBlank()
            else -> false
        }
    }

    private fun logShareFailure(error: Throwable) {
        val errorType = error::class.java.simpleName.ifEmpty { "UnknownError" }
        Log.w(logTag, "Unable to import shared audio ($errorType)")
    }

    private companion object {
        const val logTag = "ShareActivity"
    }
}

/** Copies one validated external audio URI into an app-private cache directory. */
private class ShareAudioCache(
    private val cacheDirectory: File,
    private val contentResolver: ContentResolver,
    private val onFailure: (Throwable) -> Unit,
) {
    fun copy(uri: Uri): String? {
        var outputFile: File? = null
        var result: String? = null
        try {
            val directory = createSharedDirectory()
            val name = canonicalAudioName(
                ShareFileNamePolicy.sanitize(displayName(uri)),
            )
            if (!hasSupportedExtension(name)) return null
            val candidate = directory?.let { createOutputFile(it, name) }
            outputFile = candidate
            if (candidate != null && copyStream(uri, candidate)) {
                result = candidate.canonicalPath
            }
        } catch (error: IOException) {
            onFailure(error)
        } catch (error: SecurityException) {
            onFailure(error)
        } catch (error: IllegalArgumentException) {
            onFailure(error)
        }
        if (result == null) outputFile?.delete()
        return result
    }

    private fun copyStream(uri: Uri, outputFile: File): Boolean {
        val input = contentResolver.openInputStream(uri) ?: return false
        return input.use { inputStream ->
            outputFile.outputStream().use { output ->
                copyStreamWithinLimit(inputStream, output) &&
                    outputFile.length() in 1..maximumAudioBytes
            }
        }
    }

    private fun copyStreamWithinLimit(input: InputStream, output: OutputStream): Boolean {
        val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
        var total = 0L
        var count = input.read(buffer)
        while (count >= 0 && total <= maximumAudioBytes) {
            total += count
            if (total <= maximumAudioBytes) output.write(buffer, 0, count)
            count = if (total <= maximumAudioBytes) input.read(buffer) else -1
        }
        return total in 1..maximumAudioBytes
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

    private fun displayName(uri: Uri): String? {
        val providerName = if (uri.scheme.equals("file", ignoreCase = true)) {
            null
        } else {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
            }
        }
        return providerName.takeUnless { it.isNullOrEmpty() } ?: uri.lastPathSegment
    }

    private fun hasSupportedExtension(name: String): Boolean {
        val extension = name.substringAfterLast('.', missingDelimiterValue = "")
            .lowercase(Locale.ROOT)
        return extension in supportedExtensions
    }

    private fun canonicalAudioName(name: String): String {
        return if (name.endsWith(".opus", ignoreCase = true)) {
            name.dropLast(opusSuffixLength) + ".ogg"
        } else {
            name
        }
    }

    private companion object {
        const val maximumAudioBytes = 250L * 1024L * 1024L
        const val opusSuffixLength = 5
        val supportedExtensions = setOf(
            "flac", "mp3", "mp4", "mpeg", "mpga", "m4a", "ogg", "opus", "wav", "webm",
        )
    }
}
