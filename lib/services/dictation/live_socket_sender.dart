import 'dart:async';
import 'dart:collection';
import 'dart:convert';

/// Bounds queued and in-flight UTF-8 data while honoring transport backpressure.
final class LiveSocketSender {
  LiveSocketSender({
    required this.write,
    required this.onFailure,
    this.maximumPendingBytes = 256 * 1024,
    this.writeTimeout = const Duration(seconds: 5),
  });

  final Future<void> Function(String message) write;
  final void Function() onFailure;
  final int maximumPendingBytes;
  final Duration writeTimeout;
  final Queue<({String text, int bytes})> _pending = Queue();
  int _pendingBytes = 0;
  bool _writing = false;
  bool _closed = false;

  void add(String message) {
    if (_closed) return;
    if (message.length > maximumPendingBytes) {
      _fail();
      return;
    }
    final bytes = utf8.encode(message).length;
    if (_pendingBytes + bytes > maximumPendingBytes) {
      _fail();
      return;
    }
    _pending.add((text: message, bytes: bytes));
    _pendingBytes += bytes;
    if (!_writing) unawaited(_drain());
  }

  Future<void> _drain() async {
    _writing = true;
    try {
      while (!_closed && _pending.isNotEmpty) {
        final message = _pending.removeFirst();
        await write(message.text).timeout(writeTimeout);
        if (!_closed) _pendingBytes -= message.bytes;
      }
    } catch (_) {
      _fail();
    } finally {
      _writing = false;
    }
  }

  void _fail() {
    if (_closed) return;
    close();
    onFailure();
  }

  void close() {
    _closed = true;
    _pending.clear();
    _pendingBytes = 0;
  }
}
