package com.transcriber.app

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.io.IOException

/** Owns bounded WAV capture independently of Dart timers and lifecycle pauses. */
internal class BoundedRecordingChannel(
    context: Context,
    messenger: BinaryMessenger,
    private val cacheOwner: AudioCacheQuota.Owner = AudioCacheQuota.shared.owner(context.cacheDir),
) {
    private val channel = MethodChannel(
        messenger,
        "app/recording",
        StandardMethodCodec.INSTANCE,
        messenger.makeBackgroundTaskQueue(),
    )
    private val recorder = PcmAudioRecorder(context, ::onChunk) { finishCapture(failed = true) }
    private var writer: BoundedRecordingFile? = null
    private var path: String? = null
    private var level = 0.0

    @Volatile private var stopped = true
    private var limited = false
    private var failed = false
    private var disposed = false

    fun register() {
        channel.setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            if (call.method == "start") start(call, result) else handleCapture(call, result)
        } catch (_: Exception) {
            result.error("recording_failed", "Unable to complete audio capture. Please retry.", null)
        }
    }

    @Synchronized
    private fun handleCapture(call: MethodCall, result: MethodChannel.Result) {
        check(!disposed) { "The recording channel is disposed." }
        when (call.method) {
            "pause" -> result.success(!stopped && recorder.pause())
            "resume" -> result.success(!stopped && recorder.resume())
            "progress" -> result.success(
                mapOf(
                    "bytes" to (writer?.dataBytes ?: 0L),
                    "level" to level,
                    "stopped" to stopped,
                    "limited" to limited,
                    "failed" to failed,
                ),
            )
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
    }

    private fun start(call: MethodCall, result: MethodChannel.Result) {
        checkCanStart()
        val destination = File(requireNotNull(call.argument<String>("path")))
        val maxBytes = requireNotNull(call.argument<Number>("maxBytes")).toLong()
        val minimumBytes = BoundedWaveWriter.headerBytes + BoundedWaveWriter.bytesPerSample
        require(maxBytes in minimumBytes..BoundedWaveWriter.maxSupportedBytes)
        require((maxBytes - BoundedWaveWriter.headerBytes) % BoundedWaveWriter.bytesPerSample == 0L)
        val reservation = cacheOwner.reserveRecording(destination, maxBytes)
        BoundedRecordingFile.withNewPath(reservation) { startCapture(reservation) }
        result.success(reservation.file.path)
    }

    @Synchronized
    private fun checkCanStart() {
        check(!disposed && stopped) { "Recording is unavailable." }
    }

    @Synchronized
    private fun startCapture(reservation: AudioCacheQuota.Lease) {
        checkCanStart()
        writer?.finish()
        writer = BoundedRecordingFile(reservation)
        path = reservation.file.path
        limited = false
        failed = false
        level = 0.0
        stopped = false
        var started = false
        try {
            started = recorder.start(BoundedWaveWriter.sampleRate)
            check(started) { "Unable to start audio capture." }
        } finally {
            if (!started) {
                try {
                    disposeCapture()
                } finally {
                    path = null
                }
            }
        }
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
    private fun disposeCapture(preserve: Boolean = false) {
        try {
            recorder.stop()
        } finally {
            stopped = true
            val destination = writer
            writer = null
            destination?.close(preserve)
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
        } catch (_: IOException) {
            // Lifecycle cleanup must release capture even when storage fails.
        } finally {
            cacheOwner.close()
        }
    }
}
