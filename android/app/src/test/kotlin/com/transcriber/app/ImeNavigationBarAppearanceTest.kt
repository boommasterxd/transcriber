package com.transcriber.app

import android.app.Activity
import android.view.WindowInsetsController
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class ImeNavigationBarAppearanceTest {
    @Test
    fun noWindowOrUnrequestedAppearanceIsNotApplied() {
        assertFalse(ImeNavigationBarAppearance { null }.request(true))
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        assertFalse(ImeNavigationBarAppearance { activity.window }.apply())
        val window = mock(android.view.Window::class.java)
        `when`(window.insetsController).thenReturn(null)
        assertFalse(ImeNavigationBarAppearance { window }.request(true))
    }

    @Test
    fun modernAppearanceUsesDarkIconsForLightBackgroundAndClearsThemForDark() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val appearance = ImeNavigationBarAppearance { activity.window }
        assertTrue(appearance.request(true))
        val mask = WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS
        assertEquals(mask, activity.window.insetsController!!.systemBarsAppearance and mask)
        assertTrue(appearance.request(false))
        assertEquals(0, activity.window.insetsController!!.systemBarsAppearance and mask)
    }

    @Suppress("DEPRECATION")
    @Test
    @Config(sdk = [28])
    fun legacyAppearancePreservesUnrelatedFlags() {
        val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
        val appearance = ImeNavigationBarAppearance { activity.window }
        assertTrue(appearance.request(true))
        val light = android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        assertEquals(light, activity.window.decorView.systemUiVisibility and light)
        assertTrue(appearance.request(false))
        assertEquals(0, activity.window.decorView.systemUiVisibility and light)
    }
}
