package com.transcriber.app

import android.os.Build
import android.view.View
import android.view.Window
import android.view.WindowInsetsController

/** Keeps system-owned IME navigation icons legible against the Flutter theme. */
internal class ImeNavigationBarAppearance(
    private val currentWindow: () -> Window?,
) {
    private var lightBackground: Boolean? = null

    fun request(lightBackground: Boolean): Boolean {
        this.lightBackground = lightBackground
        return apply()
    }

    fun apply(): Boolean {
        val keyboardWindow = currentWindow()
        val useDarkIcons = lightBackground
        if (keyboardWindow == null || useDarkIcons == null) return false
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            applyModern(keyboardWindow, useDarkIcons)
        } else {
            applyLegacy(keyboardWindow, useDarkIcons)
        }
    }

    private fun applyModern(window: Window, lightBackground: Boolean): Boolean {
        val controller = window.insetsController ?: return false
        val mask = WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
        controller.setSystemBarsAppearance(if (lightBackground) mask else 0, mask)
        return true
    }

    @Suppress("DEPRECATION")
    private fun applyLegacy(window: Window, lightBackground: Boolean): Boolean {
        val decorView = window.decorView
        decorView.systemUiVisibility = navigationBarVisibility(
            decorView.systemUiVisibility,
            lightBackground,
        )
        return true
    }
}

@Suppress("DEPRECATION")
internal fun navigationBarVisibility(current: Int, lightBackground: Boolean): Int {
    val lightNavigationBar = View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
    return if (lightBackground) current or lightNavigationBar else current and lightNavigationBar.inv()
}
