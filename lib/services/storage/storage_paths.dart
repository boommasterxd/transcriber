import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// App-private storage locations for temporary and retained audio.
final class StoragePaths {
  const StoragePaths({required this.supportRoot, required this.cacheRoot});

  final Directory supportRoot;
  final Directory cacheRoot;

  static Future<StoragePaths> create() async => StoragePaths(
    supportRoot: await getApplicationSupportDirectory(),
    cacheRoot: await getTemporaryDirectory(),
  );

  Future<Directory> importCacheDir() => _ensure(cacheRoot, 'audio/import');

  Future<Directory> sharedCacheDir() => _ensure(cacheRoot, 'shared');

  Future<Directory> recordingCacheDir() =>
      _ensure(cacheRoot, 'audio/recording');

  Future<Directory> retainedAudioDir() =>
      _ensure(supportRoot, 'audio/retained');

  Future<Directory> _ensure(Directory root, String relativePath) async {
    final directory = Directory(p.join(root.path, relativePath));
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      await directory.create(recursive: true);
      return directory;
    }
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException(
        'Storage path is not a directory',
        directory.path,
      );
    }
    return directory;
  }
}
