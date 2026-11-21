package com.transcriber.app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Process
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.SynchronousQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

internal object BoundedAudioImports {
    private const val importDeadlineMillis = 60_000L

    // A provider ignoring cancellation occupies the single process-wide import slot.
    private val importWorker = ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS, SynchronousQueue())
    private val cleanupWorker = ThreadPoolExecutor(1, 1, 0L, TimeUnit.MILLISECONDS, ArrayBlockingQueue(1))

    fun createControl() = ShareImportControl(cleanupWorker)

    fun canRead(context: Context, uri: Uri): Boolean {
        val authority = uri.authority?.substringAfter('@') ?: return false
        return try {
            val granted = context.checkUriPermission(
                uri,
                Process.myPid(),
                Process.myUid(),
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            ) == PackageManager.PERMISSION_GRANTED
            granted && context.packageManager.resolveContentProvider(authority, 0)?.packageName?.let {
                it != context.packageName
            } == true
        } catch (_: SecurityException) {
            false
        }
    }

    fun createCoordinator(control: ShareImportControl): ShareImportCoordinator {
        val main = Handler(Looper.getMainLooper())
        return ShareImportCoordinator(
            importWorker,
            { main.post(it) },
            { expire ->
                val deadline = Runnable(expire)
                main.postDelayed(deadline, importDeadlineMillis)
                val cancel: () -> Unit = { main.removeCallbacks(deadline) }
                cancel
            },
            control,
        )
    }
}
