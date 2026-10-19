import 'package:test/test.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/services/transcription/remote_transcription_service.dart';
import 'package:transcriber/services/transcription/transcription_service.dart';

void main() {
  const response = TranscriptionResult(
    text: 'Remote transcript',
    segments: [TranscriptLine(text: 'Remote transcript')],
  );

  test('forwards the path, language, and configured model', () async {
    final client = _RecordingTranscriptionClient(response: response);
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
    final client = _RecordingTranscriptionClient(response: response);
    final service = RemoteTranscriptionService(client, 'automatic-model');

    await service.transcribe('/audio/automatic.wav');

    expect(client.languageCode, isNull);
    expect(client.model, 'automatic-model');
  });

  test('propagates provider transcription failures unchanged', () async {
    final failure = StateError('provider failed');
    final client = _RecordingTranscriptionClient(
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

final class _RecordingTranscriptionClient
    implements TranscriptionProviderClient {
  _RecordingTranscriptionClient({required this.response, this.error});

  final TranscriptionResult response;
  final Object? error;
  int transcribeCalls = 0;
  String? audioPath;
  String? languageCode;
  String? model;

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
    required String modelId,
  }) async {
    transcribeCalls++;
    this.audioPath = audioPath;
    this.languageCode = languageCode;
    model = modelId;
    if (error != null) throw error!;
    return response;
  }
}
