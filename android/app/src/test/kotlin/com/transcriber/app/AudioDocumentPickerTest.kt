package com.transcriber.app

import android.app.Activity
import android.content.ActivityNotFoundException
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
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.mockito.Mockito.mock
import org.mockito.Mockito.`when`
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import java.util.concurrent.Executor

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [35])
class AudioDocumentPickerTest {
    @get:Rule
    val temporary = TemporaryFolder()

    @Test
    fun selectionUsesOpenDocumentAndDeliversOwnedAudioOnce() {
        val audio = temporary.newFile("123_fixture_voice_note.wav")
        val fixture = Fixture(audio)
        val reply = Reply()
        fixture.picker.pick(reply)
        val (intent, code) = fixture.launches.single()
        assertEquals(Intent.ACTION_OPEN_DOCUMENT, intent.action)
        assertEquals("audio/*", intent.type)
        assertTrue(intent.hasCategory(Intent.CATEGORY_OPENABLE))
        assertEquals(Intent.FLAG_GRANT_READ_URI_PERMISSION, intent.flags)
        assertFalse(intent.getBooleanExtra(Intent.EXTRA_ALLOW_MULTIPLE, false))
        assertTrue(fixture.worker.isEmpty())

        val duplicate = Reply()
        fixture.picker.pick(duplicate)
        assertEquals(listOf<Any?>(null), duplicate.successes)
        assertEquals(1, fixture.launches.size)

        assertTrue(fixture.picker.onActivityResult(code, Activity.RESULT_OK, audioDocument()))
        assertTrue(reply.successes.isEmpty())
        assertEquals(0, fixture.picker.savedRequestCode())
        fixture.finishImport()
        assertEquals(listOf(mapOf("path" to audio.path, "fileName" to "voice_note.wav")), reply.successes)

        assertTrue(fixture.picker.onActivityResult(code, Activity.RESULT_OK, audioDocument()))
        fixture.picker.cancel()
        assertTrue(audio.exists())
        assertTrue(fixture.worker.isEmpty())
        assertEquals(1, reply.successes.size)
    }

    @Test
    fun reopenedActivityRecoversAnOutstandingSystemPickerResult() {
        val original = Fixture()
        original.picker.pick(Reply())
        val code = original.picker.savedRequestCode()
        original.picker.cancel()
        val audio = temporary.newFile("123_fixture_recovered.wav")
        val restarted = Fixture(audio)
        restarted.picker.restore(code)
        restarted.picker.onActivityResult(code, Activity.RESULT_OK, audioDocument())
        restarted.finishImport()
        assertTrue(restarted.launches.isEmpty())

        val recovered = Reply()
        restarted.picker.recover(recovered)
        assertEquals(listOf(mapOf("path" to audio.path, "fileName" to "recovered.wav")), recovered.successes)
        val next = Reply()
        restarted.picker.recover(next)
        assertEquals(listOf<Any?>(null), next.successes)
    }

    @Test
    fun aLivePickSupersedesRecoveryAndIgnoresTheOldResult() {
        val fixture = Fixture()
        fixture.picker.pick(Reply())
        val old = fixture.picker.savedRequestCode()
        val restarted = Fixture()
        restarted.picker.restore(old)
        val recovery = Reply()
        restarted.picker.recover(recovery)
        val live = Reply()
        restarted.picker.pick(live)
        val new = restarted.picker.savedRequestCode()

        assertNotEquals(old, new)
        assertEquals(listOf<Any?>(null), recovery.successes)
        restarted.picker.onActivityResult(old, Activity.RESULT_OK, audioDocument())
        assertTrue(live.successes.isEmpty())
        assertTrue(restarted.worker.isEmpty())
        restarted.picker.onActivityResult(new, Activity.RESULT_CANCELED, null)
        assertEquals(listOf<Any?>(null), live.successes)
    }

    @Test
    fun malformedOrUngrantedResultsCannotReachProviderIo() {
        val fixture = Fixture()
        val multiple = audioDocument().apply {
            clipData = ClipData.newRawUri("fixture", fixtureUri).apply {
                addItem(ClipData.Item(Uri.parse("content://fixture/second.wav")))
            }
        }
        val documents = listOf(null, Intent().setData(Uri.parse("file:///voice.wav")), multiple, audioDocument())
        fixture.readAllowed = false
        for (document in documents) {
            val reply = Reply()
            fixture.picker.pick(reply)
            fixture.picker.onActivityResult(fixture.picker.savedRequestCode(), Activity.RESULT_OK, document)
            assertEquals(listOf("audio_import_failed"), reply.errors)
            assertTrue(fixture.worker.isEmpty())
        }
        assertFalse(fixture.picker.onActivityResult(431, Activity.RESULT_OK, audioDocument()))
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

        assertFalse(BoundedAudioImports.canRead(context, fixtureUri))
        val provider = ProviderInfo().apply { packageName = ownPackage }
        `when`(packages.resolveContentProvider("fixture", 0)).thenReturn(provider)
        assertFalse(BoundedAudioImports.canRead(context, fixtureUri))

        provider.packageName = "com.fixture.documents"
        assertTrue(BoundedAudioImports.canRead(context, fixtureUri))
    }

    @Test
    fun expiryAndDisposalReleaseTheReplyAndRemoveUnclaimedOutput() {
        for (expires in listOf(false, true)) {
            val audio = temporary.newFile()
            val fixture = Fixture(audio)
            val reply = Reply()
            fixture.picker.pick(reply)
            fixture.picker.onActivityResult(fixture.picker.savedRequestCode(), Activity.RESULT_OK, audioDocument())
            fixture.worker.removeFirst().run()
            assertTrue(audio.exists())

            if (expires) fixture.expire() else fixture.picker.cancel()
            fixture.dispatch.removeFirst().invoke()

            assertFalse(audio.exists())
            assertEquals(if (expires) listOf("audio_import_failed") else emptyList(), reply.errors)
            assertEquals(if (expires) emptyList() else listOf<Any?>(null), reply.successes)
            val next = Reply()
            fixture.picker.pick(next)
            fixture.picker.onActivityResult(fixture.picker.savedRequestCode(), Activity.RESULT_CANCELED, null)
            assertEquals(listOf<Any?>(null), next.successes)
        }
    }

    @Test
    fun missingPickerFailsWithoutLeavingARequestToRecover() {
        val picker = AudioDocumentPicker(
            { _, _ -> throw ActivityNotFoundException() },
            { _, _ -> error("No document was selected") },
            { false },
        )
        val reply = Reply()
        picker.pick(reply)
        assertEquals(listOf("audio_import_failed"), reply.errors)
        assertEquals(0, picker.savedRequestCode())
    }

    private fun audioDocument(): Intent = Intent().setDataAndType(fixtureUri, "audio/wav")

    private class Fixture(audio: File? = null) {
        val launches = mutableListOf<Pair<Intent, Int>>()
        val worker = ArrayDeque<Runnable>()
        val dispatch = ArrayDeque<() -> Unit>()
        var expire: () -> Unit = {}
        var readAllowed = true
        val picker = AudioDocumentPicker(
            { intent, code -> launches.add(intent to code) },
            { _, _ -> importAudio(audio) },
            { readAllowed },
        )

        fun finishImport() {
            worker.removeFirst().run()
            dispatch.removeFirst().invoke()
        }

        private fun importAudio(audio: File?): ShareImportCoordinator {
            val control = ShareImportControl(Executor { it.run() })
            val coordinator = ShareImportCoordinator(
                Executor { worker.add(it) },
                { dispatch.add(it) },
                { deadline ->
                    expire = deadline
                    val cancel: () -> Unit = {}
                    cancel
                },
                control,
            )
            coordinator.start { audio?.takeIf(control::track)?.path }
            return coordinator
        }
    }

    private class Reply : Result {
        val successes = mutableListOf<Any?>()
        val errors = mutableListOf<String>()

        override fun success(result: Any?) {
            successes.add(result)
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            errors.add(errorCode)
        }

        override fun notImplemented() = error("Unexpected reply")
    }

    private companion object {
        val fixtureUri: Uri = Uri.parse("content://fixture/voice.wav")
    }
}
