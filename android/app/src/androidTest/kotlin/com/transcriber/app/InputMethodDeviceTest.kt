package com.transcriber.app

import android.Manifest
import android.content.ComponentName
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.InputConnection
import android.view.inspector.WindowInspector
import android.widget.EditText
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.CompletableFuture
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

@RunWith(AndroidJUnit4::class)
class InputMethodDeviceTest {
    @Test
    fun externalEditorReceivesDictationTextAndHonorsInputRestrictions() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val target = instrumentation.targetContext
        val fixture = instrumentation.context
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
        assertEquals(target.applicationInfo.uid, Process.myUid())
        assertNotEquals(Process.myUid(), fixture.applicationInfo.uid)
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
                ui.tap(ExternalDeviceFixtureActivity.EDITOR_PREFIX)
                ui.tap("Ready for live dictation", "Bereit für Live-Diktat")
                ui.requireLabel(
                    "Allow microphone access in app settings.",
                    "Erlaube den Mikrofonzugriff in den App-Einstellungen.",
                )
                verifyTextDelivery(ui, fixture.packageName)
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

    private fun verifyTextDelivery(ui: DeviceUi, fixturePackage: String) {
        val prefix = ExternalDeviceFixtureActivity.EDITOR_PREFIX
        val draft = " initial draft"
        val transcript = " committed dictation"
        val discarded = " discarded draft"
        val committed = prefix + transcript
        ui.requireEditorText(fixturePackage, prefix)
        val ime = awaitOnMain("Transcriber did not attach to the external fixture editor") {
            findFixtureIme(fixturePackage)
        }
        val (editor, sessionId) = awaitOnMain("Could not read the active editor session") {
            ime.editorContext().let { it to it.sessionId }
        }
        fun activeConnection(): InputConnection {
            assertEquals(fixturePackage, ime.currentInputEditorInfo?.packageName)
            assertTrue(ime.isInputViewShown && editor.accepts(sessionId))
            return checkNotNull(ime.currentInputConnection)
        }
        awaitOnMain("Could not compose the initial draft") {
            val connection = activeConnection()
            assertTrue(connection.setSelection(prefix.length, prefix.length))
            assertTrue(editor.setComposition(connection, draft))
        }
        ui.requireEditorText(fixturePackage, prefix + draft)
        awaitOnMain("Could not commit the dictation") {
            assertTrue(editor.commitComposition(activeConnection(), transcript))
        }
        ui.requireEditorText(fixturePackage, committed)
        awaitOnMain("Could not compose the discarded draft") {
            assertTrue(editor.setComposition(activeConnection(), discarded))
        }
        ui.requireEditorText(fixturePackage, committed + discarded)
        val confirmation = ImeEditorContext::class.java.fixtureField("compositionConfirmed")
        awaitOnMain("The external editor did not acknowledge the composing span") {
            activeConnection()
            if (!confirmation.getBoolean(editor)) return@awaitOnMain null
            assertTrue(editor.clearComposition())
        }
        ui.requireEditorText(fixturePackage, committed)
    }

    private fun DeviceUi.requireEditorText(fixturePackage: String, expected: String) {
        val node = requireLabel(expected)
        assertEquals(fixturePackage, node.packageName?.toString())
        assertEquals(EditText::class.java.name, node.className?.toString())
        assertTrue(node.isEditable && node.isFocused)
        assertEquals(expected, node.text?.toString())
    }

    private fun findFixtureIme(fixturePackage: String): TranscriberInputMethodService? {
        check(Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) { "IME device tests require API 29 or later" }
        return WindowInspector.getGlobalWindowViews().firstNotNullOfOrNull { root ->
            root.findImeService()?.takeIf { ime ->
                ime.isInputViewShown && ime.currentInputEditorInfo?.packageName == fixturePackage
            }
        }
    }

    private fun View.findImeService(): TranscriberInputMethodService? =
        (context as? TranscriberInputMethodService) ?: if (this is ViewGroup) {
            (0 until childCount).firstNotNullOfOrNull { index -> getChildAt(index).findImeService() }
        } else {
            null
        }

    // Reuse the live coordinator's editor and Android's real selection acknowledgment.
    private fun TranscriberInputMethodService.editorContext(): ImeEditorContext {
        assertEquals(Process.myUid(), applicationInfo.uid)
        val coordinator = TranscriberInputMethodService::class.java.fixtureField("coordinator").get(this)
        return ImeSessionCoordinator::class.java.fixtureField("editor").get(coordinator) as ImeEditorContext
    }

    private fun Class<*>.fixtureField(name: String) = getDeclaredField(name).apply { isAccessible = true }

    private fun <T : Any> awaitOnMain(description: String, operation: () -> T?): T {
        val main = Handler(Looper.getMainLooper())
        val result = CompletableFuture<T>()
        val probe = object : Runnable {
            override fun run() {
                if (result.isDone) return
                val value = runCatching(operation).getOrElse {
                    result.completeExceptionally(it)
                    return
                }
                if (value == null) {
                    main.postDelayed(this, pollIntervalMillis)
                } else {
                    result.complete(value)
                }
            }
        }
        check(main.post(probe))
        try {
            return result.get(editorTimeoutSeconds, TimeUnit.SECONDS)
        } catch (failure: TimeoutException) {
            throw AssertionError(description, failure)
        } catch (failure: ExecutionException) {
            throw failure.cause ?: failure
        } finally {
            result.cancel(false)
            main.removeCallbacks(probe)
        }
    }

    private companion object {
        const val editorTimeoutSeconds = 10L
        const val pollIntervalMillis = 25L
    }
}
