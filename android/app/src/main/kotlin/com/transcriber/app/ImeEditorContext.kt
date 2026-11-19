package com.transcriber.app

import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputConnection

/** Guards access to the current InputConnection with a rotating editor session. */
class ImeEditorContext(
    private val service: TranscriberInputMethodService,
) {
    private val gate = EditorSessionGate()
    private var visible = false
    private var composition: Pair<InputConnection, Int>? = null
    private var compositionConfirmed = false

    val sessionId: String
        get() = gate.sessionId

    fun start(editorInfo: EditorInfo?) {
        clearComposition()
        gate.startEditor(EditorFieldPolicy.isSupported(editorInfo))
    }

    fun setVisible(isVisible: Boolean) {
        visible = isVisible
        gate.setVisible(isVisible)
    }

    fun invalidate() {
        clearComposition()
        visible = false
        gate.invalidate()
    }

    fun setComposition(connection: InputConnection, text: String): Boolean {
        val changed = connection.setComposingText(text, 1)
        if (changed) {
            composition = if (text.isEmpty()) null else connection to text.length
            compositionConfirmed = false
        }
        return changed
    }

    fun commitComposition(connection: InputConnection, text: String): Boolean {
        val changed = connection.commitText(text, 1)
        if (changed) composition = null
        return changed
    }

    fun clearComposition(): Boolean {
        val (connection) = composition ?: return false
        composition = null
        val confirmed = compositionConfirmed
        compositionConfirmed = false
        val cleared = confirmed && connection.setComposingText("", 1)
        if (cleared) connection.finishComposingText()
        return cleared
    }

    fun updateSelection(selectionStart: Int, selectionEnd: Int, candidatesStart: Int, candidatesEnd: Int) {
        val expected = composition?.second ?: return
        compositionConfirmed = candidatesStart >= 0 && candidatesEnd - candidatesStart == expected &&
            selectionStart == candidatesEnd && selectionEnd == candidatesEnd
    }

    fun accepts(candidate: String?): Boolean =
        visible && gate.accepts(candidate) && EditorFieldPolicy.isSupported(service.currentInputEditorInfo)

    fun state(microphoneGranted: Boolean): Map<String, Any> {
        val supported = gate.accepts(gate.sessionId) &&
            EditorFieldPolicy.isSupported(service.currentInputEditorInfo)
        return mapOf(
            "sessionId" to gate.sessionId,
            "visible" to visible,
            "supported" to supported,
            "microphoneGranted" to microphoneGranted,
        )
    }
}
