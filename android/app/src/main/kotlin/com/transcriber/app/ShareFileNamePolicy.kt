package com.transcriber.app

/** Converts an untrusted provider name into one safe path component. */
internal object ShareFileNamePolicy {
    const val fallbackName = "shared_audio"

    private const val maxNameLength = 128

    fun sanitize(name: String?): String {
        val leaf = name
            ?.substringAfterLast('/')
            ?.substringAfterLast('\\')
            ?.trim()
            .orEmpty()
        val sanitized = leaf.map { character ->
            if (character.isISOControl() || character == '/' || character == '\\') {
                '_'
            } else {
                character
            }
        }.joinToString("").take(maxNameLength)

        return sanitized.takeUnless { it.isEmpty() || it == "." || it == ".." }
            ?: fallbackName
    }
}
