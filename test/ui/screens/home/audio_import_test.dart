import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/ui/screens/home/audio_import.dart';

void main() {
  _registerSelectedFileTest();
}

final _strings = AppStrings.of(AppLanguage.en);

void _registerSelectedFileTest() {
  testWidgets('selected audio is forwarded to processing once', (tester) async {
    final fixture = await _createFixture(tester);
    await _pumpImportAction(tester, fixture);
    await _tapImport(tester, fixture);

    final selection = fixture.started.single;
    expect(selection.fileName, 'meeting.m4a');
    expect(selection.path, fixture.source.path);
    expect(await tester.runAsync(() => File(selection.path).readAsBytes()), [
      1,
      2,
      3,
    ]);
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

  AudioImportSelection get selection =>
      AudioImportSelection(path: source.path, fileName: 'meeting.m4a');

  Future<void> startImport(
    BuildContext context, {
    AudioImportPicker? picker,
    AudioImportStarter? starter,
  }) => startAudioImport(
    context,
    cacheManager: manager,
    strings: _strings,
    picker: picker ?? () async => selection,
    starter: starter ?? (_, selection) async => started.add(selection),
  );

  static Future<_AudioImportFixture> create() async {
    final root = await Directory.systemTemp.createTemp('audio-import-test-');
    final support = Directory(p.join(root.path, 'support'));
    final cache = Directory(p.join(root.path, 'cache'));
    await support.create();
    await cache.create();
    final source = File(p.join(cache.path, 'shared', 'meeting.m4a'));
    await source.parent.create();
    await source.writeAsBytes([1, 2, 3]);
    return _AudioImportFixture(
      root: root,
      source: source,
      manager: AudioCacheManager(
        paths: Future.value(
          StoragePaths(supportRoot: support, cacheRoot: cache),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    if (await root.exists()) await root.delete(recursive: true);
  }
}
