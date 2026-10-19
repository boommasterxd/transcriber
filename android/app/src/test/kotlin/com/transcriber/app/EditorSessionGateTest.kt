package com.transcriber.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EditorSessionGateTest {
    @Test
    fun productionIdentityRotatesAndRejectsHiddenSessions() {
        val gate = EditorSessionGate()
        val initial = gate.sessionId
        gate.startEditor(isSupported = true)
        assertFalse(initial == gate.sessionId)
        assertFalse(gate.accepts(gate.sessionId))
        gate.setVisible(true)
        assertTrue(gate.accepts(gate.sessionId))
        gate.setVisible(false)
        assertFalse(gate.accepts(gate.sessionId))
    }

    @Test
    fun acceptsOnlyVisibleSupportedCurrentSession() {
        val ids = ArrayDeque(listOf("initial", "editor", "invalid"))
        val gate = EditorSessionGate(ids::removeFirst)

        gate.startEditor(isSupported = true)
        gate.setVisible(true)

        assertTrue(gate.accepts("editor"))
        assertFalse(gate.accepts("initial"))
        assertFalse(gate.accepts(null))
    }

    @Test
    fun invalidationRejectsLateResults() {
        val ids = ArrayDeque(listOf("initial", "editor", "invalid"))
        val gate = EditorSessionGate(ids::removeFirst)
        gate.startEditor(isSupported = true)
        gate.setVisible(true)
        val stale = gate.sessionId

        gate.invalidate()

        assertFalse(gate.accepts(stale))
        assertFalse(gate.accepts(gate.sessionId))
    }

    @Test
    fun unsupportedEditorNeverAccepts() {
        val ids = ArrayDeque(listOf("initial", "editor"))
        val gate = EditorSessionGate(ids::removeFirst)
        gate.startEditor(isSupported = false)
        gate.setVisible(true)

        assertFalse(gate.accepts(gate.sessionId))
    }
}
