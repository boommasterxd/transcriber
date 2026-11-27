part of 'dictation_controller.dart';

extension _DictationSession on DictationController {
  void _startSessionLimits(String sessionId, int generation, int sampleRate) {
    _remainingPcmBytes = LiveTranscriptionLimits.maximumPcmBytes(sampleRate);
    _sessionDeadline = Timer(
      LiveTranscriptionLimits.maximumSessionDuration,
      () => _finishAtLimit(sessionId, generation),
    );
  }

  void _startCaptureTimer(String sessionId, int generation) {
    _pauseDeadline?.cancel();
    _pauseDeadline = null;
    _captureElapsed.start();
    _lastPcmAt = _captureElapsed.elapsed;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_canChangePause(sessionId, generation)) return;
      final elapsed = _captureElapsed.elapsed;
      if (elapsed - _lastPcmAt >= LiveTranscriptionLimits.maximumIdleDuration) {
        _finishAtLimit(sessionId, generation);
        return;
      }
      _setState(
        _state.copyWith(progress: _state.progress.copyWith(elapsed: elapsed)),
      );
    });
  }

  void _pauseCaptureTimer(String sessionId, int generation) {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _captureElapsed.stop();
    _pauseDeadline = Timer(LiveTranscriptionLimits.maximumIdleDuration, () {
      if (_capturePaused) _finishAtLimit(sessionId, generation);
    });
  }

  void _finishAtLimit(String sessionId, int generation) {
    if (_canChangePause(sessionId, generation)) {
      unawaited(_stop(atLimit: true));
    }
  }

  void _stopSessionTimers() {
    _elapsedTimer?.cancel();
    _elapsedTimer = null;
    _sessionDeadline?.cancel();
    _sessionDeadline = null;
    _pauseDeadline?.cancel();
    _pauseDeadline = null;
    _captureElapsed.stop();
  }

  Future<void> _finishClient() async {
    if (!_connected) {
      await _disconnectClient();
      return;
    }
    try {
      await _client?.finish();
    } catch (error) {
      final interrupted =
          error is TimeoutException ||
          (error is LiveConnectionException &&
              error.code == 'connection_failed');
      if (!_stoppingAtLimit || !interrupted || !_hasStagedText) rethrow;
    }
  }

  bool get _hasStagedText => _finalized.isNotEmpty || _partial.isNotEmpty;

  Future<LiveTranscriptionConfig?> _readConfiguration(
    String sessionId,
    int generation,
  ) async {
    if (!_ownsSession(sessionId, generation)) return null;
    final settings = await _settingsRepository.load();
    if (!_ownsSession(sessionId, generation)) return null;
    final key = (await _settingsRepository.apiKey(settings.asrProvider))
        ?.trim();
    if (!_ownsSession(sessionId, generation)) return null;
    if (key == null || key.isEmpty) {
      throw const LiveConnectionException('api_key_missing');
    }
    return LiveTranscriptionConfig(
      provider: settings.asrProvider,
      apiKey: key,
      languageCode: LiveDictationModelCatalog.languageCodeFor(
        settings.asrProvider,
        settings.transcriptionLanguage,
      ),
    );
  }

  Future<void> _abortWithError(String code) async {
    // A transport interruption at the limit can still leave text to commit.
    if (_stoppingAtLimit && code == 'connection_failed' && _hasStagedText) {
      return;
    }
    final cleanup = _endSession(discard: true);
    _fail(code);
    await cleanup;
  }

  Future<void> _endSession({bool discard = false}) {
    final ongoing = _sessionCleanup;
    if (ongoing != null) return ongoing;
    final completed = Completer<void>();
    _sessionCleanup = completed.future;
    _sessionGeneration++;
    _textGeneration++;
    _pendingComposition = null;
    _finalized = '';
    _partial = '';
    _config = null;
    _pendingAudio.clear();
    _remainingPcmBytes = 0;
    _capturePaused = false;
    _stoppingAtLimit = false;
    _reconnectAttempt = 0;
    _releaseReconnectDelay();
    _stopSessionTimers();
    _captureElapsed.reset();
    final sessionId = discard ? _editor?.sessionId : null;
    unawaited(_cleanupSession(sessionId, completed));
    return completed.future;
  }

  Future<void> _cleanupSession(
    String? discardedSessionId,
    Completer<void> completed,
  ) async {
    try {
      await Future.wait([
        _disconnectClient(),
        if (discardedSessionId != null) _discardRecording(discardedSessionId),
      ]);
    } catch (_) {
      // Cleanup failures must not keep the keyboard in a transient state.
    } finally {
      _sessionCleanup = null;
      completed.complete();
    }
  }

  Future<void> _discardRecording(String sessionId) async {
    try {
      await _stopRecording(sessionId);
    } catch (_) {
      // The platform may have already revoked the editor session.
    }
    await _editorWrites;
    try {
      await _platform.clearComposingText(sessionId);
    } catch (_) {
      // Native lifecycle cleanup also clears composition for a revoked editor.
    }
  }

  Future<bool> _stopRecording(String sessionId) async {
    final inFlight = _recordingStop;
    if (inFlight != null) return inFlight;
    final stopping = _stopAfterRecordingChange(sessionId);
    _recordingStop = stopping;
    try {
      return await stopping;
    } finally {
      _recordingStop = null;
    }
  }

  Future<bool> _stopAfterRecordingChange(String sessionId) async {
    try {
      await _recordingChange;
    } catch (_) {
      // Stop also rolls back a partially completed platform transition.
    }
    return _platform.stopRecording(sessionId);
  }

  Future<void> _changeRecording(Future<void> Function() change) async {
    final pending = Future<void>.sync(change);
    _recordingChange = pending;
    try {
      await pending;
    } finally {
      _recordingChange = null;
    }
  }

  Future<void> _handleStartFailure(
    String sessionId,
    int generation,
    String code,
  ) async {
    if (_ownsSession(sessionId, generation)) await _abortWithError(code);
  }
}
