import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/app.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/audio_ownership.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/ui/screens/detail/transcript_detail_screen.dart';
import 'package:transcriber/ui/screens/home/home_screen.dart';
import 'package:transcriber/ui/screens/onboarding/onboarding_screen.dart';

import 'support/app_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestPermissionChannel permissions;

  setUp(() {
    permissions = TestPermissionChannel(granted: true);
    permissions.install();
  });

  tearDown(() => permissions.uninstall());

  _registerRevokedMicrophoneTest(() => permissions);
  _registerResumeRefreshTest();
}

void _registerRevokedMicrophoneTest(
  TestPermissionChannel Function() currentPermissions,
) {
  testWidgets('revoked microphone access preserves access to existing notes', (
    tester,
  ) async {
    final database = testDatabase();
    await NotesRepository(database).saveAll([_sharedNote()]);
    await _pumpApp(
      tester,
      AppSettings.initial().copyWith(onboarded: true),
      textScale: 0.7,
      database: database,
    );
    expect(find.byType(HomeScreen), findsOneWidget);

    currentPermissions().granted = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byType(OnboardingScreen), findsNothing);
    await tester.tap(find.text('Shared WhatsApp audio'));
    await tester.pumpAndSettle();
    expect(find.byType(TranscriptDetailScreen), findsOneWidget);
  });
}

void _registerResumeRefreshTest() {
  testWidgets('resume reloads a note saved by the share entry point', (
    tester,
  ) async {
    final database = testDatabase();
    await _pumpApp(
      tester,
      AppSettings.initial().copyWith(onboarded: true),
      database: database,
      textScale: 0.7,
    );
    expect(find.text('Shared WhatsApp audio'), findsNothing);

    await NotesRepository(database).saveAll([_sharedNote()]);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.text('Shared WhatsApp audio'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  AppSettings settings, {
  Size size = const Size(400, 900),
  double? textScale,
  AppDatabase? database,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final appDatabase = database ?? testDatabase();
  addTearDown(appDatabase.close);
  const app = TranscriberApp();
  await tester.pumpWidget(
    appScope(
      database: appDatabase,
      settings: settings,
      child: textScale == null
          ? app
          : MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: app,
            ),
    ),
  );
  await tester.pump();
}

TranscriptNote _sharedNote() => TranscriptNote(
  metadata: NoteMetadata(
    id: 'shared-note',
    title: 'Shared WhatsApp audio',
    speaker: 'Unknown',
    source: NoteSource.shared,
    durationSec: 2,
    createdAt: DateTime.utc(2026, 8, 28),
  ),
  origins: const NoteOrigins(
    asrIsLocal: false,
    summaryIsLocal: false,
    asrName: 'Gemini 3.5 Transcribe',
    asrSub: 'Google Gemini',
    llmName: 'Gemini 3.7 Flash',
    llmSub: 'Google Gemini',
  ),
  content: const NoteContent(
    gist: 'Shared note',
    points: [],
    todos: [],
    transcript: [TranscriptLine(text: 'Shared transcript')],
  ),
  audioOwnership: AudioOwnership.external,
);
