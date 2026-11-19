import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'live_failure_classifier.dart';
import 'live_socket_sender.dart';
import 'live_socket_transport.dart';
import 'live_transcription.dart';

abstract interface class LiveSocket {
  Stream<Object?> get messages;
  int? get closeCode;
  String? get closeReason;
  Future<void> send(String message);
  Future<void> close();
}

typedef LiveSocketConnector = Future<LiveSocket> Function(
  Uri uri,
  Map<String, String> headers,
  void Function(void Function() abort) onCancellation,
);

Future<LiveSocket> connectLiveSocket(
  Uri uri,
  Map<String, String> headers, [
  void Function(void Function() abort)? onCancellation,
]) => _openLiveSocket(uri, Map.of(headers), onCancellation);

Future<LiveSocket> _openLiveSocket(
  Uri uri,
  Map<String, String> requestHeaders,
  void Function(void Function() abort)? onCancellation,
) async {
  final transport = LiveSocketTransport.begin(uri);
  try {
    onCancellation?.call(() {
      requestHeaders.clear();
      transport.abort();
    });
    final socket = await WebSocket.connect(
      uri.toString(),
      headers: requestHeaders,
      customClient: transport.httpClient,
      compression: CompressionOptions.compressionOff,
      maxPayloadLength: LiveTranscriptionLimits.maximumFrameBytes,
    );
    final liveSocket = IoLiveSocket(
      socket,
      transport.abort,
      transport.messageReceived,
    );
    if (transport.aborted) {
      await liveSocket.close();
      throw const _LiveConnectionCancelled();
    }
    return liveSocket;
  } catch (_) {
    transport.abort();
    rethrow;
  } finally {
    requestHeaders.clear();
    transport.endHandshake();
  }
}

final class IoLiveSocket implements LiveSocket {
  IoLiveSocket(this._socket, this._abort, this._messageReceived);
  final WebSocket _socket;
  final void Function() _abort;
  final void Function() _messageReceived;
  bool _sending = false;
  bool _closed = false;

  @override
  Stream<Object?> get messages => _socket.map((message) {
    _messageReceived();
    return message;
  });

  @override
  int? get closeCode => _socket.closeCode;

  @override
  String? get closeReason => _socket.closeReason;

  @override
  Future<void> send(String message) async {
    if (_closed || _sending) throw StateError('Socket is not writable.');
    _sending = true;
    try {
      await _socket.addStream(Stream.value(message));
    } finally {
      _sending = false;
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      // Initiate WebSocket lifecycle cleanup even if its sink is still bound.
      await _socket
          .close(WebSocketStatus.normalClosure)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // A bound addStream or stalled close must still destroy the transport.
    } finally {
      _abort();
    }
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
  LiveSocketSender? _sender;
  StreamSubscription<Object?>? _subscription;
  _LiveConnectionAttempt? _connectionAttempt;
  Completer<void>? _finishCompleter;
  Future<void>? _closing;
  bool isClosed = false;

  @override
  Stream<LiveTranscriptionEvent> get events => eventController.stream;

  Future<void> _connectSocket(
    Uri uri,
    Map<String, String> headers,
    Object setupMessage,
    _LiveConnectionAttempt attempt,
  ) async {
    final socketCloseTimeout = closeTimeout;
    final pendingSocket = connector(uri, headers, attempt.onCancellation).then((
      socket,
    ) async {
      if (!attempt.cancelled.isCompleted) return socket;
      await _runBoundedCleanup(socket.close(), socketCloseTimeout);
      throw const _LiveConnectionCancelled();
    });
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
    _sender = LiveSocketSender(
      write: socket.send,
      onFailure: _handleSendFailure,
    );
    _subscription = socket.messages.listen(
      _dispatchSocketMessage,
      onError: (_) => handleTransportFailure(null),
      onDone: () => handleTransportFailure(
        classifyLiveSocketClosure(socket.closeCode, socket.closeReason),
      ),
      cancelOnError: false,
    );
    _sender!.add(jsonEncode(setupMessage));
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
      unawaited(close());
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
    if (!isClosed) _sender?.add(jsonEncode(message));
  }

  void _handleSendFailure() {
    failSetupOrEmit('connection_failed');
    unawaited(close());
  }

  Map<String, dynamic>? decodeMessage(Object? raw) {
    if (!_isBoundedFrame(raw)) {
      rejectMalformedResponse();
      return null;
    }
    try {
      final text = switch (raw) {
        String value => value,
        List<int> bytes => utf8.decode(bytes),
        _ => null,
      };
      if (text == null) {
        rejectMalformedResponse();
        return null;
      }
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
      rejectMalformedResponse();
      return null;
    } on FormatException {
      rejectMalformedResponse();
      return null;
    }
  }

  void rejectMalformedResponse() {
    if (isClosed) return;
    final attempt = _connectionAttempt;
    if (attempt != null && !attempt.setup.isCompleted) {
      failSetupOrEmit('provider_rejected');
    } else {
      emit(const LiveTranscriptionFailure('provider_rejected'));
    }
    unawaited(close());
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

  void onClosing() {}

  void _dispatchSocketMessage(Object? raw) {
    try {
      handleSocketMessage(raw);
    } on Object {
      rejectMalformedResponse();
    }
  }

  bool _isBoundedFrame(Object? raw) => switch (raw) {
    String value =>
      value.length <= LiveTranscriptionLimits.maximumFrameBytes &&
          utf8.encode(value).length <=
              LiveTranscriptionLimits.maximumFrameBytes,
    List<int> bytes =>
      bytes.length <= LiveTranscriptionLimits.maximumFrameBytes,
    _ => false,
  };

  @override
  Future<void> close() => _closing ??= _close();

  Future<void> _close() async {
    isClosed = true;
    _sender?.close();
    _sender = null;
    onClosing();
    final attempt = _connectionAttempt;
    _connectionAttempt = null;
    attempt?.cancel();
    final subscription = _subscription;
    _subscription = null;
    final socket = activeSocket;
    activeSocket = null;
    await Future.wait([
      if (subscription != null)
        _runBoundedCleanup(subscription.cancel(), closeTimeout),
      if (socket != null) _closeSocket(socket),
    ]);
    await eventController.close();
  }

  bool _isCurrent(_LiveConnectionAttempt attempt) =>
      !isClosed && identical(_connectionAttempt, attempt);

  Future<void> _closeSocket(LiveSocket socket) async {
    await _runBoundedCleanup(socket.close(), closeTimeout);
  }
}

Future<void> _runBoundedCleanup(
  Future<void> operation,
  Duration timeout,
) async {
  try {
    await operation.timeout(timeout, onTimeout: () {});
  } catch (_) {
    // Cleanup failures must not keep the input method in a transient state.
  }
}

final class _LiveConnectionAttempt {
  final Completer<void> setup = Completer<void>();
  final Completer<void> cancelled = Completer<void>();
  void Function()? _abort;

  void onCancellation(void Function() abort) {
    if (cancelled.isCompleted) {
      abort();
    } else {
      _abort = abort;
    }
  }

  void cancel() {
    if (cancelled.isCompleted) return;
    cancelled.complete();
    _abort?.call();
    _abort = null;
  }
}

final class _LiveConnectionCancelled implements Exception {
  const _LiveConnectionCancelled();
}

enum _ConnectionSignal { setup, cancelled }
