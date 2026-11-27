import 'package:flutter/services.dart';

/// The engine-scoped bridge to Android's shared temporary audio cache.
final class AudioCacheQuota {
  const AudioCacheQuota();

  static const _channel = MethodChannel('app/audio_cache');

  Future<bool> owns(String path) async =>
      await _channel.invokeMethod<bool>('owns', path) ?? false;

  Future<bool> discard(String path) async =>
      await _channel.invokeMethod<bool>('discard', path) ?? false;

  Future<void> cleanup({required bool enforceQuota}) =>
      _channel.invokeMethod<void>('cleanup', enforceQuota);
}
