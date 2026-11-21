import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/repositories/settings_repository.dart';
import '../services/dictation/dictation_platform.dart';
import '../services/dictation/live_transcription.dart';
import '../services/dictation/live_transcription_client_factory.dart';
import 'dictation_state.dart';

part 'dictation_connection.dart';
part 'dictation_session.dart';

/// Coordinates one editor-bound, non-persistent live dictation session.
final class DictationController extends ChangeNotifier {
  factory DictationController({
    required SettingsRepository settingsRepository,
    required DictationPlatform platform,
    LiveTranscriptionClientFactory clientFactory =
        createLiveTranscriptionClient,
    List<Duration> reconnectDelays = const [
      Duration(milliseconds: 400),
      Duration(milliseconds: 900),
      Duration(milliseconds: 1800),
    ],
  }) => DictationController._(
    settingsRepository,
    platform,
    clientFactory,
    reconnectDelays,
  );

  DictationController._(
    this._settingsRepository,
    this._platform,
    this._clientFactory,
    this._reconnectDelays,
  );

  final SettingsRepository _settingsRepository;
  final DictationPlatform _platform;
  final LiveTranscriptionClientFactory _clientFactory;
  final List<Duration> _reconnectDelays;
  final Queue<Uint8List> _pendingAudio = Queue();
  DictationState _state = DictationState.initial();
  StreamSubscription<DictationPlatformEvent>? _platformSubscription;
  StreamSubscription<LiveTranscriptionEvent>? _clientSubscription;
  LiveTranscriptionClient? _client;
  LiveTranscriptionConfig? _config;
  KeyboardEditorState? _editor;
  Timer? _timer;
  Timer? _reconnectTimer;
  Completer<void>? _reconnectDelay;
  DateTime? _startedAt;
  Duration _elapsedBeforeSegment = Duration.zero;
  Future<void> _editorWrites = Future.value();
  Future<void> _editorTransitions = Future.value();
  Future<void> _clientCleanup = Future.value();
  Future<void>? _sessionCleanup;
  Future<void>? _recordingChange;
  Future<void>? _recordingStop;
  ({String sessionId, String text, int generation})? _pendingComposition;
  String _finalized = '';
  String _partial = '';
  int _connectionGeneration = 0;
  int _sessionGeneration = 0;
  int _textGeneration = 0;
  int _reconnectAttempt = 0;
  bool _compositionWorkerRunning = false;
  bool _connected = false;
  bool _capturePaused = false;
  bool _disposed = false;

  DictationState get state => _state;

  Future<void> initialize() async {
    _platformSubscription ??= _platform.events.listen(_handlePlatformEvent);
    await _applyEditor(await _platform.editorState());
    await _refreshConfigurationLabel();
  }

  Future<void> start() async {
    final editor = _editor;
    if (_state.isActive ||
        _sessionCleanup != null ||
        editor == null ||
        !_isCurrent(editor.sessionId)) {
      return;
    }
    if (!editor.microphoneGranted) {
      _fail('microphone_denied');
      return;
    }
    final sessionId = editor.sessionId;
    final generation = ++_sessionGeneration;
    _setState(
      _state.copyWith(
        phase: DictationPhase.connecting,
        progress: const DictationProgress(),
        clearError: true,
      ),
    );
    try {
      final config = await _readConfiguration(sessionId, generation);
      if (config == null || !_ownsSession(sessionId, generation)) return;
      _config = config;
      _setState(
        _state.copyWith(
          selection: DictationModelSelection(
            provider: config.provider,
            modelId: config.modelId,
          ),
        ),
      );
      if (!_ownsSession(sessionId, generation)) return;
      await _connect(sessionId);
      if (!_ownsSession(sessionId, generation)) return;
      await _changeRecording(
        () => _platform.startRecording(sessionId, config.sampleRate),
      );
      if (!_ownsSession(sessionId, generation)) return;
      _startTimer();
      _setState(
        _state.copyWith(
          phase: DictationPhase.recording,
          progress: _state.progress.copyWith(
            levels: List.filled(maximumLevels, initialWaveformLevel),
          ),
        ),
      );
    } on LiveConnectionException catch (error) {
      await _handleStartFailure(sessionId, generation, error.code);
    } on PlatformException catch (error) {
      await _handleStartFailure(sessionId, generation, error.code);
    } catch (_) {
      await _handleStartFailure(sessionId, generation, 'connection_failed');
    }
  }

  Future<void> stop() async {
    if (!_state.isActive ||
        _state.phase == DictationPhase.stopping ||
        _sessionCleanup != null) {
      return;
    }
    if (_state.phase == DictationPhase.connecting) {
      await cancel();
      return;
    }
    final sessionId = _editor!.sessionId;
    final generation = _sessionGeneration;
    _setState(_state.copyWith(phase: DictationPhase.stopping));
    _stopTimer();
    _releaseReconnectDelay();
    try {
      if (_ownsSession(sessionId, generation)) {
        await _stopRecording(sessionId);
      }
      if (!_ownsSession(sessionId, generation)) return;
      if (_connected) {
        await _client?.finish();
      } else {
        await _disconnectClient();
      }
      if (!_ownsSession(sessionId, generation)) return;
      await _editorWrites;
      if (!_ownsSession(sessionId, generation)) return;
      final transcript = _sessionTranscript;
      if (transcript.isNotEmpty) {
        await _platform.commitText(sessionId, transcript);
      }
      if (!_ownsSession(sessionId, generation)) return;
      await _endSession();
      if (generation + 1 == _sessionGeneration) _setReadyState();
    } catch (_) {
      if (_ownsSession(sessionId, generation)) {
        await _abortWithError('finalization_failed');
      }
    }
  }

  Future<void> togglePause() async {
    final editor = _editor;
    final generation = _sessionGeneration;
    if (editor == null ||
        !_ownsSession(editor.sessionId, generation) ||
        _recordingChange != null) {
      return;
    }
    final sessionId = editor.sessionId;
    try {
      if (_state.phase == DictationPhase.paused) {
        await _changeRecording(() => _platform.resumeRecording(sessionId));
        if (!_canChangePause(sessionId, generation)) return;
        _capturePaused = false;
        _startTimer();
        if (_state.phase != DictationPhase.reconnecting) {
          _setState(_state.copyWith(phase: DictationPhase.recording));
        }
      } else if (_state.phase == DictationPhase.recording ||
          _state.phase == DictationPhase.correcting) {
        await _changeRecording(() => _platform.pauseRecording(sessionId));
        if (!_canChangePause(sessionId, generation)) return;
        _capturePaused = true;
        _pauseTimer();
        if (_state.phase != DictationPhase.reconnecting) {
          _setState(_state.copyWith(phase: DictationPhase.paused));
        }
      }
    } on PlatformException catch (error) {
      if (_canChangePause(sessionId, generation)) {
        await _abortWithError(error.code);
      }
    } catch (_) {
      if (_canChangePause(sessionId, generation)) {
        await _abortWithError('audio_state_failed');
      }
    }
  }

  Future<void> cancel() async {
    final cleanup = _endSession(discard: true);
    final generation = _sessionGeneration;
    await cleanup;
    if (generation == _sessionGeneration) _setReadyState();
  }

  Future<void> switchBack() async {
    await cancel();
    await _platform.switchToPreviousInputMethod();
  }

  Future<void> deleteBackward() async {
    final editor = _editor;
    if (editor == null || !_isCurrent(editor.sessionId)) return;
    await _platform.deleteBackward(editor.sessionId);
  }

  void _handlePlatformEvent(DictationPlatformEvent event) {
    switch (event) {
      case DictationEditorChanged(:final editor):
        _queueEditorTransition(editor);
      case DictationAudioChunk(:final sessionId, :final pcm, :final level):
        _handleAudio(sessionId, pcm, level);
      case DictationPlatformFailure(:final sessionId, :final code):
        if (_ownsSession(sessionId, _sessionGeneration)) {
          unawaited(_abortWithError(code));
        }
    }
  }

  void _queueEditorTransition(KeyboardEditorState editor) {
    final transition = _editorTransitions.then((_) => _applyEditor(editor));
    _editorTransitions = transition.onError((_, _) {});
    unawaited(_editorTransitions);
  }

  void _handleAudio(String sessionId, Uint8List pcm, double level) {
    final generation = _sessionGeneration;
    if (_capturePaused || !_canChangePause(sessionId, generation)) return;
    final levels = [..._state.levels, level];
    if (levels.length > maximumLevels) levels.removeAt(0);
    _setState(
      _state.copyWith(progress: _state.progress.copyWith(levels: levels)),
    );
    if (!_canChangePause(sessionId, generation)) return;
    if (_connected) {
      _client?.addAudio(pcm);
    } else {
      if (_pendingAudio.length == maximumPendingChunks) {
        _pendingAudio.removeFirst();
      }
      _pendingAudio.addLast(Uint8List.fromList(pcm));
    }
  }

  Future<void> _applyEditor(KeyboardEditorState editor) async {
    if (_disposed) return;
    final changed = _editor?.sessionId != editor.sessionId;
    final available = editor.visible && editor.supported;
    if (_state.isActive && (changed || !available)) {
      await _endSession(discard: true);
    }
    if (_disposed) return;
    _editor = editor;
    _setState(
      _state.copyWith(
        phase: _state.isActive && !changed && available
            ? _state.phase
            : available
            ? DictationPhase.ready
            : DictationPhase.unavailable,
        editor: DictationEditorStatus(
          visible: editor.visible,
          supported: editor.supported,
          microphoneGranted: editor.microphoneGranted,
        ),
        clearError: true,
      ),
    );
  }

  Future<void> _refreshConfigurationLabel() async {
    final settings = await _settingsRepository.load();
    _setState(
      _state.copyWith(
        selection: DictationModelSelection(
          provider: settings.asrProvider,
          modelId: LiveDictationModelCatalog.modelFor(settings.asrProvider),
        ),
      ),
    );
  }

  void _startTimer() {
    _timer?.cancel();
    _elapsedBeforeSegment = _state.elapsed;
    _startedAt = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final startedAt = _startedAt;
      if (startedAt != null) {
        _setState(
          _state.copyWith(
            progress: _state.progress.copyWith(
              elapsed:
                  _elapsedBeforeSegment + DateTime.now().difference(startedAt),
            ),
          ),
        );
      }
    });
  }

  void _pauseTimer() {
    final startedAt = _startedAt;
    if (startedAt != null) {
      _elapsedBeforeSegment += DateTime.now().difference(startedAt);
      _setState(
        _state.copyWith(
          progress: _state.progress.copyWith(elapsed: _elapsedBeforeSegment),
        ),
      );
    }
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    _elapsedBeforeSegment = Duration.zero;
  }

  void _setReadyState() {
    final editor = _editor;
    final available = editor?.visible == true && editor?.supported == true;
    _setState(
      _state.copyWith(
        phase: available ? DictationPhase.ready : DictationPhase.unavailable,
        progress: const DictationProgress(),
        clearError: true,
      ),
    );
  }

  void _fail(String code) {
    _setState(_state.copyWith(phase: DictationPhase.error, errorCode: code));
  }

  bool _isCurrent(String sessionId) =>
      !_disposed &&
      _editor?.sessionId == sessionId &&
      _editor?.visible == true &&
      _editor?.supported == true;

  bool _ownsSession(String sessionId, int generation) =>
      generation == _sessionGeneration &&
      _sessionCleanup == null &&
      _state.isActive &&
      _isCurrent(sessionId);

  bool _canChangePause(String sessionId, int generation) =>
      _ownsSession(sessionId, generation) &&
      _state.phase != DictationPhase.stopping;

  void _setState(DictationState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_endSession(discard: true));
    final platformSubscription = _platformSubscription;
    _platformSubscription = null;
    unawaited(platformSubscription?.cancel());
    super.dispose();
  }

  static const int maximumLevels = 42;
  static const int maximumPendingChunks = 12;
  static const double initialWaveformLevel = 0.12;

  String get _sessionTranscript => _joinTranscript(_finalized, _partial);
}

String _joinTranscript(String finalized, String current) {
  if (finalized.isEmpty) return current;
  if (current.isEmpty) return finalized;
  if (_hasBoundaryWhitespace(finalized, current) ||
      _startsWithPunctuation(current)) {
    return '$finalized$current';
  }
  return '$finalized $current';
}

bool _fitsSessionTranscript(String finalized, String current) =>
    _joinedTranscriptLength(finalized, current) <=
    LiveTranscriptionLimits.maximumTranscriptCharacters;

int _joinedTranscriptLength(String finalized, String current) {
  if (finalized.isEmpty || current.isEmpty) {
    return finalized.length + current.length;
  }
  final needsSeparator =
      !_hasBoundaryWhitespace(finalized, current) &&
      !_startsWithPunctuation(current);
  return finalized.length + current.length + (needsSeparator ? 1 : 0);
}

bool _hasBoundaryWhitespace(String left, String right) =>
    RegExp(r'\s$').hasMatch(left) || RegExp(r'^\s').hasMatch(right);

bool _startsWithPunctuation(String value) =>
    RegExp(r'^[.,!?;:)}\]]').hasMatch(value);
