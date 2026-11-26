import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/toast.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_accent.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/services/audio/audio_import_picker.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/services/processing/processing_request.dart';
import 'package:transcriber/ui/screens/home/audio_import_recovery_gate.dart';
import 'package:transcriber/ui/screens/processing/processing_screen.dart';

import '../../../support/app_test_fakes.dart';

const _channel = MethodChannel('app/audio_import');
final _strings = AppStrings.of(AppLanguage.de);

late AudioImportPickerService picker;
late Completer<Object?> recovery;
late List<String> calls;
late Completer<void> processingPushed;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    picker = AudioImportPickerService();
    calls = [];
    processingPushed = Completer<void>();
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
    recovery.complete(_result(source.path));
    await tester.pumpAndSettle();
    expect(find.byType(ProcessingScreen), findsNothing);
    await _confirmImport(tester);
    await tester.pump();
    final screen = tester.widget<ProcessingScreen>(
      find.byType(ProcessingScreen),
    );
    expect(screen.fileName, 'voice.wav');
    expect(screen.audioPath, source.path);
    expect(await tester.runAsync(() => File(screen.audioPath).readAsBytes()), [
      1,
      2,
      3,
    ]);
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
  bool dark = false,
  bool largeText = false,
  AudioCacheManager? manager,
}) async {
  final database = testDatabase();
  addTearDown(database.close);
  await tester.pumpWidget(
    appScope(
      database: database,
      settings: AppSettings.initial(),
      cacheManager: manager,
      child: ProviderScope(
        overrides: [
          audioImportPickerProvider.overrideWithValue(picker),
          processingControllerProvider.overrideWith(
            _NoopProcessingController.new,
          ),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          navigatorObservers: [_ProcessingObserver()],
          theme: AppTheme.build(
            dark ? Brightness.dark : Brightness.light,
            AppAccent.blue,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(largeText ? 2 : 1)),
            child: child!,
          ),
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

class _ProcessingObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null &&
        route is PageRoute &&
        !processingPushed.isCompleted) {
      processingPushed.complete();
    }
  }
}

Future<void> _confirmImport(WidgetTester tester) => tester.runAsync(() async {
  await tester.tap(find.text(_strings.recoveredAudioContinue));
  final deadline = Stopwatch()..start();
  while (!processingPushed.isCompleted && deadline.elapsed.inSeconds < 10) {
    await tester.pump();
    await Future<void>(() {});
  }
  expect(processingPushed.isCompleted, isTrue);
});

class _NoopProcessingController extends ProcessingController {
  @override
  Future<void> run(
    ProcessingInput input, {
    String? fileName,
    bool save = true,
    Object? owner,
  }) async {}
}
