package com.transcriber.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.BadParcelableException
import io.flutter.plugin.common.MethodChannel.Result

/** Main-thread lifetime of a single Android document request. */
internal class AudioDocumentPicker(
    private val launch: (Intent, Int) -> Unit,
    private val startImport: (Uri, String?) -> ShareImportCoordinator,
    private val canRead: (Uri) -> Boolean,
) {
    private var pending: Pick? = null
    private var nextRequestCode = requestCodes.first

    fun restore(requestCode: Int) {
        if (requestCode !in requestCodes) return
        nextRequestCode = followingCode(requestCode)
        pending = Pick(requestCode, recovered = true)
    }

    fun savedRequestCode(): Int = pending?.takeIf { it.awaitingDocument }?.code ?: 0

    fun pick(reply: Result) {
        if (pending?.recovered == false) {
            reply.success(null)
            return
        }
        cancel()
        val request = Pick(nextRequestCode, recovered = false, reply = reply)
        nextRequestCode = followingCode(request.code)
        pending = request
        try {
            launch(documentIntent(), request.code)
        } catch (_: ActivityNotFoundException) {
            fail(request)
        } catch (_: SecurityException) {
            fail(request)
        }
    }

    fun recover(reply: Result) {
        val request = pending?.takeIf { it.recovered && it.reply == null }
        if (request == null) {
            reply.success(null)
            return
        }
        request.reply = reply
        if (request.failed) fail(request) else observeImport(request)
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode !in requestCodes) return false
        val request = pending
        if (request != null && request.code == requestCode && request.awaitingDocument) {
            request.awaitingDocument = false
            if (resultCode == Activity.RESULT_OK) accept(request, data) else cancel()
        }
        return true
    }

    fun cancel() {
        val request = pending ?: return
        pending = null
        request.import?.cancel()
        request.reply?.success(null)
    }

    private fun accept(request: Pick, data: Intent?) {
        val uri = documentUri(data)
        if (uri == null || !canRead(uri)) {
            fail(request)
            return
        }
        request.import = startImport(uri, data?.type)
        observeImport(request)
    }

    private fun observeImport(request: Pick) {
        val reply = request.reply ?: return
        request.import?.takePath { path ->
            if (pending !== request) return@takePath
            if (path == null) {
                fail(request)
            } else {
                pending = null
                reply.success(mapOf("path" to path, "fileName" to ShareAudioCache.displayNameFromPath(path)))
            }
        }
    }

    private fun fail(request: Pick) {
        val reply = request.reply
        if (reply == null) {
            request.failed = true
        } else {
            pending = null
            reply.error("audio_import_failed", "Unable to import selected audio", null)
        }
    }

    private fun followingCode(code: Int): Int = if (code == requestCodes.last) requestCodes.first else code + 1

    private class Pick(val code: Int, val recovered: Boolean, var reply: Result? = null) {
        var awaitingDocument = true
        var import: ShareImportCoordinator? = null
        var failed = false
    }

    private companion object {
        val requestCodes = 0x4600..0x46FF
    }
}

private fun documentUri(data: Intent?): Uri? = try {
    val uri = data?.data
    val clip = data?.clipData
    uri?.takeIf {
        it.scheme == ContentResolver.SCHEME_CONTENT && !it.authority.isNullOrBlank() &&
            (clip == null || (clip.itemCount == 1 && clip.getItemAt(0).uri == it))
    }
} catch (_: BadParcelableException) {
    null
}

private fun documentIntent() = Intent(Intent.ACTION_OPEN_DOCUMENT)
    .addCategory(Intent.CATEGORY_OPENABLE)
    .setType("audio/*")
    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
