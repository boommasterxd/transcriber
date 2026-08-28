import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/recording_controller.dart';

import 'state_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fixture = _RecordingFixture();
  setUp(fixture.setUp);
  tearDown(fixture.tearDown);
  _registerStartTests(fixture);
  _registerAmplitudeTests(fixture);
  _registerTimerTests(fixture);
  _registerStopTests(fixture);
}

void _registerStartTests(_RecordingFixture fixture) {
  test(
    'starts with an inactive empty state and delegates permission checks',
    () async {
      expect(fixture.state.active, isFalse);
      expect(fixture.state.levels, isEmpty);
      expect(await fixture.controller.hasPermission(), isTrue);
    },
  );

  test('refuses to start without permission', () async {
    fixture.recorder.permission = false;

    expect(await fixture.controller.start(), isFalse);
    expect(fixture.recorder.startCalls, 0);
    expect(fixture.state.active, isFalse);
  });

  test('starts recording with a full baseline waveform', () async {
    expect(await fixture.controller.start(), isTrue);

    final state = fixture.state;
    expect(state.active, isTrue);
    expect(state.paused, isFalse);
    expect(state.path, fixture.recorder.path);
    expect(state.elapsedSec, 0);
    expect(state.levels, hasLength(42));
    expect(state.levels, everyElement(0.12));
  });
}

void _registerAmplitudeTests(_RecordingFixture fixture) {
  test(
    'maps amplitudes, ignores them while paused, and keeps 42 bars',
    () async {
      await fixture.controller.start();
      fixture.recorder.amplitudes.add(Amplitude(current: -45, max: -10));
      fixture.recorder.amplitudes.add(Amplitude(current: 0, max: 0));
      fixture.recorder.amplitudes.add(Amplitude(current: -100, max: -10));

      expect(fixture.state.levels, hasLength(42));
      expect(fixture.state.levels.skip(39), [0.05, 1.0, 0.05]);
      await fixture.controller.togglePause();
      final pausedLevels = List.of(fixture.state.levels);
      fixture.recorder.amplitudes.add(Amplitude(current: 0, max: 0));

      expect(fixture.state.paused, isTrue);
      expect(fixture.state.levels, pausedLevels);
      expect(fixture.recorder.pauseCalls, 1);
      await fixture.controller.togglePause();
      expect(fixture.state.paused, isFalse);
      expect(fixture.recorder.resumeCalls, 1);
    },
  );
}

void _registerTimerTests(_RecordingFixture fixture) {
  testWidgets('increments elapsed time and pauses the ticker with recording', (
    tester,
  ) async {
    expect(await fixture.controller.start(), isTrue);
    await tester.pump(const Duration(seconds: 2));

    expect(fixture.state.elapsedSec, 2);
    await fixture.controller.cancel();
  });
}

void _registerStopTests(_RecordingFixture fixture) {
  test('stop returns a minimum one-second duration and resets state', () async {
    await fixture.controller.start();
    final result = await fixture.controller.stop();

    expect(result?.path, fixture.recorder.stoppedPath);
    expect(result?.durationSec, 1);
    expect(fixture.recorder.stopCalls, 1);
    expect(fixture.state, const RecordingState());
  });

  test('stop returns null when recorder produced no path', () async {
    fixture.recorder.stoppedPath = null;
    await fixture.controller.start();

    expect(await fixture.controller.stop(), isNull);
    expect(fixture.state.active, isFalse);
  });

  test('cancel delegates, tears down, and resets state', () async {
    await fixture.controller.start();

    await fixture.controller.cancel();

    expect(fixture.recorder.cancelCalls, 1);
    expect(fixture.state, const RecordingState());
  });
}

class _RecordingFixture {
  late ProviderContainer container;
  late FakeAudioRecorderService recorder;

  void setUp() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          (_) async => null,
        );
    recorder = FakeAudioRecorderService();
    container = ProviderContainer(
      overrides: [audioRecorderProvider.overrideWithValue(recorder)],
    );
  }

  RecordingController get controller =>
      container.read(recordingControllerProvider.notifier);
  RecordingState get state => container.read(recordingControllerProvider);

  Future<void> tearDown() async {
    container.dispose();
    await recorder.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.llfbandit.record/messages'),
          null,
        );
  }
}
