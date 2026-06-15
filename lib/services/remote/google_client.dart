import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/models/transcript_note.dart';
import '../service_exceptions.dart';
import '../transcription/transcription_service.dart';
import 'mime_utils.dart';
import 'remote_api_client.dart';

/// Google Gemini client. Chat via `generateContent`; transcription by sending
/// the audio inline to a multimodal Gemini model.
class GoogleClient implements RemoteApiClient {
  GoogleClient({required this.apiKey, this.transcribeModelId = 'gemini-2.5-flash', http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final String apiKey;
  final String transcribeModelId;
  final http.Client _http;

  static const _base = 'https://generativelanguage.googleapis.com/v1beta/models';

  @override
  bool get supportsAudioTranscription => true;

  @override
  String get asrLabel => transcribeModelId;

  @override
  Future<String> chat({
    required String system,
    required String user,
    required String modelId,
  }) async {
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': user},
          ],
        },
      ],
    };
    return _generateContent(modelId, body);
  }

  @override
  Future<TranscriptionResult> transcribe(String audioPath, {String? languageCode}) async {
    final bytes = await File(audioPath).readAsBytes();
    final prompt = languageCode == null || languageCode.isEmpty || languageCode == 'auto'
        ? 'Transcribe this audio verbatim. Return only the transcript text.'
        : 'Transcribe this audio verbatim in language "$languageCode". Return only the transcript text.';
    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inline_data': {'mime_type': audioMimeType(audioPath), 'data': base64Encode(bytes)},
            },
          ],
        },
      ],
    };
    final text = (await _generateContent(transcribeModelId, body)).trim();
    return TranscriptionResult(
      text: text,
      segments: text.isEmpty ? const [] : [TranscriptLine(time: '0:00', text: text)],
    );
  }

  Future<String> _generateContent(String modelId, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_base/$modelId:generateContent?key=$apiKey');
    final response = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) {
      throw RemoteApiException(
        'Google-Fehler (${response.statusCode}): ${_errorBody(response.body)}',
        statusCode: response.statusCode,
      );
    }
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) return '';
    final parts = ((candidates.first as Map)['content'] as Map?)?['parts'] as List?;
    if (parts == null) return '';
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] is String) buffer.write(part['text']);
    }
    return buffer.toString().trim();
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
