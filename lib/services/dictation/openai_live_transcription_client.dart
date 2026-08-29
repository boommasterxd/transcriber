import 'dart:convert';
import 'dart:typed_data';

import 'live_socket.dart';
import 'live_transcription.dart';

/// OpenAI Realtime transcription client using header-based BYOK authentication.
final class OpenAiLiveTranscriptionClient
    extends LiveSocketTranscriptionClient {
  factory OpenAiLiveTranscriptionClient(
    LiveTranscriptionConfig config, {
    LiveSocketConnector connector = connectLiveSocket,
  }) => OpenAiLiveTranscriptionClient._(config, connector);

  OpenAiLiveTranscriptionClient._(this._config, super.connector);

  final LiveTranscriptionConfig _config;
  final Map<String, StringBuffer> _partials = {};
  bool _audioSinceFinal = false;

  @override
  Future<void> connect() => connectWithSetup(
    Uri.parse('wss://api.openai.com/v1/realtime?model=${_config.modelId}'),
    {'Authorization': 'Bearer ${_config.apiKey}'},
    _sessionUpdate(),
  );

  @override
  void addAudio(Uint8List pcm) {
    if (activeSocket == null || pcm.isEmpty || isClosed) return;
    _audioSinceFinal = true;
    send({'type': 'input_audio_buffer.append', 'audio': base64Encode(pcm)});
  }

  @override
  Future<void> finish() => sendAndAwaitFinal({
    'type': 'input_audio_buffer.commit',
  }, skip: !_audioSinceFinal);

  Map<String, Object> _sessionUpdate() {
    final transcription = <String, Object>{
      'model': _config.modelId,
      'delay': 'low',
    };
    final language = _config.languageCode;
    if (language != null) transcription['languages'] = [language];
    return {
      'type': 'session.update',
      'session': {
        'type': 'transcription',
        'audio': {
          'input': {
            'format': {'type': 'audio/pcm', 'rate': _config.sampleRate},
            'transcription': transcription,
            'turn_detection': {
              'type': 'server_vad',
              'silence_duration_ms': 700,
            },
          },
        },
      },
    };
  }

  @override
  void handleSocketMessage(Object? raw) {
    final message = decodeMessage(raw);
    if (message == null) return;
    final type = message['type'];
    if (type == 'session.updated') {
      completeSetup();
    } else if (type == 'conversation.item.input_audio_transcription.delta') {
      _handleDelta(message);
    } else if (type ==
        'conversation.item.input_audio_transcription.completed') {
      _handleCompleted(message);
    } else if (type == 'error') {
      _handleError(message);
    }
  }

  void _handleDelta(Map<String, dynamic> message) {
    final itemId = message['item_id'] as String?;
    final delta = message['delta'] as String?;
    if (itemId == null || delta == null || delta.isEmpty) return;
    final partial = _partials.putIfAbsent(itemId, StringBuffer.new)
      ..write(delta);
    emit(LiveTranscriptionPartial(partial.toString()));
  }

  void _handleCompleted(Map<String, dynamic> message) {
    final itemId = message['item_id'] as String?;
    if (itemId != null) _partials.remove(itemId);
    final transcript = (message['transcript'] as String?)?.trim();
    _audioSinceFinal = false;
    if (transcript != null && transcript.isNotEmpty) {
      emit(LiveTranscriptionFinal(transcript));
    }
    completeFinalization();
  }

  void _handleError(Map<String, dynamic> message) {
    final error = message['error'];
    final code = error is Map ? error['code']?.toString() : null;
    if (code == 'input_audio_buffer_commit_empty') {
      completeFinalization();
      return;
    }
    failSetupOrEmit(
      classifyProviderFailure(
        code: code,
        message: error is Map ? error['message'] : null,
      ),
    );
  }
}
