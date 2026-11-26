package com.transcriber.app

import android.content.ClipDescription
import android.content.ClipboardManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35], manifest = Config.NONE)
class SensitiveClipboardChannelTest {
    @Test
    fun copiesSyntheticTranscriptAndMarksItSensitive() {
        val app = RuntimeEnvironment.getApplication()
        val transport = NativeChannelHarness()
        val clipboard = requireNotNull(app.getSystemService(ClipboardManager::class.java))
        SensitiveClipboardChannel(app, transport).register()
        transport.call("app/clipboard", "setSensitiveText", "Synthetic transcript")
        val clip = requireNotNull(clipboard.primaryClip)
        assertEquals("Synthetic transcript", clip.getItemAt(0).text)
        assertTrue(clip.description.extras!!.getBoolean(ClipDescription.EXTRA_IS_SENSITIVE))
    }
}
