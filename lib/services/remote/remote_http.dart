import 'dart:async';

import '../service_exceptions.dart';

/// Network timeouts for cloud calls so a stalled request fails with a clear
/// error instead of hanging the processing UI forever.
const Duration remoteChatTimeout = Duration(seconds: 90);
const Duration remoteListTimeout = Duration(seconds: 25);
const Duration remoteTranscribeTimeout = Duration(seconds: 180);

/// Applies [timeout] to [future], converting a timeout into a user-facing error.
Future<T> guardTimeout<T>(Future<T> future, Duration timeout) {
  return future.timeout(
    timeout,
    onTimeout: () => throw const RemoteApiException(
      'Zeitüberschreitung – der Anbieter hat nicht rechtzeitig geantwortet. '
      'Prüfe deine Verbindung und versuche es erneut.',
    ),
  );
}
