import 'dart:async';

/// Cancellation shared by the sequential provider requests of one run.
final class RemoteCancellation {
  final _listeners = <void Function()>{};
  bool _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    final listeners = _listeners.toList(growable: false);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  /// Registers a listener until it is removed or this run is cancelled.
  void Function() listen(void Function() listener) {
    throwIfCancelled();
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  void throwIfCancelled() {
    if (_cancelled) throw const RemoteRequestCancelledException();
  }
}

final class RemoteRequestCancelledException implements Exception {
  const RemoteRequestCancelledException();
}

Future<void> waitForRemotePoll(
  Duration duration,
  RemoteCancellation? cancellation,
) async {
  if (cancellation == null) return Future<void>.delayed(duration);
  final pending = Completer<void>();
  final removeListener = cancellation.listen(
    () => pending.completeError(const RemoteRequestCancelledException()),
  );
  final timer = Timer(duration, () {
    removeListener();
    pending.complete();
  });
  try {
    await pending.future;
  } finally {
    timer.cancel();
  }
}
