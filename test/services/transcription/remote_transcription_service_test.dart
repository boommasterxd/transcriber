import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/services/transcription/remote_transcription_service.dart';
import 'package:transcriber/services/transcription/transcription_service.dart';

void main() {
  const response = TranscriptionResult(
    text: 'Remote transcript',
    segments: [TranscriptLine(time: '0:03', text: 'Remote transcript')],
  );

  test('forwards the path, language, and configured model', () async {
    final client = _RecordingRemoteApiClient(response: response);
    final service = RemoteTranscriptionService(client, 'asr-model');

    final result = await service.transcribe(
      '/audio/input.wav',
      languageCode: 'de',
    );

    expect(service, isA<TranscriptionService>());
    expect(result, same(response));
    expect(client.transcribeCalls, 1);
    expect(client.audioPath, '/audio/input.wav');
    expect(client.languageCode, 'de');
    expect(client.model, 'asr-model');
  });

  test('preserves a null language for provider auto-detection', () async {
    final client = _RecordingRemoteApiClient(response: response);
    final service = RemoteTranscriptionService(client, 'automatic-model');

    await service.transcribe('/audio/automatic.wav');

    expect(client.languageCode, isNull);
    expect(client.model, 'automatic-model');
  });

  test('rejects unsupported providers without calling them', () {
    final client = _RecordingRemoteApiClient(
      response: response,
      supportsTranscription: false,
    );
    final service = RemoteTranscriptionService(client, 'unused-model');

    expect(
      () => service.transcribe('/audio/input.wav'),
      throwsA(
        isA<RemoteApiException>().having(
          (error) => error.message,
          'message',
          contains('does not support audio transcription'),
        ),
      ),
    );
    expect(client.transcribeCalls, 0);
  });

  test('propagates provider transcription failures unchanged', () async {
    final failure = StateError('provider failed');
    final client = _RecordingRemoteApiClient(
      response: response,
      error: failure,
    );
    final service = RemoteTranscriptionService(client, 'asr-model');

    await expectLater(
      service.transcribe('/audio/input.wav', languageCode: 'en'),
      throwsA(same(failure)),
    );
    expect(client.transcribeCalls, 1);
  });
}

final class _RecordingRemoteApiClient implements RemoteApiClient {
  _RecordingRemoteApiClient({
    required this.response,
    this.supportsTranscription = true,
    this.error,
  });

  final TranscriptionResult response;
  final bool supportsTranscription;
  final Object? error;
  int transcribeCalls = 0;
  String? audioPath;
  String? languageCode;
  String? model;

  @override
  bool get supportsAudioTranscription => supportsTranscription;

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
    required String model,
  }) async {
    transcribeCalls++;
    this.audioPath = audioPath;
    this.languageCode = languageCode;
    this.model = model;
    if (error != null) throw error!;
    return response;
  }

  @override
  Future<String> chat({
    required String system,
    required String user,
    required String modelId,
  }) async => throw UnsupportedError('Chat is outside this test boundary');

  @override
  Future<List<RemoteModelInfo>> listModels({
    required bool forTranscription,
  }) async => throw UnsupportedError('Model listing is outside this boundary');
}
