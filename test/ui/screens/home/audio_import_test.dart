import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_accent.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/ui/processing_navigation.dart';
import 'package:transcriber/ui/screens/home/audio_import.dart';

void main() {
  _registerSelectedFileTest();
}

final _strings = AppStrings.of(AppLanguage.en);

void _registerSelectedFileTest() {
  testWidgets('selected audio uses the settings approved before processing', (
    tester,
  ) async {
    final fixture = await _createFixture(tester);
    await _pumpImportAction(tester, fixture);
    await _tapImport(tester, fixture);

    final approvedSettings = fixture.settings;
    expect(fixture.started, isEmpty);
    expect(find.text(_strings.shareAudioRecipient('OpenAI')), findsOneWidget);
    expect(
      find.text(_strings.shareTranscriptRecipient('Google Gemini')),
      findsOneWidget,
    );
    fixture.settings = AppSettings.initial();
    await tester.runAsync(() async {
      await tester.tap(find.text(_strings.shareConfirmAction));
      await fixture.operation.timeout(const Duration(seconds: 10));
    });
    await tester.pump();

    final request = fixture.started.single;
    expect(request.settings, same(approvedSettings));
    expect(request.fileName, 'meeting.m4a');
    expect(request.audio.path, fixture.source.path);
    expect(await tester.runAsync(fixture.source.readAsBytes), [1, 2, 3]);
  });
}

Future<_AudioImportFixture> _createFixture(WidgetTester tester) async {
  final fixture = (await tester.runAsync(_AudioImportFixture.create))!;
  addTearDown(() => tester.runAsync(fixture.dispose));
  return fixture;
}

Future<void> _pumpImportAction(
  WidgetTester tester,
  _AudioImportFixture fixture,
) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.build(Brightness.light, AppAccent.blue),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () {
            fixture.operation = fixture.startImport(context);
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
    await fixture.settingsRead.future.timeout(const Duration(seconds: 10));
  });
  await tester.pumpAndSettle();
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
  late Future<void> operation;
  final settingsRead = Completer<void>();
  final started = <ProcessingNavigationRequest>[];
  AppSettings settings = const AppSettings(
    appearance: AppearanceSettings(language: AppLanguage.en),
    transcription: TranscriptionSettings(provider: RemoteProviderId.openai),
  );

  AudioImportSelection get selection =>
      AudioImportSelection(path: source.path, fileName: 'meeting.m4a');

  Future<void> startImport(BuildContext context) => startAudioImport(
    context,
    cacheManager: manager,
    readSettings: () async {
      if (!settingsRead.isCompleted) settingsRead.complete();
      return settings;
    },
    picker: () async => selection,
    starter: (_, request) async => started.add(request),
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
