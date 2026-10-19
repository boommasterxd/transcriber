package com.transcriber.app

import org.junit.Assert.assertEquals
import org.junit.Test

class ShareFileNamePolicyTest {
    @Test
    fun emptyAndDotNamesUseSafeFallback() {
        for (name in listOf(null, "", " ", ".", "..", "/", "\\")) {
            assertEquals("shared_audio", ShareFileNamePolicy.sanitize(name))
        }
    }

    @Test
    fun pathsControlCharactersAndLengthAreBounded() {
        assertEquals("voice_.wav", ShareFileNamePolicy.sanitize("../../folder\\voice\u0000.wav"))
        assertEquals("voice.wav", ShareFileNamePolicy.sanitize("  voice.wav  "))
        assertEquals("a".repeat(128), ShareFileNamePolicy.sanitize("a".repeat(200)))
    }
}
