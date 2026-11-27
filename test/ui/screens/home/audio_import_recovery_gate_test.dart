import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_accent.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/audio/audio_import_picker.dart';
import 'package:transcriber/services/processing/processing_request.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/ui/screens/home/audio_import_recovery_gate.dart';
import 'package:transcriber/ui/screens/processing/processing_screen.dart';

import '../../../support/app_test_fakes.dart';

const _channel = MethodChannel('app/audio_import');
final _strings = AppStrings.of(AppLanguage.de);
const _settings = AppSettings(
  summary: SummarySettings(provider: RemoteProviderId.openai),
);

late AudioImportPickerService picker;
late Completer<Object?> recovery;
late List<String> calls;
late List<ProcessingInput> submitted;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    picker = AudioImportPickerService();
    calls = [];
    submitted = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) {
          calls.add(call.method);
          return call.method == 'recoverInterruptedPick'
              ? recovery.future
              : Future.value(null);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  _registerDialogTests();
}

void _registerDialogTests() {
  testWidgets('confirmation imports recovered audio without another pick', (
    tester,
  ) async {
    final root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('recovery-test-'),
    );
    addTearDown(() => tester.runAsync(() => root!.delete(recursive: true)));
    final source = File('${root!.path}/cache/shared/voice.wav');
    await tester.runAsync(() async {
      await source.parent.create(recursive: true);
      await source.writeAsBytes([1, 2, 3]);
    });
    recovery = Completer<Object?>();
    final manager = await tester.runAsync(
      () async => AudioCacheManager(
        paths: Future.value(
          StoragePaths(
            supportRoot: Directory('${root.path}/support'),
            cacheRoot: Directory('${root.path}/cache'),
          ),
        ),
      ),
    );
    final ready = ValueNotifier(true);
    addTearDown(ready.dispose);
    await _pumpGate(tester, picker, ready, manager: manager);
    await _showRecoveredApproval(tester, source.path);
    await tester.pumpAndSettle();
    expect(find.byType(ProcessingScreen), findsNothing);
    expect(submitted, isEmpty);
    expect(
      find.text(_strings.shareAudioRecipient('Google Gemini')),
      findsOneWidget,
    );
    expect(
      find.text(_strings.shareTranscriptRecipient('OpenAI')),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      await tester.tap(find.text(_strings.recoveredAudioContinue));
      await Future<void>(() {});
    });
    await tester.pump();

    final input = submitted.single;
    final screen = tester.widget<ProcessingScreen>(
      find.byType(ProcessingScreen, skipOffstage: false),
    );
    expect(screen.fileName, 'voice.wav');
    expect(input.settings, same(_settings));
    expect(input.audioPath, source.path);
    expect(await tester.runAsync(source.readAsBytes), [1, 2, 3]);
    expect(calls, ['recoverInterruptedPick']);
  });
}

Map<String, Object?> _result(String path) => {
  'path': path,
  'fileName': path.split('/').last,
};

Future<void> _pumpGate(
  WidgetTester tester,
  AudioImportPickerService picker,
  ValueNotifier<bool> ready, {
  AudioCacheManager? manager,
}) async {
  final database = testDatabase();
  addTearDown(database.close);
  await tester.pumpWidget(
    appScope(
      database: database,
      settings: _settings,
      cacheManager: manager,
      child: ProviderScope(
        overrides: [
          audioImportPickerProvider.overrideWithValue(picker),
          processingControllerProvider.overrideWith(
            _CapturingProcessingController.new,
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.build(Brightness.light, AppAccent.blue),
          home: ValueListenableBuilder<bool>(
            valueListenable: ready,
            builder: (context, value, _) => AudioImportRecoveryGate(
              ready: value,
              child: const Scaffold(body: Text('Home')),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showRecoveredApproval(WidgetTester tester, String path) =>
    tester.runAsync(() async {
      recovery.complete(_result(path));
      final deadline = Stopwatch()..start();
      final title = find.text(_strings.recoveredAudioTitle);
      while (title.evaluate().isEmpty && deadline.elapsed.inSeconds < 10) {
        await tester.pump();
        await Future<void>(() {});
      }
      expect(title, findsOneWidget);
    });

class _CapturingProcessingController extends ProcessingController {
  @override
  Future<void> run(
    ProcessingInput input, {
    String? fileName,
    bool save = true,
    Object? owner,
  }) async => submitted.add(input);
}
