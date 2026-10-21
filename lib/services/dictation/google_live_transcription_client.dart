import 'dart:convert';
import 'dart:typed_data';

import 'live_failure_classifier.dart';
import 'live_socket.dart';
import 'live_transcription.dart';

/// Gemini Live transcription client with the API key in a handshake header.
final class GoogleLiveTranscriptionClient
    extends LiveSocketTranscriptionClient {
  factory GoogleLiveTranscriptionClient(
    LiveTranscriptionConfig config, {
    LiveSocketConnector connector = connectLiveSocket,
    Duration connectionTimeout = const Duration(seconds: 10),
    Duration closeTimeout = const Duration(seconds: 2),
  }) => GoogleLiveTranscriptionClient._(
    config,
    connector,
    connectionTimeout,
    closeTimeout,
  );

  GoogleLiveTranscriptionClient._(
    this._config,
    LiveSocketConnector connector,
    Duration connectionTimeout,
    Duration closeTimeout,
  ) : super(
        connector,
        connectionTimeout: connectionTimeout,
        closeTimeout: closeTimeout,
      );

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
        'inputAudioTranscription': {
          'languageCodes': languageCodes,
          'mode': 'SMART',
        },
      },
    };
  }

  @override
  void handleSocketMessage(Object? raw) {
    if (isClosed) return;
    final message = decodeMessage(raw);
    if (message == null) return;
    if (message.containsKey('setupComplete')) {
      _handleSetupComplete(message);
      return;
    }
    if (message.containsKey('error')) {
      _handleProviderError(message);
      return;
    }
    _handleServerContent(message);
  }

  void _handleSetupComplete(Map<String, dynamic> message) {
    if (message['setupComplete'] is! Map) {
      rejectMalformedResponse();
      return;
    }
    completeSetup();
  }

  void _handleProviderError(Map<String, dynamic> message) {
    final error = message['error'];
    if (error is! Map) {
      rejectMalformedResponse();
      return;
    }
    final code = error['code'];
    final detail = error['message'];
    if ((code != null && code is! String && code is! num) ||
        (detail != null && detail is! String)) {
      rejectMalformedResponse();
      return;
    }
    failSetupOrEmit(classifyProviderFailure(code: code, message: detail));
  }

  void _handleServerContent(Map<String, dynamic> message) {
    if (!message.containsKey('serverContent')) return;
    final content = message['serverContent'];
    if (content is! Map<String, dynamic>) {
      rejectMalformedResponse();
      return;
    }
    if (!_emitTranscript(content, 'interimInputTranscription', partial: true)) {
      return;
    }
    if (!_emitTranscript(content, 'inputTranscription', partial: false)) {
      return;
    }
    if (content.containsKey('turnComplete') &&
        content['turnComplete'] is! bool) {
      rejectMalformedResponse();
      return;
    }
    if (content['turnComplete'] == true) {
      completeFinalization();
    }
  }

  bool _emitTranscript(
    Map<String, dynamic> content,
    String key, {
    required bool partial,
  }) {
    if (!content.containsKey(key)) return true;
    final value = content[key];
    if (value is! Map || value['text'] is! String) {
      rejectMalformedResponse();
      return false;
    }
    final rawText = value['text'] as String;
    if (rawText.length > LiveTranscriptionLimits.maximumTranscriptCharacters) {
      rejectMalformedResponse();
      return false;
    }
    final text = rawText.trim();
    if (text.isEmpty) return true;
    emit(
      partial ? LiveTranscriptionPartial(text) : LiveTranscriptionFinal(text),
    );
    if (!partial) completeFinalization();
    return true;
  }

  static final Uri liveUri = Uri.parse(
    'wss://generativelanguage.googleapis.com/ws/'
    'google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent',
  );
}
