package com.transcriber.app

import android.view.View
import org.junit.Assert.assertEquals
import org.junit.Test

@Suppress("DEPRECATION")
class NavigationBarAppearanceTest {
    @Test
    fun lightBackgroundAddsLightNavigationBarFlagWithoutDroppingOtherFlags() {
        val existingFlag = View.SYSTEM_UI_FLAG_FULLSCREEN

        val result = navigationBarVisibility(existingFlag, true)

        assertEquals(existingFlag or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR, result)
    }

    @Test
    fun darkBackgroundRemovesOnlyLightNavigationBarFlag() {
        val existingFlag = View.SYSTEM_UI_FLAG_FULLSCREEN
        val current = existingFlag or View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR

        val result = navigationBarVisibility(current, false)

        assertEquals(existingFlag, result)
    }
}
