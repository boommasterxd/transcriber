import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/audio/audio_recorder_service.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _recordChannel = MethodChannel('com.llfbandit.record/messages');

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
      expect(args['encoder'], 'wav');
      expect(args['sampleRate'], 16000);
      expect(args['numChannels'], 1);
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

  test('forwards pause and resume commands', () async {
    final service = AudioRecorderService();

    await service.pause();
    await service.resume();

    expect(
      state.calls.map((call) => call.method),
      containsAllInOrder(['create', 'pause', 'resume']),
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

class _RecorderState {
  bool permission = true;
  String? stopPath;
  final calls = <MethodCall>[];

  void reset() {
    permission = true;
    stopPath = null;
    calls.clear();
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
      return state.stopPath;
    case 'cancel':
      return null;
    case 'create':
    case 'start':
    case 'pause':
    case 'resume':
    case 'dispose':
      return null;
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
