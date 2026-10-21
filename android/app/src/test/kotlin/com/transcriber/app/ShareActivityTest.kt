package com.transcriber.app

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import android.os.BadParcelableException
import android.os.Bundle
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.doReturn
import org.mockito.Mockito.doThrow
import org.mockito.Mockito.mock
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.annotation.RealObject
import java.nio.ByteBuffer
import java.time.Duration
import java.util.concurrent.Executor

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE, shadows = [ShareActivityTest.FlutterHostShadow::class])
class ShareActivityTest {
    @Test
    fun supportedIntentActionsChooseFirstStreamOrClipAndValidateUri() {
        val activity = Robolectric.buildActivity(ShareActivity::class.java).get()
        val uri = Uri.parse("content://fixture/audio.wav")
        assertEquals(uri, extract(activity, shareIntent().putExtra(Intent.EXTRA_STREAM, uri)))
        val multiple = Intent(Intent.ACTION_SEND_MULTIPLE).setType(" Audio/WAV ")
            .putParcelableArrayListExtra(Intent.EXTRA_STREAM, arrayListOf(uri, Uri.parse("file:///other.wav")))
        assertEquals(uri, extract(activity, multiple))
        val clip = shareIntent().apply { clipData = ClipData.newRawUri("audio", uri) }
        assertEquals(uri, extract(activity, clip))
        assertEquals(uri, extract(activity, Intent(Intent.ACTION_VIEW).setDataAndType(uri, "audio/wav")))
        assertEquals(
            Uri.parse("file:///voice.wav"),
            extract(
                activity,
                shareIntent()
                    .putExtra(Intent.EXTRA_STREAM, Uri.parse("file:///voice.wav"))
            )
        )
        for (invalid in listOf("https://fixture/voice.wav", "content:///voice.wav", "file:", "/voice.wav")) {
            assertNull(extract(activity, shareIntent().putExtra(Intent.EXTRA_STREAM, Uri.parse(invalid))))
        }
        assertNull(extract(activity, Intent(Intent.ACTION_VIEW).setType("audio/wav")))
        assertNull(extract(activity, Intent(Intent.ACTION_VIEW).setDataAndType(uri, "text/plain")))
        assertNull(extract(activity, Intent(Intent.ACTION_SEND)))
        assertNull(
            extract(
                activity,
                Intent(Intent.ACTION_SEND).setType("text/plain")
                    .putExtra(Intent.EXTRA_STREAM, uri)
            )
        )
        assertNull(extract(activity, Intent(Intent.ACTION_SEND).setType("audio/wav")))
        assertNull(extract(activity, shareIntent().setType("text/plain")))
        assertNull(extract(activity, shareIntent()))
        assertNull(extract(activity, null))
        assertNull(extract(activity, shareIntent().putExtra(Intent.EXTRA_STREAM, "invalid")))
        assertNull(
            extract(
                activity,
                Intent(Intent.ACTION_SEND_MULTIPLE).setType("audio/wav")
                    .putParcelableArrayListExtra(Intent.EXTRA_STREAM, arrayListOf<Uri>())
            )
        )
    }

    @Test
    fun malformedParcelableIsRejectedWithoutLeakingProviderData() {
        val activity = Robolectric.buildActivity(ShareActivity::class.java).get()
        val intent = mock(Intent::class.java)
        doReturn(Intent.ACTION_SEND).`when`(intent).action
        doReturn("audio/wav").`when`(intent).type
        doThrow(BadParcelableException("private source")).`when`(intent).extras
        assertNull(extract(activity, intent))
    }

    @Test
    fun nativeChannelWaitsForImportRejectsDuplicateAndRestoresHiddenIntent() {
        val fixture = Fixture()
        fixture.coordinator.start { "ready.wav" }
        fixture.activity.configureFlutterEngine(fixture.engine)
        assertSame(fixture.intent, fixture.activity.intent)
        assertTrue(FlutterHostShadow.intentHidden)
        val first = fixture.channel.call("getInitialSharedPath")
        assertFalse(first.replied)
        val duplicate = fixture.channel.call("getInitialSharedPath")
        assertEquals("share_request_pending", assertThrows(FlutterException::class.java) { duplicate.value() }.code)
        fixture.worker.removeFirst().run()
        assertTrue(first.replied)
        assertEquals("ready.wav", first.value())
        assertEquals("ready.wav", fixture.channel.call("getInitialSharedPath").value())
        assertNull(fixture.channel.call("unknown").value())
        assertEquals(true, fixture.channel.call("finish").value())
        assertTrue(fixture.activity.isFinishing)
    }

    @Test
    fun destroyCancelsPendingReplyAndUnregistersChannel() {
        val fixture = Fixture()
        fixture.coordinator.start { "late.wav" }
        fixture.activity.configureFlutterEngine(fixture.engine)
        val pending = fixture.channel.call("getInitialSharedPath")
        fixture.controller.destroy()
        assertTrue(pending.replied)
        assertNull(pending.value())
        assertNull(fixture.channel.handler)
        fixture.worker.removeFirst().run()
        val destroy = ShareActivity::class.java.getDeclaredMethod("onDestroy")
        destroy.isAccessible = true
        destroy.invoke(fixture.activity)
    }

    @Test
    fun onCreateSetsCoordinatorBeforeFlutterAndDeadlineBoundsReadiness() {
        val controller = Robolectric.buildActivity(ShareActivity::class.java, shareIntent())
        controller.create()
        val activity = controller.get()
        assertEquals("shareMain", activity.dartEntrypointFunctionName)
        val background = ShareActivity::class.java.getDeclaredMethod("getBackgroundMode")
        background.isAccessible = true
        assertEquals(BackgroundMode.transparent, background.invoke(activity))
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(60))
        controller.destroy()
    }

    private fun shareIntent(): Intent = Intent(Intent.ACTION_SEND).setType("audio/wav")

    private fun extract(activity: ShareActivity, intent: Intent?): Uri? {
        val method = ShareActivity::class.java.getDeclaredMethod("extractSharedUri", Intent::class.java)
        method.isAccessible = true
        return method.invoke(activity, intent) as Uri?
    }

    private class Fixture {
        val intent = Intent(Intent.ACTION_SEND).setType("audio/wav")
        val controller = Robolectric.buildActivity(ShareActivity::class.java, intent)
        val activity = controller.get()
        val worker = ArrayDeque<Runnable>()
        val channel = AsyncChannel()
        val coordinator = ShareImportCoordinator(
            Executor { worker.add(it) },
            { it() },
            { {} },
            ShareImportControl(Executor { it.run() }),
        )
        val engine = mock(FlutterEngine::class.java)

        init {
            val field = ShareActivity::class.java.getDeclaredField("importCoordinator")
            field.isAccessible = true
            field.set(activity, coordinator)
            val executor = mock(DartExecutor::class.java)
            doReturn(executor).`when`(engine).dartExecutor
            doReturn(channel).`when`(executor).binaryMessenger
        }
    }

    private class AsyncChannel : BinaryMessenger {
        var handler: BinaryMessenger.BinaryMessageHandler? = null

        override fun send(channel: String, message: ByteBuffer?) = Unit
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) = Unit
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
            assertEquals("app/share", channel)
            this.handler = handler
        }

        fun call(method: String): Reply {
            val reply = Reply()
            val encoded = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, null))
            handler!!.onMessage(encoded.apply { flip() }, reply)
            return reply
        }
    }

    private class Reply : BinaryMessenger.BinaryReply {
        var replied = false
        private var buffer: ByteBuffer? = null

        override fun reply(reply: ByteBuffer?) {
            assertFalse(replied)
            replied = true
            buffer = reply
        }

        fun value(): Any? = buffer?.let { StandardMethodCodec.INSTANCE.decodeEnvelope(it.duplicate().apply { flip() }) }
    }

    /** Flutter embedding is the external boundary; exercise our actual host code. */
    @Implements(FlutterActivity::class)
    class FlutterHostShadow : org.robolectric.shadows.ShadowActivity() {
        @RealObject
        lateinit var activity: FlutterActivity

        @Implementation
        fun onCreate(ignored: Bundle?) = Unit

        @Implementation
        override fun onDestroy() = Unit

        @Implementation
        fun configureFlutterEngine(ignored: FlutterEngine) {
            intentHidden = activity.intent.action == null
        }

        companion object {
            var intentHidden = false
        }
    }
}
