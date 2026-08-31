package com.transcriber.app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Exposes IME status, explicit Android actions, and IME window appearance. */
class KeyboardSettingsChannel(
    private val context: Context,
    messenger: BinaryMessenger,
    private val updateLightNavigationBar: ((Boolean) -> Boolean)? = null,
) {
    private val channel = MethodChannel(messenger, channelName)

    fun register() {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(status())
                "openInputMethodSettings" -> result.success(openInputMethodSettings())
                "showInputMethodPicker" -> result.success(showInputMethodPicker())
                "openAppSettings" -> result.success(openAppSettings())
                "setLightNavigationBar" -> {
                    val lightBackground = call.argument<Boolean>("lightBackground")
                    if (lightBackground == null) {
                        result.error("invalid_argument", "lightBackground is required", null)
                    } else {
                        result.success(updateLightNavigationBar?.invoke(lightBackground) ?: false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun status(): Map<String, Boolean> {
        val manager = context.getSystemService(InputMethodManager::class.java)
        val component = ComponentName(context, TranscriberInputMethodService::class.java)
        val enabled = manager.enabledInputMethodList.any {
            ComponentName.unflattenFromString(it.id) == component
        }
        val selected = Settings.Secure.getString(
            context.contentResolver,
            Settings.Secure.DEFAULT_INPUT_METHOD,
        ) == component.flattenToShortString()
        return mapOf("enabled" to enabled, "selected" to selected)
    }

    private fun openInputMethodSettings(): Boolean = start(
        Intent(Settings.ACTION_INPUT_METHOD_SETTINGS),
    )

    private fun showInputMethodPicker(): Boolean {
        context.getSystemService(InputMethodManager::class.java).showInputMethodPicker()
        return true
    }

    private fun openAppSettings(): Boolean = start(
        Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${context.packageName}"),
        ),
    )

    private fun start(intent: Intent): Boolean {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        context.startActivity(intent)
        return true
    }

    private companion object {
        const val channelName = "app/keyboard/settings"
    }
}
