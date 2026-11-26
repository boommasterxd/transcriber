package com.transcriber.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EditorSessionGateTest {
    @Test
    fun changingEditorsAndInvalidatingRejectPreviousSessions() {
        val ids = ArrayDeque(listOf("initial", "first", "second", "invalid"))
        val gate = EditorSessionGate(ids::removeFirst)
        gate.startEditor(isSupported = true)
        assertFalse(gate.accepts("first"))
        gate.setVisible(true)
        assertTrue(gate.accepts("first"))
        gate.startEditor(isSupported = true)
        assertFalse(gate.accepts("first"))
        assertTrue(gate.accepts("second"))
        gate.invalidate()
        assertFalse(gate.accepts("second"))
        assertFalse(gate.accepts(gate.sessionId))
    }
}
