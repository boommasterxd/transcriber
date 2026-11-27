package com.transcriber.app

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.BadParcelableException
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

/** Translucent share target with a bounded background import and deferred handoff. */
class ShareActivity : FlutterActivity() {
    private lateinit var importCoordinator: ShareImportCoordinator
    private var channel: MethodChannel? = null
    private var audioCacheChannel: AudioCacheChannel? = null

    // shareMain lives in lib/main.dart so the default resolution works in AOT.
    override fun getDartEntrypointFunctionName(): String = "shareMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        val control = BoundedAudioImports.createControl()
        importCoordinator = BoundedAudioImports.createCoordinator(control)
        // Initialize the coordinator before Flutter can call the channel. Its
        // pending reply preserves the startup race fix without blocking startup.
        super.onCreate(savedInstanceState)
        val uri = extractSharedUri(intent)?.takeIf {
            intent.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0 && BoundedAudioImports.canRead(this, it)
        }
        val mimeType = intent?.type
        val context = applicationContext
        val owner = audioCacheChannel?.owner
        importCoordinator.start {
            if (uri == null || owner == null) {
                null
            } else {
                ShareAudioCache(context.cacheDir, context.contentResolver, owner, ::logShareFailure)
                    .copy(uri, mimeType, control)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Hide the share intent from plugins so only the bounded importer can read it.
        val sharedIntent = intent
        setIntent(Intent())
        try {
            super.configureFlutterEngine(flutterEngine)
        } finally {
            setIntent(sharedIntent)
        }
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val owner = AudioCacheQuota.shared.owner(cacheDir)
        audioCacheChannel = AudioCacheChannel(messenger, owner).also { it.register() }
        channel = MethodChannel(messenger, "app/share").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedPath" -> {
                        if (!importCoordinator.takePath(result::success)) {
                            result.error("share_request_pending", "Share import is pending", null)
                        }
                    }
                    "finish" -> {
                        importCoordinator.cancel()
                        result.success(true)
                        finish()
                        overridePendingTransition(0, 0)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (::importCoordinator.isInitialized) importCoordinator.cancel()
        channel?.setMethodCallHandler(null)
        channel = null
        audioCacheChannel?.dispose()
        audioCacheChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onDestroy() {
        importCoordinator.cancel()
        super.onDestroy()
    }

    private fun extractSharedUri(intent: Intent?): Uri? {
        if (intent == null || !isSupportedShareIntent(intent)) return null
        return try {
            readSharedUri(intent)?.takeIf {
                it.scheme == ContentResolver.SCHEME_CONTENT && !it.authority.isNullOrBlank()
            }
        } catch (error: BadParcelableException) {
            logShareFailure(error)
            null
        }
    }

    private fun isSupportedShareIntent(intent: Intent): Boolean {
        val actionSupported = intent.action == Intent.ACTION_VIEW ||
            intent.action == Intent.ACTION_SEND ||
            intent.action == Intent.ACTION_SEND_MULTIPLE
        val type = intent.type?.trim()?.lowercase(Locale.ROOT)
        return actionSupported && type?.startsWith("audio/") == true
    }

    private fun readSharedUri(intent: Intent): Uri? {
        if (intent.action == Intent.ACTION_VIEW) return intent.data
        val stream = intent.extras?.get(Intent.EXTRA_STREAM)
        val extraUri = when (intent.action) {
            Intent.ACTION_SEND -> stream as? Uri
            Intent.ACTION_SEND_MULTIPLE ->
                (stream as? ArrayList<*>)?.firstOrNull() as? Uri
            else -> null
        }
        return extraUri
            ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
    }

    private companion object {
        fun logShareFailure(error: Throwable) {
            val errorType = error::class.java.simpleName.ifEmpty { "UnknownError" }
            Log.w("ShareActivity", "Unable to import shared audio ($errorType)")
        }
    }
}
