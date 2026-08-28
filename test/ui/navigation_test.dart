import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/ui/navigation.dart';
import 'package:transcriber/ui/screens/detail/transcript_detail_screen.dart';
import 'package:transcriber/ui/screens/processing/processing_screen.dart';
import 'package:transcriber/ui/screens/record/record_screen.dart';
import 'package:transcriber/ui/screens/settings/settings_screen.dart';

void main() {
  testWidgets('openSettings pushes the settings screen', (tester) async {
    final observer = _RouteObserver();
    await _pumpHarness(tester, observer);

    await _tapAction(tester, () => AppNavigator.openSettings(_context(tester)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(observer.pushes, hasLength(2));
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('openRecord pushes the record screen', (tester) async {
    final observer = _RouteObserver();
    await _pumpHarness(tester, observer);

    await _tapAction(tester, () => AppNavigator.openRecord(_context(tester)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(observer.pushes, hasLength(2));
    expect(find.byType(RecordScreen), findsOneWidget);
  });

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
        audioPath: '/tmp/input.m4a',
        source: NoteSource.shared,
        fileName: 'shared.m4a',
        knownDurationSec: 17,
      ),
    );
    await tester.pump();

    final screen = tester.widget<ProcessingScreen>(
      find.byType(ProcessingScreen),
    );
    expect(screen.audioPath, '/tmp/input.m4a');
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
        audioPath: '/tmp/recording.m4a',
        source: NoteSource.recording,
        knownDurationSec: 3,
        replace: true,
      ),
    );

    expect(observer.pushes, hasLength(1));
    expect(observer.replacements, hasLength(1));
  });
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
  NavigatorObserver observer,
) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings.initial().copyWith(
    asrMode: ProcessingMode.cloud,
    summarizeEnabled: false,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialSettingsProvider.overrideWithValue(settings),
        initialConnectionsProvider.overrideWithValue(const {}),
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
