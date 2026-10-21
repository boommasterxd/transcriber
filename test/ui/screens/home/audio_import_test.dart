import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:transcriber/core/l10n/app_strings.dart';
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
  _registerImportFailures();
}

final _strings = AppStrings.of(AppLanguage.en);

void _registerSelectedFileTest() {
  testWidgets('selected audio is forwarded to processing once', (tester) async {
    final fixture = await _createFixture(tester);
    await _pumpImportAction(tester, fixture);
    await _tapImport(tester, fixture);

    final selection = fixture.started.single;
    expect(selection.fileName, 'meeting.m4a');
    expect(selection.path, isNot(fixture.source.path));
    expect(await tester.runAsync(() => File(selection.path).readAsBytes()), [
      1,
      2,
      3,
    ]);
  });
}

void _registerCancellationTest() {
  testWidgets('cancelled audio selection does not start processing', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await _pumpImportAction(tester, fixture, picker: () async => null);
    await _tapImport(tester, fixture);

    expect(fixture.started, isEmpty);
  });
}

void _registerUnmountedContextTest() {
  testWidgets('selection is ignored after its screen is unmounted', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    final picker = Completer<AudioImportSelection?>();
    late BuildContext context;
    await tester.pumpWidget(captureBuildContext((value) => context = value));
    final operation = fixture.startImport(context, picker: () => picker.future);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    picker.complete(
      const AudioImportSelection(path: '/tmp/note.wav', fileName: 'note.wav'),
    );
    await operation;

    expect(fixture.started, isEmpty);
  });
}

void _registerImportFailures() {
  testWidgets('rejected audio reports an error and can be selected again', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await tester.runAsync(() => fixture.source.writeAsBytes([]));
    await _pumpImportAction(tester, fixture);
    await _tapImport(tester, fixture);
    expect(find.text(_strings.audioImportFailed), findsOneWidget);
    expect(fixture.started, isEmpty);
    expect(tester.takeException(), isNull);
    expect(find.textContaining(fixture.source.path), findsNothing);

    await tester.runAsync(() => fixture.source.writeAsBytes([1, 2, 3]));
    await _tapImport(tester, fixture);
    expect(fixture.started, hasLength(1));
  });

  testWidgets('picker failure reports an error without starting processing', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await _pumpImportAction(
      tester,
      fixture,
      picker: () async => throw const FileSystemException('access denied'),
    );

    await _tapImport(tester, fixture);

    expect(find.text(_strings.audioImportFailed), findsOneWidget);
    expect(fixture.started, isEmpty);
    expect(tester.takeException(), isNull);
  });

  _registerNavigationFailure();
  _registerOversizedImport();
}

void _registerOversizedImport() {
  testWidgets('oversized audio reports an error before processing', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await tester.runAsync(() async {
      final file = await fixture.source.open(mode: FileMode.write);
      await file.truncate(fixture.manager.maximumFileBytes + 1);
      await file.close();
    });
    await _pumpImportAction(tester, fixture);

    await _tapImport(tester, fixture);

    expect(fixture.started, isEmpty);
    expect(find.text(_strings.audioImportFailed), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _registerNavigationFailure() {
  testWidgets('failed navigation removes the imported copy and reports error', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    String? copyPath;
    await _pumpImportAction(
      tester,
      fixture,
      starter: (_, selection) async {
        copyPath = selection.path;
        throw StateError('route unavailable');
      },
    );

    await _tapImport(tester, fixture);

    expect(copyPath, isNotNull);
    expect(await tester.runAsync(() => File(copyPath!).exists()), isFalse);
    expect(await tester.runAsync(fixture.source.exists), isTrue);
    expect(find.text(_strings.audioImportFailed), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<_AudioImportFixture> _createFixture(WidgetTester tester) async {
  final fixture = (await tester.runAsync(_AudioImportFixture.create))!;
  addTearDown(() => tester.runAsync(fixture.dispose));
  return fixture;
}

Future<void> _pumpImportAction(
  WidgetTester tester,
  _AudioImportFixture fixture, {
  AudioImportPicker? picker,
  AudioImportStarter? starter,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () {
            fixture.operation = fixture.startImport(
              context,
              picker: picker,
              starter: starter,
            );
          },
          child: const Text('Import'),
        ),
      ),
    ),
  ),
);

Future<void> _tapImport(
  WidgetTester tester,
  _AudioImportFixture fixture,
) async {
  await tester.runAsync(() async {
    await tester.tap(find.text('Import'));
    await fixture.operation;
  });
  await tester.pump();
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
  Future<void>? operation;
  final started = <AudioImportSelection>[];

  Future<void> startImport(
    BuildContext context, {
    AudioImportPicker? picker,
    AudioImportStarter? starter,
  }) => startAudioImport(
    context,
    cacheManager: manager,
    strings: _strings,
    picker:
        picker ??
        () async =>
            AudioImportSelection(path: source.path, fileName: 'meeting.m4a'),
    starter: starter ?? (_, selection) async => started.add(selection),
  );

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
