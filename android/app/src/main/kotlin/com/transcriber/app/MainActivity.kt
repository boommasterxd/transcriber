package com.transcriber.app

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "app/icon"

    // Dart accent id → the launcher and share-target alias names for that accent.
    // Both are swapped together so the home-screen icon AND the share-sheet icon
    // follow the chosen accent color.
    private val aliasesByAccent = mapOf(
        "violet" to listOf("IconViolet", "ShareIconViolet"),
        "blue" to listOf("IconBlue", "ShareIconBlue"),
        "emerald" to listOf("IconEmerald", "ShareIconEmerald"),
        "amber" to listOf("IconAmber", "ShareIconAmber"),
        "magenta" to listOf("IconMagenta", "ShareIconMagenta"),
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setIcon" -> {
                        setIcon(call.argument<String>("accent") ?: "violet")
                        result.success(true)
                    }
                    "syncShareIcon" -> {
                        // Only toggles ShareActivity aliases — safe while the app
                        // is in the foreground (ShareActivity isn't running), so it
                        // can run on start / on accent change, not just on pause.
                        syncShareIcon(call.argument<String>("accent") ?: "violet")
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun syncShareIcon(accent: String) {
        val pm = packageManager
        val pkg = packageName
        for ((key, aliases) in aliasesByAccent) {
            val shareAlias = aliases[1]
            val state = if (key == accent) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(
                ComponentName(pkg, "$pkg.$shareAlias"),
                state,
                PackageManager.DONT_KILL_APP,
            )
        }
    }

    /// Enables the launcher + share aliases for [accent] and disables the rest,
    /// recoloring both the home-screen and share-sheet icons. DONT_KILL_APP keeps
    /// the running app alive.
    private fun setIcon(accent: String) {
        val pm = packageManager
        val pkg = packageName
        for ((key, aliases) in aliasesByAccent) {
            val state = if (key == accent) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            for (alias in aliases) {
                pm.setComponentEnabledSetting(
                    ComponentName(pkg, "$pkg.$alias"),
                    state,
                    PackageManager.DONT_KILL_APP,
                )
            }
        }
    }
}
