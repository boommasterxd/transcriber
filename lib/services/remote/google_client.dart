import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/models/transcript_note.dart';
import '../../data/models/transcription_result.dart';
import '../service_exceptions.dart';
import 'gemini_upload_uri.dart';
import 'gemini_uploaded_file_cleanup.dart';
import 'mime_utils.dart';
import 'model_catalog_listing.dart';
import 'provider_model_capabilities.dart';
import 'remote_api_client.dart';
import 'remote_http.dart';
import 'transcription_prompt.dart';

/// Direct REST client for Gemini generation, files, and interactions APIs.
class GoogleClient with ModelCatalogListing implements RemoteProviderClient {
  GoogleClient({
    required this.apiKey,
    http.Client? httpClient,
    this.pollInterval = const Duration(seconds: 2),
    this.pollTimeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null;

  final String apiKey;
  final http.Client _http;
  final bool _ownsHttp;
  late final _fileCleanup = GeminiUploadedFileCleanup(_http);
  bool _closed = false;
  final Duration pollInterval;
  final Duration pollTimeout;

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsHttp) _fileCleanup.closeWhenIdle();
  }

  static const _apiHost = 'generativelanguage.googleapis.com';
  static const _baseUrl = 'https://$_apiHost/v1beta';
  static const _uploadUrl = 'https://$_apiHost/upload/v1beta/files';
  static const _modelPageSize = 1000;
  static const _maxModelPages = 10;
  @override
  Future<void> testConnection() async {
    await _getJson('/models?pageSize=1', timeout: remoteListTimeout);
  }

  @override
  Future<ProviderModelCatalog> loadModelCatalog() =>
      ProviderModelCatalog.loadGooglePages(_modelCatalogPages());

  @override
  Future<String> summarize({
    required String systemPrompt,
    required String userPrompt,
    required String modelId,
    RemoteCancellation? cancellation,
  }) async {
    if (!ProviderModelCapabilities.isGeminiSummaryModel(modelId, const {
      'generateContent',
    })) {
      throw const RemoteApiException(
        'The selected Gemini model does not support text summaries.',
      );
    }
    final json = await _postJson(
      '/models/$modelId:generateContent',
      {
        'store': false,
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
      },
      timeout: remoteChatTimeout,
      cancellation: cancellation,
    );
    final candidates = json['candidates'];
    if (candidates is List &&
        candidates.isNotEmpty &&
        candidates.first is Map &&
        (candidates.first as Map)['finishReason'] == 'MAX_TOKENS') {
      throw const RemoteApiException(
        'Gemini summary exceeded its response token limit.',
      );
    }
    return _candidateText(json);
  }

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    required String modelId,
    String? languageCode,
    RemoteCancellation? cancellation,
  }) async {
    if (!ProviderModelCapabilities.isGeminiTranscriptionModel(modelId, const {
      'generateContent',
    })) {
      throw const RemoteApiException(
        'The selected Gemini model does not support audio transcription.',
      );
    }

    final file = File(audioPath);
    final length = await validateRemoteAudioFile(
      file,
      cancellation: cancellation,
    );
    cancellation?.throwIfCancelled();
    if (_closed) throw StateError('The Gemini client is closed.');
    _fileCleanup.reserve();
    String? uploadedName;
    try {
      final uploaded = await _uploadFile(file, length, cancellation);
      uploadedName = uploaded.name;
      if (uploaded.uri.isEmpty) {
        throw const RemoteApiException('Gemini returned an incomplete file.');
      }
      await _waitUntilActive(uploaded.name, uploaded.state, cancellation);
      final nativeTranscription =
          ProviderModelCapabilities.usesGeminiNativeTranscription(modelId);
      final json = await _postJson(
        '/interactions',
        {
          'model': modelId,
          'store': false,
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
        },
        timeout: remoteTranscribeTimeout,
        cancellation: cancellation,
      );
      final text = _interactionText(json).trim();
      return TranscriptionResult(
        text: text,
        segments: text.isEmpty ? const [] : [TranscriptLine(text: text)],
      );
    } finally {
      _fileCleanup.finish(_deleteRequest(uploadedName));
    }
  }

  Stream<Iterable<Map>> _modelCatalogPages() async* {
    final seenTokens = <String>{};
    String? pageToken;
    for (var page = 0; page < _maxModelPages; page++) {
      final query = <String, String>{'pageSize': '$_modelPageSize'};
      if (pageToken != null) query['pageToken'] = pageToken;
      final path = Uri(path: '/models', queryParameters: query).toString();
      final json = await _getJson(path, timeout: remoteListTimeout);
      final pageModels = json['models'];
      if (pageModels is List) yield pageModels.whereType<Map>();

      final next = json['nextPageToken'];
      if (next == null || next == '') return;
      if (next is! String || next.length > 2048 || !seenTokens.add(next)) {
        throw const RemoteApiException(
          'Gemini returned invalid model pagination.',
        );
      }
      pageToken = next;
    }
    throw const RemoteApiException('Gemini returned too many model pages.');
  }

  Future<_GeminiFile> _uploadFile(
    File file,
    int length,
    RemoteCancellation? cancellation,
  ) async {
    final mimeType = audioMimeType(file.path);
    final start = http.Request('POST', Uri.parse(_uploadUrl))
      ..headers.addAll({
        'x-goog-api-key': apiKey,
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': '$length',
        'X-Goog-Upload-Header-Content-Type': mimeType,
        'Content-Type': 'application/json',
      })
      ..body = jsonEncode({
        'file': {'display_name': 'transcriber-audio'},
      });
    final startResponse = await _send(
      start,
      timeout: remoteTranscribeTimeout,
      cancellation: cancellation,
    );
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

    final upload =
        _AudioUploadRequest(
            validateGeminiUploadUri(uploadUri, _apiHost, apiKey),
            file,
          )
          ..headers.addAll({
            'X-Goog-Upload-Offset': '0',
            'X-Goog-Upload-Command': 'upload, finalize',
            'Content-Type': mimeType,
          })
          ..contentLength = length;
    final response = await _sendFileBytes(upload, cancellation);
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
    if (!_isSafeFileName(name)) {
      throw const RemoteApiException('Gemini returned an incomplete file.');
    }
    return _GeminiFile(
      name: name,
      uri: uri,
      mimeType: rawFile['mimeType']?.toString() ?? mimeType,
      state: rawFile['state']?.toString(),
    );
  }

  Future<RemoteHttpResponse> _sendFileBytes(
    _AudioUploadRequest upload,
    RemoteCancellation? cancellation,
  ) async {
    try {
      final response = await _send(
        upload,
        timeout: remoteTranscribeTimeout,
        cancellation: cancellation,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      throw RemoteApiException(
        'Gemini upload error (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    } on http.ClientException {
      throw const RemoteApiException('Gemini could not upload the audio file.');
    }
  }

  Future<void> _waitUntilActive(
    String name,
    String? initialState,
    RemoteCancellation? cancellation,
  ) async {
    var state = initialState ?? 'PROCESSING';
    final stopwatch = Stopwatch()..start();
    while (state == 'PROCESSING') {
      var remaining = _remainingPollTime(stopwatch);
      await waitForRemotePoll(
        pollInterval < remaining ? pollInterval : remaining,
        cancellation,
      );
      remaining = _remainingPollTime(stopwatch);
      final json = await _getJson(
        '/$name',
        timeout: remaining,
        cancellation: cancellation,
      );
      _remainingPollTime(stopwatch);
      final wrapped = json['file'];
      state =
          json['state']?.toString() ??
          (wrapped is Map ? wrapped['state']?.toString() : null) ??
          '';
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

  Duration _remainingPollTime(Stopwatch stopwatch) {
    final remaining = pollTimeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw const RemoteApiException('Gemini file processing timed out.');
    }
    return remaining;
  }

  http.Request? _deleteRequest(String? name) => name == null
      ? null
      : (http.Request('DELETE', Uri.parse('$_baseUrl/$name'))
          ..followRedirects = false
          ..headers['x-goog-api-key'] = apiKey);

  Future<Map<String, dynamic>> _getJson(
    String path, {
    required Duration timeout,
    RemoteCancellation? cancellation,
  }) async {
    final response = await _send(
      http.Request('GET', Uri.parse('$_baseUrl$path'))
        ..headers['x-goog-api-key'] = apiKey,
      timeout: timeout,
      cancellation: cancellation,
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
    RemoteCancellation? cancellation,
  }) async {
    final response = await _send(
      http.Request('POST', Uri.parse('$_baseUrl$path'))
        ..headers.addAll({
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode(payload),
      timeout: timeout,
      cancellation: cancellation,
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
    RemoteCancellation? cancellation,
  }) => sendRemoteRequest(
    _http,
    request..followRedirects = false,
    timeout: timeout,
    cancellation: cancellation,
  );

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

/// Finalizes directly from disk so transport abort also cancels the file read.
final class _AudioUploadRequest extends http.BaseRequest {
  _AudioUploadRequest(Uri uri, this.file) : super('POST', uri);

  final File file;

  @override
  http.ByteStream finalize() {
    super.finalize();
    return http.ByteStream(file.openRead());
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
