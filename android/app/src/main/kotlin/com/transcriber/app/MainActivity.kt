package com.transcriber.app

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var recordingChannel: BoundedRecordingChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        KeyboardSettingsChannel(this, flutterEngine.dartExecutor.binaryMessenger).register()
        recordingChannel = BoundedRecordingChannel(this, flutterEngine.dartExecutor.binaryMessenger)
            .also { it.register() }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        recordingChannel?.dispose()
        recordingChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
