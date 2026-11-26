package com.transcriber.app

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
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
    fun explicitSendMultipleIntentIsForwardedWithItsStreams() {
        val streams = arrayListOf(Uri.parse("content://provider/first.wav"), Uri.parse("content://provider/second.wav"))
        val incoming = Intent(Intent.ACTION_SEND_MULTIPLE).setType("audio/wav")
            .putParcelableArrayListExtra(Intent.EXTRA_STREAM, streams)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        val controller = Robolectric.buildActivity(MainActivity::class.java, incoming)
        val activity = controller.create().get()

        val forwarded = shadowOf(activity).nextStartedActivity
        assertEquals(ShareActivity::class.java.name, forwarded.component?.className)
        assertEquals(Intent.ACTION_SEND_MULTIPLE, forwarded.action)
        assertEquals(streams, forwarded.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java))
        assertTrue(forwarded.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
        assertNull(activity.intent.action)
    }

    @Implements(FlutterActivity::class)
    class FlutterHostShadow : org.robolectric.shadows.ShadowActivity() {
        @Implementation
        fun onCreate(ignored: Bundle?) = Unit
    }
}
