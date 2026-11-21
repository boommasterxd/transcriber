import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'live_transcription.dart';

/// Owns the native connection until the HTTP upgrade and its socket settle.
final class LiveSocketTransport {
  LiveSocketTransport._(this._origin) {
    httpClient
      ..findProxy = null
      ..connectionFactory = _connect;
  }

  static LiveSocketTransport? _handshake;

  static LiveSocketTransport begin(Uri origin) {
    if (_handshake != null) {
      throw const LiveConnectionException('connection_timeout');
    }
    return _handshake = LiveSocketTransport._(origin);
  }

  final Uri _origin;
  final HttpClient httpClient = HttpClient();
  final _budget = LiveSocketReadBudget();
  final _tasks = <ConnectionTask<Socket>>{};
  final _sockets = <Socket>{};
  int _connections = 0;
  bool _handshakeEnded = false;
  bool _aborted = false;

  bool get aborted => _aborted;

  Future<ConnectionTask<Socket>> _connect(
    Uri target,
    String? proxyHost,
    int? proxyPort,
  ) async {
    if (_aborted) throw const SocketException('Connection cancelled.');
    if (proxyHost != null || proxyPort != null) {
      throw const SocketException(
        'Live dictation requires a direct connection.',
      );
    }
    if (!_matchesOrigin(target)) {
      throw const SocketException('Live connection origin changed.');
    }
    _connections++;
    try {
      final task = target.scheme == 'https'
          ? await SecureSocket.startConnect(target.host, target.port)
          : await Socket.startConnect(target.host, target.port);
      final socket = _acceptSocket(task);
      _tasks.add(task);
      if (_aborted) _cancelTask(task);
      return ConnectionTask.fromSocket(socket, () => _cancelTask(task));
    } catch (_) {
      _connectionSettled();
      rethrow;
    }
  }

  bool _matchesOrigin(Uri target) =>
      target.scheme == (_origin.scheme == 'wss' ? 'https' : 'http') &&
      target.host == _origin.host &&
      target.port == _origin.port;

  Future<Socket> _acceptSocket(ConnectionTask<Socket> task) async {
    try {
      final socket = await task.socket;
      if (_aborted) {
        socket.destroy();
        throw const SocketException('Connection cancelled.');
      }
      _sockets.add(socket);
      return _BudgetedSocket(socket, _budget);
    } finally {
      _tasks.remove(task);
      _connectionSettled();
    }
  }

  void messageReceived() => _budget.messageReceived();

  void endHandshake() {
    _handshakeEnded = true;
    httpClient.close(force: true);
    _releaseHandshake();
  }

  void abort() {
    if (_aborted) return;
    _aborted = true;
    for (final task in _tasks.toList()) {
      _cancelTask(task);
    }
    httpClient.close(force: true);
    for (final socket in _sockets) {
      socket.destroy();
    }
    _sockets.clear();
  }

  void _cancelTask(ConnectionTask<Socket> task) {
    if (_tasks.remove(task)) task.cancel();
  }

  void _connectionSettled() {
    _connections--;
    _releaseHandshake();
  }

  void _releaseHandshake() {
    if (_handshakeEnded && _connections == 0 && identical(_handshake, this)) {
      _handshake = null;
    }
  }
}

/// Bounds bytes supplied to the native parser before it yields a complete message.
final class LiveSocketReadBudget {
  static const _readSliceBytes = 16 * 1024;
  static const _wireBudget =
      LiveTranscriptionLimits.maximumFrameBytes + 64 * 1024;

  int _bytesSinceMessage = 0;
  int _deliveringBytes = 0;
  bool _exhausted = false;

  Stream<Uint8List> bind(Stream<Uint8List> source) =>
      source.transform(StreamTransformer.fromHandlers(handleData: _add));

  void messageReceived() {
    // Retain the whole slice because it may start the following message too.
    if (_deliveringBytes > 0) _bytesSinceMessage = _deliveringBytes;
  }

  void _add(Uint8List bytes, EventSink<Uint8List> sink) {
    for (var offset = 0; offset < bytes.length && !_exhausted;) {
      final end = min(offset + _readSliceBytes, bytes.length);
      _deliveringBytes = end - offset;
      _bytesSinceMessage += _deliveringBytes;
      if (_bytesSinceMessage > _wireBudget) {
        _exhausted = true;
        sink.addError(
          const WebSocketException('Live response exceeded its read budget.'),
        );
      } else {
        sink.add(
          offset == 0 && end == bytes.length
              ? bytes
              : Uint8List.fromList(Uint8List.sublistView(bytes, offset, end)),
        );
      }
      _deliveringBytes = 0;
      offset = end;
    }
  }
}

final class _BudgetedSocket extends Stream<Uint8List> implements Socket {
  _BudgetedSocket(this._socket, LiveSocketReadBudget budget)
    : _reads = budget.bind(_socket);

  final Socket _socket;
  final Stream<Uint8List> _reads;

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _reads.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );

  @override
  Encoding get encoding => _socket.encoding;
  @override
  set encoding(Encoding value) => _socket.encoding = value;
  @override
  void write(Object? value) => _socket.write(value);
  @override
  void writeAll(Iterable<Object?> values, [String separator = '']) =>
      _socket.writeAll(values, separator);
  @override
  void writeln([Object? value = '']) => _socket.writeln(value);
  @override
  void writeCharCode(int value) => _socket.writeCharCode(value);
  @override
  void add(List<int> data) => _socket.add(data);
  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _socket.addError(error, stackTrace);
  @override
  Future<void> addStream(Stream<List<int>> stream) => _socket.addStream(stream);
  @override
  Future<void> flush() async => _socket.flush();
  @override
  Future<void> close() async => _socket.close();
  @override
  Future<void> get done async => _socket.done;
  @override
  void destroy() => _socket.destroy();
  @override
  InternetAddress get address => _socket.address;
  @override
  int get port => _socket.port;
  @override
  InternetAddress get remoteAddress => _socket.remoteAddress;
  @override
  int get remotePort => _socket.remotePort;
  @override
  bool setOption(SocketOption option, bool enabled) =>
      _socket.setOption(option, enabled);
  @override
  Uint8List getRawOption(RawSocketOption option) =>
      _socket.getRawOption(option);
  @override
  void setRawOption(RawSocketOption option) => _socket.setRawOption(option);
}
