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

  /// Syncs only the share-target icon. Safe to call any time (the ShareActivity
  /// isn't the running component), so the share-sheet icon matches the accent
  /// immediately, without waiting for the app to be backgrounded.
  Future<void> syncShareIcon(String accentId) async {
    try {
      await _channel.invokeMethod<void>('syncShareIcon', {'accent': accentId});
    } catch (_) {
      // Not available (e.g. non-Android) — ignore.
    }
  }
}
