package com.transcriber.app

import java.util.UUID

/** Rejects audio and text operations after an editor or visibility change. */
class EditorSessionGate(
    private val idFactory: () -> String = { UUID.randomUUID().toString() },
) {
    var sessionId: String = idFactory()
        private set
    private var visible = false
    private var supported = false

    fun startEditor(isSupported: Boolean) {
        sessionId = idFactory()
        supported = isSupported
    }

    fun setVisible(isVisible: Boolean) {
        visible = isVisible
    }

    fun invalidate() {
        visible = false
        supported = false
        sessionId = idFactory()
    }

    fun accepts(candidate: String?): Boolean =
        visible && supported && candidate == sessionId
}
