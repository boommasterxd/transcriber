package com.transcriber.app

import android.text.InputType
import android.view.inputmethod.EditorInfo
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EditorFieldPolicyTest {
    @Test
    fun permitsTextButBlocksPasswordPinAndPrivateEditors() {
        assertTrue(EditorFieldPolicy.isSupported(InputType.TYPE_CLASS_TEXT, 0))
        val sensitiveFields = listOf(
            InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_VARIATION_PASSWORD,
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD,
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD,
            InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD,
        )
        sensitiveFields.forEach { assertFalse(EditorFieldPolicy.isSupported(it, 0)) }
        assertFalse(
            EditorFieldPolicy.isSupported(
                InputType.TYPE_CLASS_TEXT,
                EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING,
            ),
        )
    }
}
