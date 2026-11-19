package com.transcriber.app

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.PersistableBundle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Keeps transcript content out of the Android clipboard preview. */
internal class SensitiveClipboardChannel(context: Context, messenger: BinaryMessenger) {
    private val clipboard = context.getSystemService(ClipboardManager::class.java)
    private val channel = MethodChannel(messenger, "app/clipboard")

    fun register() = channel.setMethodCallHandler(::handle)

    fun dispose() = channel.setMethodCallHandler(null)

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "setSensitiveText") {
            result.notImplemented()
            return
        }
        val text = call.arguments as? String
        if (text == null || clipboard == null) {
            result.error("clipboard_unavailable", "Unable to copy text", null)
            return
        }
        val clip = ClipData.newPlainText("", text)
        clip.description.extras = PersistableBundle().apply {
            putBoolean(ClipDescription.EXTRA_IS_SENSITIVE, true)
        }
        try {
            clipboard.setPrimaryClip(clip)
            result.success(null)
        } catch (_: RuntimeException) {
            result.error("clipboard_unavailable", "Unable to copy text", null)
        }
    }
}
