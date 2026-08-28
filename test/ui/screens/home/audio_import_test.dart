import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/ui/screens/home/audio_import.dart';
import 'package:uuid/data.dart';
import 'package:uuid/rng.dart';
import 'package:uuid/uuid.dart';

import 'home_test_helpers.dart';

void main() {
  _registerSelectedFileTest();
  _registerCancellationTest();
  _registerUnmountedContextTest();
}

void _registerSelectedFileTest() {
  testWidgets('selected audio is forwarded to processing once', (tester) async {
    final fixture = (await tester.runAsync(_AudioImportFixture.create))!;
    addTearDown(() => tester.runAsync(fixture.dispose));
    final selection = AudioImportSelection(
      path: fixture.source.path,
      fileName: 'meeting.m4a',
    );
    AudioImportSelection? startedSelection;
    late BuildContext context;
    await tester.pumpWidget(captureBuildContext((value) => context = value));

    await tester.runAsync(
      () => startAudioImport(
        context,
        cacheManager: fixture.manager,
        picker: () async => selection,
        starter: (_, value) async => startedSelection = value,
      ),
    );

    expect(startedSelection?.fileName, selection.fileName);
    expect(startedSelection?.path, isNot(selection.path));
    expect(
      await tester.runAsync(() => File(startedSelection!.path).readAsBytes()),
      [1, 2, 3],
    );
  });
}

void _registerCancellationTest() {
  testWidgets('cancelled audio selection does not start processing', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_AudioImportFixture.create))!;
    addTearDown(() => tester.runAsync(fixture.dispose));
    var started = false;
    late BuildContext context;
    await tester.pumpWidget(captureBuildContext((value) => context = value));

    await tester.runAsync(
      () => startAudioImport(
        context,
        cacheManager: fixture.manager,
        picker: () async => null,
        starter: (_, _) async => started = true,
      ),
    );

    expect(started, isFalse);
  });
}

void _registerUnmountedContextTest() {
  testWidgets('selection is ignored after its screen is unmounted', (
    tester,
  ) async {
    final fixture = (await tester.runAsync(_AudioImportFixture.create))!;
    addTearDown(() => tester.runAsync(fixture.dispose));
    final picker = Completer<AudioImportSelection?>();
    var started = false;
    late BuildContext context;
    await tester.pumpWidget(captureBuildContext((value) => context = value));
    final operation = startAudioImport(
      context,
      cacheManager: fixture.manager,
      picker: () => picker.future,
      starter: (_, _) async => started = true,
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    picker.complete(
      const AudioImportSelection(path: '/tmp/note.wav', fileName: 'note.wav'),
    );
    await operation;

    expect(started, isFalse);
  });
}

final class _AudioImportFixture {
  _AudioImportFixture({
    required this.root,
    required this.source,
    required this.manager,
  });

  final Directory root;
  final File source;
  final AudioCacheManager manager;

  static Future<_AudioImportFixture> create() async {
    final root = await Directory.systemTemp.createTemp('audio-import-test-');
    final support = Directory(p.join(root.path, 'support'));
    final cache = Directory(p.join(root.path, 'cache'));
    await support.create();
    await cache.create();
    final source = File(p.join(root.path, 'meeting.m4a'));
    await source.writeAsBytes([1, 2, 3]);
    return _AudioImportFixture(
      root: root,
      source: source,
      manager: AudioCacheManager(
        paths: Future.value(
          StoragePaths(supportRoot: support, cacheRoot: cache),
        ),
        uuid: Uuid(goptions: GlobalOptions(MathRNG(seed: 9))),
      ),
    );
  }

  Future<void> dispose() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
