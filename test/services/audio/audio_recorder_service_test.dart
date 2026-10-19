import 'dart:io';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/audio/audio_recorder_service.dart';
import 'package:transcriber/services/audio/recording_limits.dart';
import 'package:transcriber/services/remote/remote_audio_limits.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _recordChannel = MethodChannel('com.llfbandit.record/messages');
const _boundedChannel = MethodChannel('app/recording');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  final state = _RecorderState();

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('transcriber_recorder_');
    _installPathProviderMock(root);
    _installRecorderMock(state);
    addTearDown(() async {
      await root.delete(recursive: true);
      _removeChannelMock(_pathChannel);
      _removeChannelMock(_recordChannel);
      _removeChannelMock(_boundedChannel);
    });
  });

  setUp(() {
    state.reset();
  });

  test('forwards the microphone permission result', () async {
    final service = AudioRecorderService();
    expect(await service.hasPermission(), isTrue);
    state.permission = false;
    expect(await service.hasPermission(), isFalse);
    await service.dispose();
  });

  test(
    'starts a mono 16 kHz WAV recording in the managed audio directory',
    () async {
      final service = AudioRecorderService();

      final path = await service.start();

      expect(path, startsWith('${root.path}/audio/recording/recording_'));
      expect(path, endsWith('.wav'));
      final start = state.calls.singleWhere((call) => call.method == 'start');
      final args = start.arguments as Map<dynamic, dynamic>;
      expect(args['path'], path);
      expect(
        args['maxBytes'],
        const RecordingLimits(maxRemoteAudioBytes).captureBytes,
      );
      await service.dispose();
    },
  );

  test('returns the native stop path when one is provided', () async {
    state.stopPath = '/native/finished.wav';
    final service = AudioRecorderService();
    final startedPath = await service.start();

    expect(await service.stop(), state.stopPath);
    expect(startedPath, isNotEmpty);
    await service.dispose();
  });

  test('falls back to the requested path when stop returns null', () async {
    final service = AudioRecorderService();
    final startedPath = await service.start();

    expect(await service.stop(), startedPath);
    await service.dispose();
  });

  _registerControlTests(state);
  _registerBoundaryTests(state);
  _registerPollingTests(state);
  _registerStartCancellationTests(state);
}

void _registerControlTests(_RecorderState state) {
  test(
    'dispose closes streams and the permission handle after native failure',
    () async {
      final service = AudioRecorderService();
      await service.start();
      final progressDone = expectLater(service.progressStream, emitsDone);
      final amplitudeDone = expectLater(service.amplitudeStream(), emitsDone);
      state.disposeError = true;
      await service.dispose();
      await Future.wait([progressDone, amplitudeDone]);
      expect(state.calls.last.method, 'dispose');
    },
  );

  test('forwards pause and resume commands', () async {
    final service = AudioRecorderService();

    await service.pause();
    await service.resume();

    expect(
      state.calls.map((call) => call.method),
      containsAllInOrder(['pause', 'resume']),
    );
    await service.dispose();
  });

  test('cancels and discards the current recording path', () async {
    final service = AudioRecorderService();
    await service.start();

    await expectLater(service.cancel(), completes);
    expect(await service.stop(), isNull);
    await service.dispose();
  });

  test(
    'exposes a broadcast amplitude stream and closes it on dispose',
    () async {
      final service = AudioRecorderService();
      final stream = service.amplitudeStream();
      final done = expectLater(stream, emitsDone);

      expect(stream.isBroadcast, isTrue);
      await service.dispose();
      await done;
    },
  );
}

void _registerBoundaryTests(_RecorderState state) {
  test(
    'rejects unusable limits and duplicate starts before native capture',
    () async {
      final service = AudioRecorderService();
      for (final limit in [0, 44, 32043, maxRemoteAudioBytes + 1]) {
        await expectLater(service.start(maxBytes: limit), throwsArgumentError);
      }
      expect(state.calls.where((call) => call.method == 'start'), isEmpty);
      await service.start(maxBytes: maxInlineAudioBytes);
      final start = state.calls.singleWhere((call) => call.method == 'start');
      expect((start.arguments as Map)['maxBytes'], 44 + 655 * 32000);
      await expectLater(service.start(), throwsStateError);
      await service.dispose();
    },
  );

  test('a failed stop preserves the destination for retry', () async {
    final service = AudioRecorderService();
    final path = await service.start();
    state.stopError = true;
    await expectLater(service.stop(), throwsA(isA<PlatformException>()));
    await expectLater(service.start(), throwsStateError);
    state.stopError = false;
    expect(await service.stop(), path);
    await service.dispose();
  });

  test('failed pause and resume report a state error', () async {
    final service = AudioRecorderService();
    state.changeSucceeded = false;
    await expectLater(service.pause(), throwsStateError);
    await expectLater(service.resume(), throwsStateError);
    await service.dispose();
  });
}

void _registerPollingTests(_RecorderState state) {
  test(
    'native progress is authoritative and polling ends at the cap',
    () async {
      late _RecordingTimer timer;
      final service = AudioRecorderService(
        recordingDestination: () async => '/cache/bounded.wav',
        periodicTimer: (_, callback) => timer = _RecordingTimer(callback),
      );
      await service.start();
      final first = service.progressStream.first;
      final level = service.amplitudeStream().first;
      state.progress = {'bytes': 32000, 'level': 0.5, 'stopped': false};
      timer.fire();
      expect((await first).elapsedSec, 1);
      expect((await level).current, -22.5);
      final finalProgress = service.progressStream.first;
      state.progress = {
        'bytes': 655 * 32000,
        'level': 0.0,
        'stopped': true,
        'limited': true,
      };
      timer.fire();
      final event = await finalProgress;
      expect(event.limited, isTrue);
      expect(event.stopped, isTrue);
      expect(timer.isActive, isFalse);
      await service.dispose();
    },
  );

  test('a stalled status call cannot create overlapping polling', () async {
    late _RecordingTimer timer;
    final service = AudioRecorderService(
      recordingDestination: () async => '/cache/bounded.wav',
      periodicTimer: (_, callback) => timer = _RecordingTimer(callback),
    );
    await service.start();
    state.pendingProgress = Completer<Object?>();
    for (var tick = 0; tick < 100; tick++) {
      timer.fire();
    }
    expect(
      state.calls.where((call) => call.method == 'progress'),
      hasLength(1),
    );
    state.pendingProgress!.complete(null);
    await service.dispose();
  });
}

void _registerStartCancellationTests(_RecorderState state) {
  test(
    'cancel while resolving a destination prevents native startup',
    () async {
      final destination = Completer<String>();
      final service = AudioRecorderService(
        recordingDestination: () => destination.future,
      );
      final starting = service.start();
      final rejected = expectLater(starting, throwsStateError);
      await service.cancel();
      destination.complete('/cache/cancelled.wav');
      await rejected;
      expect(state.calls.where((call) => call.method == 'start'), isEmpty);
      await service.dispose();
    },
  );

  test(
    'cancel while native start is pending tears down late capture',
    () async {
      state.pendingStart = Completer<Object?>();
      final service = AudioRecorderService(
        recordingDestination: () async => '/cache/cancelled.wav',
      );
      final starting = service.start();
      final rejected = expectLater(starting, throwsStateError);
      await Future<void>.microtask(() {});
      await service.cancel();
      state.pendingStart!.complete(null);
      await rejected;
      expect(
        state.calls.where((call) => call.method == 'cancel'),
        hasLength(2),
      );
      await service.dispose();
    },
  );
}

class _RecordingTimer implements Timer {
  _RecordingTimer(this.callback);
  final void Function(Timer) callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;
  @override
  void cancel() => isActive = false;
  void fire() {
    if (isActive) {
      tick++;
      callback(this);
    }
  }
}

class _RecorderState {
  bool permission = true;
  String? stopPath;
  final calls = <MethodCall>[];
  bool stopError = false;
  bool disposeError = false;
  bool changeSucceeded = true;
  Object? progress;
  Completer<Object?>? pendingProgress;
  Completer<Object?>? pendingStart;

  void reset() {
    permission = true;
    stopPath = null;
    calls.clear();
    stopError = false;
    disposeError = false;
    changeSucceeded = true;
    progress = null;
    pendingProgress = null;
    pendingStart = null;
  }
}

void _installPathProviderMock(Directory root) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathChannel, (call) async {
        if (call.method == 'getApplicationSupportDirectory' ||
            call.method == 'getTemporaryDirectory') {
          return root.path;
        }
        return null;
      });
}

void _installRecorderMock(_RecorderState state) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_boundedChannel, (call) async {
        if (call.method == 'dispose' && state.disposeError) {
          throw PlatformException(code: 'recording_failed');
        }
        return _handleRecorderCall(call, state);
      });
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_recordChannel, (call) {
        return _handleRecorderCall(call, state);
      });
}

Future<Object?> _handleRecorderCall(
  MethodCall call,
  _RecorderState state,
) async {
  state.calls.add(call);
  switch (call.method) {
    case 'hasPermission':
      return state.permission;
    case 'stop':
      if (state.stopError) throw PlatformException(code: 'recording_failed');
      return state.stopPath;
    case 'progress':
      return state.pendingProgress?.future ?? state.progress;
    case 'cancel':
      return null;
    case 'create':
    case 'dispose':
      return null;
    case 'start':
      return state.pendingStart?.future;
    case 'pause':
    case 'resume':
      return state.changeSucceeded;
    case 'isRecording':
      return false;
    case 'getAmplitude':
      return <String, double>{'current': -12, 'max': -3};
    default:
      return null;
  }
}

void _removeChannelMock(MethodChannel channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}
