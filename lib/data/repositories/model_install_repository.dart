import 'package:shared_preferences/shared_preferences.dart';

/// Tracks which on-device Whisper models have been downloaded. (Gemma models are
/// detected by file presence via [GemmaEngine].)
class ModelInstallRepository {
  ModelInstallRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _whisperKey = 'downloaded_whisper';

  Set<String> downloadedWhisperIds() =>
      (_prefs.getStringList(_whisperKey) ?? const <String>[]).toSet();

  Future<void> markWhisper(String id) async {
    final set = downloadedWhisperIds()..add(id);
    await _prefs.setStringList(_whisperKey, set.toList());
  }

  Future<void> unmarkWhisper(String id) async {
    final set = downloadedWhisperIds()..remove(id);
    await _prefs.setStringList(_whisperKey, set.toList());
  }
}
