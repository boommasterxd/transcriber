import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:transcriber/services/remote/google_client.dart';
import 'package:transcriber/services/remote/remote_cancellation.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'http_test_client.dart';
import 'remote_test_support.dart';

const _pollPath = '/v1beta/files/processing-audio';

void main() {
  test(
    'cancels poll sleep, skips generation and deletes the uploaded file',
    () async {
      const interval = Duration(seconds: 2);
      final sleep = _HeldTimer((duration) => duration == interval);
      final cancellation = RemoteCancellation();
      final transport = _processingFileClient();

      await runZoned(() async {
        final client = GoogleClient(
          apiKey: 'secret-key',
          httpClient: transport,
        );
        final result = _transcribe(client, cancellation);
        final terminal = expectLater(
          result,
          throwsA(isA<RemoteRequestCancelledException>()),
        );
        await sleep.ready.future;
        cancellation.cancel();
        await terminal;
        expect(sleep.timer.isActive, isFalse);
      }, zoneSpecification: sleep.zone);

      expect(_requestsAfterUpload(transport), ['DELETE $_pollPath']);
    },
  );

  test(
    'bounds a stalled status request by the remaining polling budget',
    () async {
      const timeout = Duration(seconds: 19);
      final deadline = _HeldTimer(
        (duration) => duration > Duration.zero && duration <= timeout,
      );
      final polling = Completer<void>();
      final aborted = Completer<void>();
      final transport = _processingFileClient(
        statusRequest: (request) async {
          polling.complete();
          await (request as http.Abortable).abortTrigger;
          aborted.complete();
          return jsonResponse({'state': 'ACTIVE'});
        },
      );

      await runZoned(() async {
        final client = GoogleClient(
          apiKey: 'secret-key',
          httpClient: transport,
          pollInterval: Duration.zero,
          pollTimeout: timeout,
        );
        final terminal = expectLater(
          _transcribe(client),
          throwsA(isA<RemoteApiException>()),
        );
        await polling.future;
        expect(deadline.ready.isCompleted, isTrue);
        deadline.expire();
        await terminal;
        await aborted.future;
      }, zoneSpecification: deadline.zone);

      expect(_requestsAfterUpload(transport), [
        'GET $_pollPath',
        'DELETE $_pollPath',
      ]);
    },
  );

  test(
    'an expired polling budget skips the next request and generation',
    () async {
      final transport = _processingFileClient();
      final client = GoogleClient(
        apiKey: 'secret-key',
        httpClient: transport,
        pollTimeout: Duration.zero,
      );
      await expectLater(
        _transcribe(client),
        throwsA(
          isA<RemoteApiException>().having(
            (error) => error.message,
            'message',
            'Gemini file processing timed out.',
          ),
        ),
      );
      expect(_requestsAfterUpload(transport), ['DELETE $_pollPath']);
    },
  );
}

Future<void> _transcribe(
  GoogleClient client, [
  RemoteCancellation? cancellation,
]) {
  return withTemporaryAudio(
    prefix: 'gemini-cancel-audio-',
    action: (file) async {
      await client.transcribe(
        file.path,
        modelId: 'gemini-3.5-transcribe',
        cancellation: cancellation,
      );
    },
  );
}

RecordingHttpClient _processingFileClient({RequestHandler? statusRequest}) {
  return RecordingHttpClient((request) async {
    return switch (request.headers['X-Goog-Upload-Command']) {
      'start' => jsonResponse(
        {},
        headers: {'x-goog-upload-url': googleUploadUrl('processing')},
      ),
      'upload, finalize' => jsonResponse({
        'file': {
          'name': 'files/processing-audio',
          'uri': 'https://generativelanguage.googleapis.com$_pollPath',
          'state': 'PROCESSING',
        },
      }),
      _ when request.method == 'DELETE' => jsonResponse({}),
      _ when request.method == 'GET' && statusRequest != null => statusRequest(
        request,
      ),
      _ => throw StateError('Unexpected request'),
    };
  });
}

List<String> _requestsAfterUpload(RecordingHttpClient client) => [
  for (final request in client.requests.skip(2))
    '${request.method} ${request.url.path}',
];

final class _HeldTimer {
  _HeldTimer(this.matches);

  final bool Function(Duration) matches;
  final ready = Completer<void>();
  late void Function() expire;
  late Timer timer;

  ZoneSpecification get zone => ZoneSpecification(
    createTimer: (self, parent, zone, duration, callback) {
      if (ready.isCompleted || !matches(duration)) {
        return parent.createTimer(zone, duration, callback);
      }
      expire = callback;
      timer = parent.createTimer(zone, const Duration(days: 1), callback);
      ready.complete();
      return timer;
    },
  );
}
