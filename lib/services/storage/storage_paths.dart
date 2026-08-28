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
    final type = await FileSystemEntity.type(dir.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) {
      await dir.create(recursive: true);
    } else if (type != FileSystemEntityType.directory) {
      throw FileSystemException('Storage path is not a directory', dir.path);
    }
    return dir;
  }

  Future<Directory> whisperDir() => _ensure('models/whisper');
  Future<Directory> gemmaDir() => _ensure('models/gemma');
  Future<Directory> audioDir() => _ensure('audio');

  Future<String> gemmaModelFile(String fileName) async {
    _validateFileName(fileName);
    final directory = await gemmaDir();
    final candidate = p.normalize(p.join(directory.path, fileName));
    if (!p.isWithin(directory.path, candidate)) {
      throw ArgumentError.value(fileName, 'fileName', 'Must remain in models');
    }
    return candidate;
  }

  void _validateFileName(String fileName) {
    final isSingleSegment =
        p.posix.basename(fileName) == fileName &&
        p.windows.basename(fileName) == fileName;
    if (fileName.trim().isEmpty ||
        fileName == '.' ||
        fileName == '..' ||
        !isSingleSegment) {
      throw ArgumentError.value(fileName, 'fileName', 'Invalid model name');
    }
  }
}
