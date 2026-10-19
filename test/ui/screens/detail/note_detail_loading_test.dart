import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/state/note_detail_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/ui/screens/detail/transcript_detail_screen.dart';

import '../../widgets/widget_test_helpers.dart';
import 'detail_test_helpers.dart';

void main() {
  testWidgets('renders only the requested detail after lookup completes', (
    tester,
  ) async {
    final pending = Completer<TranscriptNote?>();
    await _pumpDetail(tester, (_) => pending.future);
    expect(find.text('Planning session'), findsNothing);
    pending.complete(detailTestNote(id: 'requested-note'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Planning session'), findsOneWidget);
    expect(find.text('Concise summary'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('waits for detail lookup before showing a missing note', (
    tester,
  ) async {
    final pending = Completer<TranscriptNote?>();
    final requestedIds = <String>[];
    await _pumpDetail(tester, (id) {
      requestedIds.add(id);
      return pending.future;
    });
    expect(requestedIds, ['requested-note']);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(AppStrings.of(AppLanguage.en).errorTitle), findsNothing);
    pending.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(AppStrings.of(AppLanguage.en).errorTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail failure exposes a keyboard-accessible retry', (
    tester,
  ) async {
    var attempts = 0;
    final pending = Completer<TranscriptNote?>();
    final semantics = tester.ensureSemantics();
    await _pumpDetail(tester, (id) {
      attempts++;
      return attempts == 1
          ? Future.error(StateError('Detail unavailable'))
          : pending.future;
    });
    await tester.pump();
    final retry = AppStrings.of(AppLanguage.en).retry;
    expect(find.text(retry), findsOneWidget);
    expect(find.bySemanticsLabel(retry), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(attempts, 2);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(null);
    await tester.pump();
    await tester.pump();
    expect(find.text(retry), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  Future<TranscriptNote?> Function(String) load,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        stringsProvider.overrideWithValue(AppStrings.of(AppLanguage.en)),
        noteDetailProvider.overrideWith((ref, id) => load(id)),
      ],
      child: themed(const TranscriptDetailScreen(noteId: 'requested-note')),
    ),
  );
  await tester.pump();
}
