import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'live_failure_classifier.dart';
import 'live_transcription.dart';

abstract interface class LiveSocket {
  Stream<Object?> get messages;
  int? get closeCode;
  String? get closeReason;
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
  int? get closeCode => _socket.closeCode;

  @override
  String? get closeReason => _socket.closeReason;

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
  LiveSocketTranscriptionClient(
    this.connector, {
    this.connectionTimeout = const Duration(seconds: 10),
    this.closeTimeout = const Duration(seconds: 2),
  });

  final LiveSocketConnector connector;
  final Duration connectionTimeout;
  final Duration closeTimeout;
  final StreamController<LiveTranscriptionEvent> eventController =
      StreamController<LiveTranscriptionEvent>.broadcast(sync: true);
  LiveSocket? activeSocket;
  StreamSubscription<Object?>? _subscription;
  _LiveConnectionAttempt? _connectionAttempt;
  Completer<void>? _finishCompleter;
  bool isClosed = false;

  @override
  Stream<LiveTranscriptionEvent> get events => eventController.stream;

  Future<void> _connectSocket(
    Uri uri,
    Map<String, String> headers,
    Object setupMessage,
    _LiveConnectionAttempt attempt,
  ) async {
    final pendingSocket = connector(uri, headers);
    unawaited(
      pendingSocket.then((socket) async {
        if (!_isCurrent(attempt)) await _closeSocket(socket);
      }, onError: (_) {}),
    );
    final result = await Future.any<Object>([
      pendingSocket,
      attempt.cancelled.future.then((_) => _ConnectionSignal.cancelled),
    ]);
    if (identical(result, _ConnectionSignal.cancelled)) {
      throw const _LiveConnectionCancelled();
    }
    final socket = result as LiveSocket;
    if (!_isCurrent(attempt)) {
      await _closeSocket(socket);
      throw const _LiveConnectionCancelled();
    }
    activeSocket = socket;
    _subscription = socket.messages.listen(
      handleSocketMessage,
      onError: (_) => handleTransportFailure(null),
      onDone: () => handleTransportFailure(
        classifyLiveSocketClosure(socket.closeCode, socket.closeReason),
      ),
      cancelOnError: false,
    );
    socket.add(jsonEncode(setupMessage));
    final setupResult = await Future.any<Object>([
      attempt.setup.future.then((_) => _ConnectionSignal.setup),
      attempt.cancelled.future.then((_) => _ConnectionSignal.cancelled),
    ]);
    if (identical(setupResult, _ConnectionSignal.cancelled)) {
      throw const _LiveConnectionCancelled();
    }
  }

  Future<void> connectWithSetup(
    Uri uri,
    Map<String, String> headers,
    Object setupMessage,
  ) async {
    ensureOpen();
    if (_connectionAttempt != null) {
      throw StateError('A live connection attempt is already active.');
    }
    final attempt = _LiveConnectionAttempt();
    _connectionAttempt = attempt;
    try {
      await _connectSocket(
        uri,
        headers,
        setupMessage,
        attempt,
      ).timeout(connectionTimeout);
      if (!_isCurrent(attempt)) throw const _LiveConnectionCancelled();
      emit(const LiveTranscriptionReady());
    } on TimeoutException {
      attempt.cancel();
      throw const LiveConnectionException('connection_timeout');
    } on _LiveConnectionCancelled {
      throw const LiveConnectionException('connection_cancelled');
    } finally {
      if (identical(_connectionAttempt, attempt)) {
        _connectionAttempt = null;
      }
    }
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

  void completeSetup() {
    final setup = _connectionAttempt?.setup;
    if (setup != null && !setup.isCompleted) setup.complete();
  }

  void failSetupOrEmit(String code) {
    final setup = _connectionAttempt?.setup;
    if (setup != null) {
      if (!setup.isCompleted) {
        setup.completeError(LiveConnectionException(code));
      }
      return;
    }
    emit(LiveTranscriptionFailure(code));
  }

  void send(Object message) {
    if (!isClosed) activeSocket?.add(jsonEncode(message));
  }

  Map<String, dynamic>? decodeMessage(Object? raw) {
    try {
      final text = switch (raw) {
        String value => value,
        List<int> bytes => utf8.decode(bytes),
        _ => null,
      };
      if (text == null) return null;
      final decoded = jsonDecode(text);
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

  void handleTransportFailure(String? code) {
    if (_connectionAttempt != null) {
      failSetupOrEmit(code ?? 'connection_failed');
      return;
    }
    emit(
      code == null
          ? const LiveTranscriptionDisconnected()
          : LiveTranscriptionFailure(code),
    );
  }

  void handleSocketMessage(Object? raw);

  @override
  Future<void> close() async {
    if (isClosed) return;
    isClosed = true;
    final attempt = _connectionAttempt;
    _connectionAttempt = null;
    attempt?.cancel();
    final subscription = _subscription;
    _subscription = null;
    final socket = activeSocket;
    activeSocket = null;
    await Future.wait([
      if (subscription != null) _runBoundedCleanup(subscription.cancel()),
      if (socket != null) _closeSocket(socket),
    ]);
    await eventController.close();
  }

  bool _isCurrent(_LiveConnectionAttempt attempt) =>
      !isClosed && identical(_connectionAttempt, attempt);

  Future<void> _closeSocket(LiveSocket socket) async {
    await _runBoundedCleanup(socket.close());
  }

  Future<void> _runBoundedCleanup(Future<void> operation) async {
    try {
      await operation.timeout(closeTimeout, onTimeout: () {});
    } catch (_) {
      // Cleanup failures must not keep the input method in a transient state.
    }
  }
}

final class _LiveConnectionAttempt {
  final Completer<void> setup = Completer<void>();
  final Completer<void> cancelled = Completer<void>();

  void cancel() {
    if (!cancelled.isCompleted) cancelled.complete();
  }
}

final class _LiveConnectionCancelled implements Exception {
  const _LiveConnectionCancelled();
}

enum _ConnectionSignal { setup, cancelled }
