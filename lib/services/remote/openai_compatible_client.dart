import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/utils/formatting.dart';
import '../../data/models/transcript_note.dart';
import '../../data/models/transcription_result.dart';
import 'remote_api_client.dart';
import 'remote_http.dart';

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
    final response = await guardTimeout(
      _http.post(
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
      ),
      remoteChatTimeout,
    );
    validateRemoteResponse(
      statusCode: response.statusCode,
      body: response.body,
      errorLabel: 'API error',
      preferScalarError: true,
    );
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    if (choices == null || choices.isEmpty) return '';
    final message = (choices.first as Map)['message'] as Map?;
    return (message?['content'] as String?)?.trim() ?? '';
  }

  @override
  Future<List<RemoteModelInfo>> listModels({
    required bool forTranscription,
  }) async {
    final response = await guardTimeout(
      _http.get(
        Uri.parse('$baseUrl/models'),
        headers: {'Authorization': 'Bearer $apiKey', ...extraHeaders},
      ),
      remoteListTimeout,
    );
    validateRemoteResponse(
      statusCode: response.statusCode,
      body: response.body,
      errorLabel: 'Failed to fetch model list',
      preferScalarError: true,
    );
    final json =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final data = json['data'] as List? ?? const [];
    final ids =
        data
            .map((e) => (e as Map)['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .where(
              (id) => forTranscription
                  ? _isTranscriptionModel(id)
                  : _isChatModel(id),
            )
            .toList()
          ..sort();
    return ids.map((id) => RemoteModelInfo(id: id)).toList();
  }

  bool _isTranscriptionModel(String id) {
    final l = id.toLowerCase();
    return l.contains('transcribe') || l.contains('whisper');
  }

  bool _isChatModel(String id) {
    final l = id.toLowerCase();
    const blocked = [
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
    return !blocked.any(l.contains);
  }

  /// Shared OpenAI Whisper / gpt-4o-transcribe implementation. Subclasses that
  /// support transcription delegate here.
  Future<TranscriptionResult> transcribeOpenAi(
    String audioPath, {
    String? languageCode,
    required String model,
  }) async {
    // Only Whisper supports `verbose_json` (with timestamped segments). The
    // newer gpt-4o-transcribe models reject it — request plain `json` there and
    // fall back to a single segment from the full text below.
    final wantsSegments = model.toLowerCase().contains('whisper');
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$baseUrl/audio/transcriptions'),
          )
          ..headers['Authorization'] = 'Bearer $apiKey'
          ..fields['model'] = model
          ..fields['response_format'] = wantsSegments ? 'verbose_json' : 'json';
    if (languageCode != null &&
        languageCode.isNotEmpty &&
        languageCode != 'auto') {
      request.fields['language'] = languageCode;
    }
    request.files.add(await http.MultipartFile.fromPath('file', audioPath));

    final streamed = await guardTimeout(
      _http.send(request),
      remoteTranscribeTimeout,
    );
    final body = await streamed.stream.bytesToString();
    validateRemoteResponse(
      statusCode: streamed.statusCode,
      body: body,
      errorLabel: 'Transcription error',
      preferScalarError: true,
    );
    final json = jsonDecode(body) as Map<String, dynamic>;
    final text = (json['text'] as String?)?.trim() ?? '';
    final segments = _transcriptSegments(json['segments'] as List?);
    if (segments.isEmpty && text.isNotEmpty) {
      segments.add(TranscriptLine(time: '0:00', text: text));
    }
    return TranscriptionResult(text: text, segments: segments);
  }

  List<TranscriptLine> _transcriptSegments(List<dynamic>? rawSegments) {
    if (rawSegments == null) return [];
    final segments = <TranscriptLine>[];
    for (final segment in rawSegments) {
      final map = segment as Map;
      final text = (map['text'] as String?)?.trim() ?? '';
      if (text.isEmpty) continue;
      final start = (map['start'] as num?)?.round() ?? 0;
      segments.add(TranscriptLine(time: formatDuration(start), text: text));
    }
    return segments;
  }
}
