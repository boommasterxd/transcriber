import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/audio/audio_import_picker.dart';

const _channel = MethodChannel('app/audio_import');
final _messenger =
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
const _selected = {'path': '/cache/shared/voice.wav', 'fileName': 'voice.wav'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => _messenger.setMockMethodCallHandler(_channel, null));

  test('delivers one native recovery with its display name', () async {
    final service = AudioImportPickerService();
    final calls = <String>[];
    _messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call.method);
      return _selected;
    });

    final result = await service.recoverInterruptedPick();
    expect(result?.path, '/cache/shared/voice.wav');
    expect(result?.fileName, 'voice.wav');
    expect(await service.recoverInterruptedPick(), isNull);
    expect(calls, ['recoverInterruptedPick']);
  });

  test('reports invalid native results and permits a live retry', () async {
    final service = AudioImportPickerService();
    _messenger.setMockMethodCallHandler(_channel, (call) async {
      if (call.method == 'pick') return _selected;
      return {'path': 'content://audio/1', 'fileName': 'voice.wav'};
    });

    await expectLater(service.recoverInterruptedPick(), throwsFormatException);
    expect((await service.pick())?.path, '/cache/shared/voice.wav');
  });

  test('missing recovery channel and cancelled picks resolve empty', () async {
    final service = AudioImportPickerService();
    expect(await service.recoverInterruptedPick(), isNull);
    _messenger.setMockMethodCallHandler(_channel, (_) async => null);
    expect(await service.pick(), isNull);
  });

  test('a failed pick releases the slot for a new selection', () async {
    final service = AudioImportPickerService();
    _messenger.setMockMethodCallHandler(_channel, (_) async {
      throw PlatformException(code: 'audio_import_failed');
    });

    await expectLater(service.pick(), throwsA(isA<PlatformException>()));
    _messenger.setMockMethodCallHandler(_channel, (_) async => _selected);
    expect((await service.pick())?.fileName, 'voice.wav');
  });

  test('a live pick can supersede recovery without waiting for it', () async {
    final service = AudioImportPickerService();
    final recovery = Completer<Object?>();
    final live = Completer<Object?>();
    final calls = <String>[];
    _messenger.setMockMethodCallHandler(_channel, (call) {
      calls.add(call.method);
      return call.method == 'recoverInterruptedPick'
          ? recovery.future
          : live.future;
    });

    final recovered = service.recoverInterruptedPick();
    final selected = service.pick();
    expect(service.recoverySuperseded, isTrue);
    expect(await service.pick(), isNull);
    expect(calls, ['recoverInterruptedPick', 'pick']);
    live.complete(_selected);
    expect((await selected)?.path, '/cache/shared/voice.wav');
    recovery.complete(null);
    expect(await recovered, isNull);
  });

  test('does not request startup recovery after a live pick', () async {
    final service = AudioImportPickerService();
    final calls = <String>[];
    _messenger.setMockMethodCallHandler(_channel, (call) async {
      calls.add(call.method);
      return null;
    });
    expect(await service.pick(), isNull);
    expect(await service.recoverInterruptedPick(), isNull);
    expect(calls, ['pick']);
  });
}
