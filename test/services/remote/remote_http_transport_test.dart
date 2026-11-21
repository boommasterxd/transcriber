import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:test/test.dart';
import 'package:transcriber/services/remote/remote_http.dart';
import 'package:transcriber/services/service_exceptions.dart';

void main() {
  test(
    'native HTTP transport cancels a stalled upload at its deadline',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final serverSubscription = server.listen((request) {
        request.listen((_) {}, onError: (Object _) {});
      });
      final client = IOClient();
      final listening = Completer<void>();
      final cancelled = Completer<void>();
      final body = StreamController<List<int>>(
        onListen: listening.complete,
        onCancel: cancelled.complete,
      );
      final request = _StalledUpload(
        Uri.parse('http://127.0.0.1:${server.port}/upload'),
        body.stream,
      );
      final deadline = _ManualDeadline();
      try {
        final result = deadline.run(
          () => sendRemoteRequest(
            client,
            request,
            timeout: remoteTranscribeTimeout,
          ),
        );
        final assertion = expectLater(
          result,
          throwsA(isA<RemoteApiException>()),
        );
        await listening.future;
        deadline.fire();
        await assertion;
        await cancelled.future;
        expect(body.hasListener, isFalse);
      } finally {
        client.close();
        await server.close(force: true);
        await serverSubscription.cancel();
        await body.close();
      }
    },
  );
}

final class _StalledUpload extends http.BaseRequest {
  _StalledUpload(Uri url, this.body) : super('POST', url) {
    contentLength = 1;
  }

  final Stream<List<int>> body;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(body);
  }
}

/// Advances only the request deadline after native upload consumption starts.
final class _ManualDeadline implements Timer {
  void Function()? _callback;
  @override
  bool isActive = true;
  @override
  int tick = 0;

  T run<T>(T Function() action) => runZoned(
    action,
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        if (duration != remoteTranscribeTimeout) {
          return parent.createTimer(zone, duration, callback);
        }
        _callback = callback;
        return this;
      },
    ),
  );

  void fire() {
    if (!isActive) return;
    isActive = false;
    tick++;
    _callback!();
  }

  @override
  void cancel() => isActive = false;
}
