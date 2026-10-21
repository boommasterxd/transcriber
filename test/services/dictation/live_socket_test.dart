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
  _registerTransportTest();
  _registerInFlightCloseTest();
  _registerRejectedUpgradeTest();
  _registerBacklogTest();
}

void _registerTransportTest() {
  test(
    'the native socket sends ordered messages through its stream sink',
    () async {
      final connection = await _LoopbackConnection.open();
      addTearDown(connection.close);
      final received = connection.peer.take(2).toList();

      await connection.transport.send('audio');
      await connection.transport.send('finish');

      expect(await received, ['audio', 'finish']);
    },
  );
}

void _registerInFlightCloseTest() {
  test('closing during a native send destroys the owned transport', () async {
    final connection = await _LoopbackConnection.open();
    addTearDown(connection.close);
    final disconnected = connection.peer.drain<void>();
    final writing = connection.transport
        .send('audio')
        .catchError((Object _) {});

    await connection.transport.close();
    await writing;
    await expectLater(disconnected, completes);
    await expectLater(connection.transport.send('late'), throwsStateError);
  });
}

void _registerRejectedUpgradeTest() {
  test(
    'a rejected native upgrade fails without leaving a live client',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = server.listen((request) {
        request.response.statusCode = HttpStatus.badRequest;
        unawaited(request.response.close());
      });
      addTearDown(() async {
        await requests.cancel();
        await server.close(force: true);
      });

      await expectLater(
        connectLiveSocket(Uri.parse('ws://127.0.0.1:${server.port}'), {}),
        throwsA(isA<WebSocketException>()),
      );
    },
  );
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
        connector: (_, _) async => socket,
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
