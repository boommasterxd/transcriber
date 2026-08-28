import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/models/transcript_note.dart';
import '../../data/models/transcription_result.dart';
import '../service_exceptions.dart';
import 'remote_api_client.dart';
import 'remote_http.dart';

/// Direct REST client for Gemini generation, files, and interactions APIs.
class GoogleClient implements RemoteProviderClient {
  GoogleClient({
    required this.apiKey,
    http.Client? httpClient,
    this.pollInterval = const Duration(seconds: 2),
    this.pollTimeout = const Duration(seconds: 30),
    Future<void> Function(Duration)? delay,
  }) : _http = httpClient ?? http.Client(),
       _delay = delay ?? Future<void>.delayed;

  final String apiKey;
  final http.Client _http;
  final Duration pollInterval;
  final Duration pollTimeout;
  final Future<void> Function(Duration) _delay;

  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const _uploadUrl =
      'https://generativelanguage.googleapis.com/upload/v1beta/files';
  @override
  Future<void> testConnection() async {
    await _getJson('/models?pageSize=1', timeout: remoteListTimeout);
  }

  @override
  Future<List<RemoteModelInfo>> listModels({
    required bool forTranscription,
  }) async {
    final json = await _getJson(
      '/models?pageSize=100',
      timeout: remoteListTimeout,
    );
    final models = json['models'];
    if (models is! List) return const [];
    final result = <RemoteModelInfo>[];
    for (final raw in models.whereType<Map>()) {
      final id = (raw['name']?.toString() ?? '').replaceFirst('models/', '');
      if (id.isEmpty || !id.toLowerCase().contains('gemini')) continue;
      final methods = (raw['supportedGenerationMethods'] as List?)
          ?.map((method) => method.toString())
          .toSet();
      final transcriptionModel = id.toLowerCase().contains('transcribe');
      if (forTranscription
          ? !transcriptionModel
          : methods?.contains('generateContent') != true) {
        continue;
      }
      result.add(
        RemoteModelInfo(id: id, label: raw['displayName']?.toString()),
      );
    }
    return result;
  }

  @override
  Future<String> summarize({
    required String systemPrompt,
    required String userPrompt,
    required String modelId,
  }) async {
    final json = await _postJson('/models/$modelId:generateContent', {
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userPrompt},
          ],
        },
      ],
    }, timeout: remoteChatTimeout);
    return _candidateText(json);
  }

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    required String modelId,
    String? languageCode,
  }) async {
    final file = File(audioPath);
    final length = await validateRemoteAudioFile(file);

    final uploaded = await _uploadFile(file, length);
    try {
      await _waitUntilActive(uploaded.name, uploaded.state);
      final json = await _postJson('/interactions', {
        'model': modelId,
        'input': [
          {
            'type': 'audio',
            'uri': uploaded.uri,
            'mime_type': uploaded.mimeType,
          },
        ],
        if (languageCode != null &&
            languageCode.isNotEmpty &&
            languageCode != 'auto')
          'generation_config': {
            'transcription_config': {
              'language_codes': [_geminiLanguageCode(languageCode)],
            },
          },
      }, timeout: remoteTranscribeTimeout);
      final text = _interactionText(json).trim();
      return TranscriptionResult(
        text: text,
        segments: text.isEmpty
            ? const []
            : [TranscriptLine(time: '0:00', text: text)],
      );
    } finally {
      await _deleteFile(uploaded.name);
    }
  }

  Future<_GeminiFile> _uploadFile(File file, int length) async {
    final start = http.Request('POST', Uri.parse(_uploadUrl))
      ..headers.addAll({
        'x-goog-api-key': apiKey,
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': '$length',
        'X-Goog-Upload-Header-Content-Type': _mimeType(file.path),
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'file': {'display_name': 'transcriber-audio'},
      });
    final startResponse = await _send(start, timeout: remoteTranscribeTimeout);
    validateRemoteResponse(
      statusCode: startResponse.statusCode,
      body: startResponse.body,
      errorLabel: 'Gemini upload error',
      secret: apiKey,
    );
    final uploadUri = _header(startResponse.headers, 'x-goog-upload-url');
    if (uploadUri == null || uploadUri.isEmpty) {
      throw const RemoteApiException('Gemini did not return an upload URL.');
    }

    final upload = http.StreamedRequest('POST', Uri.parse(uploadUri))
      ..headers.addAll({
        'x-goog-api-key': apiKey,
        'X-Goog-Upload-Offset': '0',
        'X-Goog-Upload-Command': 'upload, finalize',
        'Content-Type': _mimeType(file.path),
      })
      ..contentLength = length;
    final responseFuture = _send(upload, timeout: remoteTranscribeTimeout);
    await upload.sink.addStream(file.openRead());
    await upload.sink.close();
    final response = await responseFuture;
    validateRemoteResponse(
      statusCode: response.statusCode,
      body: response.body,
      errorLabel: 'Gemini upload error',
      secret: apiKey,
    );
    final json = decodeRemoteJsonObject(
      response.body,
      'Gemini upload response',
    );
    final rawFile = json['file'];
    if (rawFile is! Map) {
      throw const RemoteApiException('Gemini returned no uploaded file.');
    }
    final name = rawFile['name']?.toString() ?? '';
    final uri = rawFile['uri']?.toString() ?? '';
    if (!_isSafeFileName(name) || uri.isEmpty) {
      throw const RemoteApiException('Gemini returned an incomplete file.');
    }
    return _GeminiFile(
      name: name,
      uri: uri,
      mimeType: rawFile['mimeType']?.toString() ?? _mimeType(file.path),
      state: rawFile['state']?.toString(),
    );
  }

  Future<void> _waitUntilActive(String name, String? initialState) async {
    var state = initialState ?? 'PROCESSING';
    final deadline = DateTime.now().add(pollTimeout);
    while (state == 'PROCESSING') {
      if (DateTime.now().isAfter(deadline)) {
        throw const RemoteApiException('Gemini file processing timed out.');
      }
      await _delay(pollInterval);
      final json = await _getJson('/$name', timeout: remoteTranscribeTimeout);
      final wrapped = json['file'];
      state =
          json['state']?.toString() ??
          (wrapped is Map ? wrapped['state']?.toString() : null) ??
          '';
      if (state == 'FAILED') {
        throw const RemoteApiException(
          'Gemini could not process the audio file.',
        );
      }
      if (state.isEmpty) {
        throw const RemoteApiException(
          'Gemini returned an invalid file state.',
        );
      }
    }
    if (state == 'FAILED') {
      throw const RemoteApiException(
        'Gemini could not process the audio file.',
      );
    }
    if (state != 'ACTIVE') {
      throw const RemoteApiException('Gemini returned an invalid file state.');
    }
  }

  Future<void> _deleteFile(String name) async {
    try {
      final response = await _send(
        http.Request('DELETE', Uri.parse('$_baseUrl/$name'))
          ..headers['x-goog-api-key'] = apiKey,
        timeout: remoteListTimeout,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) return;
    } catch (_) {
      // Cleanup must not hide a transcription result or its primary error.
    }
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    required Duration timeout,
  }) async {
    final response = await _send(
      http.Request('GET', Uri.parse('$_baseUrl$path'))
        ..headers['x-goog-api-key'] = apiKey,
      timeout: timeout,
    );
    validateRemoteResponse(
      statusCode: response.statusCode,
      body: response.body,
      errorLabel: 'Gemini error',
      secret: apiKey,
    );
    return decodeRemoteJsonObject(response.body, 'Gemini response');
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    required Duration timeout,
  }) async {
    final response = await _send(
      http.Request('POST', Uri.parse('$_baseUrl$path'))
        ..headers.addAll({
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode(payload),
      timeout: timeout,
    );
    validateRemoteResponse(
      statusCode: response.statusCode,
      body: response.body,
      errorLabel: 'Gemini error',
      secret: apiKey,
    );
    return decodeRemoteJsonObject(response.body, 'Gemini response');
  }

  Future<_RemoteResponse> _send(
    http.BaseRequest request, {
    required Duration timeout,
  }) async {
    final streamed = await guardTimeout(_http.send(request), timeout);
    return _RemoteResponse(
      statusCode: streamed.statusCode,
      headers: streamed.headers,
      body: await readRemoteResponseBody(streamed),
    );
  }

  String _candidateText(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) return '';
    final content = candidates.first is Map
        ? (candidates.first as Map)['content']
        : null;
    final parts = content is Map ? content['parts'] : null;
    if (parts is! List) return '';
    return parts
        .whereType<Map>()
        .map((part) => part['text'])
        .whereType<String>()
        .join()
        .trim();
  }

  String _interactionText(Map<String, dynamic> json) {
    if (json['status']?.toString().toLowerCase() != 'completed') {
      throw const RemoteApiException(
        'Gemini did not complete the transcription.',
      );
    }
    final steps = json['steps'];
    if (steps is! List) {
      throw const RemoteApiException(
        'Gemini returned an invalid transcription.',
      );
    }
    final buffer = StringBuffer();
    for (final step in steps.whereType<Map>()) {
      final content = step['content'];
      if (content is! List) continue;
      for (final item in content.whereType<Map>()) {
        if (item['type'] == 'text' && item['text'] is String) {
          buffer.write(item['text']);
        }
      }
    }
    final result = buffer.toString();
    if (result.trim().isEmpty) {
      throw const RemoteApiException('Gemini returned an empty transcription.');
    }
    return result;
  }

  String? _header(Map<String, String> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value;
    }
    return null;
  }

  bool _isSafeFileName(String name) {
    return RegExp(r'^files/[A-Za-z0-9_-]+$').hasMatch(name);
  }

  String _mimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.mpeg') ||
        lower.endsWith('.mpga')) {
      return 'audio/mpeg';
    }
    if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'audio/mp4';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.webm')) return 'audio/webm';
    return 'application/octet-stream';
  }

  String _geminiLanguageCode(String code) => switch (code) {
    'de' => 'de-DE',
    'en' => 'en-US',
    _ => code,
  };
}

final class _GeminiFile {
  const _GeminiFile({
    required this.name,
    required this.uri,
    required this.mimeType,
    this.state,
  });

  final String name;
  final String uri;
  final String mimeType;
  final String? state;
}

final class _RemoteResponse {
  const _RemoteResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
}
