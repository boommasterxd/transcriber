import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/processing/processing_pipeline.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/model_manager_controller.dart';
import 'package:transcriber/state/notes_controller.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/detail/transcript_detail_screen.dart';
import 'package:transcriber/ui/screens/processing/processing_screen.dart';
import 'package:transcriber/ui/screens/processing/widgets/processing_status_content.dart';
import 'package:transcriber/ui/screens/settings/settings_screen.dart';
import '../../../support/app_test_fakes.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);

  testWidgets('renders a running transcription with model metadata', (
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
    expect(controller.lastFileName, 'meeting.m4a');
  });

  testWidgets('renders summarization and model download progress', (
    tester,
  ) async {
    final controller = _FakeProcessingController(
      const ProcessingState(
        running: true,
        step: ProcessingStep.summarizing,
        modelProgress: 0.426,
      ),
    );
    await _pumpScreen(tester, controller);

    expect(find.text(strings.shSummarize), findsOneWidget);
    expect(find.text('${strings.downloading} 43%'), findsOneWidget);
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

  testWidgets('opens settings for a missing model error', (tester) async {
    final controller = _FakeProcessingController(
      const ProcessingState(error: ModelNotDownloadedException('model path')),
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
}

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeProcessingController controller, {
  NavigatorObserver? observer,
}) async {
  final preferences = await testPreferences();
  final settings = AppSettings.initial().copyWith(
    language: AppLanguage.en,
    summarizeEnabled: true,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        processingControllerProvider.overrideWith(() => controller),
        sharedPreferencesProvider.overrideWithValue(preferences),
        settingsControllerProvider.overrideWith(
          () => TestSettingsController(settings),
        ),
        connectionsControllerProvider.overrideWith(
          TestConnectionsController.new,
        ),
        modelManagerControllerProvider.overrideWith(
          TestModelManagerController.new,
        ),
        notesControllerProvider.overrideWith(TestNotesController.new),
      ],
      child: MaterialApp(
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            AppPalette.light(AppAccent.violet),
          ],
        ),
        navigatorObservers: [?observer],
        home: const ProcessingScreen(
          audioPath: '/tmp/audio.m4a',
          source: NoteSource.file,
          fileName: 'meeting.m4a',
        ),
      ),
    ),
  );
  await tester.pump();
}

TranscriptNote _note(String id) => TranscriptNote(
  id: id,
  title: 'Meeting',
  speaker: 'Speaker',
  source: NoteSource.file,
  durationSec: 10,
  createdAt: DateTime(2024, 1, 1),
  asrIsLocal: true,
  summaryIsLocal: true,
  asrName: 'Whisper',
  asrSub: '75 MB',
  llmName: 'Gemma',
  llmSub: '2 GB',
  gist: 'Summary',
  points: const [],
  todos: const [],
  transcript: const [],
);

final class _FakeProcessingController extends ProcessingController {
  _FakeProcessingController(this.initialState);

  final ProcessingState initialState;
  int runCount = 0;
  ProcessingInput? lastInput;
  String? lastFileName;

  @override
  ProcessingState build() => initialState;

  @override
  Future<void> run(
    ProcessingInput input, {
    String? fileName,
    bool save = true,
  }) async {
    runCount++;
    lastInput = input;
    lastFileName = fileName;
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
