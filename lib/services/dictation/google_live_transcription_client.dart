import 'dart:convert';
import 'dart:typed_data';

import 'live_socket.dart';
import 'live_transcription.dart';

/// Gemini Live transcription client with the API key in a handshake header.
final class GoogleLiveTranscriptionClient
    extends LiveSocketTranscriptionClient {
  factory GoogleLiveTranscriptionClient(
    LiveTranscriptionConfig config, {
    LiveSocketConnector connector = connectLiveSocket,
  }) => GoogleLiveTranscriptionClient._(config, connector);

  GoogleLiveTranscriptionClient._(this._config, super.connector);

  final LiveTranscriptionConfig _config;

  @override
  Future<void> connect() => connectWithSetup(liveUri, {
    'x-goog-api-key': _config.apiKey,
  }, _setupMessage());

  @override
  void addAudio(Uint8List pcm) {
    if (activeSocket == null || pcm.isEmpty || isClosed) return;
    send({
      'realtimeInput': {
        'audio': {
          'data': base64Encode(pcm),
          'mimeType': 'audio/pcm;rate=${_config.sampleRate}',
        },
      },
    });
  }

  @override
  Future<void> finish() => sendAndAwaitFinal({
    'realtimeInput': {'audioStreamEnd': true},
  });

  Map<String, Object> _setupMessage() {
    final languageCodes = <String>[];
    if (_config.languageCode case final language?) languageCodes.add(language);
    return {
      'setup': {
        'model': 'models/${_config.modelId}',
        'generationConfig': {
          'responseModalities': ['TEXT'],
        },
        'inputAudioTranscription': {'languageCodes': languageCodes},
      },
    };
  }

  @override
  void handleSocketMessage(Object? raw) {
    final message = decodeMessage(raw);
    if (message == null) return;
    if (message.containsKey('setupComplete')) {
      completeSetup();
      return;
    }
    if (message['error'] case final error?) {
      failSetupOrEmit(
        classifyProviderFailure(
          code: error is Map ? error['code'] : null,
          message: error is Map ? error['message'] : error,
        ),
      );
      return;
    }
    final content = message['serverContent'];
    if (content is! Map<String, dynamic>) return;
    _emitTranscript(content, 'interimInputTranscription', partial: true);
    _emitTranscript(content, 'inputTranscription', partial: false);
    if (content['turnComplete'] == true) {
      completeFinalization();
    }
  }

  void _emitTranscript(
    Map<String, dynamic> content,
    String key, {
    required bool partial,
  }) {
    final value = content[key];
    final text = value is Map ? value['text']?.toString().trim() : null;
    if (text == null || text.isEmpty) return;
    emit(
      partial ? LiveTranscriptionPartial(text) : LiveTranscriptionFinal(text),
    );
    if (!partial) completeFinalization();
  }

  static final Uri liveUri = Uri.parse(
    'wss://generativelanguage.googleapis.com/ws/'
    'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent',
  );
}
