package com.transcriber.app

import android.text.InputType
import android.view.inputmethod.EditorInfo

/** Classifies editor metadata without reading any surrounding field text. */
object EditorFieldPolicy {
    fun isSupported(editorInfo: EditorInfo?): Boolean = editorInfo?.let {
        isSupported(it.inputType, it.imeOptions)
    } ?: false

    fun isSupported(inputType: Int, imeOptions: Int): Boolean {
        val isText = inputType != InputType.TYPE_NULL &&
            inputType and InputType.TYPE_MASK_CLASS == InputType.TYPE_CLASS_TEXT
        val blocksPersonalizedLearning =
            imeOptions and EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING != 0
        return isText && !blocksPersonalizedLearning &&
            !isPassword(inputType)
    }

    private fun isPassword(inputType: Int): Boolean {
        val variation = inputType and InputType.TYPE_MASK_VARIATION
        return variation == InputType.TYPE_TEXT_VARIATION_PASSWORD ||
            variation == InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD ||
            variation == InputType.TYPE_TEXT_VARIATION_WEB_PASSWORD
    }
}
