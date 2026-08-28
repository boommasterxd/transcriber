import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/ui/screens/home/audio_import.dart';

import 'home_test_helpers.dart';

void main() {
  _registerSelectedFileTest();
  _registerCancellationTest();
  _registerUnmountedContextTest();
}

void _registerSelectedFileTest() {
  testWidgets('selected audio is forwarded to processing once', (tester) async {
    const selection = AudioImportSelection(
      path: '/tmp/meeting.m4a',
      fileName: 'meeting.m4a',
    );
    AudioImportSelection? startedSelection;
    late BuildContext context;
    await tester.pumpWidget(captureBuildContext((value) => context = value));

    await startAudioImport(
      context,
      picker: () async => selection,
      starter: (_, value) async => startedSelection = value,
    );

    expect(startedSelection, same(selection));
  });
}

void _registerCancellationTest() {
  testWidgets('cancelled audio selection does not start processing', (
    tester,
  ) async {
    var started = false;
    late BuildContext context;
    await tester.pumpWidget(captureBuildContext((value) => context = value));

    await startAudioImport(
      context,
      picker: () async => null,
      starter: (_, _) async => started = true,
    );

    expect(started, isFalse);
  });
}

void _registerUnmountedContextTest() {
  testWidgets('selection is ignored after its screen is unmounted', (
    tester,
  ) async {
    final picker = Completer<AudioImportSelection?>();
    var started = false;
    late BuildContext context;
    await tester.pumpWidget(captureBuildContext((value) => context = value));
    final operation = startAudioImport(
      context,
      picker: () => picker.future,
      starter: (_, _) async => started = true,
    );

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    picker.complete(
      const AudioImportSelection(path: '/tmp/note.wav', fileName: 'note.wav'),
    );
    await operation;

    expect(started, isFalse);
  });
}
