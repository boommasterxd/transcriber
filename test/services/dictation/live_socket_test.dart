import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/dictation/live_socket.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';
import 'package:transcriber/services/dictation/openai_live_transcription_client.dart';

import 'live_test_support.dart';

void main() {
  _registerNativeAbortAndReadBudgetTests();
  _registerOriginAndHandshakeTests();
  _registerBacklogTest();
}

void _registerOriginAndHandshakeTests() {
  test('keeps provider headers on the initial origin', () async {
    final original = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final destination = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => original.close(force: true));
    addTearDown(() => destination.close(force: true));
    var forwarded = false;
    final requests = destination.listen((request) {
      forwarded = true;
      unawaited(request.response.close());
    });
    final redirects = original.listen((request) {
      unawaited(
        request.response.redirect(
          Uri.parse('http://127.0.0.1:${destination.port}'),
          status: HttpStatus.temporaryRedirect,
        ),
      );
    });
    addTearDown(requests.cancel);
    addTearDown(redirects.cancel);

    await expectLater(
      connectLiveSocket(Uri.parse('ws://127.0.0.1:${original.port}'), {
        'x-goog-api-key': 'synthetic-key',
      }),
      throwsA(isA<IOException>()),
    );
    expect(forwarded, isFalse);
  });
}

void _registerNativeAbortAndReadBudgetTests() {
  test('rejects a single oversized frame before delivering it', () async {
    final connection = await _LoopbackConnection.open();
    addTearDown(connection.close);
    final messages = connection.transport.messages.toList();
    final tooLarge = Uint8List(LiveTranscriptionLimits.maximumFrameBytes + 1);

    connection.peer.add(tooLarge);

    expect(await messages, isEmpty);
    expect(connection.transport.closeCode, WebSocketStatus.protocolError);
  });
}

final class _LoopbackConnection {
  _LoopbackConnection(
    this.server,
    this.subscription,
    this.transport,
    this.peer,
  );

  final HttpServer server;
  final StreamSubscription<WebSocket> subscription;
  final LiveSocket transport;
  final WebSocket peer;

  static Future<_LoopbackConnection> open() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final peer = Completer<WebSocket>();
    final subscription = server
        .transform(WebSocketTransformer())
        .listen(peer.complete);
    try {
      final transport = await connectLiveSocket(
        Uri.parse('ws://127.0.0.1:${server.port}'),
        {},
      );
      return _LoopbackConnection(
        server,
        subscription,
        transport,
        await peer.future,
      );
    } catch (_) {
      await subscription.cancel();
      await server.close(force: true);
      rethrow;
    }
  }

  Future<void> close() async {
    await transport.close();
    await peer.close();
    await subscription.cancel();
    await server.close(force: true);
  }
}

void _registerBacklogTest() {
  test(
    'a connected upload exceeding its backlog closes with a safe failure',
    () async {
      final socket = FakeLiveSocket();
      final client = OpenAiLiveTranscriptionClient(
        const LiveTranscriptionConfig(
          provider: RemoteProviderId.openai,
          apiKey: 'synthetic-key',
          languageCode: null,
        ),
        connector: (_, _, _) async => socket,
      );
      final events = collectEvents(client);
      await connectLiveClient(client, socket, {'type': 'session.updated'});
      final writeGate = Completer<void>();
      socket.sendGate = writeGate;
      final audio = Uint8List(48 * 1024);

      for (var index = 0; index < 5; index++) {
        client.addAudio(audio);
      }
      await pumpEventQueue();

      expect(client.isClosed, isTrue);
      expect(socket.closed, isTrue);
      expect(
        events.whereType<LiveTranscriptionFailure>().single.code,
        'connection_failed',
      );
      expect(socket.sent, hasLength(2));
      expect(jsonDecode(socket.sent.last)['type'], 'input_audio_buffer.append');
      writeGate.complete();
      await pumpEventQueue();
      expect(socket.sent, hasLength(2));
      await client.close();
    },
  );
}
