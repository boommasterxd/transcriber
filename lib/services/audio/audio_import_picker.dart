import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../data/models/audio_import_selection.dart';

class AudioImportPickerService {
  static const _channel = MethodChannel('app/audio_import');

  bool _recoveryAttempted = false;
  bool _liveRequested = false;
  bool _picking = false;

  bool get recoverySuperseded => _liveRequested;

  Future<AudioImportSelection?> recoverInterruptedPick() async {
    if (_recoveryAttempted || _liveRequested) return null;
    _recoveryAttempted = true;
    try {
      return await _select('recoverInterruptedPick');
    } on MissingPluginException {
      return null;
    }
  }

  Future<AudioImportSelection?> pick() async {
    if (_picking) return null;
    _liveRequested = true;
    _picking = true;
    try {
      return await _select('pick');
    } finally {
      _picking = false;
    }
  }

  Future<AudioImportSelection?> _select(String method) async {
    final result = await _channel.invokeMethod<Object?>(method);
    if (result == null) return null;
    if (result case {'path': final String path, 'fileName': final String name}
        when p.isAbsolute(path) &&
            name.trim().isNotEmpty &&
            name == p.basename(name) &&
            !name.contains('\\')) {
      return AudioImportSelection(path: path, fileName: name);
    }
    throw const FormatException('Invalid cached audio selection');
  }
}
