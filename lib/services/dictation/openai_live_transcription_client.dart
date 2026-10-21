import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'live_failure_classifier.dart';
import 'live_socket.dart';
import 'live_transcription.dart';

/// OpenAI Realtime transcription client using header-based BYOK authentication.
final class OpenAiLiveTranscriptionClient
    extends LiveSocketTranscriptionClient {
  factory OpenAiLiveTranscriptionClient(
    LiveTranscriptionConfig config, {
    LiveSocketConnector connector = connectLiveSocket,
    Duration connectionTimeout = const Duration(seconds: 10),
    Duration closeTimeout = const Duration(seconds: 2),
    Duration finalizationTimeout = const Duration(seconds: 4),
  }) => OpenAiLiveTranscriptionClient._(
    config,
    connector,
    connectionTimeout,
    closeTimeout,
    finalizationTimeout,
  );

  OpenAiLiveTranscriptionClient._(
    this._config,
    LiveSocketConnector connector,
    Duration connectionTimeout,
    Duration closeTimeout,
    this._finalizationTimeout,
  ) : super(
        connector,
        connectionTimeout: connectionTimeout,
        closeTimeout: closeTimeout,
      );

  final LiveTranscriptionConfig _config;
  final Duration _finalizationTimeout;
  final Map<String, StringBuffer> _partials = {};
  String? _committedItemId;
  int _partialCharacters = 0;
  bool _audioPending = false;
  bool _awaitingCommit = false;
  int _commitSequence = 0;
  String? _commitEventId;
  Completer<void>? _finalization;
  Future<void>? _finishing;

  @override
  Future<void> connect() => connectWithSetup(
    Uri.parse('wss://api.openai.com/v1/realtime?model=${_config.modelId}'),
    {'Authorization': 'Bearer ${_config.apiKey}'},
    _sessionUpdate(),
  );

  @override
  void addAudio(Uint8List pcm) {
    if (activeSocket == null || pcm.isEmpty || isClosed) return;
    _audioPending = true;
    send({'type': 'input_audio_buffer.append', 'audio': base64Encode(pcm)});
  }

  @override
  Future<void> finish() {
    if (_finishing case final pending?) return pending;
    if (isClosed || activeSocket == null || !_audioPending) {
      return Future.value();
    }
    _audioPending = false;
    _awaitingCommit = true;
    final completion = _finalization = Completer<void>();
    _commitEventId = 'finish-${++_commitSequence}';
    final finishing = _finishing = completion.future
        .timeout(_finalizationTimeout)
        .whenComplete(() {
          _finalization = null;
          _finishing = null;
          _awaitingCommit = false;
          _committedItemId = null;
        });
    send({'type': 'input_audio_buffer.commit', 'event_id': _commitEventId});
    return finishing;
  }

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
            'turn_detection': null,
          },
        },
      },
    };
  }

  @override
  void handleSocketMessage(Object? raw) {
    if (isClosed) return;
    final message = decodeMessage(raw);
    if (message == null) return;
    final type = message['type'];
    if (message.containsKey('type') && type is! String) {
      rejectMalformedResponse();
      return;
    }
    if (type == 'session.updated') {
      completeSetup();
    } else if (type == 'input_audio_buffer.committed') {
      _handleCommitted(message);
    } else if (type == 'conversation.item.input_audio_transcription.delta') {
      _handleDelta(message);
    } else if (type ==
        'conversation.item.input_audio_transcription.completed') {
      _handleCompleted(message);
    } else if (type == 'error') {
      _handleError(message);
    }
  }

  void _handleCommitted(Map<String, dynamic> message) {
    final itemId = message['item_id'];
    if (!_validItemId(itemId)) {
      rejectMalformedResponse();
      return;
    }
    if (!_awaitingCommit) return;
    _committedItemId = itemId as String;
    // With server VAD disabled, the next acknowledgement is our manual commit.
    _awaitingCommit = false;
  }

  bool _validItemId(Object? itemId) =>
      itemId is String &&
      itemId.isNotEmpty &&
      itemId.length <= LiveTranscriptionLimits.maximumItemIdCharacters;

  void _handleDelta(Map<String, dynamic> message) {
    final itemId = message['item_id'];
    final delta = message['delta'];
    if (!_validItemId(itemId) || delta is! String) {
      rejectMalformedResponse();
      return;
    }
    if (delta.isEmpty) return;
    if ((!_partials.containsKey(itemId) &&
            _partials.length >= LiveTranscriptionLimits.maximumPartialItems) ||
        _partialCharacters + delta.length >
            LiveTranscriptionLimits.maximumTranscriptCharacters) {
      rejectMalformedResponse();
      return;
    }
    final partial = _partials.putIfAbsent(itemId as String, StringBuffer.new)
      ..write(delta);
    _partialCharacters += delta.length;
    emit(LiveTranscriptionPartial(partial.toString()));
  }

  void _handleCompleted(Map<String, dynamic> message) {
    final itemId = message['item_id'];
    final transcript = message['transcript'];
    if (!_validItemId(itemId) ||
        transcript is! String ||
        transcript.length >
            LiveTranscriptionLimits.maximumTranscriptCharacters) {
      rejectMalformedResponse();
      return;
    }
    final partial = _partials.remove(itemId);
    if (partial != null) _partialCharacters -= partial.length;
    if (itemId != _committedItemId) return;
    _committedItemId = null;
    final normalizedTranscript = transcript.trim();
    if (normalizedTranscript.isNotEmpty) {
      emit(LiveTranscriptionFinal(normalizedTranscript));
    }
    _completeFinalization();
  }

  void _completeFinalization() {
    final completion = _finalization;
    if (completion != null && !completion.isCompleted) {
      completion.complete();
    }
  }

  void _handleError(Map<String, dynamic> message) {
    final error = message['error'];
    if (error is! Map) {
      rejectMalformedResponse();
      return;
    }
    final rawCode = error['code'];
    final rawMessage = error['message'];
    if ((rawCode != null && rawCode is! String && rawCode is! num) ||
        (rawMessage != null && rawMessage is! String)) {
      rejectMalformedResponse();
      return;
    }
    final code = rawCode?.toString();
    if (code == 'input_audio_buffer_commit_empty') {
      final eventId = error['event_id'];
      if (_awaitingCommit && (eventId == null || eventId == _commitEventId)) {
        _awaitingCommit = false;
        _completeFinalization();
      }
      return;
    }
    final failure = classifyProviderFailure(code: code, message: rawMessage);
    failSetupOrEmit(failure);
    _failFinalization(failure);
  }

  void _failFinalization(String code) {
    final completion = _finalization;
    if (completion != null && !completion.isCompleted) {
      completion.completeError(LiveConnectionException(code));
    }
  }

  @override
  void handleTransportFailure(String? code) {
    super.handleTransportFailure(code);
    _failFinalization(code ?? 'connection_failed');
  }

  @override
  void onClosing() {
    _partials.clear();
    _partialCharacters = 0;
    _committedItemId = null;
    _audioPending = false;
    _failFinalization('connection_cancelled');
  }
}
