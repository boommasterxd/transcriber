import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../data/models/transcript_note.dart';
import '../../data/models/transcription_result.dart';
import '../service_exceptions.dart';
import 'mime_utils.dart';
import 'model_catalog_listing.dart';
import 'provider_model_capabilities.dart';
import 'remote_audio_limits.dart';
import 'remote_api_client.dart';
import 'remote_http.dart';
import 'transcription_prompt.dart';

/// Direct REST client for OpenAI's chat and transcription endpoints.
class OpenAiClient with ModelCatalogListing implements RemoteProviderClient {
  OpenAiClient({required this.apiKey, http.Client? httpClient})
    : _http = httpClient ?? http.Client(),
      _ownsHttp = httpClient == null;

  final String apiKey;
  final http.Client _http;
  final bool _ownsHttp;
  bool _closed = false;

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsHttp) _http.close();
  }

  static const _baseUrl = 'https://api.openai.com/v1';
  @override
  Future<void> testConnection() async {
    await _getJson('/models', timeout: remoteListTimeout);
  }

  @override
  Future<ProviderModelCatalog> loadModelCatalog() async {
    final json = await _getJson('/models', timeout: remoteListTimeout);
    final data = json['data'];
    return ProviderModelCatalog.openAi(
      data is List ? data.whereType<Map>() : const [],
    );
  }

  @override
  Future<String> summarize({
    required String systemPrompt,
    required String userPrompt,
    required String modelId,
    RemoteCancellation? cancellation,
  }) async {
    if (!ProviderModelCapabilities.isOpenAiSummaryModel(modelId)) {
      throw const RemoteApiException(
        'The selected OpenAI model does not support text summaries.',
      );
    }
    final json = await _postJson(
      '/chat/completions',
      {
        'model': modelId,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
      },
      timeout: remoteChatTimeout,
      cancellation: cancellation,
    );
    return _messageText(json).trim();
  }

  @override
  Future<TranscriptionResult> transcribe(
    String audioPath, {
    required String modelId,
    String? languageCode,
    RemoteCancellation? cancellation,
  }) async {
    final file = File(audioPath);
    final length = await validateRemoteAudioFile(
      file,
      cancellation: cancellation,
    );

    if (ProviderModelCapabilities.usesOpenAiAudioChat(modelId)) {
      return _transcribeWithAudioChat(
        file,
        length: length,
        modelId: modelId,
        languageCode: languageCode,
        cancellation: cancellation,
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
      cancellation: cancellation,
    );
  }

  Future<TranscriptionResult> _transcribeWithAudioEndpoint(
    String audioPath, {
    required String modelId,
    String? languageCode,
    RemoteCancellation? cancellation,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse('$_baseUrl/audio/transcriptions'),
          )
          ..followRedirects = false
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
    cancellation?.throwIfCancelled();
    final extension = p.extension(audioPath).toLowerCase();
    final contentType = extension == '.opus'
        ? 'audio/ogg'
        : audioMimeType(audioPath);
    final uploadExtension = switch (contentType) {
      'application/octet-stream' => '',
      _ when extension == '.opus' => '.ogg',
      _ => extension,
    };
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        audioPath,
        filename: 'audio$uploadExtension',
        contentType: http.MediaType.parse(contentType),
      ),
    );

    final response = await sendRemoteRequest(
      _http,
      request,
      timeout: remoteTranscribeTimeout,
      cancellation: cancellation,
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

  Future<TranscriptionResult> _transcribeWithAudioChat(
    File file, {
    required int length,
    required String modelId,
    String? languageCode,
    RemoteCancellation? cancellation,
  }) async {
    final format = _inlineAudioFormat(file.path);
    if (format == null) {
      throw const RemoteApiException(
        'This OpenAI multimodal model requires WAV or MP3 audio.',
      );
    }
    if (length > maxInlineAudioBytes) {
      throw const RemoteApiException(
        'This OpenAI multimodal model requires audio up to 20 MiB.',
      );
    }
    cancellation?.throwIfCancelled();
    final bytes = await file.readAsBytes();
    cancellation?.throwIfCancelled();
    final json = await _postJson(
      '/chat/completions',
      {
        'model': modelId,
        'modalities': ['text'],
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': buildTranscriptionPrompt(languageCode)},
              {
                'type': 'input_audio',
                'input_audio': {'data': base64Encode(bytes), 'format': format},
              },
            ],
          },
        ],
      },
      timeout: remoteTranscribeTimeout,
      cancellation: cancellation,
    );
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
    RemoteCancellation? cancellation,
  }) async {
    return _requestJson(
      http.Request('POST', Uri.parse('$_baseUrl$path'))
        ..headers.addAll({
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode(payload),
      timeout,
      cancellation: cancellation,
    );
  }

  Future<Map<String, dynamic>> _requestJson(
    http.BaseRequest request,
    Duration timeout, {
    RemoteCancellation? cancellation,
  }) async {
    final response = await sendRemoteRequest(
      _http,
      request..followRedirects = false,
      timeout: timeout,
      cancellation: cancellation,
    );
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
