package com.transcriber.app

import android.content.Context
import android.provider.Settings
import android.content.ComponentName
import android.view.inputmethod.InputMethodInfo
import android.view.inputmethod.InputMethodManager
import io.flutter.plugin.common.FlutterException
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class KeyboardSettingsChannelTest {
    private val context: Context = RuntimeEnvironment.getApplication()
    private val transport = NativeChannelHarness()

    private fun call(method: String, arguments: Any? = null): Any? =
        transport.call("app/keyboard/settings", method, arguments)

    @Test
    fun settingsActionsUseExplicitAndroidIntentsAndHandleUnknownMethods() {
        KeyboardSettingsChannel(context, transport).register()
        assertEquals(mapOf("enabled" to false, "selected" to false), call("getStatus"))
        assertEquals(true, call("openInputMethodSettings"))
        assertEquals(Settings.ACTION_INPUT_METHOD_SETTINGS, shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity.action)
        assertEquals(true, call("openAppSettings"))
        val intent = shadowOf(RuntimeEnvironment.getApplication()).nextStartedActivity
        assertEquals(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, intent.action)
        assertEquals("package:${context.packageName}", intent.data.toString())
        assertEquals(true, call("showInputMethodPicker"))
        assertEquals(null, call("unknown"))
    }

    @Test
    fun appearanceRequiresAnArgumentAndPropagatesWhetherTheHostAppliedIt() {
        KeyboardSettingsChannel(context, transport).register()
        assertEquals("invalid_argument", assertThrows(FlutterException::class.java) {
            call("setLightNavigationBar")
        }.code)
        assertEquals(false, call("setLightNavigationBar", mapOf("lightBackground" to true)))
        KeyboardSettingsChannel(context, transport) { it }.register()
        assertEquals(true, call("setLightNavigationBar", mapOf("lightBackground" to true)))
        assertEquals(false, call("setLightNavigationBar", mapOf("lightBackground" to false)))
    }

    @Test
    fun statusMatchesTheExactEnabledAndSelectedServiceComponent() {
        val host = mock(Context::class.java)
        val manager = mock(InputMethodManager::class.java)
        `when`(host.packageName).thenReturn(context.packageName)
        `when`(host.contentResolver).thenReturn(context.contentResolver)
        `when`(host.getSystemService(InputMethodManager::class.java)).thenReturn(manager)
        val component = ComponentName(context, TranscriberInputMethodService::class.java)
        val info = mock(InputMethodInfo::class.java)
        `when`(info.id).thenReturn("invalid-component")
        `when`(manager.enabledInputMethodList).thenReturn(listOf(info))
        KeyboardSettingsChannel(host, transport).register()
        assertEquals(mapOf("enabled" to false, "selected" to false), call("getStatus"))
        `when`(info.id).thenReturn(component.flattenToString())
        Settings.Secure.putString(context.contentResolver, Settings.Secure.DEFAULT_INPUT_METHOD, component.flattenToShortString())
        assertEquals(mapOf("enabled" to true, "selected" to true), call("getStatus"))
    }
}
