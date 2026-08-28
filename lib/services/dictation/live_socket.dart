import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'live_transcription.dart';

abstract interface class LiveSocket {
  Stream<Object?> get messages;
  void add(String message);
  Future<void> close();
}

typedef LiveSocketConnector =
    Future<LiveSocket> Function(Uri uri, Map<String, String> headers);

Future<LiveSocket> connectLiveSocket(
  Uri uri,
  Map<String, String> headers,
) async =>
    IoLiveSocket(await WebSocket.connect(uri.toString(), headers: headers));

final class IoLiveSocket implements LiveSocket {
  IoLiveSocket(this._socket);
  final WebSocket _socket;

  @override
  Stream<Object?> get messages => _socket;

  @override
  void add(String message) => _socket.add(message);

  @override
  Future<void> close() async {
    await _socket.close(WebSocketStatus.normalClosure);
  }
}

/// Shared transport lifecycle for provider-specific live transcription clients.
abstract base class LiveSocketTranscriptionClient
    implements LiveTranscriptionClient {
  LiveSocketTranscriptionClient(this.connector);

  final LiveSocketConnector connector;
  final StreamController<LiveTranscriptionEvent> eventController =
      StreamController<LiveTranscriptionEvent>.broadcast(sync: true);
  LiveSocket? activeSocket;
  StreamSubscription<Object?>? _subscription;
  Completer<void>? _finishCompleter;
  bool isClosed = false;

  @override
  Stream<LiveTranscriptionEvent> get events => eventController.stream;

  Future<LiveSocket> connectSocket(Uri uri, Map<String, String> headers) async {
    ensureOpen();
    final socket = await connector(uri, headers);
    activeSocket = socket;
    _subscription = socket.messages.listen(
      handleSocketMessage,
      onError: (_) => emit(const LiveTranscriptionDisconnected()),
      onDone: () => emit(const LiveTranscriptionDisconnected()),
      cancelOnError: false,
    );
    return socket;
  }

  Future<void> sendAndAwaitFinal(Object message, {bool skip = false}) async {
    if (isClosed || activeSocket == null || skip) return;
    _finishCompleter = Completer<void>();
    send(message);
    await _finishCompleter!.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () {},
    );
  }

  void completeFinalization() {
    _finishCompleter?.complete();
    _finishCompleter = null;
  }

  void send(Object message) {
    if (!isClosed) activeSocket?.add(jsonEncode(message));
  }

  Map<String, dynamic>? decodeMessage(Object? raw) {
    if (raw is! String) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  void emit(LiveTranscriptionEvent event) {
    if (!isClosed) eventController.add(event);
  }

  void ensureOpen() {
    if (isClosed) throw StateError('The live transcription client is closed.');
  }

  void handleSocketMessage(Object? raw);

  @override
  Future<void> close() async {
    if (isClosed) return;
    isClosed = true;
    await _subscription?.cancel();
    await activeSocket?.close();
    await eventController.close();
  }
}
