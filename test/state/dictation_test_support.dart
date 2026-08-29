import 'dart:async';
import 'dart:typed_data';

import 'package:transcriber/services/dictation/dictation_platform.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';

final class FakeDictationPlatform implements DictationPlatform {
  FakeDictationPlatform({KeyboardEditorState? editor})
    : currentEditor =
          editor ??
          const KeyboardEditorState(
            sessionId: 'editor-1',
            visible: true,
            supported: true,
            microphoneGranted: true,
          );

  final controller = StreamController<DictationPlatformEvent>.broadcast();
  KeyboardEditorState currentEditor;
  final List<({String sessionId, int sampleRate})> starts = [];
  final List<({String sessionId, String text})> compositions = [];
  final List<({String sessionId, String text})> commits = [];
  final List<String> clears = [];
  int stopCount = 0;
  int pauseCount = 0;
  int resumeCount = 0;
  int switchCount = 0;
  bool acceptEdits = true;

  @override
  Stream<DictationPlatformEvent> get events => controller.stream;

  @override
  Future<KeyboardEditorState> editorState() async => currentEditor;

  @override
  Future<void> startRecording(String sessionId, int sampleRate) async {
    starts.add((sessionId: sessionId, sampleRate: sampleRate));
  }

  @override
  Future<void> pauseRecording(String sessionId) async => pauseCount++;

  @override
  Future<void> resumeRecording(String sessionId) async => resumeCount++;

  @override
  Future<void> stopRecording() async => stopCount++;

  @override
  Future<bool> setComposingText(String sessionId, String text) async {
    compositions.add((sessionId: sessionId, text: text));
    return acceptEdits;
  }

  @override
  Future<bool> commitText(String sessionId, String text) async {
    commits.add((sessionId: sessionId, text: text));
    return acceptEdits;
  }

  @override
  Future<bool> clearComposingText(String sessionId) async {
    clears.add(sessionId);
    return acceptEdits;
  }

  @override
  Future<bool> switchToPreviousInputMethod() async {
    switchCount++;
    return true;
  }

  void emitAudio(List<int> bytes, {double level = 0.5}) {
    controller.add(
      DictationAudioChunk(
        sessionId: currentEditor.sessionId,
        pcm: Uint8List.fromList(bytes),
        level: level,
      ),
    );
  }

  void changeEditor(KeyboardEditorState editor) {
    currentEditor = editor;
    controller.add(DictationEditorChanged(editor));
  }

  void emitFailure(String code) {
    controller.add(DictationPlatformFailure(currentEditor.sessionId, code));
  }

  Future<void> close() => controller.close();
}

final class FakeLiveTranscriptionClient implements LiveTranscriptionClient {
  final controller = StreamController<LiveTranscriptionEvent>.broadcast(
    sync: true,
  );
  final List<Uint8List> audio = [];
  Completer<void>? connectGate;
  Object? connectError;
  bool connected = false;
  bool finished = false;
  bool closed = false;
  String? finalTextOnFinish;
  Completer<void>? closeGate;

  @override
  Stream<LiveTranscriptionEvent> get events => controller.stream;

  @override
  Future<void> connect() async {
    await connectGate?.future;
    final error = connectError;
    if (error != null) throw error;
    connected = true;
    controller.add(const LiveTranscriptionReady());
  }

  @override
  void addAudio(Uint8List pcm) => audio.add(Uint8List.fromList(pcm));

  @override
  Future<void> finish() async {
    finished = true;
    if (finalTextOnFinish case final text?) {
      controller.add(LiveTranscriptionFinal(text));
    }
  }

  @override
  Future<void> close() async {
    closed = true;
    await closeGate?.future;
  }
}
