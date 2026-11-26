package com.transcriber.app

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.RETURNS_DEEP_STUBS
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.annotation.RealObject

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE, shadows = [ShareActivityTest.FlutterHostShadow::class])
class ShareActivityTest {
    @Test
    fun sharedAudioIsHiddenFromGenericPluginsDuringAttachment() {
        val audio = Uri.parse("content://fixture/voice.wav")
        val share = Intent(Intent.ACTION_SEND).setType("audio/wav").putExtra(Intent.EXTRA_STREAM, audio)
        val activity = Robolectric.buildActivity(ShareActivity::class.java, share).get()
        val engine = mock(FlutterEngine::class.java, RETURNS_DEEP_STUBS)
        `when`(engine.dartExecutor.binaryMessenger).thenReturn(NativeChannelHarness())

        activity.configureFlutterEngine(engine)

        assertSame(share, activity.intent)
    }

    @Implements(FlutterActivity::class)
    class FlutterHostShadow : org.robolectric.shadows.ShadowActivity() {
        @RealObject
        lateinit var activity: FlutterActivity

        @Implementation
        fun configureFlutterEngine(ignored: FlutterEngine) {
            assertNull(activity.intent.action)
            assertNull(activity.intent.extras)
        }
    }
}
