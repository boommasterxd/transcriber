package com.transcriber.app

import android.content.Intent
import android.net.Uri
import android.os.BadParcelableException
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/** Translucent share target with a bounded background import and deferred handoff. */
class ShareActivity : FlutterActivity() {
    private lateinit var importCoordinator: ShareImportCoordinator
    private var channel: MethodChannel? = null

    // shareMain lives in lib/main.dart so the default resolution works in AOT.
    override fun getDartEntrypointFunctionName(): String = "shareMain"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun onCreate(savedInstanceState: Bundle?) {
        val handler = Handler(Looper.getMainLooper())
        val control = ShareImportControl(cleanupWorker)
        importCoordinator = ShareImportCoordinator(
            importWorker,
            { handler.post(it) },
            { expire ->
                val deadline = Runnable(expire)
                handler.postDelayed(deadline, importDeadlineMillis)
                val cancel: () -> Unit = { handler.removeCallbacks(deadline) }
                cancel
            },
            control,
        )
        // Initialize the coordinator before Flutter can call the channel. Its
        // pending reply preserves the startup race fix without blocking startup.
        super.onCreate(savedInstanceState)
        val uri = extractSharedUri(intent)
        val mimeType = intent?.type
        val context = applicationContext
        val cache = ShareAudioCache(context.cacheDir, context.contentResolver, ::logShareFailure)
        importCoordinator.start { uri?.let { cache.copy(it, mimeType, control) } }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Hide the dedicated share intent while generic plugins attach, avoiding
        // a second unbounded copy by receive_sharing_intent.
        val sharedIntent = intent
        setIntent(Intent())
        try {
            super.configureFlutterEngine(flutterEngine)
        } finally {
            setIntent(sharedIntent)
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app/share").also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialSharedPath" -> {
                        if (!importCoordinator.awaitPath(result::success)) {
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

    override fun onDestroy() {
        importCoordinator.cancel()
        channel?.setMethodCallHandler(null)
        channel = null
        super.onDestroy()
    }

    private fun extractSharedUri(intent: Intent?): Uri? {
        if (intent == null || !isSupportedShareIntent(intent)) return null
        return try {
            readSharedUri(intent)?.takeIf(::isSupportedUri)
        } catch (error: BadParcelableException) {
            logShareFailure(error)
            null
        }
    }

    private fun isSupportedShareIntent(intent: Intent): Boolean {
        val actionSupported = intent.action == Intent.ACTION_SEND ||
            intent.action == Intent.ACTION_SEND_MULTIPLE
        val type = intent.type?.trim()?.lowercase(Locale.ROOT)
        return actionSupported && type?.startsWith("audio/") == true
    }

    private fun readSharedUri(intent: Intent): Uri? {
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

    private fun isSupportedUri(uri: Uri): Boolean {
        return when (uri.scheme?.lowercase(Locale.ROOT)) {
            "content" -> !uri.authority.isNullOrBlank()
            "file" -> !uri.path.isNullOrBlank()
            else -> false
        }
    }

    private companion object {
        const val importDeadlineMillis = 60_000L

        // One import for the entire process; a provider ignoring cancellation
        // occupies this slot instead of accumulating threads on repeated shares.
        val importWorker = ThreadPoolExecutor(
            1,
            1,
            0L,
            TimeUnit.MILLISECONDS,
            SynchronousQueue(),
        )
        val cleanupWorker = ThreadPoolExecutor(
            1,
            1,
            0L,
            TimeUnit.MILLISECONDS,
            ArrayBlockingQueue(1),
        )

        fun logShareFailure(error: Throwable) {
            val errorType = error::class.java.simpleName.ifEmpty { "UnknownError" }
            Log.w("ShareActivity", "Unable to import shared audio ($errorType)")
        }
    }
}
