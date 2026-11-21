package com.transcriber.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var recordingChannel: BoundedRecordingChannel? = null
    private var sensitiveClipboardChannel: SensitiveClipboardChannel? = null
    private var audioDocumentPickerChannel: AudioDocumentPickerChannel? = null
    private val audioDocumentPicker by lazy {
        AudioDocumentPicker(::launchAudioDocumentPicker, ::startAudioImport) {
            BoundedAudioImports.canRead(this, it)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        audioDocumentPicker.restore(savedInstanceState?.getInt(audioPickerRequestKey) ?: 0)
        val incoming = intent
        val shareIntent = incoming.takeIf(::isExternalMediaIntent)?.let {
            Intent(it).setClass(this, ShareActivity::class.java)
        }
        if (shareIntent != null) {
            // The sharing plugin handles the activity's initial intent as soon
            // as Flutter attaches. Keep it away from untrusted media intents.
            setIntent(Intent())
        }
        super.onCreate(savedInstanceState)
        if (shareIntent != null) startActivity(shareIntent)
    }

    override fun onNewIntent(intent: Intent) {
        if (isExternalMediaIntent(intent)) {
            setIntent(Intent())
            startActivity(Intent(intent).setClass(this, ShareActivity::class.java))
            return
        }
        super.onNewIntent(intent)
    }

    private fun isExternalMediaIntent(intent: Intent): Boolean =
        intent.action in setOf(Intent.ACTION_VIEW, Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE)

    override fun onSaveInstanceState(outState: Bundle) {
        super.onSaveInstanceState(outState)
        outState.putInt(audioPickerRequestKey, audioDocumentPicker.savedRequestCode())
    }

    @Suppress("DEPRECATION") // FlutterActivity uses the platform result callback, not ComponentActivity.
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (!audioDocumentPicker.onActivityResult(requestCode, resultCode, data)) {
            super.onActivityResult(requestCode, resultCode, data)
        }
    }

    @Suppress("DEPRECATION")
    private fun launchAudioDocumentPicker(intent: Intent, requestCode: Int) {
        startActivityForResult(intent, requestCode)
    }

    private fun startAudioImport(uri: Uri, mimeType: String?): ShareImportCoordinator {
        val control = BoundedAudioImports.createControl()
        val context = applicationContext
        val cache = ShareAudioCache(context.cacheDir, context.contentResolver) { /* The channel reports failure. */ }
        return BoundedAudioImports.createCoordinator(control).also { coordinator ->
            coordinator.start { cache.copy(uri, mimeType, control) }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        KeyboardSettingsChannel(this, messenger).register()
        recordingChannel = BoundedRecordingChannel(this, messenger).also { it.register() }
        sensitiveClipboardChannel = SensitiveClipboardChannel(this, messenger).also { it.register() }
        audioDocumentPickerChannel = AudioDocumentPickerChannel(messenger, audioDocumentPicker).also { it.register() }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        audioDocumentPickerChannel?.dispose()
        audioDocumentPickerChannel = null
        sensitiveClipboardChannel?.dispose()
        sensitiveClipboardChannel = null
        recordingChannel?.dispose()
        recordingChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object {
        const val audioPickerRequestKey = "audio_document_picker_request"
    }
}
