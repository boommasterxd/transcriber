package com.transcriber.app

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File

/** Owns bounded WAV capture independently of Dart timers and lifecycle pauses. */
class BoundedRecordingChannel(context: Context, messenger: BinaryMessenger) {
    private val appContext = context.applicationContext
    private val channel = MethodChannel(
        messenger,
        "app/recording",
        StandardMethodCodec.INSTANCE,
        messenger.makeBackgroundTaskQueue(),
    )
    private val recorder = PcmAudioRecorder(context, ::onChunk) { finishCapture(failed = true) }
    private var writer: BoundedWaveWriter? = null
    private var path: String? = null
    private var level = 0.0

    @Volatile private var stopped = true
    private var limited = false
    private var failed = false
    private var disposed = false

    fun register() {
        channel.setMethodCallHandler(::handle)
    }

    @Synchronized
    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            check(!disposed) { "The recording channel is disposed." }
            when (call.method) {
                "start" -> start(call, result)
                "pause" -> result.success(!stopped && recorder.pause())
                "resume" -> result.success(!stopped && recorder.resume())
                "progress" -> result.success(progress())
                "stop" -> {
                    finishCapture()
                    writer?.finish()
                    result.success(path)
                }
                "cancel" -> {
                    disposeCapture()
                    path = null
                    result.success(null)
                }
                "dispose" -> {
                    disposeCapture(preserve = true)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("recording_failed", "Unable to complete audio capture. Please retry.", null)
        }
    }

    @Synchronized
    private fun start(call: MethodCall, result: MethodChannel.Result) {
        check(stopped) { "A recording is already active." }
        writer?.finish()
        val destination = File(requireNotNull(call.argument<String>("path"))).canonicalFile
        val root = File(appContext.cacheDir, "audio/recording").canonicalFile
        require(destination.parentFile == root && destination.extension == "wav")
        val maxBytes = requireNotNull(call.argument<Number>("maxBytes")).toLong()
        val nextWriter = BoundedWaveWriter(destination, maxBytes)
        path = destination.path
        writer = nextWriter
        limited = false
        failed = false
        level = 0.0
        stopped = false
        if (!recorder.start(BoundedWaveWriter.sampleRate)) {
            disposeCapture()
            destination.delete()
            path = null
            error("Unable to start audio capture.")
        }
        result.success(path)
    }

    @Synchronized
    private fun onChunk(bytes: ByteArray, level: Double) {
        if (stopped) return
        try {
            limited = writer?.append(bytes) ?: true
            this.level = level
            if (limited) finishCapture()
        } catch (_: Exception) {
            finishCapture(failed = true)
        }
    }

    @Synchronized
    private fun finishCapture(failed: Boolean = false) {
        recorder.stop()
        stopped = true
        this.failed = this.failed || failed
        try {
            writer?.finish()
        } catch (_: Exception) {
            this.failed = true
        }
    }

    @Synchronized
    private fun progress(): Map<String, Any> = mapOf(
        "bytes" to (writer?.dataBytes ?: 0L),
        "level" to level,
        "stopped" to stopped,
        "limited" to limited,
        "failed" to failed,
    )

    @Synchronized
    private fun disposeCapture(preserve: Boolean = false) {
        recorder.stop()
        stopped = true
        val destination = writer
        writer = null
        try {
            if (preserve) destination?.finish()
        } finally {
            destination?.close()
        }
    }

    @Synchronized
    fun dispose() {
        if (disposed) return
        disposed = true
        channel.setMethodCallHandler(null)
        try {
            // Abandoned temporary capture needs no blocking fsync on engine cleanup.
            disposeCapture()
        } catch (_: java.io.IOException) {
            // Lifecycle cleanup must release capture even when storage fails.
        }
    }
}
