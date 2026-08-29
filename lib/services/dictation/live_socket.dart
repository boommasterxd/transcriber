import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  LiveSocketTranscriptionClient(this.connector);

  final LiveSocketConnector connector;
  final StreamController<LiveTranscriptionEvent> eventController =
      StreamController<LiveTranscriptionEvent>.broadcast(sync: true);
  LiveSocket? activeSocket;
  StreamSubscription<Object?>? _subscription;
  Completer<void>? _setupCompleter;
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
      onError: (_) => handleTransportFailure(null),
      onDone: () => handleTransportFailure(
        classifyLiveSocketClosure(socket.closeCode, socket.closeReason),
      ),
      cancelOnError: false,
    );
    return socket;
  }

  Future<void> connectWithSetup(
    Uri uri,
    Map<String, String> headers,
    Object setupMessage,
  ) async {
    _setupCompleter = Completer<void>();
    try {
      final socket = await connectSocket(uri, headers);
      socket.add(jsonEncode(setupMessage));
      await _setupCompleter!.future.timeout(const Duration(seconds: 10));
      emit(const LiveTranscriptionReady());
    } on TimeoutException {
      throw const LiveConnectionException('connection_timeout');
    } finally {
      _setupCompleter = null;
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
    final setup = _setupCompleter;
    if (setup != null && !setup.isCompleted) setup.complete();
  }

  void failSetupOrEmit(String code) {
    final setup = _setupCompleter;
    if (setup != null && !setup.isCompleted) {
      setup.completeError(LiveConnectionException(code));
    } else {
      emit(LiveTranscriptionFailure(code));
    }
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

  void handleTransportFailure(String? code) {
    if (_setupCompleter != null) {
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
    await _subscription?.cancel();
    await activeSocket?.close();
    await eventController.close();
  }
}

String? classifyLiveSocketClosure(int? closeCode, String? closeReason) {
  if (closeCode == null || closeCode == WebSocketStatus.normalClosure) {
    return null;
  }
  return classifyProviderFailure(
    code: closeCode.toString(),
    message: closeReason,
  );
}

String classifyProviderFailure({Object? code, Object? message}) {
  final detail = '${code ?? ''} ${message ?? ''}'.toLowerCase();
  if (_containsAny(detail, const [
    'api key',
    'invalid_api_key',
    'authentication',
    'unauthenticated',
    'unauthorized',
    '401',
  ])) {
    return 'authentication_failed';
  }
  if (_containsAny(detail, const [
    'quota',
    'rate_limit',
    'rate limit',
    'resource_exhausted',
    'billing',
    '429',
  ])) {
    return 'quota_exceeded';
  }
  if (_containsAny(detail, const [
    'model',
    'not_found',
    'not found',
    'unsupported',
    'unavailable',
  ])) {
    return 'model_unavailable';
  }
  if (_containsAny(detail, const [
    'permission',
    'access denied',
    'forbidden',
    '403',
  ])) {
    return 'provider_access_denied';
  }
  if (_containsAny(detail, const [
    'invalid_request',
    'invalid argument',
    'configuration',
    'language',
    '1007',
  ])) {
    return 'configuration_rejected';
  }
  return 'provider_rejected';
}

bool _containsAny(String value, List<String> needles) =>
    needles.any(value.contains);
