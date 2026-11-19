import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/audio_ownership.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/ui/navigation.dart';
import 'package:transcriber/ui/screens/detail/transcript_detail_screen.dart';
import 'package:transcriber/ui/screens/processing/processing_screen.dart';
import 'package:transcriber/ui/screens/record/record_screen.dart';
import 'package:transcriber/ui/screens/settings/settings_screen.dart';

import '../state/state_test_fakes.dart';
import 'screens/onboarding/onboarding_test_support.dart';

void main() {
  testWidgets('openSettings pushes the settings screen', (tester) async {
    final observer = _RouteObserver();
    await _pumpHarness(tester, observer);

    await _tapAction(tester, () => AppNavigator.openSettings(_context(tester)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(observer.pushes, hasLength(2));
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  group('Recording permission', _registerRecordingTests);

  testWidgets('openDetail passes the note id and pushes a route', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await _pumpHarness(tester, observer);

    await _tapAction(
      tester,
      () => AppNavigator.openDetail(_context(tester), 'note-42'),
    );
    await tester.pump();

    final screen = tester.widget<TranscriptDetailScreen>(
      find.byType(TranscriptDetailScreen),
    );
    expect(screen.noteId, 'note-42');
    expect(observer.pushes, hasLength(2));
  });

  testWidgets('startProcessing passes every processing argument', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await _pumpHarness(tester, observer);

    await _tapAction(
      tester,
      () => AppNavigator.startProcessing(
        _context(tester),
        const ProcessingNavigationRequest(
          audioPath: '/tmp/input.m4a',
          ownership: AudioOwnership.temporary,
          source: NoteSource.shared,
          fileName: 'shared.m4a',
          knownDurationSec: 17,
        ),
      ),
    );
    await tester.pump();

    final screen = tester.widget<ProcessingScreen>(
      find.byType(ProcessingScreen),
    );
    expect(screen.audioPath, '/tmp/input.m4a');
    expect(screen.ownership, AudioOwnership.temporary);
    expect(screen.source, NoteSource.shared);
    expect(screen.fileName, 'shared.m4a');
    expect(screen.knownDurationSec, 17);
    expect(observer.pushes, hasLength(2));
    expect(observer.replacements, isEmpty);
  });

  testWidgets('startProcessing replaces the current route when requested', (
    tester,
  ) async {
    final observer = _RouteObserver();
    await _pumpHarness(tester, observer);

    await _tapAction(
      tester,
      () => AppNavigator.startProcessing(
        _context(tester),
        const ProcessingNavigationRequest(
          audioPath: '/tmp/recording.m4a',
          ownership: AudioOwnership.temporary,
          source: NoteSource.recording,
          knownDurationSec: 3,
        ),
        replace: true,
      ),
    );

    expect(observer.pushes, hasLength(1));
    expect(observer.replacements, hasLength(1));
  });
}

void _registerRecordingTests() {
  const channel = MethodChannel('com.llfbandit.record/messages');
  final strings = AppStrings.of(AppLanguage.de);
  late OnboardingPermissionChannel permissions;
  late FakeAudioRecorderService recorder;

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => null);
    permissions = OnboardingPermissionChannel()..install();
    final root = Directory.systemTemp.createTempSync(
      'transcriber_record_test_',
    );
    addTearDown(() => root.delete(recursive: true));
    recorder = FakeAudioRecorderService(
      AudioCacheManager(
        paths: Future.value(StoragePaths(supportRoot: root, cacheRoot: root)),
      ),
    );
  });
  tearDown(() async {
    await recorder.dispose();
    await permissions.uninstall();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Future<void> open(WidgetTester tester) async {
    await _pumpHarness(tester, _RouteObserver(), recorder: recorder);
    expect(permissions.requestCalls, 0);
    await _tapAction(tester, () => AppNavigator.openRecord(_context(tester)));
    await tester.pumpAndSettle();
    expect(permissions.requestCalls, 1);
  }

  testWidgets('recording starts when microphone access is granted', (
    tester,
  ) async {
    permissions.requestedMicrophone = PermissionStatus.granted;
    await open(tester);
    expect(find.byType(RecordScreen), findsOneWidget);
    expect(recorder.startCalls, 1);
    await tester.tap(find.text(strings.recCancel));
    await tester.pumpAndSettle();
    expect(recorder.cancelCalls, 1);
    expect(find.byType(RecordScreen), findsNothing);
  });

  testWidgets('declining microphone access returns to the previous screen', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(RecordScreen), findsNothing);
    expect(find.text(strings.micPermissionBody), findsOneWidget);
    expect(find.text(strings.micPermissionSettings), findsNothing);
    expect(recorder.startCalls, 0);
  });

  testWidgets('permanent denial offers app settings without recording', (
    tester,
  ) async {
    permissions.requestedMicrophone = PermissionStatus.permanentlyDenied;
    await open(tester);
    expect(find.byType(RecordScreen), findsNothing);
    expect(recorder.startCalls, 0);
    await tester.tap(find.text(strings.micPermissionSettings));
    await tester.pumpAndSettle();
    expect(permissions.settingsCalls, 1);
  });

  testWidgets(
    'cancelling before the permission response prevents late capture',
    (tester) async {
      final pending = Completer<PermissionStatus>();
      permissions.pendingRequest = pending.future;
      await open(tester);
      expect(find.text(strings.recHint), findsNothing);
      await tester.tap(find.text(strings.recCancel));
      await tester.pumpAndSettle();
      pending.complete(PermissionStatus.granted);
      await tester.pumpAndSettle();
      expect(find.byType(RecordScreen), findsNothing);
      expect(recorder.startCalls, 0);
    },
  );
}

BuildContext _context(WidgetTester tester) => tester.element(find.text('Open'));

Future<void> _tapAction(
  WidgetTester tester,
  Future<dynamic> Function() action,
) async {
  unawaited(action());
  await tester.pump();
}

Future<void> _pumpHarness(
  WidgetTester tester,
  NavigatorObserver observer, {
  FakeAudioRecorderService? recorder,
}) async {
  final database = AppDatabase(NativeDatabase.memory());
  addTearDown(database.close);
  final settings = AppSettings.initial().copyWith(
    summary: const SummarySettings(enabled: false),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialSettingsProvider.overrideWithValue(settings),
        initialConnectionsProvider.overrideWithValue(const {}),
        initialNotesProvider.overrideWithValue(const []),
        audioCacheManagerProvider.overrideWithValue(AudioCacheManager()),
        if (recorder != null) audioRecorderProvider.overrideWithValue(recorder),
      ],
      child: MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            AppPalette.light(AppAccent.violet),
          ],
        ),
        navigatorObservers: [observer],
        home: Builder(builder: (context) => const Scaffold(body: Text('Open'))),
      ),
    ),
  );
}

class _RouteObserver extends NavigatorObserver {
  final pushes = <Route<dynamic>>[];
  final replacements =
      <({Route<dynamic>? newRoute, Route<dynamic>? oldRoute})>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes.add(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replacements.add((newRoute: newRoute, oldRoute: oldRoute));
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
