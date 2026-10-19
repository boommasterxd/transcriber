package com.transcriber.app

import io.flutter.embedding.engine.FlutterEngine
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.RETURNS_DEEP_STUBS
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class MainActivityTest {
    @Test
    fun configuringAProvidedEngineRegistersTheNativeSettingsChannel() {
        val activity = Robolectric.buildActivity(MainActivity::class.java).get()
        // Supply Flutter's host delegate without starting its native renderer.
        val delegateType = Class.forName("io.flutter.embedding.android.FlutterActivityAndFragmentDelegate")
        val delegate = mock(delegateType)
        val fromHost = delegateType.getDeclaredMethod("isFlutterEngineFromHost").apply { isAccessible = true }
        `when`(fromHost.invoke(delegate)).thenReturn(true)
        io.flutter.embedding.android.FlutterActivity::class.java.getDeclaredField("delegate").apply {
            isAccessible = true
            set(activity, delegate)
        }
        val engine = mock(FlutterEngine::class.java, RETURNS_DEEP_STUBS)
        val transport = NativeChannelHarness()
        `when`(engine.dartExecutor.binaryMessenger).thenReturn(transport)
        activity.configureFlutterEngine(engine)
        assertEquals(null, transport.call("app/keyboard/settings", "unknown"))
    }
}
