import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/models/transcript_note.dart';
import '../../data/models/transcription_result.dart';
import '../service_exceptions.dart';
import 'mime_utils.dart';
import 'provider_model_capabilities.dart';
import 'remote_api_client.dart';
import 'remote_http.dart';
import 'transcription_prompt.dart';

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
  static const _modelPageSize = 1000;
  static const _maxModelPages = 10;
  @override
  Future<void> testConnection() async {
    await _getJson('/models?pageSize=1', timeout: remoteListTimeout);
  }

  @override
  Future<List<RemoteModelInfo>> listModels({
    required bool forTranscription,
  }) async {
    final models = await _listModelCatalog();
    final result = <String, RemoteModelInfo>{};
    for (final raw in models) {
      final id = (raw['name']?.toString() ?? '').replaceFirst('models/', '');
      if (!id.toLowerCase().startsWith('gemini-')) continue;
      final methods =
          (raw['supportedGenerationMethods'] as List?)
              ?.map((method) => method.toString())
              .toSet() ??
          const <String>{};
      final transcriptionModel =
          ProviderModelCapabilities.isGeminiTranscriptionModel(id, methods);
      if (forTranscription
          ? !transcriptionModel
          : !methods.contains('generateContent')) {
        continue;
      }
      result.putIfAbsent(
        id,
        () => RemoteModelInfo(id: id, label: raw['displayName']?.toString()),
      );
    }
    final sorted = result.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return sorted;
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
      'generationConfig': {
        'responseMimeType': 'application/json',
        'maxOutputTokens': 1024,
        if (_supportsThinkingLevel(modelId))
          'thinkingConfig': {'thinkingLevel': 'LOW'},
      },
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
      final nativeTranscription =
          ProviderModelCapabilities.usesGeminiNativeTranscription(modelId);
      final json = await _postJson('/interactions', {
        'model': modelId,
        'input': [
          if (!nativeTranscription)
            {'type': 'text', 'text': buildTranscriptionPrompt(languageCode)},
          {
            'type': 'audio',
            'uri': uploaded.uri,
            'mime_type': uploaded.mimeType,
          },
        ],
        if (nativeTranscription)
          'generation_config': {
            'transcription_config': {
              'mode': {'type': 'smart'},
              if (languageCode != null &&
                  languageCode.isNotEmpty &&
                  languageCode != 'auto')
                'language_codes': [_geminiLanguageCode(languageCode)],
            },
          },
      }, timeout: remoteTranscribeTimeout);
      final text = _interactionText(json).trim();
      return TranscriptionResult(
        text: text,
        segments: text.isEmpty ? const [] : [TranscriptLine(text: text)],
      );
    } finally {
      await _deleteFile(uploaded.name);
    }
  }

  Future<List<Map>> _listModelCatalog() async {
    final models = <Map>[];
    final seenTokens = <String>{};
    String? pageToken;
    for (var page = 0; page < _maxModelPages; page++) {
      final query = <String, String>{'pageSize': '$_modelPageSize'};
      if (pageToken != null) query['pageToken'] = pageToken;
      final path = Uri(path: '/models', queryParameters: query).toString();
      final json = await _getJson(path, timeout: remoteListTimeout);
      final pageModels = json['models'];
      if (pageModels is List) models.addAll(pageModels.whereType<Map>());

      final next = json['nextPageToken']?.toString();
      if (next == null || next.isEmpty) return models;
      if (next.length > 2048 || !seenTokens.add(next)) {
        throw const RemoteApiException(
          'Gemini returned invalid model pagination.',
        );
      }
      pageToken = next;
    }
    throw const RemoteApiException('Gemini returned too many model pages.');
  }

  Future<_GeminiFile> _uploadFile(File file, int length) async {
    final start = http.Request('POST', Uri.parse(_uploadUrl))
      ..headers.addAll({
        'x-goog-api-key': apiKey,
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': '$length',
        'X-Goog-Upload-Header-Content-Type': audioMimeType(file.path),
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
        'Content-Type': audioMimeType(file.path),
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
      mimeType: rawFile['mimeType']?.toString() ?? audioMimeType(file.path),
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

  Future<RemoteHttpResponse> _send(
    http.BaseRequest request, {
    required Duration timeout,
  }) => sendRemoteRequest(_http, request, timeout: timeout);

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

  String _geminiLanguageCode(String code) => switch (code) {
    'de' => 'de-DE',
    'en' => 'en-US',
    _ => code,
  };

  bool _supportsThinkingLevel(String modelId) {
    final match = RegExp(r'^gemini-(\d+)').firstMatch(modelId.toLowerCase());
    final major = match == null ? null : int.tryParse(match.group(1)!);
    return major != null && major >= 3;
  }
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
