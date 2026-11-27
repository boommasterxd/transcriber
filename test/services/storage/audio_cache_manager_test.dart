import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/managed_audio_file.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';
import 'package:uuid/rng.dart';

typedef _HarnessGetter = _AudioCacheTestHarness Function();

void main() {
  late _AudioCacheTestHarness harness;

  setUp(() async {
    harness = await _AudioCacheTestHarness.create();
  });

  tearDown(() => harness.dispose());

  _registerExternalPathSafetyTest(() => harness);
  _registerOwnershipTests(() => harness);
  _registerCleanupTests(() => harness);
}

final class _AudioCacheTestHarness {
  _AudioCacheTestHarness({
    required this.root,
    required this.cacheRoot,
    required this.externalRoot,
    required this.paths,
    required this.manager,
    required this.now,
  });

  final Directory root;
  final Directory cacheRoot;
  final Directory externalRoot;
  final StoragePaths paths;
  final AudioCacheManager manager;
  final DateTime now;

  static Future<_AudioCacheTestHarness> create() async {
    final root = await Directory.systemTemp.createTemp(
      'transcriber-audio-cache-',
    );
    final supportRoot = Directory(p.join(root.path, 'support'));
    final cacheRoot = Directory(p.join(root.path, 'cache'));
    final externalRoot = Directory(p.join(root.path, 'external'));
    await supportRoot.create(recursive: true);
    await cacheRoot.create(recursive: true);
    await externalRoot.create(recursive: true);

    final paths = StoragePaths(supportRoot: supportRoot, cacheRoot: cacheRoot);
    final now = DateTime.utc(2026, 8, 28, 12);
    final manager = AudioCacheManager(
      paths: Future.value(paths),
      now: () => now,
      uuid: Uuid(goptions: GlobalOptions(MathRNG(seed: 7))),
      maximumFileBytes: 10,
      cacheQuotaBytes: 10,
      temporaryTtl: const Duration(hours: 24),
    );
    return _AudioCacheTestHarness(
      root: root,
      cacheRoot: cacheRoot,
      externalRoot: externalRoot,
      paths: paths,
      manager: manager,
      now: now,
    );
  }

  Future<void> dispose() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}

void _registerExternalPathSafetyTest(_HarnessGetter getHarness) {
  test('rejects path traversal and symlink sources', () async {
    final harness = getHarness();
    final source = await _writeAudio(harness.externalRoot, 'source.m4a', 4);
    final importDirectory = await harness.paths.importCacheDir();
    final link = Link(p.join(importDirectory.path, 'link.m4a'));
    await link.create(source.path);

    expect(
      harness.manager.registerShared(link.path),
      throwsA(isA<FileSystemException>()),
    );
    final traversal = p.join(
      importDirectory.path,
      '..',
      '..',
      '..',
      'external',
      'source.m4a',
    );
    expect(
      harness.manager.discard(
        ManagedAudioFile(path: traversal, ownership: AudioOwnership.temporary),
      ),
      completes,
    );
    expect(await source.exists(), isTrue);
  });
}

void _registerOwnershipTests(_HarnessGetter getHarness) {
  group('shared and recording ownership', () {
    _registerSharedOwnershipTest(getHarness);
  });
}

void _registerSharedOwnershipTest(_HarnessGetter getHarness) {
  test('accepts shared files only inside the shared cache directory', () async {
    final harness = getHarness();
    final sharedDirectory = await harness.paths.sharedCacheDir();
    final shared = await _writeAudio(sharedDirectory, 'shared.mp3', 4);
    final external = await _writeAudio(harness.externalRoot, 'external.mp3', 4);
    final registered = await harness.manager.registerShared(shared.path);

    expect(registered.ownership, AudioOwnership.temporary);
    expect(registered.path, shared.path);
    expect(
      harness.manager.registerShared(external.path),
      throwsA(isA<FileSystemException>()),
    );
  });
}

void _registerCleanupTests(_HarnessGetter getHarness) {
  group('cleanup', () {
    _registerActiveCleanupTest(getHarness);
  });
}

void _registerActiveCleanupTest(_HarnessGetter getHarness) {
  test('never evicts active files during TTL or quota cleanup', () async {
    final harness = getHarness();
    final directory = await harness.paths.importCacheDir();
    final active = await _writeAudio(directory, 'active.m4a', 6);
    final other = await _writeAudio(directory, 'other.m4a', 6);
    await active.setLastModified(harness.now.subtract(const Duration(days: 2)));
    await other.setLastModified(harness.now.subtract(const Duration(hours: 1)));
    final activeManaged = ManagedAudioFile(
      path: active.path,
      ownership: AudioOwnership.temporary,
    );
    harness.manager.markActive(activeManaged);

    await harness.manager.cleanup();

    expect(await active.exists(), isTrue);
    expect(await other.exists(), isFalse);
    harness.manager.markInactive(activeManaged);
  });
}

Future<File> _writeAudio(Directory directory, String name, int size) async {
  final file = File(p.join(directory.path, name));
  await file.writeAsBytes(List<int>.filled(size, 0));
  return file;
}
