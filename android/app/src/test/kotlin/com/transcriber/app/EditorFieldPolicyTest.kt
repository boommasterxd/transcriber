package com.transcriber.app

import android.text.InputType
import android.view.inputmethod.EditorInfo
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EditorFieldPolicyTest {
    @Test
    fun acceptsOrdinaryAndMultilineText() {
        assertTrue(EditorFieldPolicy.isSupported(InputType.TYPE_CLASS_TEXT, 0))
        assertTrue(
            EditorFieldPolicy.isSupported(
                InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_MULTI_LINE,
                0,
            ),
        )
    }

    @Test
    fun rejectsNonTextAndSensitiveText() {
        assertFalse(EditorFieldPolicy.isSupported(InputType.TYPE_NULL, 0))
        assertFalse(EditorFieldPolicy.isSupported(InputType.TYPE_CLASS_NUMBER, 0))
        assertFalse(
            EditorFieldPolicy.isSupported(
                InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD,
                0,
            ),
        )
        assertFalse(
            EditorFieldPolicy.isSupported(
                InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD,
                0,
            ),
        )
        assertFalse(
            EditorFieldPolicy.isSupported(
                InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD,
                0,
            ),
        )
    }

    @Test
    fun rejectsEditorsThatDisallowPersonalizedLearning() {
        assertFalse(
            EditorFieldPolicy.isSupported(
                InputType.TYPE_CLASS_TEXT,
                EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING,
            ),
        )
    }
}
