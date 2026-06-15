package com.transcriber.app

import android.content.Context
import java.io.PrintWriter
import java.io.StringWriter

/// Persists the last uncaught exception so it can be shown in-app on next launch
/// (a no-adb way to get a stack trace for the translucent ShareActivity crash).
/// Writes into Flutter's SharedPreferences file so Dart can read it as
/// `prefs.getString('last_crash')`.
object CrashCapture {
    fun install(context: Context, tag: String) {
        val app = context.applicationContext
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
            try {
                val sw = StringWriter()
                PrintWriter(sw).use { throwable.printStackTrace(it) }
                app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    .edit()
                    .putString("flutter.last_crash", "[$tag]\n$sw")
                    .commit()
            } catch (_: Throwable) {
                // Never let crash capture itself crash.
            }
            previous?.uncaughtException(thread, throwable)
        }
    }
}
