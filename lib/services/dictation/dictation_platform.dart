import 'dart:async';
import 'package:flutter/services.dart';

class KeyboardStatus {
  const KeyboardStatus({required this.enabled, required this.selected});
  final bool enabled;
  final bool selected;
}

class KeyboardEditorState {
  const KeyboardEditorState({
    required this.sessionId,
    required this.visible,
    required this.supported,
    required this.microphoneGranted,
  });

  final String sessionId;
  final bool visible;
  final bool supported;
  final bool microphoneGranted;

  factory KeyboardEditorState.fromMap(Map<Object?, Object?> map) =>
      KeyboardEditorState(
        sessionId: map['sessionId'] as String? ?? '',
        visible: map['visible'] as bool? ?? false,
        supported: map['supported'] as bool? ?? false,
        microphoneGranted: map['microphoneGranted'] as bool? ?? false,
      );
}

sealed class DictationPlatformEvent {
  const DictationPlatformEvent();
}

final class DictationAudioChunk extends DictationPlatformEvent {
  const DictationAudioChunk({
    required this.sessionId,
    required this.pcm,
    required this.level,
  });
  final String sessionId;
  final Uint8List pcm;
  final double level;
}

final class DictationEditorChanged extends DictationPlatformEvent {
  const DictationEditorChanged(this.editor);
  final KeyboardEditorState editor;
}

final class DictationPlatformFailure extends DictationPlatformEvent {
  const DictationPlatformFailure(this.sessionId, this.code);
  final String sessionId;
  final String code;
}

abstract interface class DictationPlatform {
  Stream<DictationPlatformEvent> get events;
  Future<KeyboardEditorState> editorState();
  Future<void> startRecording(String sessionId, int sampleRate);
  Future<void> pauseRecording(String sessionId);
  Future<void> resumeRecording(String sessionId);
  Future<bool> stopRecording(String sessionId);
  Future<bool> setComposingText(String sessionId, String text);
  Future<bool> commitText(String sessionId, String text);
  Future<bool> clearComposingText(String sessionId);
  Future<int> deleteBackward(String sessionId);
  Future<bool> switchToPreviousInputMethod();
}

final class MethodChannelDictationPlatform implements DictationPlatform {
  MethodChannelDictationPlatform({
    this.methods = const MethodChannel('app/keyboard/ime'),
    this.audio = const EventChannel('app/keyboard/audio'),
  });

  final MethodChannel methods;
  final EventChannel audio;

  @override
  Stream<DictationPlatformEvent> get events =>
      audio.receiveBroadcastStream().map(_eventFrom);

  @override
  Future<KeyboardEditorState> editorState() async {
    final raw = await methods.invokeMapMethod<Object?, Object?>(
      'getEditorState',
    );
    return KeyboardEditorState.fromMap(raw ?? const {});
  }

  @override
  Future<void> startRecording(String sessionId, int sampleRate) =>
      methods.invokeMethod<void>('startRecording', {
        'sessionId': sessionId,
        'sampleRate': sampleRate,
      });

  @override
  Future<void> pauseRecording(String sessionId) =>
      methods.invokeMethod<void>('pauseRecording', {'sessionId': sessionId});

  @override
  Future<void> resumeRecording(String sessionId) =>
      methods.invokeMethod<void>('resumeRecording', {'sessionId': sessionId});

  @override
  Future<bool> stopRecording(String sessionId) async =>
      await methods.invokeMethod<bool>('stopRecording', {
        'sessionId': sessionId,
      }) ??
      false;

  @override
  Future<bool> setComposingText(String sessionId, String text) =>
      _edit('setComposingText', sessionId, text);

  @override
  Future<bool> commitText(String sessionId, String text) =>
      _edit('commitText', sessionId, text);

  @override
  Future<bool> clearComposingText(String sessionId) async =>
      await methods.invokeMethod<bool>('clearComposingText', {
        'sessionId': sessionId,
      }) ??
      false;

  @override
  Future<int> deleteBackward(String sessionId) async =>
      await methods.invokeMethod<int>('deleteBackward', {
        'sessionId': sessionId,
      }) ??
      0;

  @override
  Future<bool> switchToPreviousInputMethod() async =>
      await methods.invokeMethod<bool>('switchToPreviousInputMethod') ?? false;

  Future<bool> _edit(String method, String sessionId, String text) async =>
      await methods.invokeMethod<bool>(method, {
        'sessionId': sessionId,
        'text': text,
      }) ??
      false;

  DictationPlatformEvent _eventFrom(dynamic raw) {
    if (raw is! Map) return const DictationPlatformFailure('', 'invalid_event');
    final map = raw.cast<Object?, Object?>();
    return switch (map['type']) {
      'audio' => DictationAudioChunk(
        sessionId: map['sessionId'] as String? ?? '',
        pcm: map['pcm'] as Uint8List? ?? Uint8List(0),
        level: (map['level'] as num?)?.toDouble() ?? 0,
      ),
      'editor' => DictationEditorChanged(
        KeyboardEditorState.fromMap(
          (map['editor'] as Map?)?.cast<Object?, Object?>() ?? const {},
        ),
      ),
      _ => DictationPlatformFailure(
        map['sessionId'] as String? ?? '',
        map['code'] as String? ?? 'platform_error',
      ),
    };
  }
}

final class KeyboardSettingsPlatform {
  const KeyboardSettingsPlatform({
    this.channel = const MethodChannel('app/keyboard/settings'),
  });

  final MethodChannel channel;

  Future<KeyboardStatus> status() async {
    final raw = await channel.invokeMapMethod<Object?, Object?>('getStatus');
    return KeyboardStatus(
      enabled: raw?['enabled'] as bool? ?? false,
      selected: raw?['selected'] as bool? ?? false,
    );
  }

  Future<void> openInputMethodSettings() =>
      channel.invokeMethod<void>('openInputMethodSettings');

  Future<void> showInputMethodPicker() =>
      channel.invokeMethod<void>('showInputMethodPicker');

  Future<void> openAppSettings() =>
      channel.invokeMethod<void>('openAppSettings');
}
