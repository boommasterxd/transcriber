import 'package:flutter/services.dart';

/// Switches the Android launcher icon to match the selected accent color by
/// toggling per-accent `activity-alias` entries (handled natively). No-op on
/// platforms without the channel.
class AppIconService {
  const AppIconService();

  static const MethodChannel _channel = MethodChannel('app/icon');

  Future<void> setIcon(String accentId) async {
    try {
      await _channel.invokeMethod<void>('setIcon', {'accent': accentId});
    } catch (_) {
      // Not available (e.g. non-Android) — ignore.
    }
  }
}
