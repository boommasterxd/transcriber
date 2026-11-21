part of 'dictation_controller.dart';

extension _DictationSession on DictationController {
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
    _capturePaused = false;
    _reconnectAttempt = 0;
    _releaseReconnectDelay();
    _stopTimer();
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

  Future<void> _stopRecording(String sessionId) async {
    final inFlight = _recordingStop;
    if (inFlight != null) return inFlight;
    final stopping = _stopAfterRecordingChange(sessionId);
    _recordingStop = stopping;
    try {
      await stopping;
    } finally {
      _recordingStop = null;
    }
  }

  Future<void> _stopAfterRecordingChange(String sessionId) async {
    try {
      await _recordingChange;
    } catch (_) {
      // Stop also rolls back a partially completed platform transition.
    }
    await _platform.stopRecording(sessionId);
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
