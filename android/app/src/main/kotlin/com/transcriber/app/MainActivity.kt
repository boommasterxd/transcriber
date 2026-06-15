package com.transcriber.app

import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "app/icon"

    override fun onCreate(savedInstanceState: Bundle?) {
        CrashCapture.install(this, "MainActivity")
        super.onCreate(savedInstanceState)
    }

    // Maps the Dart accent id to the manifest <activity-alias> name.
    private val aliases = mapOf(
        "violet" to "IconViolet",
        "blue" to "IconBlue",
        "emerald" to "IconEmerald",
        "amber" to "IconAmber",
        "magenta" to "IconMagenta",
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
                    else -> result.notImplemented()
                }
            }
    }

    /// Enables the launcher alias for [accent] and disables the rest, recoloring
    /// the home-screen icon. DONT_KILL_APP keeps the running app alive.
    private fun setIcon(accent: String) {
        val pm = packageManager
        val pkg = packageName
        for ((key, alias) in aliases) {
            val state = if (key == accent) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            pm.setComponentEnabledSetting(
                ComponentName(pkg, "$pkg.$alias"),
                state,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
