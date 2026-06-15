package com.transcriber.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// Translucent share target. Runs the dedicated `shareMain` Flutter entry point
/// with a transparent background so the app the user shared from stays visible
/// behind the overlay. The shared audio (a content:// URI) is copied to the
/// cache here and handed to Dart via a method channel.
class ShareActivity : FlutterActivity() {
    private val channelName = "app/share"
    private var sharedPath: String? = null

    // shareMain is a top-level @pragma('vm:entry-point') function in the main
    // library (lib/main.dart), so the default entrypoint-library resolution
    // finds it in AOT/release builds.
    override fun getDartEntrypointFunctionName(): String = "shareMain"

    // Transparent window — required so the source app shows through.
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        // Install before super.onCreate so a crash during Flutter's transparent
        // engine attach is captured and shown in-app on next launch.
        CrashCapture.install(this, "ShareActivity")
        super.onCreate(savedInstanceState)
        sharedPath = extractSharedAudio(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
        if (intent == null) return null
        @Suppress("DEPRECATION")
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_SEND -> intent.getParcelableExtra(Intent.EXTRA_STREAM)
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.firstOrNull()
            else -> null
        }
        return uri?.let { copyToCache(it) }
    }

    private fun copyToCache(uri: Uri): String? {
        return try {
            val name = displayName(uri) ?: "shared_audio"
            val outFile = File(cacheDir, "shared/${System.currentTimeMillis()}_$name")
            outFile.parentFile?.mkdirs()
            contentResolver.openInputStream(uri)?.use { input ->
                outFile.outputStream().use { output -> input.copyTo(output) }
            } ?: return null
            outFile.absolutePath
        } catch (e: Exception) {
            null
        }
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme == "file") return uri.lastPathSegment
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                val value = cursor.getString(index)
                if (!value.isNullOrEmpty()) return value
            }
        }
        return uri.lastPathSegment
    }
}
