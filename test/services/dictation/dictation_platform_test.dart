import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/dictation/dictation_platform.dart';

const imeChannel = MethodChannel('test/keyboard/ime');
const settingsChannel = MethodChannel('test/keyboard/settings');
final calls = <MethodCall>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imeChannel, (call) async {
          calls.add(call);
          return switch (call.method) {
            'getEditorState' => {
              'sessionId': 'session',
              'visible': true,
              'supported': true,
              'microphoneGranted': false,
            },
            'setComposingText' || 'commitText' || 'clearComposingText' => true,
            'deleteBackward' => 1,
            'switchToPreviousInputMethod' => false,
            _ => null,
          };
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settingsChannel, (call) async {
          calls.add(call);
          if (call.method == 'getStatus') {
            return {'enabled': true, 'selected': false};
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(imeChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settingsChannel, null);
  });

  _registerImeMethodTests();
  _registerSettingsMethodTests();
  _registerFallbackTests();
}

void _registerImeMethodTests() {
  test('IME methods preserve editor session IDs and text', () async {
    final platform = MethodChannelDictationPlatform(methods: imeChannel);

    final editor = await platform.editorState();
    await platform.startRecording('session', 24000);
    await platform.pauseRecording('session');
    await platform.resumeRecording('session');
    expect(await platform.setComposingText('session', 'partial'), isTrue);
    expect(await platform.commitText('session', 'final'), isTrue);
    expect(await platform.clearComposingText('session'), isTrue);
    expect(await platform.deleteBackward('session'), 1);
    await platform.stopRecording();
    expect(await platform.switchToPreviousInputMethod(), isFalse);

    expect(editor.sessionId, 'session');
    expect(editor.visible, isTrue);
    expect(editor.supported, isTrue);
    expect(editor.microphoneGranted, isFalse);
    expect(calls[1].arguments, {'sessionId': 'session', 'sampleRate': 24000});
    expect(calls[2].arguments, {'sessionId': 'session'});
    expect(calls[3].arguments, {'sessionId': 'session'});
    expect(calls[4].arguments, {'sessionId': 'session', 'text': 'partial'});
    expect(calls[5].arguments, {'sessionId': 'session', 'text': 'final'});
    expect(calls[7].method, 'deleteBackward');
    expect(calls[7].arguments, {'sessionId': 'session'});
  });
}

void _registerSettingsMethodTests() {
  test('settings methods expose status and explicit system actions', () async {
    const platform = KeyboardSettingsPlatform(channel: settingsChannel);

    final status = await platform.status();
    await platform.openInputMethodSettings();
    await platform.showInputMethodPicker();
    await platform.openAppSettings();

    expect(status.enabled, isTrue);
    expect(status.selected, isFalse);
    expect(calls.map((call) => call.method), [
      'getStatus',
      'openInputMethodSettings',
      'showInputMethodPicker',
      'openAppSettings',
    ]);
  });
}

void _registerFallbackTests() {
  test(
    'editor state and keyboard status default missing values safely',
    () async {
      const emptyChannel = MethodChannel('test/keyboard/empty');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            emptyChannel,
            (_) async => <String, Object?>{},
          );

      final editor = await MethodChannelDictationPlatform(
        methods: emptyChannel,
      ).editorState();
      final status = await const KeyboardSettingsPlatform(
        channel: emptyChannel,
      ).status();

      expect(editor.sessionId, isEmpty);
      expect(editor.visible, isFalse);
      expect(editor.supported, isFalse);
      expect(editor.microphoneGranted, isFalse);
      expect(status.enabled, isFalse);
      expect(status.selected, isFalse);
    },
  );
}
