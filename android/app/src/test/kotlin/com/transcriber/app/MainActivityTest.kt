package com.transcriber.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.RETURNS_DEEP_STUBS
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE, shadows = [MainActivityTest.FlutterHostShadow::class])
class MainActivityTest {
    @Test
    fun configuringAProvidedEngineRegistersTheNativeSettingsChannel() {
        val activity = Robolectric.buildActivity(MainActivity::class.java).get()
        val delegateType = Class.forName("io.flutter.embedding.android.FlutterActivityAndFragmentDelegate")
        val delegate = mock(delegateType)
        val fromHost = delegateType.getDeclaredMethod("isFlutterEngineFromHost").apply { isAccessible = true }
        `when`(fromHost.invoke(delegate)).thenReturn(true)
        FlutterActivity::class.java.getDeclaredField("delegate").apply {
            isAccessible = true
            set(activity, delegate)
        }
        val engine = mock(FlutterEngine::class.java, RETURNS_DEEP_STUBS)
        val transport = NativeChannelHarness()
        `when`(engine.dartExecutor.binaryMessenger).thenReturn(transport)
        activity.configureFlutterEngine(engine)
        assertEquals(null, transport.call("app/keyboard/settings", "unknown"))
    }

    @Test
    fun explicitViewIntentIsForwardedBeforeFlutterSeesIt() {
        val uri = Uri.parse("content://provider/audio.wav")
        val incoming = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "audio/wav")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val controller = Robolectric.buildActivity(MainActivity::class.java, incoming)
        val activity = controller.create().get()

        assertNull(activity.intent.action)
        val forwarded = shadowOf(activity).nextStartedActivity
        assertEquals(ShareActivity::class.java.name, forwarded.component?.className)
        assertEquals(Intent.ACTION_VIEW, forwarded.action)
        assertEquals(uri, forwarded.data)
        assertEquals("audio/wav", forwarded.type)
        assertTrue(forwarded.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
    }

    @Test
    fun explicitSendIntentIsForwardedWithItsStream() {
        val uri = Uri.parse("content://provider/audio.wav")
        val incoming = Intent(Intent.ACTION_SEND).setType("audio/wav")
            .putExtra(Intent.EXTRA_STREAM, uri)
        val controller = Robolectric.buildActivity(MainActivity::class.java, incoming)
        val activity = controller.create().get()

        val forwarded = shadowOf(activity).nextStartedActivity
        assertEquals(ShareActivity::class.java.name, forwarded.component?.className)
        assertEquals(Intent.ACTION_SEND, forwarded.action)
        assertEquals(uri, forwarded.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java))
    }

    @Test
    fun explicitSendMultipleIntentIsForwardedWithItsStreams() {
        val streams = arrayListOf(Uri.parse("content://provider/first.wav"), Uri.parse("content://provider/second.wav"))
        val incoming = Intent(Intent.ACTION_SEND_MULTIPLE).setType("audio/wav")
            .putParcelableArrayListExtra(Intent.EXTRA_STREAM, streams)
        val controller = Robolectric.buildActivity(MainActivity::class.java, incoming)
        val activity = controller.create().get()

        val forwarded = shadowOf(activity).nextStartedActivity
        assertEquals(ShareActivity::class.java.name, forwarded.component?.className)
        assertEquals(Intent.ACTION_SEND_MULTIPLE, forwarded.action)
        assertEquals(streams, forwarded.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java))
    }

    @Test
    fun mediaNewIntentIsForwardedAndRemovedFromMainActivityState() {
        val activity = Robolectric.buildActivity(MainActivity::class.java).create().get()
        val uri = Uri.parse("content://provider/audio.wav")
        val incoming = Intent(Intent.ACTION_VIEW).setDataAndType(uri, "audio/wav")

        val onNewIntent = MainActivity::class.java.getDeclaredMethod("onNewIntent", Intent::class.java)
        onNewIntent.isAccessible = true
        onNewIntent.invoke(activity, incoming)

        assertNull(activity.intent.action)
        val forwarded = shadowOf(activity).nextStartedActivity
        assertEquals(ShareActivity::class.java.name, forwarded.component?.className)
        assertEquals(uri, forwarded.data)
    }

    @Implements(FlutterActivity::class)
    class FlutterHostShadow : org.robolectric.shadows.ShadowActivity() {
        @Implementation
        fun onCreate(ignored: Bundle?) = Unit
    }
}
