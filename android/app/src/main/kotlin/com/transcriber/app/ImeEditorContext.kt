package com.transcriber.app

import android.view.inputmethod.EditorInfo

/** Guards access to the current InputConnection with a rotating editor session. */
class ImeEditorContext(
    private val service: TranscriberInputMethodService,
) {
    private val gate = EditorSessionGate()
    private var visible = false

    val sessionId: String
        get() = gate.sessionId

    fun start(editorInfo: EditorInfo?) {
        gate.startEditor(EditorFieldPolicy.isSupported(editorInfo))
    }

    fun setVisible(isVisible: Boolean) {
        visible = isVisible
        gate.setVisible(isVisible)
    }

    fun invalidate() {
        service.currentInputConnection?.finishComposingText()
        visible = false
        gate.invalidate()
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
