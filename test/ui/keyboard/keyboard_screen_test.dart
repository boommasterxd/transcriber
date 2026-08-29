import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/dictation_state.dart';
import 'package:transcriber/ui/keyboard/keyboard_screen.dart';
import 'package:transcriber/ui/widgets/recording_controls.dart';
import 'package:transcriber/ui/widgets/provider_logo.dart';
import 'package:transcriber/ui/widgets/waveforms.dart';

void main() {
  _registerInteractionTests();
  _registerDeletionTests();
  _registerBrandingTests();
  _registerAccessibilityAndRecoveryTests();
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
    expect(
      tester.widget<ProviderLogo>(find.byType(ProviderLogo)).provider,
      RemoteProviderId.openai,
    );
    expect(find.text('Bereit für Live-Diktat'), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.mic_rounded));
    expect(starts, 1);
  });

  testWidgets('renders live correction, waveform, timer, and controls', (
    tester,
  ) async {
    var stops = 0;
    var cancels = 0;
    var pauses = 0;
    var deletes = 0;
    await _pumpKeyboard(
      tester,
      _state(DictationPhase.correcting).copyWith(
        preview: 'Guten Mor',
        elapsed: const Duration(minutes: 2, seconds: 7),
        levels: const [0.1, 0.5, 0.9],
      ),
      brightness: Brightness.dark,
      size: const Size(360, 312),
      actions: _KeyboardActions(
        stop: () => stops++,
        cancel: () => cancels++,
        togglePause: () => pauses++,
        deleteBackward: () => deletes++,
      ),
    );

    expect(find.text('Text wird live korrigiert'), findsOneWidget);
    expect(find.text('Guten Mor'), findsOneWidget);
    expect(find.text('02:07'), findsOneWidget);
    final wave = tester.widget<RecordWave>(find.byType(RecordWave));
    expect(wave.barWidth, 5);
    expect(tester.getSize(find.byType(RecordWave)).height, greaterThan(100));
    expect(
      find.ancestor(
        of: find.byType(RecordWave),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.tap(find.text('Stoppen'));
    expect(find.byType(RecordWave), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.tap(find.text('Verwerfen'));
    expect(stops, 1);
    expect(cancels, 1);
    expect(pauses, 1);
    expect(deletes, 1);
  });

  testWidgets('shows paused waveform and resume action', (tester) async {
    var resumes = 0;
    await _pumpKeyboard(
      tester,
      _state(DictationPhase.paused).copyWith(
        levels: const [0.2, 0.7, 0.4],
        elapsed: const Duration(seconds: 12),
      ),
      actions: _KeyboardActions(togglePause: () => resumes++),
    );

    expect(find.text('Pausiert'), findsOneWidget);
    expect(find.text('Fortsetzen'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(tester.widget<RecordWave>(find.byType(RecordWave)).paused, isTrue);
    await tester.tap(find.text('Fortsetzen'));
    expect(resumes, 1);
  });
}

void _registerDeletionTests() {
  testWidgets('holding backspace repeats until the pointer is released', (
    tester,
  ) async {
    var deletes = 0;
    await _pumpKeyboard(
      tester,
      _state(DictationPhase.ready),
      actions: _KeyboardActions(deleteBackward: () => deletes++),
    );
    final backspace = find.byIcon(Icons.backspace_outlined);

    final gesture = await tester.startGesture(tester.getCenter(backspace));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 500));

    expect(deletes, greaterThan(3));
    await gesture.up();
    final deletesAfterRelease = deletes;
    await tester.pump(const Duration(milliseconds: 500));
    expect(deletes, deletesAfterRelease);
  });
}

void _registerBrandingTests() {
  testWidgets('uses the selected Google provider logo in the switch action', (
    tester,
  ) async {
    await _pumpKeyboard(
      tester,
      _state(DictationPhase.ready).copyWith(provider: RemoteProviderId.google),
    );

    expect(
      tester.widget<ProviderLogo>(find.byType(ProviderLogo)).provider,
      RemoteProviderId.google,
    );
  });
}

void _registerAccessibilityAndRecoveryTests() {
  testWidgets('shows a compact cancellable connection state', (tester) async {
    var cancels = 0;
    final strings = AppStrings.of(AppLanguage.de);
    await _pumpKeyboard(
      tester,
      _state(DictationPhase.connecting),
      textScale: 1.6,
      size: const Size(360, 280),
      actions: _KeyboardActions(cancel: () => cancels++),
    );

    expect(find.text(strings.keyboardConnect), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(RecordControls), findsNothing);
    expect(find.text(strings.recStopShort), findsNothing);
    expect(find.text(strings.recPause), findsNothing);
    expect(find.text(strings.recCancel), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text(strings.keyboardCancel));
    expect(cancels, 1);
  });

  testWidgets('fits active controls on a small keyboard with large text', (
    tester,
  ) async {
    await _pumpKeyboard(
      tester,
      _state(
        DictationPhase.paused,
      ).copyWith(levels: const [0.2, 0.7, 0.4], preview: 'Pausierter Text'),
      textScale: 1.6,
      size: const Size(360, 280),
    );

    expect(find.text('Verwerfen'), findsOneWidget);
    expect(find.text('Stoppen'), findsOneWidget);
    expect(find.text('Fortsetzen'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
      tester.widget<RecordStartControl>(find.byType(RecordStartControl)).onTap,
      isNull,
    );
    expect(find.bySemanticsLabel('Vorherige Tastatur'), findsOneWidget);
    expect(find.bySemanticsLabel('Zeichen löschen'), findsOneWidget);
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
      size: const Size(360, 280),
    );
    final timeoutText = find.textContaining('antwortet nicht');
    expect(timeoutText, findsOneWidget);
    expect(tester.widget<Text>(timeoutText).overflow, isNull);

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
  Size size = const Size(900, 312),
  _KeyboardActions actions = const _KeyboardActions(),
}) async {
  tester.view.physicalSize = size;
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
          togglePause: actions.togglePause ?? _noOp,
          cancel: actions.cancel ?? _noOp,
          deleteBackward: actions.deleteBackward ?? _noOp,
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
    this.togglePause,
    this.deleteBackward,
    this.openAppSettings,
  });

  final VoidCallback? start;
  final VoidCallback? stop;
  final VoidCallback? cancel;
  final VoidCallback? togglePause;
  final VoidCallback? deleteBackward;
  final VoidCallback? openAppSettings;
}
