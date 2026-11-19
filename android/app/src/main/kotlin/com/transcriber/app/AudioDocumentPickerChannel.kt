package com.transcriber.app

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal class AudioDocumentPickerChannel(messenger: BinaryMessenger, private val picker: AudioDocumentPicker) {
    private val channel = MethodChannel(messenger, "app/audio_import")

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> picker.pick(result)
                "recoverInterruptedPick" -> picker.recover(result)
                else -> result.notImplemented()
            }
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        picker.cancel()
    }
}
