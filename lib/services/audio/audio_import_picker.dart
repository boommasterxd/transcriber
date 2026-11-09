import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';

import '../../data/models/audio_import_selection.dart';

class AudioImportPickerService {
  bool _recoveryAttempted = false;
  bool _liveRequested = false;
  Future<AudioImportSelection?>? _recovery;
  Future<AudioImportSelection?>? _livePick;

  bool get recoverySuperseded => _liveRequested;

  Future<AudioImportSelection?> recoverInterruptedPick() {
    if (_recoveryAttempted) return Future.value(null);
    _recoveryAttempted = true;
    if (_livePick != null) return Future.value(null);
    return _recovery = _recover();
  }

  Future<AudioImportSelection?> _recover() async {
    if (FilePickerPlatform.instance case final FilePickerAndroid android) {
      try {
        final result = await android.retrieveLostData().timeout(
          const Duration(seconds: 60),
        );
        if (_liveRequested || result == null) return null;
        if (result.exception case final exception?) throw exception;
        if (result.files.length > 1) {
          throw const FormatException('Expected a single audio file');
        }
        return _selection(result.files.firstOrNull);
      } catch (_) {
        if (_liveRequested) return null;
        rethrow;
      }
    }
    return null;
  }

  Future<AudioImportSelection?> pick() {
    if (_livePick != null) return Future.value(null);
    _liveRequested = true;
    final pending = _pick();
    _livePick = pending;
    return pending.whenComplete(() => _livePick = null);
  }

  Future<AudioImportSelection?> _pick() async {
    try {
      await _recovery;
    } catch (_) {
      // A failed recovery must not prevent a new selection.
    }
    return _selection(await FilePicker.pickFile(type: FileType.audio));
  }

  AudioImportSelection? _selection(PlatformFile? file) {
    final path = file?.path;
    if (file == null ||
        path == null ||
        path.trim().isEmpty ||
        file.name.trim().isEmpty) {
      return null;
    }
    return AudioImportSelection(path: path, fileName: file.name);
  }
}
