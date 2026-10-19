part of 'dictation_controller.dart';

extension _DictationConnection on DictationController {
  Future<void> _connect(String sessionId) async {
    final config = _config!;
    final generation = ++_connectionGeneration;
    final client = _clientFactory(config);
    _client = client;
    _clientSubscription = client.events.listen(
      (event) => _handleClientEvent(event, sessionId, generation),
    );
    await client.connect();
    if (generation != _connectionGeneration || !_isCurrent(sessionId)) {
      await client.close();
      return;
    }
    _connected = true;
    _reconnectAttempt = 0;
    while (_pendingAudio.isNotEmpty) {
      client.addAudio(_pendingAudio.removeFirst());
    }
  }

  void _handleClientEvent(
    LiveTranscriptionEvent event,
    String sessionId,
    int generation,
  ) {
    if (generation != _connectionGeneration || !_isCurrent(sessionId)) return;
    switch (event) {
      case LiveTranscriptionReady():
        break;
      case LiveTranscriptionPartial(:final text):
        _partial = text;
        _setState(
          _state.copyWith(
            phase: _streamingPhase(true),
            progress: _state.progress.copyWith(preview: text),
          ),
        );
        _queueComposition(sessionId, _sessionTranscript);
      case LiveTranscriptionFinal(:final text):
        _finalized = _joinTranscript(_finalized, text);
        _partial = '';
        _setState(
          _state.copyWith(
            phase: _streamingPhase(false),
            progress: _state.progress.copyWith(preview: text),
          ),
        );
        _queueComposition(sessionId, _finalized);
      case LiveTranscriptionDisconnected():
        unawaited(_reconnect(sessionId, generation));
      case LiveTranscriptionFailure(:final code):
        unawaited(_abortWithError(code));
    }
  }

  void _queueComposition(String sessionId, String text) {
    final generation = _textGeneration;
    _editorWrites = _editorWrites.then((_) async {
      if (generation != _textGeneration || !_isCurrent(sessionId)) return;
      try {
        if (!await _platform.setComposingText(sessionId, text) &&
            generation == _textGeneration) {
          unawaited(cancel());
        }
      } catch (_) {
        if (generation == _textGeneration) unawaited(cancel());
      }
    });
  }

  Future<void> _reconnect(
    String sessionId,
    int generation, {
    bool? resumePaused,
  }) async {
    if (!_state.isActive || generation != _connectionGeneration) return;
    final wasPaused = resumePaused ?? _state.phase == DictationPhase.paused;
    _connected = false;
    if (_reconnectAttempt >= _reconnectDelays.length) {
      await _abortWithError('reconnect_failed');
      return;
    }
    final delay = _reconnectDelays[_reconnectAttempt++];
    _setState(_state.copyWith(phase: DictationPhase.reconnecting));
    await _clientSubscription?.cancel();
    await _client?.close();
    await Future<void>.delayed(delay);
    if (!_state.isActive || !_isCurrent(sessionId)) return;
    try {
      await _connect(sessionId);
      _setState(
        _state.copyWith(
          phase: wasPaused ? DictationPhase.paused : DictationPhase.recording,
        ),
      );
    } catch (_) {
      await _reconnect(
        sessionId,
        _connectionGeneration,
        resumePaused: wasPaused,
      );
    }
  }

  DictationPhase _streamingPhase(bool hasPartial) =>
      _state.phase == DictationPhase.paused
      ? DictationPhase.paused
      : hasPartial
      ? DictationPhase.correcting
      : DictationPhase.recording;

  Future<void> _closeClient() async {
    _connected = false;
    _connectionGeneration++;
    final subscription = _clientSubscription;
    final client = _client;
    _clientSubscription = null;
    _client = null;
    _config = null;
    _pendingAudio.clear();
    await subscription?.cancel();
    await client?.close();
  }
}
