package com.transcriber.app

import android.Manifest
import android.content.ComponentName
import android.content.pm.PackageManager
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class InputMethodDeviceTest {
    @Test
    fun realEditorChangesHonorMissingMicrophoneAndProtectPassword() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val target = instrumentation.targetContext
        val component = ComponentName(target, TranscriberInputMethodService::class.java)

        @Suppress("DEPRECATION")
        val service = target.packageManager.getServiceInfo(component, PackageManager.GET_META_DATA)
        assertTrue(service.exported)
        assertEquals(Manifest.permission.BIND_INPUT_METHOD, service.permission)
        assertEquals(R.xml.input_method, service.metaData.getInt("android.view.im"))
        assertEquals(
            "Device test requires an isolated app with the microphone permission denied",
            PackageManager.PERMISSION_DENIED,
            target.checkSelfPermission(Manifest.permission.RECORD_AUDIO),
        )
        val transcriber = component.flattenToShortString()
        DeviceUi(instrumentation).use { ui ->
            val previous = ui.shell("settings get secure default_input_method")
            assertTrue(
                "Device test requires a previous system keyboard",
                previous.contains('/') && previous != transcriber,
            )
            val alreadyEnabled = ui.shell("ime list -s").lineSequence().any { it == transcriber }
            try {
                ui.shell("ime enable $transcriber")
                ui.shell("ime set $transcriber")
                assertEquals(transcriber, ui.shell("settings get secure default_input_method"))
                ui.launchFixture()
                ui.tap("Ordinary fixture editor")
                ui.tap("Ready for live dictation", "Bereit für Live-Diktat")
                ui.requireLabel(
                    "Allow microphone access in app settings.",
                    "Erlaube den Mikrofonzugriff in den App-Einstellungen.",
                )
                ui.tap("Protected fixture editor")
                ui.requireLabel(
                    "Dictation is disabled in this protected text field.",
                    "In diesem geschützten Textfeld ist Diktieren deaktiviert.",
                )
            } finally {
                ui.shell("ime set $previous")
                if (!alreadyEnabled) ui.shell("ime disable $transcriber")
            }
        }
    }
}
