import 'package:test/test.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'remote_test_support.dart';

void main() {
  _registerGoogleFailureTests();
  _registerSizeLimitTest();
}

void _registerGoogleFailureTests() {
  group('GoogleClient interaction contracts', () {
    test(
      'cleans up when the file status reports a failure',
      () => _expectGoogleFailure(
        prefix: 'gemini-status-',
        session: 'status',
        fileState: 'PROCESSING',
        failureBody: {'state': 'FAILED'},
        message: 'Gemini could not process the audio file.',
      ),
    );

    test(
      'cleans up for non-completed interactions',
      () => _expectGoogleFailure(
        prefix: 'gemini-interaction-',
        session: 'interaction',
        fileState: 'ACTIVE',
        failureBody: {'status': 'processing', 'steps': []},
        message: 'Gemini did not complete the transcription.',
      ),
    );

    test(
      'cleans up for completed interactions without text',
      () => _expectGoogleFailure(
        prefix: 'gemini-interaction-',
        session: 'interaction',
        fileState: 'ACTIVE',
        failureBody: {'status': 'completed', 'steps': []},
        message: 'Gemini returned an empty transcription.',
      ),
    );

    test(
      'cleans up for completed interactions with malformed steps',
      () => _expectGoogleFailure(
        prefix: 'gemini-interaction-',
        session: 'interaction',
        fileState: 'ACTIVE',
        failureBody: {'status': 'completed', 'steps': 'not-a-list'},
        message: 'Gemini returned an invalid transcription.',
      ),
    );

    test(
      'cleans up when the interaction response is malformed JSON',
      () => _expectGoogleFailure(
        prefix: 'gemini-interaction-',
        session: 'interaction',
        fileState: 'ACTIVE',
        failureBody: '{malformed-json',
        message: 'Gemini response was invalid.',
      ),
    );
  });
}

Future<void> _expectGoogleFailure({
  required String prefix,
  required String session,
  required String fileState,
  required Object failureBody,
  required String message,
}) async {
  await withTemporaryAudio(
    prefix: prefix,
    action: (file) async {
      final httpClient = scriptedHttpClient(
        googleTranscriptionFailureResponses(
          session: session,
          fileState: fileState,
          failureBody: failureBody,
        ),
      );
      final client = GoogleClient(
        apiKey: 'key',
        pollInterval: Duration.zero,
        delay: (_) async {},
        httpClient: httpClient,
      );

      await expectLater(
        client.transcribe(file.path, modelId: 'gemini-3.5-transcribe'),
        throwsA(
          isA<RemoteApiException>().having(
            (error) => error.message,
            'message',
            message,
          ),
        ),
      );
      expect(httpClient.requests.last.method, 'DELETE');
      expect(httpClient.requests, hasLength(4));
    },
  );
}

void _registerSizeLimitTest() {
  test(
    'rejects an audio file above the provider size limit locally',
    () => expectOversizedAudioRejected(
      prefix: 'gemini-size-',
      transcribe: (path, httpClient) => GoogleClient(
        apiKey: 'key',
        httpClient: httpClient,
      ).transcribe(path, modelId: 'gemini-3.5-transcribe'),
    ),
  );
}
