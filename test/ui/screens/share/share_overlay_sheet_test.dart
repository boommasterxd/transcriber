import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/processing/processing_request.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/ui/screens/settings/settings_screen.dart';
import 'package:transcriber/ui/screens/share/share_overlay_sheet.dart';

import '../../../support/app_test_fakes.dart';
import 'share_test_support.dart';

void main() {
  testWidgets(
    'share reconfirms uploads and saves only after an explicit action',
    (tester) async {
      var finished = false;
      final controller = _FakeProcessingController([
        const MissingApiKeyException('Provider key unavailable'),
        shareTestNote(gist: 'Recovered after connecting'),
      ]);
      await tester.pumpWidget(
        _shareApp(
          createProcessing: () => controller,
          child: ShareSheetContent(
            audioPath: '/audio/shared.m4a',
            onFinished: () => finished = true,
          ),
        ),
      );
      expect(controller.runCalls, 0);
      await _confirmShare(tester);
      expect(controller.lastSave, isFalse);

      await tester.tap(find.text(shareTestStrings.goToSettings));
      await tester.pumpAndSettle();

      expect(finished, isFalse);
      expect(controller.discardCalls, 0);
      expect(find.byType(SettingsScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(controller.runCalls, 1);
      expect(find.text(shareTestStrings.shareConfirmTitle), findsOneWidget);
      await _confirmShare(tester);
      expect(controller.runCalls, 2);
      expect(controller.lastSave, isFalse);
      expect(find.text('Recovered after connecting'), findsOneWidget);
      expect(controller.commitCalls, 0);
      expect(finished, isFalse);

      await tester.tap(find.text(shareTestStrings.shSave));
      await tester.pumpAndSettle();
      expect(controller.commitCalls, 1);
      expect(finished, isTrue);
    },
  );
}

Future<void> _confirmShare(WidgetTester tester) async {
  await tester.tap(find.text(shareTestStrings.shareConfirmAction));
  await tester.pump();
}

Widget _shareApp({
  required Widget child,
  required _FakeProcessingController Function() createProcessing,
}) {
  final database = testDatabase();
  addTearDown(database.close);
  return appScope(
    database: database,
    settings: shareTestSettings(),
    child: ProviderScope(
      overrides: [processingControllerProvider.overrideWith(createProcessing)],
      child: MaterialApp(
        theme: shareTestTheme(),
        home: Scaffold(body: child),
      ),
    ),
  );
}

final class _FakeProcessingController extends ProcessingController {
  _FakeProcessingController(this._outcomes);

  final List<Object> _outcomes;
  int runCalls = 0;
  int commitCalls = 0;
  int discardCalls = 0;
  bool? lastSave;

  @override
  ProcessingState build() => const ProcessingState();

  @override
  Future<void> run(
    ProcessingInput input, {
    String? fileName,
    bool save = true,
    Object? owner,
  }) async {
    runCalls++;
    lastSave = save;
    final outcome = _outcomes.removeAt(0);
    state = outcome is TranscriptNote
        ? ProcessingState(result: outcome)
        : ProcessingState(error: outcome);
  }

  @override
  Future<void> commit() async {
    commitCalls++;
  }

  @override
  Future<void> discardCurrent({Object? owner}) async {
    discardCalls++;
  }
}
