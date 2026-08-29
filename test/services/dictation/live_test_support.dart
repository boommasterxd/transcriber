import 'dart:async';

import 'package:transcriber/services/dictation/live_socket.dart';
import 'package:transcriber/services/dictation/live_transcription.dart';

final class FakeLiveSocket implements LiveSocket {
  final controller = StreamController<Object?>.broadcast();
  final List<String> sent = [];
  bool closed = false;

  @override
  int? closeCode;

  @override
  String? closeReason;

  @override
  Stream<Object?> get messages => controller.stream;

  @override
  void add(String message) => sent.add(message);

  @override
  Future<void> close() async {
    closed = true;
    if (!controller.isClosed) await controller.close();
  }

  Future<void> disconnect({int? code, String? reason}) async {
    closeCode = code;
    closeReason = reason;
    if (!controller.isClosed) await controller.close();
  }
}

final class CapturingConnector {
  CapturingConnector(this.socket);
  final FakeLiveSocket socket;
  Uri? uri;
  Map<String, String>? headers;

  Future<LiveSocket> call(Uri value, Map<String, String> requestHeaders) async {
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
