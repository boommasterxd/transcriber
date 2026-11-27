package com.transcriber.app

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/** Routes temporary audio operations to the process cache through this engine's owner. */
internal class AudioCacheChannel(messenger: BinaryMessenger, val owner: AudioCacheQuota.Owner) {
    private val channel = MethodChannel(
        messenger,
        "app/audio_cache",
        StandardMethodCodec.INSTANCE,
        messenger.makeBackgroundTaskQueue(),
    )

    fun register() {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "owns" -> result.success(owner.owns(requireNotNull(call.arguments as? String)))
                    "discard" -> result.success(owner.discard(requireNotNull(call.arguments as? String)))
                    "cleanup" -> {
                        owner.cleanup(call.arguments == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("audio_cache_failed", "Unable to access the audio cache.", null)
            }
        }
    }

    fun dispose() {
        owner.close()
        channel.setMethodCallHandler(null)
    }
}
