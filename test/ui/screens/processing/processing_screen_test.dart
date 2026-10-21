import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/audio_ownership.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/ui/screens/detail/transcript_detail_screen.dart';
import 'package:transcriber/ui/screens/processing/processing_screen.dart';
import 'package:transcriber/ui/screens/processing/widgets/processing_status_content.dart';
import 'package:transcriber/ui/screens/settings/settings_screen.dart';
import '../../../support/app_test_fakes.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);

  testWidgets('renders a running transcription with cloud metadata', (
    tester,
  ) async {
    final controller = _FakeProcessingController(
      const ProcessingState(running: true, fileName: 'meeting.m4a'),
    );
    await _pumpScreen(tester, controller);

    expect(find.text(strings.shTranscribe), findsOneWidget);
    expect(find.text('meeting.m4a'), findsOneWidget);
    expect(find.byType(ProcessingStatusContent), findsOneWidget);
    expect(controller.runCount, 1);
    expect(controller.lastInput?.audioPath, '/tmp/audio.m4a');
    expect(controller.lastInput?.audio.ownership, AudioOwnership.external);
    expect(controller.lastFileName, 'meeting.m4a');
  });

  testWidgets('renders cloud summarization status and both steps', (
    tester,
  ) async {
    final controller = _FakeProcessingController(
      const ProcessingState(running: true, step: ProcessingStep.summarizing),
    );
    await _pumpScreen(tester, controller);

    expect(find.text(strings.shSummarize), findsOneWidget);
    expect(find.text('gemini-3.7-flash · Google Gemini'), findsOneWidget);
    expect(find.text(strings.shStep1), findsOneWidget);
    expect(find.text(strings.shStep2), findsOneWidget);
  });

  testWidgets('dismisses a normal processing error', (tester) async {
    final controller = _FakeProcessingController(
      const ProcessingState(error: RemoteApiException('Provider unavailable')),
    );
    final observer = _RouteObserver();
    await _pumpScreen(tester, controller, observer: observer);

    expect(find.text(strings.errorTitle), findsOneWidget);
    expect(find.text('Provider unavailable'), findsOneWidget);
    await tester.tap(find.text(strings.dismiss));
    await tester.pump();

    expect(observer.pops, 1);
  });

  testWidgets('retries a normal processing error after resetting state', (
    tester,
  ) async {
    final controller = _FakeProcessingController(
      const ProcessingState(error: RemoteApiException('Temporary failure')),
    );
    await _pumpScreen(tester, controller);

    await tester.tap(find.text(strings.retry));
    await tester.pump();

    expect(controller.runCount, 2);
    expect(find.byType(ProcessingStatusContent), findsOneWidget);
    expect(find.text(strings.errorTitle), findsNothing);
  });

  testWidgets('opens settings for a missing API key error', (tester) async {
    final controller = _FakeProcessingController(
      const ProcessingState(
        error: MissingApiKeyException('Connect a provider first'),
      ),
    );
    await _pumpScreen(tester, controller);

    await tester.tap(find.text(strings.goToSettings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text(strings.setTitle), findsOneWidget);
  });

  testWidgets('replaces processing with the transcript detail on success', (
    tester,
  ) async {
    final controller = _FakeProcessingController(const ProcessingState());
    await _pumpScreen(tester, controller);

    controller.emit(ProcessingState(result: _note('note-42')));
    await tester.pump();
    await tester.pump();

    final detail = tester.widget<TranscriptDetailScreen>(
      find.byType(TranscriptDetailScreen),
    );
    expect(detail.noteId, 'note-42');
  });

  _registerReentryNavigationTest();
}

void _registerReentryNavigationTest() {
  testWidgets('System Back releases the old route before a new import starts', (
    tester,
  ) async {
    final controller = _FakeProcessingController(
      const ProcessingState(running: true),
    );
    await _pumpScreen(
      tester,
      controller,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProcessingScreen(
                  audioPath: '/tmp/audio.m4a',
                  ownership: AudioOwnership.external,
                  source: NoteSource.file,
                ),
              ),
            ),
            child: const Text('Import'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    final firstOwner = controller.lastOwner;

    await tester.binding.handlePopRoute();
    expect(controller.discardedOwners, contains(firstOwner));
    controller.emit(ProcessingState(result: _note('discarded-note')));
    await tester.pumpAndSettle();
    expect(find.text('Import'), findsOneWidget);
    expect(find.byType(TranscriptDetailScreen), findsNothing);

    controller.emit(const ProcessingState(running: true));
    await tester.tap(find.text('Import'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 320));
    expect(controller.runCount, 2);
    expect(controller.lastOwner, isNot(same(firstOwner)));
    controller.emit(ProcessingState(result: _note('second-note')));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<TranscriptDetailScreen>(find.byType(TranscriptDetailScreen))
          .noteId,
      'second-note',
    );
  });
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeProcessingController controller, {
  NavigatorObserver? observer,
  Widget? home,
}) async {
  final database = testDatabase();
  addTearDown(database.close);
  final settings = AppSettings.initial().copyWith(
    appearance: const AppearanceSettings(language: AppLanguage.en),
    summary: const SummarySettings(enabled: true),
  );
  await tester.pumpWidget(
    appScope(
      database: database,
      settings: settings,
      child: ProviderScope(
        overrides: [
          processingControllerProvider.overrideWith(() => controller),
        ],
        child: MaterialApp(
          theme: ThemeData(
            extensions: <ThemeExtension<dynamic>>[
              AppPalette.light(AppAccent.violet),
            ],
          ),
          navigatorObservers: [?observer],
          home:
              home ??
              const ProcessingScreen(
                audioPath: '/tmp/audio.m4a',
                ownership: AudioOwnership.external,
                source: NoteSource.file,
                fileName: 'meeting.m4a',
              ),
        ),
      ),
    ),
  );
  await tester.pump();
}

TranscriptNote _note(String id) => TranscriptNote(
  metadata: NoteMetadata(
    id: id,
    title: 'Meeting',
    speaker: 'Speaker',
    source: NoteSource.file,
    durationSec: 10,
    createdAt: DateTime(2024, 1, 1),
  ),
  origins: const NoteOrigins(
    asrIsLocal: false,
    summaryIsLocal: false,
    asrName: 'gpt-transcribe',
    asrSub: 'OpenAI',
    llmName: 'gpt-5.6-luna',
    llmSub: 'OpenAI',
  ),
  content: const NoteContent(
    gist: 'Summary',
    points: [],
    todos: [],
    transcript: [],
  ),
);

final class _FakeProcessingController extends ProcessingController {
  _FakeProcessingController(this.initialState);

  final ProcessingState initialState;
  int runCount = 0;
  ProcessingInput? lastInput;
  String? lastFileName;
  Object? lastOwner;
  final discardedOwners = <Object?>[];

  @override
  ProcessingState build() => initialState;

  @override
  Future<void> run(
    ProcessingInput input, {
    String? fileName,
    bool save = true,
    Object? owner,
  }) async {
    runCount++;
    lastInput = input;
    lastFileName = fileName;
    lastOwner = owner;
  }

  @override
  bool isOwnedBy(Object owner) => identical(owner, lastOwner);

  @override
  Future<void> discardCurrent({Object? owner}) async {
    discardedOwners.add(owner);
  }

  void emit(ProcessingState next) => state = next;
}

final class _RouteObserver extends NavigatorObserver {
  int pops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pops++;
    super.didPop(route, previousRoute);
  }
}
