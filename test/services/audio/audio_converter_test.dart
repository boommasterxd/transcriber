import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/audio/audio_converter.dart';
import 'package:transcriber/services/service_exceptions.dart';

const _pathChannel = MethodChannel('plugins.flutter.io/path_provider');
const _ffmpegChannel = MethodChannel('flutter.arthenica.com/ffmpeg_kit');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  final state = _ConverterState();

  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('transcriber_converter_');
    _installPathProviderMock(root);
    _installFfmpegMock(state);
    addTearDown(() async {
      await root.delete(recursive: true);
      _removeChannelMock(_pathChannel);
      _removeChannelMock(_ffmpegChannel);
    });
  });

  setUp(() {
    state.reset();
  });

  _registerSuccessfulConversionTests(() => root, state);
  _registerConversionFailureTests(state);
}

void _registerSuccessfulConversionTests(
  Directory Function() root,
  _ConverterState state,
) {
  test(
    'normalizes an input path and creates the canonical WAV output',
    () async {
      final result = await const AudioConverter().toWhisperWav(
        '/input folder/meeting recording.m4a',
      );

      expect(result, '${root().path}/converted/meeting recording_16k.wav');
      expect(await File(result).length(), 16000);
      expect(state.outputWasAbsent, isTrue);
      expect(state.arguments, contains('/input folder/meeting recording.m4a'));
      expect(state.arguments, contains('-ar'));
      expect(state.arguments, contains('16000'));
      expect(state.arguments, contains('-ac'));
      expect(state.arguments, contains('1'));
      expect(state.arguments, contains('pcm_s16le'));
    },
  );

  test('removes a stale output before invoking FFmpeg', () async {
    final stale = File('${root().path}/converted/source_16k.wav');
    await stale.parent.create(recursive: true);
    await stale.writeAsBytes(List.filled(18000, 1));

    final result = await const AudioConverter().toWhisperWav('/source.wav');

    expect(result, stale.path);
    expect(state.outputWasAbsent, isTrue);
    expect(await stale.readAsBytes(), everyElement(0));
  });

  test('passes quoted paths to FFmpeg as single arguments', () async {
    const input = '/input folder/a "quoted" recording.m4a';

    final result = await const AudioConverter().toWhisperWav(input);

    expect(state.arguments[2], input);
    expect(state.arguments.last, result);
    expect(result, '${root().path}/converted/a "quoted" recording_16k.wav');
  });
}

void _registerConversionFailureTests(_ConverterState state) {
  test('rejects a successful conversion with no audio samples', () async {
    state.conversionSize = 'empty';

    final future = const AudioConverter().toWhisperWav('/empty.wav');

    await expectLater(
      future,
      throwsA(
        predicate<AudioProcessingException>(
          (error) => error.message.contains('contains no audible data'),
        ),
      ),
    );
  });

  test('rejects output below the minimum sample-size boundary', () async {
    state.conversionSize = 'short';

    await expectLater(
      const AudioConverter().toWhisperWav('/short.wav'),
      throwsA(
        predicate<AudioProcessingException>(
          (error) => error.message.contains('contains no audible data'),
        ),
      ),
    );
  });

  test('exposes FFmpeg diagnostics when conversion fails', () async {
    state.conversionSize = 'error';

    await expectLater(
      const AudioConverter().toWhisperWav('/broken.wav'),
      throwsA(
        predicate<AudioProcessingException>(
          (error) => error.message.contains('decoder rejected input'),
        ),
      ),
    );
  });
}

class _ConverterState {
  String conversionSize = 'normal';
  List<String> arguments = <String>[];
  bool outputWasAbsent = false;

  void reset() {
    conversionSize = 'normal';
    arguments = <String>[];
    outputWasAbsent = false;
  }
}

void _installPathProviderMock(Directory root) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_pathChannel, (call) async {
        if (call.method == 'getTemporaryDirectory') return root.path;
        return null;
      });
}

void _installFfmpegMock(_ConverterState state) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_ffmpegChannel, (call) {
        return _handleFfmpegCall(call, state);
      });
}

Future<Object?> _handleFfmpegCall(
  MethodCall call,
  _ConverterState state,
) async {
  switch (call.method) {
    case 'getLogLevel':
      return 0;
    case 'getPlatform':
      return 'test';
    case 'getArch':
      return 'test';
    case 'getPackageName':
      return 'test';
    case 'isLTSBuild':
      return false;
    case 'enableRedirection':
      return null;
    case 'ffmpegSession':
      state.arguments = List<String>.from(
        (call.arguments as Map)['arguments'] as List,
      );
      return <String, dynamic>{'sessionId': 1};
    case 'ffmpegSessionExecute':
      await _writeConversionOutput(state);
      return null;
    case 'abstractSessionGetReturnCode':
      return state.conversionSize == 'error' ? 1 : 0;
    case 'abstractSessionGetAllLogsAsString':
      return 'decoder rejected input';
    default:
      return null;
  }
}

Future<void> _writeConversionOutput(_ConverterState state) async {
  final outputPath = state.arguments.last;
  state.outputWasAbsent = !File(outputPath).existsSync();
  final bytes = switch (state.conversionSize) {
    'empty' => 44,
    'short' => 15999,
    _ => 16000,
  };
  await File(outputPath).writeAsBytes(List.filled(bytes, 0));
}

void _removeChannelMock(MethodChannel channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}
