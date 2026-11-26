import 'dart:async';
import 'dart:typed_data';

import 'package:transcriber/services/dictation/dictation_platform.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';

final class FakeDictationPlatform implements DictationPlatform {
  final controller = StreamController<DictationPlatformEvent>.broadcast();
  KeyboardEditorState currentEditor = const KeyboardEditorState(
    sessionId: 'editor-1',
    visible: true,
    supported: true,
    microphoneGranted: true,
  );
  final List<({String sessionId, int sampleRate})> starts = [];
  final List<({String sessionId, String text})> compositions = [];
  final List<({String sessionId, String text})> commits = [];
  final List<String> clears = [];
  int pauseCount = 0;
  int resumeCount = 0;
  Completer<bool>? compositionGate;

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
  Future<void> resumeRecording(String sessionId) async {
    resumeCount++;
  }

  @override
  Future<bool> stopRecording(String sessionId) async {
    return currentEditor.sessionId == sessionId;
  }

  @override
  Future<bool> setComposingText(String sessionId, String text) async {
    compositions.add((sessionId: sessionId, text: text));
    final gate = compositionGate;
    if (gate != null) return gate.future;
    return true;
  }

  @override
  Future<bool> commitText(String sessionId, String text) async {
    commits.add((sessionId: sessionId, text: text));
    return true;
  }

  @override
  Future<bool> clearComposingText(String sessionId) async {
    clears.add(sessionId);
    return true;
  }

  @override
  Future<int> deleteBackward(String sessionId) async => 1;

  @override
  Future<bool> switchToPreviousInputMethod() async => true;

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

  Future<void> close() => controller.close();
}

final class FakeLiveTranscriptionClient implements LiveTranscriptionClient {
  final controller = StreamController<LiveTranscriptionEvent>.broadcast(
    sync: true,
  );
  final List<Uint8List> audio = [];
  bool closed = false;

  @override
  Stream<LiveTranscriptionEvent> get events => controller.stream;

  @override
  Future<void> connect() async {
    controller.add(const LiveTranscriptionReady());
  }

  @override
  void addAudio(Uint8List pcm) => audio.add(Uint8List.fromList(pcm));

  @override
  Future<void> finish() async {}

  @override
  Future<void> close() async {
    closed = true;
  }
}
