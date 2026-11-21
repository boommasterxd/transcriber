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
    if (generation != _connectionGeneration || !_isCurrent(sessionId)) return;
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
    if (generation != _connectionGeneration ||
        !_ownsSession(sessionId, _sessionGeneration)) {
      return;
    }
    switch (event) {
      case LiveTranscriptionReady():
        break;
      case LiveTranscriptionPartial(:final text):
        if (!_fitsSessionTranscript(_finalized, text)) {
          unawaited(_abortWithError('provider_rejected'));
          return;
        }
        _partial = text;
        _setState(
          _state.copyWith(
            phase: _streamingPhase(true),
            progress: _state.progress.copyWith(preview: text),
          ),
        );
        if (generation == _connectionGeneration) {
          _queueComposition(sessionId, _sessionTranscript);
        }
      case LiveTranscriptionFinal(:final text):
        if (!_fitsSessionTranscript(_finalized, text)) {
          unawaited(_abortWithError('provider_rejected'));
          return;
        }
        _finalized = _joinTranscript(_finalized, text);
        _partial = '';
        _setState(
          _state.copyWith(
            phase: _streamingPhase(false),
            progress: _state.progress.copyWith(preview: text),
          ),
        );
        if (generation == _connectionGeneration) {
          _queueComposition(sessionId, _finalized);
        }
      case LiveTranscriptionDisconnected():
        if (_state.phase == DictationPhase.connecting) {
          unawaited(_abortWithError('connection_failed'));
        } else {
          unawaited(_reconnect(sessionId, generation));
        }
      case LiveTranscriptionFailure(:final code):
        unawaited(_abortWithError(code));
    }
  }

  void _queueComposition(String sessionId, String text) {
    _pendingComposition = (
      sessionId: sessionId,
      text: text,
      generation: _textGeneration,
    );
    if (_compositionWorkerRunning) return;
    _compositionWorkerRunning = true;
    _editorWrites = _drainCompositionQueue();
  }

  Future<void> _drainCompositionQueue() async {
    try {
      while (_pendingComposition != null) {
        final pending = _pendingComposition!;
        _pendingComposition = null;
        if (pending.generation != _textGeneration ||
            !_isCurrent(pending.sessionId)) {
          continue;
        }
        await _writeComposition(pending);
      }
    } finally {
      _compositionWorkerRunning = false;
    }
  }

  Future<void> _writeComposition(
    ({String sessionId, String text, int generation}) pending,
  ) async {
    try {
      final written = await _platform.setComposingText(
        pending.sessionId,
        pending.text,
      );
      if (!written) _cancelCompositionIfCurrent(pending.generation);
    } catch (_) {
      _cancelCompositionIfCurrent(pending.generation);
    }
  }

  void _cancelCompositionIfCurrent(int generation) {
    if (generation == _textGeneration) unawaited(cancel());
  }

  Future<void> _reconnect(String sessionId, int generation) async {
    final sessionGeneration = _sessionGeneration;
    if (generation != _connectionGeneration ||
        !_ownsSession(sessionId, sessionGeneration) ||
        _state.phase == DictationPhase.stopping) {
      return;
    }
    if (_reconnectAttempt >= _reconnectDelays.length) {
      await _abortWithError('reconnect_failed');
      return;
    }
    final delay = _reconnectDelays[_reconnectAttempt++];
    final cleanup = _disconnectClient();
    final disconnectedGeneration = _connectionGeneration;
    _setState(_state.copyWith(phase: DictationPhase.reconnecting));
    await cleanup;
    if (!_canReconnect(sessionId, sessionGeneration, disconnectedGeneration)) {
      return;
    }
    await _waitToReconnect(delay);
    if (!_canReconnect(sessionId, sessionGeneration, disconnectedGeneration)) {
      return;
    }
    final connecting = _connect(sessionId);
    final attemptGeneration = _connectionGeneration;
    try {
      await connecting;
      if (!_canReconnect(sessionId, sessionGeneration, attemptGeneration)) {
        return;
      }
      _setState(
        _state.copyWith(
          phase: _capturePaused
              ? DictationPhase.paused
              : DictationPhase.recording,
        ),
      );
    } catch (_) {
      if (_canReconnect(sessionId, sessionGeneration, attemptGeneration)) {
        await _reconnect(sessionId, attemptGeneration);
      }
    }
  }

  Future<void> _waitToReconnect(Duration delay) {
    final waiting = Completer<void>();
    _reconnectDelay = waiting;
    _reconnectTimer = Timer(delay, _releaseReconnectDelay);
    return waiting.future;
  }

  void _releaseReconnectDelay() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectDelay?.complete();
    _reconnectDelay = null;
  }

  bool _canReconnect(String sessionId, int sessionGeneration, int generation) =>
      generation == _connectionGeneration &&
      _ownsSession(sessionId, sessionGeneration) &&
      _state.phase == DictationPhase.reconnecting;

  DictationPhase _streamingPhase(bool hasPartial) => switch (_state.phase) {
    DictationPhase.connecting ||
    DictationPhase.reconnecting ||
    DictationPhase.paused ||
    DictationPhase.stopping => _state.phase,
    _ => hasPartial ? DictationPhase.correcting : DictationPhase.recording,
  };

  Future<void> _disconnectClient() {
    _connected = false;
    _connectionGeneration++;
    final subscription = _clientSubscription;
    final client = _client;
    _clientSubscription = null;
    _client = null;
    if (client != null) {
      _clientCleanup = Future.wait<void>([
        if (subscription != null) subscription.cancel(),
        client.close(),
      ]).then<void>((_) {}, onError: (Object _, StackTrace _) {});
    }
    return _clientCleanup;
  }
}
