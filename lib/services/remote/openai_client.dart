import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/models/transcript_note.dart';
import '../../data/models/transcription_result.dart';
import 'remote_api_client.dart';
import 'remote_http.dart';

/// Direct REST client for OpenAI's chat and transcription endpoints.
class OpenAiClient implements RemoteProviderClient {
  OpenAiClient({required this.apiKey, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _http;

  static const _baseUrl = 'https://api.openai.com/v1';
  @override
  Future<void> testConnection() async {
    await _getJson('/models', timeout: remoteListTimeout);
  }

  @override
  Future<List<RemoteModelInfo>> listModels({
    required bool forTranscription,
  }) async {
    final json = await _getJson('/models', timeout: remoteListTimeout);
    final data = json['data'];
    if (data is! List) return const [];
    final ids =
        data
            .whereType<Map>()
            .map((model) => model['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .where(
              (id) => forTranscription
                  ? _isTranscriptionModel(id)
                  : _isSummaryModel(id),
            )
            .toList()
          ..sort();
    return ids.map((id) => RemoteModelInfo(id: id)).toList();
  }

  @override
  Future<String> summarize({
    required String systemPrompt,
    required String userPrompt,
    required String modelId,
  }) async {
    final json = await _postJson('/chat/completions', {
      'model': modelId,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
    }, timeout: remoteChatTimeout);
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return '';
    }
    final message = (choices.first as Map)['message'];
    return message is Map ? (message['content'] as String? ?? '').trim() : '';
  }

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    required String modelId,
    String? languageCode,
  }) async {
    final file = File(audioPath);
    await validateRemoteAudioFile(file);

    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_baseUrl/audio/transcriptions'),
          )
          ..headers['Authorization'] = 'Bearer $apiKey'
          ..fields['model'] = modelId
          ..fields['response_format'] = 'json';
    if (languageCode != null &&
        languageCode.isNotEmpty &&
        languageCode != 'auto') {
      request.fields['language'] = languageCode;
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        audioPath,
        filename: audioPath.split(Platform.pathSeparator).last,
      ),
    );

    final response = await guardTimeout(
      _http.send(request),
      remoteTranscribeTimeout,
    );
    final body = await readRemoteResponseBody(response);
    validateRemoteResponse(
      statusCode: response.statusCode,
      body: body,
      errorLabel: 'OpenAI transcription error',
      secret: apiKey,
      preferScalarError: true,
    );
    final json = decodeRemoteJsonObject(body, 'OpenAI transcription response');
    final text = (json['text'] as String? ?? '').trim();
    return TranscriptionResult(
      text: text,
      segments: text.isEmpty
          ? const []
          : [TranscriptLine(time: '0:00', text: text)],
    );
  }

  bool _isTranscriptionModel(String id) {
    return id.toLowerCase().contains('transcribe');
  }

  bool _isSummaryModel(String id) {
    final lower = id.toLowerCase();
    const excluded = [
      'embed',
      'whisper',
      'transcribe',
      'tts',
      'audio',
      'realtime',
      'image',
      'moderation',
      'dall',
    ];
    return !excluded.any(lower.contains);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    required Duration timeout,
  }) async {
    return _requestJson(
      _http.send(
        http.Request('GET', Uri.parse('$_baseUrl$path'))
          ..headers['Authorization'] = 'Bearer $apiKey',
      ),
      timeout,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    required Duration timeout,
  }) async {
    return _requestJson(
      _http.send(
        http.Request('POST', Uri.parse('$_baseUrl$path'))
          ..headers.addAll({
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          })
          ..body = jsonEncode(payload),
      ),
      timeout,
    );
  }

  Future<Map<String, dynamic>> _requestJson(
    Future<http.StreamedResponse> request,
    Duration timeout,
  ) async {
    final response = await guardTimeout(request, timeout);
    final body = await readRemoteResponseBody(response);
    validateRemoteResponse(
      statusCode: response.statusCode,
      body: body,
      errorLabel: 'OpenAI error',
      secret: apiKey,
      preferScalarError: true,
    );
    return decodeRemoteJsonObject(body, 'OpenAI response');
  }
}
