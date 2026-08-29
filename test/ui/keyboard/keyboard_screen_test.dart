import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/dictation_state.dart';
import 'package:transcriber/ui/keyboard/keyboard_screen.dart';

void main() {
  _registerInteractionTests();
  _registerErrorTests();
}

void _registerInteractionTests() {
  testWidgets('shows the active live model and starts live dictation', (
    tester,
  ) async {
    var starts = 0;
    await _pumpKeyboard(
      tester,
      _state(DictationPhase.ready),
      actions: _KeyboardActions(start: () => starts++),
    );

    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('gpt-live-transcribe'), findsOneWidget);
    expect(find.text('Bereit für Live-Diktat'), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.mic_rounded));
    expect(starts, 1);
  });

  testWidgets('renders live correction, waveform, timer, and controls', (
    tester,
  ) async {
    var stops = 0;
    var cancels = 0;
    await _pumpKeyboard(
      tester,
      _state(DictationPhase.correcting).copyWith(
        preview: 'Guten Mor',
        elapsed: const Duration(minutes: 2, seconds: 7),
        levels: const [0.1, 0.5, 0.9],
      ),
      brightness: Brightness.dark,
      actions: _KeyboardActions(stop: () => stops++, cancel: () => cancels++),
    );

    expect(find.text('Text wird live korrigiert'), findsOneWidget);
    expect(find.text('Guten Mor'), findsOneWidget);
    expect(find.text('02:07'), findsOneWidget);
    await tester.tap(find.text('Stoppen'));
    await tester.tap(find.text('Abbrechen'));
    expect(stops, 1);
    expect(cancels, 1);
  });

  testWidgets('blocks protected fields and exposes TalkBack semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpKeyboard(
      tester,
      _state(DictationPhase.unavailable).copyWith(editorSupported: false),
      textScale: 1.6,
    );

    expect(find.textContaining('geschützten Textfeld'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.bySemanticsLabel('Vorherige Tastatur'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('opens app settings when microphone permission is missing', (
    tester,
  ) async {
    var settingsOpened = 0;
    await _pumpKeyboard(
      tester,
      _state(
        DictationPhase.error,
      ).copyWith(microphoneGranted: false, errorCode: 'microphone_denied'),
      actions: _KeyboardActions(openAppSettings: () => settingsOpened++),
    );

    expect(find.textContaining('Mikrofonzugriff'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    expect(settingsOpened, 1);
  });
}

void _registerErrorTests() {
  testWidgets('shows actionable provider and connection errors', (
    tester,
  ) async {
    await _pumpKeyboard(
      tester,
      _state(DictationPhase.error).copyWith(errorCode: 'api_key_missing'),
    );
    expect(find.textContaining('API-Schlüssel'), findsOneWidget);

    await _pumpKeyboard(
      tester,
      _state(DictationPhase.error).copyWith(errorCode: 'authentication_failed'),
    );
    expect(find.textContaining('Schlüssel abgelehnt'), findsOneWidget);

    await _pumpKeyboard(
      tester,
      _state(DictationPhase.error).copyWith(errorCode: 'quota_exceeded'),
    );
    expect(find.textContaining('Kontingent'), findsOneWidget);

    await _pumpKeyboard(
      tester,
      _state(DictationPhase.error).copyWith(errorCode: 'model_unavailable'),
    );
    expect(find.textContaining('Live-Modell'), findsOneWidget);

    await _pumpKeyboard(
      tester,
      _state(
        DictationPhase.error,
      ).copyWith(errorCode: 'configuration_rejected'),
    );
    expect(find.textContaining('Live-Konfiguration'), findsOneWidget);

    await _pumpKeyboard(
      tester,
      _state(DictationPhase.error).copyWith(errorCode: 'connection_timeout'),
    );
    expect(find.textContaining('antwortet nicht'), findsOneWidget);

    await _pumpKeyboard(
      tester,
      _state(DictationPhase.error).copyWith(errorCode: 'network'),
    );
    expect(find.textContaining('Live-Verbindung'), findsOneWidget);
  });
}

DictationState _state(DictationPhase phase) =>
    DictationState.initial().copyWith(
      phase: phase,
      visible: true,
      editorSupported: true,
      microphoneGranted: true,
      provider: RemoteProviderId.openai,
      modelId: 'gpt-live-transcribe',
      clearError: true,
    );

Future<void> _pumpKeyboard(
  WidgetTester tester,
  DictationState state, {
  Brightness brightness = Brightness.light,
  double textScale = 1,
  _KeyboardActions actions = const _KeyboardActions(),
}) async {
  tester.view.physicalSize = const Size(900, 280);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MaterialApp(
        theme: AppTheme.build(brightness, AppAccent.blue),
        home: KeyboardView(
          state: state,
          strings: AppStrings.of(AppLanguage.de),
          start: actions.start ?? _noOp,
          stop: actions.stop ?? _noOp,
          cancel: actions.cancel ?? _noOp,
          switchBack: _noOp,
          openAppSettings: actions.openAppSettings ?? _noOp,
        ),
      ),
    ),
  );
}

void _noOp() {}

class _KeyboardActions {
  const _KeyboardActions({
    this.start,
    this.stop,
    this.cancel,
    this.openAppSettings,
  });

  final VoidCallback? start;
  final VoidCallback? stop;
  final VoidCallback? cancel;
  final VoidCallback? openAppSettings;
}
