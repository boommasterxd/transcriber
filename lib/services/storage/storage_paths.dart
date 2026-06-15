import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Centralized, lazily-created on-disk locations for models and audio.
class StoragePaths {
  StoragePaths._(this._root);

  final Directory _root;

  static StoragePaths? _instance;

  static Future<StoragePaths> instance() async {
    if (_instance != null) return _instance!;
    final base = await getApplicationSupportDirectory();
    _instance = StoragePaths._(base);
    return _instance!;
  }

  Future<Directory> _ensure(String sub) async {
    final dir = Directory(p.join(_root.path, sub));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> whisperDir() => _ensure('models/whisper');
  Future<Directory> gemmaDir() => _ensure('models/gemma');
  Future<Directory> audioDir() => _ensure('audio');

  Future<String> gemmaModelFile(String fileName) async =>
      p.join((await gemmaDir()).path, fileName);
}
