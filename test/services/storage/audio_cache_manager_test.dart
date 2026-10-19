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

  _registerExternalImportTests(() => harness);
  _registerOwnershipTests(() => harness);
  _registerRetentionTests(() => harness);
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

void _registerExternalImportTests(_HarnessGetter getHarness) {
  group('external imports', () {
    _registerExternalCopyTest(getHarness);
    _registerExternalValidationTest(getHarness);
    _registerDisplayNameExtensionTest(getHarness);
    _registerExternalPathSafetyTest(getHarness);
  });
}

void _registerExternalCopyTest(_HarnessGetter getHarness) {
  test(
    'copies an external audio file and leaves the original untouched',
    () async {
      final harness = getHarness();
      final source = await _writeAudio(harness.externalRoot, 'meeting.m4a', 6);
      final originalBytes = await source.readAsBytes();

      final imported = await harness.manager.importExternal(
        source.path,
        displayName: 'meeting.m4a',
      );

      expect(imported.ownership, AudioOwnership.temporary);
      expect(imported.path, isNot(source.path));
      expect(
        p.isWithin((await harness.paths.importCacheDir()).path, imported.path),
        isTrue,
      );
      expect(await File(imported.path).readAsBytes(), originalBytes);
      await harness.manager.discard(
        const ManagedAudioFile(
          path: '/outside.m4a',
          ownership: AudioOwnership.external,
        ),
      );
      expect(await source.exists(), isTrue);
      expect(await source.readAsBytes(), originalBytes);
    },
  );
}

void _registerExternalValidationTest(_HarnessGetter getHarness) {
  test(
    'rejects empty, unsupported, and oversized sources before import',
    () async {
      final harness = getHarness();
      final empty = await _writeAudio(harness.externalRoot, 'empty.m4a', 0);
      final unsupported = await _writeFile(
        harness.externalRoot,
        'notes.txt',
        4,
      );
      final oversized = await _writeAudio(
        harness.externalRoot,
        'large.m4a',
        11,
      );

      expect(
        harness.manager.importExternal(empty.path),
        throwsA(isA<FileSystemException>()),
      );
      expect(
        harness.manager.importExternal(unsupported.path),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        harness.manager.importExternal(oversized.path),
        throwsA(isA<FileSystemException>()),
      );
      expect(await _files(await harness.paths.importCacheDir()), isEmpty);
    },
  );
}

void _registerDisplayNameExtensionTest(_HarnessGetter getHarness) {
  test(
    'uses the supplied display name extension for an imported copy',
    () async {
      final harness = getHarness();
      final source = await _writeAudio(
        harness.externalRoot,
        'recording.m4a',
        4,
      );

      final imported = await harness.manager.importExternal(
        source.path,
        displayName: 'whatsapp-voice.opus',
      );

      expect(p.extension(imported.path), '.opus');
    },
  );
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
    _registerRecordingOwnershipTest(getHarness);
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

  test(
    'accepts an app-owned shared file through a symlink alias',
    () async {
      final harness = getHarness();
      final sharedDirectory = await harness.paths.sharedCacheDir();
      final alias = Link(p.join(harness.cacheRoot.path, 'shared-alias'));
      await alias.create(sharedDirectory.path);
      final shared = await _writeAudio(Directory(alias.path), 'shared.mp3', 4);

      final registered = await harness.manager.registerShared(shared.path);

      expect(registered.path, shared.path);
      expect(registered.ownership, AudioOwnership.temporary);
    },
    skip: Platform.isWindows
        ? 'Symlink creation requires elevated access'
        : false,
  );
}

void _registerRecordingOwnershipTest(_HarnessGetter getHarness) {
  test(
    'creates and registers recording files only in the recording cache',
    () async {
      final harness = getHarness();
      final destination = await harness.manager.recordingDestination();
      expect(
        p.isWithin((await harness.paths.recordingCacheDir()).path, destination),
        isTrue,
      );
      expect(p.extension(destination), '.wav');

      final recording = await _writeFile(
        await harness.paths.recordingCacheDir(),
        p.basename(destination),
        4,
      );
      final registered = await harness.manager.registerRecording(
        recording.path,
      );
      expect(registered.ownership, AudioOwnership.temporary);
      final externalRecording = await _writeAudio(
        harness.externalRoot,
        'external-recording.wav',
        4,
      );
      expect(
        harness.manager.registerRecording(externalRecording.path),
        throwsA(isA<FileSystemException>()),
      );
    },
  );
}

void _registerRetentionTests(_HarnessGetter getHarness) {
  group('retention and discard', () {
    _registerTemporaryRetentionTest(getHarness);
    _registerExternalRetentionTest(getHarness);
    _registerOwnedDiscardTest(getHarness);
  });
}

void _registerTemporaryRetentionTest(_HarnessGetter getHarness) {
  test('retains a temporary copy and discards its staging file', () async {
    final harness = getHarness();
    final source = await _writeAudio(harness.externalRoot, 'source.m4a', 6);
    final temporary = await harness.manager.importExternal(source.path);

    final retained = await harness.manager.retain(temporary);

    expect(retained.ownership, AudioOwnership.retained);
    expect(
      p.isWithin((await harness.paths.retainedAudioDir()).path, retained.path),
      isTrue,
    );
    expect(await File(retained.path).exists(), isTrue);
    expect(await File(temporary.path).exists(), isFalse);
    expect(await source.exists(), isTrue);
  });
}

void _registerExternalRetentionTest(_HarnessGetter getHarness) {
  test(
    'retains an external original by copying it, never deleting it',
    () async {
      final harness = getHarness();
      final source = await _writeAudio(harness.externalRoot, 'source.wav', 6);
      final retained = await harness.manager.retain(
        ManagedAudioFile(path: source.path, ownership: AudioOwnership.external),
      );

      expect(retained.ownership, AudioOwnership.retained);
      expect(await source.exists(), isTrue);
      await harness.manager.discard(
        ManagedAudioFile(path: source.path, ownership: AudioOwnership.external),
      );
      expect(await source.exists(), isTrue);
    },
  );
}

void _registerOwnedDiscardTest(_HarnessGetter getHarness) {
  test(
    'discards owned temporary and retained files only within managed roots',
    () async {
      final harness = getHarness();
      final source = await _writeAudio(harness.externalRoot, 'source.m4a', 4);
      final temporary = await harness.manager.importExternal(source.path);
      final retained = await harness.manager.retain(temporary);

      await harness.manager.discard(retained);
      expect(await File(retained.path).exists(), isFalse);
      expect(await source.exists(), isTrue);

      final outside = await _writeAudio(harness.externalRoot, 'outside.m4a', 4);
      await harness.manager.discard(
        ManagedAudioFile(
          path: outside.path,
          ownership: AudioOwnership.retained,
        ),
      );
      expect(await outside.exists(), isTrue);
    },
  );
}

void _registerCleanupTests(_HarnessGetter getHarness) {
  group('cleanup', () {
    _registerExpiryCleanupTest(getHarness);
    _registerQuotaCleanupTest(getHarness);
    _registerActiveCleanupTest(getHarness);
    _registerRetainedQuotaTest(getHarness);
  });
}

void _registerExpiryCleanupTest(_HarnessGetter getHarness) {
  test('removes expired temporary files but preserves fresh files', () async {
    final harness = getHarness();
    final directory = await harness.paths.importCacheDir();
    final expired = await _writeAudio(directory, 'expired.m4a', 4);
    final fresh = await _writeAudio(directory, 'fresh.m4a', 4);
    await expired.setLastModified(
      harness.now.subtract(const Duration(days: 2)),
    );
    await fresh.setLastModified(harness.now.subtract(const Duration(hours: 1)));

    await harness.manager.cleanup();

    expect(await expired.exists(), isFalse);
    expect(await fresh.exists(), isTrue);
  });
}

void _registerQuotaCleanupTest(_HarnessGetter getHarness) {
  test('enforces quota in least-recently-modified order', () async {
    final harness = getHarness();
    final directory = await harness.paths.importCacheDir();
    final oldest = await _writeAudio(directory, 'oldest.m4a', 6);
    final middle = await _writeAudio(directory, 'middle.m4a', 6);
    final newest = await _writeAudio(directory, 'newest.m4a', 6);
    await oldest.setLastModified(
      harness.now.subtract(const Duration(hours: 3)),
    );
    await middle.setLastModified(
      harness.now.subtract(const Duration(hours: 2)),
    );
    await newest.setLastModified(
      harness.now.subtract(const Duration(hours: 1)),
    );

    await harness.manager.cleanup();

    expect(await oldest.exists(), isFalse);
    expect(await middle.exists(), isFalse);
    expect(await newest.exists(), isTrue);
  });
}

void _registerActiveCleanupTest(_HarnessGetter getHarness) {
  test('never evicts active files during TTL or quota cleanup', () async {
    final harness = getHarness();
    final directory = await harness.paths.importCacheDir();
    final active = await _writeAudio(directory, 'active.m4a', 6);
    final other = await _writeAudio(directory, 'other.m4a', 6);
    await active.setLastModified(harness.now.subtract(const Duration(days: 2)));
    await other.setLastModified(harness.now.subtract(const Duration(days: 2)));
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

void _registerRetainedQuotaTest(_HarnessGetter getHarness) {
  test('does not count retained audio against temporary cache quota', () async {
    final harness = getHarness();
    final source = await _writeAudio(harness.externalRoot, 'source.m4a', 6);
    final retained = await harness.manager.retain(
      ManagedAudioFile(path: source.path, ownership: AudioOwnership.external),
    );
    final temporary = await _writeAudio(
      await harness.paths.importCacheDir(),
      'temporary.m4a',
      6,
    );

    await harness.manager.cleanup();

    expect(await File(retained.path).exists(), isTrue);
    expect(await temporary.exists(), isTrue);
  });
}

Future<File> _writeAudio(Directory directory, String name, int size) =>
    _writeFile(directory, name, size);

Future<File> _writeFile(Directory directory, String name, int size) async {
  final file = File(p.join(directory.path, name));
  await file.writeAsBytes(List<int>.filled(size, 0));
  return file;
}

Future<List<File>> _files(Directory directory) async => [
  for (final entity in await directory.list().toList())
    if (entity is File) entity,
];
