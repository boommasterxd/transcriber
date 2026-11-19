import 'package:test/test.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

void main() {
  test('rejects untrusted resumable URLs before opening the audio stream', () async {
    const unsafeUrls = [
      'https://generativelanguage.googleapis.com.attacker.test/upload',
      'http://generativelanguage.googleapis.com/upload',
      'https://generativelanguage.googleapis.com:444/upload',
      'https://user:password@generativelanguage.googleapis.com/upload',
      'https://generativelanguage.googleapis.com/upload#fragment',
      'https://generativelanguage.googleapis.com/upload?%6bey=credential',
      'https://generativelanguage.googleapis.com/upload?session=client-secret',
    ];
    await withTemporaryAudio(
      prefix: 'gemini-unsafe-upload-',
      action: (file) async {
        for (final url in unsafeUrls) {
          final httpClient = scriptedHttpClient([
            jsonResponse({}, headers: {'x-goog-upload-url': url}),
          ]);
          await _expectUploadError(
            file.path,
            httpClient,
            'Gemini returned an invalid upload URL.',
          );
          expect(
            httpClient.requests.single.headers['X-Goog-Upload-Command'],
            'start',
          );
        }
      },
    );
  });

  test('rejects upload redirects without exposing the session URL', () async {
    await withTemporaryAudio(
      prefix: 'gemini-redirect-upload-',
      action: (file) async {
        final sessionUrl = googleUploadUrl('private-session');
        final httpClient = scriptedHttpClient([
          jsonResponse({}, headers: {'x-goog-upload-url': sessionUrl}),
          jsonResponse(
            {
              'error': {'message': sessionUrl},
            },
            statusCode: 307,
            headers: {'location': 'https://attacker.test/upload'},
          ),
        ]);
        await _expectUploadError(
          file.path,
          httpClient,
          'Gemini upload error (307).',
        );
        expect(httpClient.requests, hasLength(2));
        final upload = httpClient.requests.last;
        expect(upload.followRedirects, isFalse);
        expect(upload.headers['x-goog-api-key'], isNull);
      },
    );
  });
}

Future<void> _expectUploadError(
  String path,
  RecordingHttpClient transport,
  String message,
) {
  final client = GoogleClient(apiKey: 'client-secret', httpClient: transport);
  return expectLater(
    client.transcribe(path, modelId: 'gemini-3.5-transcribe'),
    throwsA(
      isA<RemoteApiException>().having(
        (error) => error.message,
        'message',
        message,
      ),
    ),
  );
}
