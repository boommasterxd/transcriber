import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:transcriber/services/storage/storage_paths.dart';

void main() {
  late Directory root;
  late Directory supportRoot;
  late Directory cacheRoot;
  late StoragePaths paths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('transcriber-storage-test-');
    supportRoot = Directory(p.join(root.path, 'support'));
    cacheRoot = Directory(p.join(root.path, 'cache'));
    await supportRoot.create(recursive: true);
    await cacheRoot.create(recursive: true);
    paths = StoragePaths(supportRoot: supportRoot, cacheRoot: cacheRoot);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test(
    'creates the four managed audio directories below their roots',
    () async {
      final importDirectory = await paths.importCacheDir();
      final sharedDirectory = await paths.sharedCacheDir();
      final recordingDirectory = await paths.recordingCacheDir();
      final retainedDirectory = await paths.retainedAudioDir();

      expect(importDirectory.path, p.join(cacheRoot.path, 'audio', 'import'));
      expect(sharedDirectory.path, p.join(cacheRoot.path, 'shared'));
      expect(
        recordingDirectory.path,
        p.join(cacheRoot.path, 'audio', 'recording'),
      );
      expect(
        retainedDirectory.path,
        p.join(supportRoot.path, 'audio', 'retained'),
      );
      expect(await importDirectory.exists(), isTrue);
      expect(await sharedDirectory.exists(), isTrue);
      expect(await recordingDirectory.exists(), isTrue);
      expect(await retainedDirectory.exists(), isTrue);
    },
  );

  test('rejects a file where a managed directory is expected', () async {
    final conflict = File(p.join(cacheRoot.path, 'shared'));
    await conflict.writeAsString('not a directory');

    expect(paths.sharedCacheDir(), throwsA(isA<FileSystemException>()));
  });
}
