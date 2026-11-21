import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/services/dictation/live_socket.dart';
import 'package:transcriber/services/dictation/live_socket_transport.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';
import 'package:transcriber/services/dictation/openai_live_transcription_client.dart';

import 'live_test_support.dart';

void main() {
  _registerTransportTest();
  _registerInFlightCloseTest();
  _registerRejectedUpgradeTest();
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

  test(
    'allows another attempt after an outstanding TLS handshake settles',
    _verifyRetryAfterTlsHandshakeSettles,
  );
}

Future<void> _verifyRetryAfterTlsHandshakeSettles() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(server.close);
  final awaitingHandshake = Completer<Socket>();
  final peers = server.listen((socket) {
    addTearDown(socket.destroy);
    socket.listen((_) {
      if (!awaitingHandshake.isCompleted) {
        awaitingHandshake.complete(socket);
      }
    });
  });
  addTearDown(peers.cancel);
  late void Function() abort;
  final uri = Uri.parse('wss://127.0.0.1:${server.port}');
  final first = connectLiveSocket(uri, {}, (cancel) => abort = cancel);
  final failure = expectLater(first, throwsA(isA<IOException>()));

  final peer = await awaitingHandshake.future;
  abort();
  await expectLater(
    connectLiveSocket(uri, {}),
    throwsA(isA<LiveConnectionException>()),
  );

  peer.destroy();
  await failure;
  final replacement = await _LoopbackConnection.open();
  addTearDown(replacement.close);
}

void _registerNativeAbortAndReadBudgetTests() {
  test('aborts a native transport waiting for an HTTP upgrade', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final request = Completer<void>();
    final peerClosed = Completer<void>();
    final peers = server.listen((socket) {
      addTearDown(socket.destroy);
      socket.listen((_) {
        if (!request.isCompleted) request.complete();
      }, onDone: peerClosed.complete);
    });
    addTearDown(peers.cancel);
    late void Function() abort;
    final connecting = connectLiveSocket(
      Uri.parse('ws://127.0.0.1:${server.port}'),
      {},
      (cancel) => abort = cancel,
    );
    final failed = expectLater(connecting, throwsA(isA<IOException>()));

    await request.future;
    abort();

    await failed;
    await peerClosed.future;
    final replacement = await _LoopbackConnection.open();
    addTearDown(replacement.close);
  });

  test(
    'replenishes the read budget when native delivery completes messages',
    () async {
      final connection = await _LoopbackConnection.open();
      addTearDown(connection.close);
      final bytes = Uint8List(LiveTranscriptionLimits.maximumFrameBytes ~/ 4);
      final lengths = connection.transport.messages
          .cast<List<int>>()
          .take(6)
          .map((data) => data.length)
          .toList();

      await connection.peer.addStream(
        Stream.fromIterable(List.filled(6, bytes)),
      );

      expect(await lengths, List.filled(6, bytes.length));
    },
  );

  test('rejects a single oversized frame before delivering it', () async {
    final connection = await _LoopbackConnection.open();
    addTearDown(connection.close);
    final messages = connection.transport.messages.toList();
    final tooLarge = Uint8List(LiveTranscriptionLimits.maximumFrameBytes + 1);

    connection.peer.add(tooLarge);

    expect(await messages, isEmpty);
    expect(connection.transport.closeCode, WebSocketStatus.protocolError);
  });

  test('stops supplying accumulated bytes before a complete message', () async {
    final budget = LiveSocketReadBudget();
    final source = StreamController<Uint8List>(sync: true);
    final slice = Uint8List(16 * 1024);
    const maximumBytes = LiveTranscriptionLimits.maximumFrameBytes + 64 * 1024;
    var delivered = 0;
    final errors = <Object>[];
    final subscription = budget
        .bind(source.stream)
        .listen((data) => delivered += data.length, onError: errors.add);
    addTearDown(subscription.cancel);

    for (var index = 0; index <= maximumBytes ~/ slice.length; index++) {
      source.add(slice);
    }
    budget.messageReceived();
    source.add(slice);
    await source.close();

    expect(delivered, maximumBytes);
    expect(errors, [isA<WebSocketException>()]);
  });
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
