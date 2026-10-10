import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../data/models/transcript_note.dart';
import '../../data/models/transcription_result.dart';
import '../service_exceptions.dart';
import 'provider_model_capabilities.dart';
import 'remote_api_client.dart';
import 'remote_http.dart';
import 'transcription_prompt.dart';

/// Direct REST client for OpenAI's chat and transcription endpoints.
class OpenAiClient implements RemoteProviderClient {
  OpenAiClient({required this.apiKey, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _http;

  static const _baseUrl = 'https://api.openai.com/v1';
  static const _maxInlineAudioBytes = 20 * 1024 * 1024;
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
            .map((model) => model['id'])
            .whereType<String>()
            .where(
              (id) => forTranscription
                  ? ProviderModelCapabilities.isOpenAiTranscriptionModel(id)
                  : ProviderModelCapabilities.isOpenAiSummaryModel(id),
            )
            .toSet()
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
    if (!ProviderModelCapabilities.isOpenAiSummaryModel(modelId)) {
      throw const RemoteApiException(
        'The selected OpenAI model does not support text summaries.',
      );
    }
    final json = await _postJson('/chat/completions', {
      'model': modelId,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
    }, timeout: remoteChatTimeout);
    return _messageText(json).trim();
  }

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    required String modelId,
    String? languageCode,
  }) async {
    final file = File(audioPath);
    final length = await validateRemoteAudioFile(file);

    if (ProviderModelCapabilities.usesOpenAiAudioChat(modelId)) {
      return _transcribeWithAudioChat(
        file,
        length: length,
        modelId: modelId,
        languageCode: languageCode,
      );
    }
    if (!ProviderModelCapabilities.usesOpenAiTranscriptionEndpoint(modelId)) {
      throw const RemoteApiException(
        'The selected OpenAI model does not support audio transcription.',
      );
    }
    return _transcribeWithAudioEndpoint(
      audioPath,
      modelId: modelId,
      languageCode: languageCode,
    );
  }

  Future<TranscriptionResult> _transcribeWithAudioEndpoint(
    String audioPath, {
    required String modelId,
    String? languageCode,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_baseUrl/audio/transcriptions'),
          )
          ..headers['Authorization'] = 'Bearer $apiKey'
          ..fields['model'] = modelId
          ..fields['response_format'] = 'json';
    if (RegExp(r'(?:^|[._-])diarize(?:$|[._-])').hasMatch(modelId)) {
      request.fields['chunking_strategy'] = 'auto';
    }
    if (languageCode != null &&
        languageCode.isNotEmpty &&
        languageCode != 'auto') {
      request.fields['language'] = languageCode;
    }
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        audioPath,
        filename: _openAiUploadFileName(audioPath),
        contentType: _openAiUploadContentType(audioPath),
      ),
    );

    final response = await sendRemoteRequest(
      _http,
      request,
      timeout: remoteTranscribeTimeout,
    );
    validateRemoteResponse(
      statusCode: response.statusCode,
      body: response.body,
      errorLabel: 'OpenAI transcription error',
      secret: apiKey,
      preferScalarError: true,
    );
    final json = decodeRemoteJsonObject(
      response.body,
      'OpenAI transcription response',
    );
    final text = (json['text'] as String? ?? '').trim();
    return _transcriptionResult(text);
  }

  String _openAiUploadFileName(String path) {
    final fileName = path.split(Platform.pathSeparator).last;
    if (!fileName.toLowerCase().endsWith('.opus')) return fileName;
    return '${fileName.substring(0, fileName.length - 5)}.ogg';
  }

  http.MediaType? _openAiUploadContentType(String path) {
    return path.toLowerCase().endsWith('.opus')
        ? http.MediaType('audio', 'ogg')
        : null;
  }

  Future<TranscriptionResult> _transcribeWithAudioChat(
    File file, {
    required int length,
    required String modelId,
    String? languageCode,
  }) async {
    final format = _inlineAudioFormat(file.path);
    if (format == null) {
      throw const RemoteApiException(
        'This OpenAI multimodal model requires WAV or MP3 audio.',
      );
    }
    if (length > _maxInlineAudioBytes) {
      throw const RemoteApiException(
        'This OpenAI multimodal model requires audio up to 20 MiB.',
      );
    }
    final json = await _postJson('/chat/completions', {
      'model': modelId,
      'modalities': ['text'],
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': buildTranscriptionPrompt(languageCode)},
            {
              'type': 'input_audio',
              'input_audio': {
                'data': base64Encode(await file.readAsBytes()),
                'format': format,
              },
            },
          ],
        },
      ],
    }, timeout: remoteTranscribeTimeout);
    return _transcriptionResult(_messageText(json));
  }

  TranscriptionResult _transcriptionResult(String rawText) {
    final text = rawText.trim();
    return TranscriptionResult(
      text: text,
      segments: text.isEmpty ? const [] : [TranscriptLine(text: text)],
    );
  }

  String _messageText(Map<String, dynamic> json) {
    final choices = json['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) return '';
    final message = (choices.first as Map)['message'];
    return message is Map ? (message['content'] as String? ?? '') : '';
  }

  String? _inlineAudioFormat(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'wav';
    if (lower.endsWith('.mp3')) return 'mp3';
    return null;
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    required Duration timeout,
  }) async {
    return _requestJson(
      http.Request('GET', Uri.parse('$_baseUrl$path'))
        ..headers['Authorization'] = 'Bearer $apiKey',
      timeout,
    );
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    required Duration timeout,
  }) async {
    return _requestJson(
      http.Request('POST', Uri.parse('$_baseUrl$path'))
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode(payload),
      timeout,
    );
  }

  Future<Map<String, dynamic>> _requestJson(
    http.BaseRequest request,
    Duration timeout,
  ) async {
    final response = await sendRemoteRequest(_http, request, timeout: timeout);
    validateRemoteResponse(
      statusCode: response.statusCode,
      body: response.body,
      errorLabel: 'OpenAI error',
      secret: apiKey,
      preferScalarError: true,
    );
    return decodeRemoteJsonObject(response.body, 'OpenAI response');
  }
}
