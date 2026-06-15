import 'dart:convert';

import 'package:http/http.dart' as http;

import '../service_exceptions.dart';
import '../transcription/transcription_service.dart';
import 'remote_api_client.dart';

/// Anthropic Messages API client. Anthropic has no audio/ASR endpoint, so
/// transcription must use OpenAI/Google or an on-device model.
class AnthropicClient implements RemoteApiClient {
  AnthropicClient({required this.apiKey, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _http;

  static const _version = '2023-06-01';
  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  @override
  bool get supportsAudioTranscription => false;

  @override
  Future<List<RemoteModelInfo>> listModels({required bool forTranscription}) async {
    if (forTranscription) return const []; // Anthropic has no ASR models.
    final response = await _http.get(
      Uri.parse('https://api.anthropic.com/v1/models?limit=100'),
      headers: {'x-api-key': apiKey, 'anthropic-version': _version},
    );
    if (response.statusCode != 200) {
      throw RemoteApiException(
        'Modell-Liste fehlgeschlagen (${response.statusCode}): ${_errorBody(response.body)}',
        statusCode: response.statusCode,
      );
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final data = json['data'] as List? ?? const [];
    return data
        .map((e) => e as Map)
        .map((m) => RemoteModelInfo(id: m['id'].toString(), label: m['display_name']?.toString()))
        .toList();
  }

  @override
  Future<String> chat({
    required String system,
    required String user,
    required String modelId,
  }) async {
    final response = await _http.post(
      Uri.parse(_endpoint),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': _version,
        'content-type': 'application/json',
      },
      body: jsonEncode({
        'model': modelId,
        'max_tokens': 1024,
        'system': system,
        'messages': [
          {'role': 'user', 'content': user},
        ],
      }),
    );
    if (response.statusCode != 200) {
      throw RemoteApiException(
        'Anthropic-Fehler (${response.statusCode}): ${_errorBody(response.body)}',
        statusCode: response.statusCode,
      );
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final content = json['content'] as List?;
    if (content == null || content.isEmpty) return '';
    final buffer = StringBuffer();
    for (final block in content) {
      if (block is Map && block['type'] == 'text') buffer.write(block['text'] ?? '');
    }
    return buffer.toString().trim();
  }

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    String? languageCode,
    required String model,
  }) {
    throw UnsupportedError('Anthropic bietet keine native Transkription.');
  }

  String _errorBody(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map) return error['message']?.toString() ?? body;
      return body;
    } catch (_) {
      return body;
    }
  }
}
