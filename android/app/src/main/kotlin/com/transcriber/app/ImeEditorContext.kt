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
        gate.invalidate()
    }

    fun accepts(candidate: String?): Boolean =
        visible && gate.accepts(candidate) && EditorFieldPolicy.isSupported(service.currentInputEditorInfo)

    fun state(microphoneGranted: Boolean): Map<String, Any> = mapOf(
        "sessionId" to gate.sessionId,
        "visible" to visible,
        "supported" to (visible && EditorFieldPolicy.isSupported(service.currentInputEditorInfo)),
        "microphoneGranted" to microphoneGranted,
    )
}
