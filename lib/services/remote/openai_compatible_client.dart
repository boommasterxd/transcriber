import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/formatting.dart';
import '../../data/models/transcript_note.dart';
import '../service_exceptions.dart';
import '../transcription/transcription_service.dart';
import 'remote_api_client.dart';

/// Base client for OpenAI-style `/chat/completions` APIs. Reused by OpenAI and
/// OpenRouter (which is wire-compatible).
abstract class OpenAiCompatibleClient implements RemoteApiClient {
  OpenAiCompatibleClient({required this.apiKey, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _http;

  String get baseUrl;
  Map<String, String> get extraHeaders => const {};

  @override
  Future<String> chat({
    required String system,
    required String user,
    required String modelId,
  }) async {
    final response = await _http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        ...extraHeaders,
      },
      body: jsonEncode({
        'model': modelId,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': user},
        ],
      }),
    );
    if (response.statusCode != 200) {
      throw RemoteApiException(
        'API-Fehler (${response.statusCode}): ${_errorBody(response.body)}',
        statusCode: response.statusCode,
      );
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    final message = (choices.first as Map)['message'] as Map?;
    return (message?['content'] as String?)?.trim() ?? '';
  }

  /// Shared OpenAI Whisper / gpt-4o-transcribe implementation. Subclasses that
  /// support transcription delegate here.
  Future<TranscriptionResult> transcribeOpenAi(
    String audioPath, {
    String? languageCode,
    required String model,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/audio/transcriptions'))
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..fields['model'] = model
      ..fields['response_format'] = 'verbose_json';
    if (languageCode != null && languageCode.isNotEmpty && languageCode != 'auto') {
      request.fields['language'] = languageCode;
    }
    request.files.add(await http.MultipartFile.fromPath('file', audioPath));

    final streamed = await _http.send(request);
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      throw RemoteApiException(
        'Transkriptions-Fehler (${streamed.statusCode}): ${_errorBody(body)}',
        statusCode: streamed.statusCode,
      );
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final text = (json['text'] as String?)?.trim() ?? '';
    final segments = <TranscriptLine>[];
    final rawSegments = json['segments'] as List?;
    if (rawSegments != null) {
      for (final seg in rawSegments) {
        final m = seg as Map;
        final start = (m['start'] as num?)?.round() ?? 0;
        final segText = (m['text'] as String?)?.trim() ?? '';
        if (segText.isNotEmpty) {
          segments.add(TranscriptLine(time: formatDuration(start), text: segText));
        }
      }
    }
    if (segments.isEmpty && text.isNotEmpty) {
      segments.add(TranscriptLine(time: '0:00', text: text));
    }
    return TranscriptionResult(text: text, segments: segments);
  }

  String _errorBody(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map) return error['message']?.toString() ?? body;
      return error?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}
