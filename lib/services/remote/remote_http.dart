import 'dart:async';
import 'dart:convert';

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
      'Request timed out — the provider did not respond in time. '
      'Check your connection and try again.',
    ),
  );
}

/// Validates a provider response while preserving its provider-specific label.
void validateRemoteResponse({
  required int statusCode,
  required String body,
  required String errorLabel,
  bool preferScalarError = false,
}) {
  if (statusCode == 200) return;
  throw RemoteApiException(
    '$errorLabel ($statusCode): '
    '${remoteErrorMessage(body, preferScalarError: preferScalarError)}',
    statusCode: statusCode,
  );
}

/// Extracts the conventional `error.message` field with a stable fallback.
String remoteErrorMessage(String body, {bool preferScalarError = false}) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final error = json['error'];
    if (error is Map) return error['message']?.toString() ?? body;
    if (preferScalarError) return error?.toString() ?? body;
    return body;
  } catch (_) {
    return body;
  }
}
