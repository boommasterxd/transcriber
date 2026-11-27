import 'dart:async';

import 'package:http/http.dart' as http;

import '../service_exceptions.dart';
import 'remote_http.dart';

/// Bounds uploaded files whose deletion this isolate has yet to attempt.
final class GeminiUploadedFileCleanup {
  GeminiUploadedFileCleanup(this._client);

  static const _maximumReserved = 4;
  static int _reserved = 0;

  final http.Client _client;
  int _pending = 0;
  bool _closeRequested = false;

  void reserve() {
    if (_reserved >= _maximumReserved) {
      throw const RemoteApiException(
        'Gemini is still cleaning up earlier uploads. Try again shortly.',
      );
    }
    _reserved++;
    _pending++;
  }

  void finish(http.Request? request) {
    if (request == null) {
      _release();
      return;
    }
    unawaited(_delete(request));
  }

  void closeWhenIdle() {
    _closeRequested = true;
    if (_pending == 0) _client.close();
  }

  Future<void> _delete(http.Request request) async {
    try {
      await sendRemoteRequest(_client, request, timeout: remoteListTimeout);
    } catch (_) {
      // Deletion is best effort and must not replace the transcription result.
    } finally {
      _release();
    }
  }

  void _release() {
    _reserved--;
    _pending--;
    if (_pending == 0 && _closeRequested) _client.close();
  }
}
