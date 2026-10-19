package com.transcriber.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var recordingChannel: BoundedRecordingChannel? = null

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
