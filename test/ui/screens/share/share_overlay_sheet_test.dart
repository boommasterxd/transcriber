import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/audio_ownership.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/processing/processing_request.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/state/processing_controller.dart';
import 'package:transcriber/ui/navigation.dart';
import 'package:transcriber/ui/screens/share/share_overlay_sheet.dart';
import '../../../support/app_test_fakes.dart';
import 'share_test_support.dart';

void main() {
  _registerPreviewCommitTest();
  _registerDismissTest();
  _registerRetryTest();
  _registerSettingsTest();
  _registerLayoutTests();
}

void _registerPreviewCommitTest() {
  testWidgets('share preview uses save false and commits at most once', (
    tester,
  ) async {
    late _FakeProcessingController controller;
    var finished = false;
    final note = shareTestNote(gist: 'A concise summary.');

    await tester.pumpWidget(
      _shareApp(
        createProcessing: () => controller = _FakeProcessingController([note]),
        child: ShareSheetContent(
          audioPath: '/audio/shared.m4a',
          onFinished: () => finished = true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.lastSave, isFalse);
    expect(controller.lastInput?.audio.ownership, AudioOwnership.temporary);
    expect(find.text(note.title), findsOneWidget);

    await tester.tap(find.text(shareTestStrings.shSave));
    await tester.pump();
    await tester.tap(find.text(shareTestStrings.shSave));
    await tester.pump();

    expect(controller.commitCalls, 1);
    expect(controller.discardCalls, 1);
    expect(finished, isTrue);
  });
}

void _registerDismissTest() {
  testWidgets('share error can be dismissed', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      _shareApp(
        createProcessing: () =>
            _FakeProcessingController([StateError('processing failed')]),
        child: ShareSheetContent(
          audioPath: '/audio/shared.m4a',
          onFinished: () => finished = true,
        ),
      ),
    );
    await tester.pump();

    expect(find.text(shareTestStrings.errorTitle), findsOneWidget);
    await tester.tap(find.text(shareTestStrings.dismiss));
    await tester.pump();

    expect(finished, isTrue);
  });
}

void _registerRetryTest() {
  testWidgets('share error retries processing', (tester) async {
    late _FakeProcessingController controller;
    final note = shareTestNote(gist: 'Recovered summary.');
    await tester.pumpWidget(
      _shareApp(
        createProcessing: () => controller = _FakeProcessingController([
          StateError('temporary failure'),
          note,
        ]),
        child: ShareSheetContent(
          audioPath: '/audio/shared.m4a',
          onFinished: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(shareTestStrings.retry));
    await tester.pump();

    expect(controller.runCalls, 2);
    expect(find.text(note.title), findsOneWidget);
  });
}

void _registerSettingsTest() {
  testWidgets('missing API key opens settings after closing share sheet', (
    tester,
  ) async {
    var finished = false;
    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      _shareApp(
        observer: observer,
        createProcessing: () => _FakeProcessingController([
          const MissingApiKeyException('Provider key unavailable'),
        ]),
        child: ShareSheetContent(
          audioPath: '/audio/shared.m4a',
          onFinished: () => finished = true,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(shareTestStrings.goToSettings));
    await tester.pump(const Duration(milliseconds: 400));

    expect(finished, isTrue);
    expect(observer.pushes, 2);
  });
}

void _registerLayoutTests() {
  _registerSheetWidthTest(
    'share sheet uses the full phone width',
    const Size(400, 800),
    400,
  );
  _registerSheetWidthTest(
    'share sheet caps its width on tablets',
    const Size(800, 800),
    600,
  );
}

void _registerSheetWidthTest(String name, Size size, double expectedWidth) {
  testWidgets(name, (tester) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpSheet(tester);

    expect(tester.getSize(find.byType(ShareSheetContent)).width, expectedWidth);
  });
}

Future<void> _pumpSheet(WidgetTester tester) async {
  final note = shareTestNote(gist: 'Layout summary.');
  await tester.pumpWidget(
    _shareApp(
      createProcessing: () => _FakeProcessingController([note]),
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => presentShareSheet(
            context: context,
            audioPath: '/audio/shared.m4a',
          ),
          child: const Text('Open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pump();
  await tester.pump();
}

Widget _shareApp({
  required Widget child,
  required _FakeProcessingController Function() createProcessing,
  NavigatorObserver? observer,
}) {
  final database = testDatabase();
  addTearDown(database.close);
  return appScope(
    database: database,
    settings: shareTestSettings(),
    child: ProviderScope(
      overrides: [processingControllerProvider.overrideWith(createProcessing)],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: observer == null ? const [] : [observer],
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
  ProcessingInput? lastInput;

  @override
  ProcessingState build() => const ProcessingState();

  @override
  Future<void> run(
    ProcessingInput input, {
    String? fileName,
    bool save = true,
  }) async {
    runCalls++;
    lastInput = input;
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
  Future<void> discardCurrent() async {
    discardCalls++;
  }
}

final class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
    super.didPush(route, previousRoute);
  }
}
