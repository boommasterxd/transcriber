import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../service_exceptions.dart';

/// Network timeouts for cloud calls so a stalled request fails with a clear
/// error instead of hanging the processing UI forever.
const Duration remoteChatTimeout = Duration(seconds: 45);
const Duration remoteListTimeout = Duration(seconds: 25);
const Duration remoteTranscribeTimeout = Duration(seconds: 180);
const int maxRemoteAudioBytes = 100 * 1024 * 1024;
const int maxRemoteResponseBytes = 4 * 1024 * 1024;

/// Validates a provider upload and returns its size for streaming requests.
Future<int> validateRemoteAudioFile(File file) async {
  if (!await file.exists()) {
    throw const RemoteApiException('The audio file could not be found.');
  }
  final length = await file.length();
  if (length <= 0 || length > maxRemoteAudioBytes) {
    throw const RemoteApiException('The audio file is too large.');
  }
  return length;
}

/// Applies [timeout] to [future], converting a timeout into a user-facing error.
Future<T> guardTimeout<T>(Future<T> future, Duration timeout) {
  return future.timeout(
    timeout,
    onTimeout: () => throw const RemoteApiException(
      'Request timed out - the provider did not respond in time. '
      'Check your connection and try again.',
    ),
  );
}

/// Sends a request and reads its complete response within one deadline.
///
/// Applying the timeout only to [http.Client.send] is insufficient because a
/// provider can return headers and then stall while streaming the body.
Future<RemoteHttpResponse> sendRemoteRequest(
  http.Client client,
  http.BaseRequest request, {
  required Duration timeout,
}) {
  return guardTimeout(_sendAndRead(client, request), timeout);
}

Future<RemoteHttpResponse> _sendAndRead(
  http.Client client,
  http.BaseRequest request,
) async {
  final response = await client.send(request);
  return RemoteHttpResponse(
    statusCode: response.statusCode,
    headers: response.headers,
    body: await readRemoteResponseBody(response),
  );
}

/// Buffered, size-limited response returned by [sendRemoteRequest].
final class RemoteHttpResponse {
  const RemoteHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
}

/// Validates a provider response while preserving its provider-specific label.
void validateRemoteResponse({
  required int statusCode,
  required String body,
  required String errorLabel,
  String? secret,
  bool preferScalarError = false,
}) {
  if (statusCode >= 200 && statusCode < 300) return;
  throw RemoteApiException(
    '$errorLabel ($statusCode): '
    '${remoteErrorMessage(body, secret: secret, preferScalarError: preferScalarError)}',
    statusCode: statusCode,
  );
}

/// Extracts a provider error while preventing credentials from escaping.
String remoteErrorMessage(
  String body, {
  String? secret,
  bool preferScalarError = false,
}) {
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    final error = json['error'];
    final message = error is Map
        ? error['message']?.toString()
        : (preferScalarError ? error?.toString() : null);
    return sanitizeRemoteErrorMessage(
      message ?? 'The provider returned an error.',
      secrets: [?secret],
    );
  } catch (_) {
    return 'The provider returned an invalid error response.';
  }
}

/// Bounds a diagnostic and removes credentials before display or persistence.
String sanitizeRemoteErrorMessage(
  String value, {
  Iterable<String> secrets = const [],
}) {
  var result = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final secret in secrets) {
    if (secret.isNotEmpty) {
      result = result.replaceAll(secret, '[REDACTED]');
    }
  }
  result = result.replaceAll(
    RegExp(
      r'(api[_-]?key|authorization|token|password)\s*[:=]\s*[^ ,;]+',
      caseSensitive: false,
    ),
    '[REDACTED]',
  );
  return result.length > 512 ? '${result.substring(0, 512)}...' : result;
}

void validateResponseSize(List<int> bytes) {
  if (bytes.length > maxRemoteResponseBytes) {
    throw const RemoteApiException('The provider response was too large.');
  }
}

/// Reads a buffered or streamed HTTP response within the shared size limit.
Future<String> readRemoteResponseBody(http.BaseResponse response) async {
  final bytes = response is http.Response
      ? response.bodyBytes
      : await _readBounded(response as http.StreamedResponse);
  validateResponseSize(bytes);
  try {
    return utf8.decode(bytes);
  } on FormatException {
    throw const RemoteApiException('The provider response was invalid.');
  }
}

Future<Uint8List> _readBounded(http.StreamedResponse response) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in response.stream) {
    if (bytes.length + chunk.length > maxRemoteResponseBytes) {
      throw const RemoteApiException('The provider response was too large.');
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}

/// Decodes a JSON object without exposing a parser error or response content.
Map<String, dynamic> decodeRemoteJsonObject(String body, String label) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {
    // Fall through to a provider-safe error.
  }
  throw RemoteApiException('$label was invalid.');
}
