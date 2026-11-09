import 'dart:async';

import 'package:android_file_picker/android_file_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/audio/audio_import_picker.dart';

const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
final messenger =
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
late FilePickerPlatform original;
late AudioImportPickerService picker;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    original = FilePickerPlatform.instance;
    FilePickerAndroid.registerWith();
    picker = AudioImportPickerService();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    FilePickerPlatform.instance = original;
  });

  _recoveryTests();
  _concurrencyTests();
}

void _recoveryTests() {
  test('recovers one native file and attempts recovery only once', () async {
    var requests = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'retrieveLostData');
      requests++;
      return {
        'files': [_file('/cache/voice.wav')],
      };
    });

    final result = await picker.recoverInterruptedPick();
    expect(result?.path, '/cache/voice.wav');
    expect(result?.fileName, 'voice.wav');
    expect(picker.recoverySuperseded, isFalse);
    expect(await picker.recoverInterruptedPick(), isNull);
    expect(requests, 1);
  });

  test('returns null when no recovery or usable local path exists', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    expect(await picker.recoverInterruptedPick(), isNull);

    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'files': [
          {'path': 'content://audio/1', 'name': 'voice.wav'},
        ],
      },
    );
    expect(await AudioImportPickerService().recoverInterruptedPick(), isNull);

    messenger.setMockMethodCallHandler(channel, (_) async => {'files': []});
    expect(await AudioImportPickerService().recoverInterruptedPick(), isNull);

    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'files': [
          {'path': '/cache/voice.wav', 'name': ' '},
        ],
      },
    );
    expect(await AudioImportPickerService().recoverInterruptedPick(), isNull);
  });

  test('does not request recovery from another platform', () async {
    FilePickerPlatform.instance = original;
    expect(await picker.recoverInterruptedPick(), isNull);
  });

  test('rejects multiple recovered files', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {
        'files': [_file('/cache/voice.wav'), _file('/cache/other.wav')],
      },
    );
    await expectLater(picker.recoverInterruptedPick(), throwsFormatException);
  });

  test(
    'propagates recovered and native errors and permits a live retry',
    () async {
      for (final nativeError in [false, true]) {
        final service = AudioImportPickerService();
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'audio') return [_file('/cache/voice.wav')];
          if (nativeError) throw PlatformException(code: 'native_failure');
          return {'errorCode': 'recovery_failure', 'errorMessage': 'failed'};
        });
        await expectLater(
          service.recoverInterruptedPick(),
          throwsA(
            isA<PlatformException>().having(
              (error) => error.code,
              'code',
              nativeError ? 'native_failure' : 'recovery_failure',
            ),
          ),
        );
        expect((await service.pick())?.path, '/cache/voice.wav');
      }
    },
  );
}

void _concurrencyTests() {
  testWidgets('times out recovery and permits a new selection', (tester) async {
    final recovery = Completer<Object?>();
    messenger.setMockMethodCallHandler(channel, (call) {
      if (call.method == 'retrieveLostData') return recovery.future;
      return Future.value([_file('/cache/voice.wav')]);
    });

    final pending = picker.recoverInterruptedPick();
    final failure = expectLater(pending, throwsA(isA<TimeoutException>()));
    await tester.pump(const Duration(seconds: 60));
    await failure;
    expect((await picker.pick())?.path, '/cache/voice.wav');
    recovery.complete(null);
  });

  test('serializes recovery and concurrent live selections', () async {
    final recovery = Completer<Object?>();
    final live = Completer<Object?>();
    final liveStarted = Completer<void>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call.method);
      if (call.method == 'retrieveLostData') return recovery.future;
      expect(call.method, 'audio');
      expect((call.arguments as Map)['allowMultipleSelection'], false);
      liveStarted.complete();
      return live.future;
    });

    final recovered = picker.recoverInterruptedPick();
    final first = picker.pick();
    expect(picker.recoverySuperseded, isTrue);
    final second = picker.pick();
    expect(calls, ['retrieveLostData']);
    recovery.complete({
      'files': [_file('/cache/old.wav')],
    });
    expect(await recovered, isNull);
    await liveStarted.future;
    expect(calls, ['retrieveLostData', 'audio']);
    live.complete([_file('/cache/voice.wav')]);
    expect((await first)?.path, '/cache/voice.wav');
    expect(await second, isNull);
  });

  test('does not recover while a live selection is active', () async {
    final live = Completer<Object?>();
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) {
      calls.add(call.method);
      return live.future;
    });
    final result = picker.pick();
    expect(await picker.recoverInterruptedPick(), isNull);
    live.complete(null);
    expect(await result, isNull);
    expect(calls, ['audio']);
  });
}

Map<String, Object?> _file(String path) => {
  'path': path,
  'name': path.split('/').last,
};
