package com.transcriber.app

import android.app.Activity
import android.content.ClipData
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ProviderInfo
import android.net.Uri
import android.os.Process
import io.flutter.plugin.common.MethodChannel.Result
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AudioDocumentPickerTest {
    @Test
    fun malformedOrUngrantedResultsCannotReachProviderIo() {
        val checked = mutableListOf<Uri>()
        val picker = AudioDocumentPicker({ _, _ -> }, { _, _ -> error("Unexpected provider access") }) {
            checked.add(it)
            false
        }
        val multiple = audioDocument().apply {
            clipData = ClipData.newRawUri("fixture", fixtureUri).apply {
                addItem(ClipData.Item(Uri.parse("content://fixture/second.wav")))
            }
        }
        val documents = listOf(Intent().setData(Uri.parse("file:///voice.wav")), multiple, audioDocument())
        for (document in documents) {
            val reply = Reply()
            picker.pick(reply)
            picker.onActivityResult(picker.savedRequestCode(), Activity.RESULT_OK, document)
            assertEquals(listOf("audio_import_failed"), reply.errors)
        }
        assertEquals(listOf(fixtureUri), checked)
    }

    @Test
    fun providerMustHaveAnExplicitReadGrantAndBelongToAnotherApp() {
        val context = mock(Context::class.java)
        val packages = mock(PackageManager::class.java)
        val ownPackage = "com.transcriber.app"
        `when`(context.packageName).thenReturn(ownPackage)
        `when`(context.packageManager).thenReturn(packages)
        `when`(
            context.checkUriPermission(
                fixtureUri,
                Process.myPid(),
                Process.myUid(),
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            ),
        ).thenReturn(PackageManager.PERMISSION_DENIED, PackageManager.PERMISSION_GRANTED)
        assertFalse(BoundedAudioImports.canRead(context, fixtureUri))
        val provider = ProviderInfo().apply { packageName = ownPackage }
        `when`(packages.resolveContentProvider("fixture", 0)).thenReturn(provider)
        assertFalse(BoundedAudioImports.canRead(context, fixtureUri))

        provider.packageName = "com.fixture.documents"
        assertTrue(BoundedAudioImports.canRead(context, fixtureUri))
    }

    private fun audioDocument(): Intent = Intent().setDataAndType(fixtureUri, "audio/wav")

    private class Reply : Result {
        val errors = mutableListOf<String>()

        override fun success(result: Any?) = error("Unexpected document acceptance")

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            errors.add(errorCode)
        }

        override fun notImplemented() = error("Unexpected reply")
    }

    private companion object {
        val fixtureUri: Uri = Uri.parse("content://fixture/voice.wav")
    }
}
