import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/app.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/audio_ownership.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/ui/screens/home/home_screen.dart';
import 'package:transcriber/ui/screens/onboarding/onboarding_screen.dart';
import 'package:transcriber/ui/screens/share/widgets/transcriber_app_shell.dart';
import 'package:transcriber/ui/screens/tablet/tablet_home_screen.dart';

import 'support/app_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TestPermissionChannel permissions;

  setUp(() {
    permissions = TestPermissionChannel(granted: true);
    permissions.install();
  });

  tearDown(() => permissions.uninstall());

  testWidgets('app shell applies theme, accent, and locale', (tester) async {
    final database = testDatabase();
    addTearDown(database.close);
    final settings = AppSettings.initial().copyWith(
      accent: AppAccent.amber,
      language: AppLanguage.en,
      themeMode: ThemeMode.dark,
    );
    await tester.pumpWidget(
      appScope(
        database: database,
        settings: settings,
        child: const TranscriberAppShell(home: Text('shell marker')),
      ),
    );

    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.locale, const Locale('en'));
    expect(material.themeMode, ThemeMode.dark);
    expect(
      material.darkTheme!.extension<AppPalette>()!.accent,
      AppAccent.amber.color,
    );
    expect(find.text('shell marker'), findsOneWidget);
  });

  testWidgets('unonboarded users are routed to onboarding', (tester) async {
    await _pumpApp(
      tester,
      AppSettings.initial(),
      size: const Size(800, 900),
      textScale: 0.7,
    );

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('onboarded phone users are routed to home', (tester) async {
    await _pumpApp(
      tester,
      AppSettings.initial().copyWith(onboarded: true),
      textScale: 0.7,
    );

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(TabletHomeScreen), findsNothing);
  });

  testWidgets('onboarded wide users are routed to the tablet split view', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      AppSettings.initial().copyWith(onboarded: true),
      size: const Size(900, 700),
    );

    expect(find.byType(TabletHomeScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('revoked permission gates an onboarded user back to onboarding', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      AppSettings.initial().copyWith(onboarded: true),
      textScale: 0.7,
    );
    expect(find.byType(HomeScreen), findsOneWidget);

    permissions.granted = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  _registerResumeRefreshTest();
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
      shareService: TestShareIntentService(),
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
  id: 'shared-note',
  title: 'Shared WhatsApp audio',
  speaker: 'Unknown',
  source: NoteSource.shared,
  durationSec: 2,
  createdAt: DateTime.utc(2026, 8, 28),
  asrIsLocal: false,
  summaryIsLocal: false,
  asrName: 'Gemini 3.5 Transcribe',
  asrSub: 'Google Gemini',
  llmName: 'Gemini 3.7 Flash',
  llmSub: 'Google Gemini',
  gist: 'Shared note',
  points: const [],
  todos: const [],
  transcript: const [TranscriptLine(text: 'Shared transcript')],
  audioOwnership: AudioOwnership.external,
);
