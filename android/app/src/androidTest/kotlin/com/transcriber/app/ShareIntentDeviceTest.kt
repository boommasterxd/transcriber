package com.transcriber.app

import android.content.Intent
import android.content.pm.PackageManager
import android.os.Process
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ShareIntentDeviceTest {
    @Test
    fun shareFromAnotherAppOffersConfirmationAndReturnsOnCancel() =
        verifySharedAudio(Intent.ACTION_SEND, "Send fixture audio")

    @Test
    fun openFromAnotherAppOffersConfirmationAndReturnsOnCancel() =
        verifySharedAudio(Intent.ACTION_VIEW, "Open fixture audio")

    private fun verifySharedAudio(action: String, button: String) {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val target = instrumentation.targetContext
        val fixture = instrumentation.context
        val uri = FixtureAudioProvider.uri(fixture.packageName, action)
        assertTrue("Fixture provider must have a different UID", fixture.applicationInfo.uid != Process.myUid())
        assertEquals(
            PackageManager.PERMISSION_DENIED,
            target.checkUriPermission(uri, Process.myPid(), Process.myUid(), Intent.FLAG_GRANT_READ_URI_PERMISSION),
        )
        DeviceUi(instrumentation).use { ui ->
            ui.launchFixture(target.packageName)
            ui.tap(button)
            ui.requireLabel("Transcribe audio?", "Audio transkribieren?")
            assertEquals(
                PackageManager.PERMISSION_GRANTED,
                target.checkUriPermission(uri, Process.myPid(), Process.myUid(), Intent.FLAG_GRANT_READ_URI_PERMISSION),
            )
            ui.tap("Cancel", "Abbrechen")
            assertEquals(fixture.packageName, ui.requireActiveLabel(button).packageName?.toString())
        }
    }
}
