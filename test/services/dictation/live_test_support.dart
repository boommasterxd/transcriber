import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:transcriber/services/dictation/live_socket.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';

final class FakeLiveSocket implements LiveSocket {
  final controller = StreamController<Object?>.broadcast();
  final List<String> sent = [];
  bool closed = false;
  Completer<void>? sendGate;

  @override
  int? closeCode;

  @override
  String? closeReason;

  @override
  Stream<Object?> get messages => controller.stream;

  @override
  Future<void> send(String message) async {
    sent.add(message);
    await sendGate?.future;
  }

  @override
  Future<void> close() async {
    closed = true;
    if (!controller.isClosed) await controller.close();
  }
}

final class CapturingConnector {
  CapturingConnector(this.socket);
  final FakeLiveSocket socket;
  Uri? uri;
  Map<String, String>? headers;

  Future<LiveSocket> call(
    Uri value,
    Map<String, String> requestHeaders,
    void Function(void Function()) _,
  ) async {
    uri = value;
    headers = requestHeaders;
    return socket;
  }
}

List<LiveTranscriptionEvent> collectEvents(LiveTranscriptionClient client) {
  final events = <LiveTranscriptionEvent>[];
  client.events.listen(events.add);
  return events;
}

Future<void> connectLiveClient(
  LiveTranscriptionClient client,
  FakeLiveSocket socket,
  Object readyMessage,
) async {
  final connecting = client.connect();
  await pumpEventQueue();
  socket.controller.add(jsonEncode(readyMessage));
  await connecting;
  await pumpEventQueue();
}

final class LiveClientTestHarness<T extends LiveTranscriptionClient> {
  LiveClientTestHarness._(
    this.socket,
    this.connector,
    this.client,
    this.events,
  );

  factory LiveClientTestHarness.create(
    T Function(CapturingConnector connector) buildClient,
  ) {
    final socket = FakeLiveSocket();
    final connector = CapturingConnector(socket);
    final client = buildClient(connector);
    return LiveClientTestHarness._(
      socket,
      connector,
      client,
      collectEvents(client),
    );
  }

  final FakeLiveSocket socket;
  final CapturingConnector connector;
  final T client;
  final List<LiveTranscriptionEvent> events;

  Future<void> close() async {
    if (!socket.closed) await client.close();
  }
}
