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
  DateTime? _startedAt;
  Duration _elapsedBeforeSegment = Duration.zero;
  String _partial = '';
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;
  bool _connected = false;
  bool _disposed = false;

  DictationState get state => _state;

  Future<void> initialize() async {
    _platformSubscription ??= _platform.events.listen(_handlePlatformEvent);
    await _applyEditor(await _platform.editorState());
    await _refreshConfigurationLabel();
  }

  Future<void> start() async {
    final editor = _editor;
    if (editor == null || !editor.visible || !editor.supported) return;
    if (!editor.microphoneGranted) {
      _fail('microphone_denied');
      return;
    }
    try {
      final settings = await _settingsRepository.load();
      final key = (await _settingsRepository.apiKey(
        settings.asrProvider,
      ))?.trim();
      if (key == null || key.isEmpty) {
        _fail('api_key_missing');
        return;
      }
      _config = LiveTranscriptionConfig(
        provider: settings.asrProvider,
        apiKey: key,
        languageCode: LiveDictationModelCatalog.languageCodeFor(
          settings.asrProvider,
          settings.transcriptionLanguage,
        ),
      );
      _setState(
        _state.copyWith(
          phase: DictationPhase.connecting,
          provider: settings.asrProvider,
          modelId: _config!.modelId,
          preview: '',
          elapsed: Duration.zero,
          levels: const [],
          clearError: true,
        ),
      );
      await _connect(editor.sessionId);
      if (!_isCurrent(editor.sessionId)) return;
      await _platform.startRecording(editor.sessionId, _config!.sampleRate);
      _startTimer();
      _setState(_state.copyWith(phase: DictationPhase.recording));
    } on LiveConnectionException catch (error) {
      await _handleStartFailure(editor.sessionId, error.code);
    } on PlatformException catch (error) {
      await _handleStartFailure(editor.sessionId, error.code);
    } catch (_) {
      await _handleStartFailure(editor.sessionId, 'connection_failed');
    }
  }

  Future<void> stop() async {
    if (!_state.isActive) return;
    final sessionId = _editor?.sessionId;
    _setState(_state.copyWith(phase: DictationPhase.stopping));
    await _platform.stopRecording();
    _stopTimer();
    try {
      await _client?.finish();
      if (sessionId != null && _partial.isNotEmpty && _isCurrent(sessionId)) {
        await _platform.commitText(sessionId, _partial);
        _partial = '';
      }
    } catch (_) {
      if (sessionId != null) await _platform.clearComposingText(sessionId);
      _fail('finalization_failed');
    } finally {
      await _closeClient();
    }
    if (_state.phase != DictationPhase.error) _setReadyState();
  }

  Future<void> togglePause() async {
    final editor = _editor;
    if (editor == null || !_isCurrent(editor.sessionId)) return;
    try {
      if (_state.phase == DictationPhase.paused) {
        await _platform.resumeRecording(editor.sessionId);
        _startTimer();
        _setState(_state.copyWith(phase: DictationPhase.recording));
      } else if (_state.phase == DictationPhase.recording ||
          _state.phase == DictationPhase.correcting) {
        await _platform.pauseRecording(editor.sessionId);
        _pauseTimer();
        _setState(_state.copyWith(phase: DictationPhase.paused));
      }
    } on PlatformException catch (error) {
      await _abortWithError(error.code);
    } catch (_) {
      await _abortWithError('audio_state_failed');
    }
  }

  Future<void> cancel() async {
    final sessionId = _editor?.sessionId;
    await _platform.stopRecording();
    _stopTimer();
    await _closeClient();
    if (sessionId != null) await _platform.clearComposingText(sessionId);
    _partial = '';
    _setReadyState();
  }

  Future<void> switchBack() async {
    await cancel();
    await _platform.switchToPreviousInputMethod();
  }

  void _handlePlatformEvent(DictationPlatformEvent event) {
    switch (event) {
      case DictationEditorChanged(:final editor):
        unawaited(_applyEditor(editor));
      case DictationAudioChunk(:final sessionId, :final pcm, :final level):
        if (_isCurrent(sessionId)) _handleAudio(pcm, level);
      case DictationPlatformFailure(:final sessionId, :final code):
        if (_isCurrent(sessionId)) unawaited(_abortWithError(code));
    }
  }

  void _handleAudio(Uint8List pcm, double level) {
    if (_state.phase == DictationPhase.paused) return;
    final levels = [..._state.levels, level];
    if (levels.length > maximumLevels) levels.removeAt(0);
    _setState(_state.copyWith(levels: levels));
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
    final changed = _editor?.sessionId != editor.sessionId;
    final available = editor.visible && editor.supported;
    if (_state.isActive && (changed || !available)) await cancel();
    _editor = editor;
    _setState(
      _state.copyWith(
        phase: available ? DictationPhase.ready : DictationPhase.unavailable,
        visible: editor.visible,
        editorSupported: editor.supported,
        microphoneGranted: editor.microphoneGranted,
        clearError: true,
      ),
    );
  }

  Future<void> _refreshConfigurationLabel() async {
    final settings = await _settingsRepository.load();
    _setState(
      _state.copyWith(
        provider: settings.asrProvider,
        modelId: LiveDictationModelCatalog.modelFor(settings.asrProvider),
      ),
    );
  }

  Future<void> _abortWithError(String code) async {
    _fail(code);
    await _platform.stopRecording();
    _stopTimer();
    await _closeClient();
    final sessionId = _editor?.sessionId;
    if (sessionId != null) await _platform.clearComposingText(sessionId);
    _partial = '';
  }

  Future<void> _handleStartFailure(String sessionId, String code) async {
    if (!_isCurrent(sessionId) || _state.phase != DictationPhase.connecting) {
      return;
    }
    await _abortWithError(code);
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
            elapsed:
                _elapsedBeforeSegment + DateTime.now().difference(startedAt),
          ),
        );
      }
    });
  }

  void _pauseTimer() {
    final startedAt = _startedAt;
    if (startedAt != null) {
      _elapsedBeforeSegment += DateTime.now().difference(startedAt);
      _setState(_state.copyWith(elapsed: _elapsedBeforeSegment));
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
        preview: '',
        levels: const [],
        elapsed: Duration.zero,
        clearError: true,
      ),
    );
  }

  void _fail(String code) {
    _setState(_state.copyWith(phase: DictationPhase.error, errorCode: code));
  }

  bool _isCurrent(String sessionId) =>
      _editor?.sessionId == sessionId && _editor?.visible == true;

  void _setState(DictationState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _connected = false;
    _connectionGeneration++;
    _timer?.cancel();
    _timer = null;
    _startedAt = null;
    _elapsedBeforeSegment = Duration.zero;
    _config = null;
    _pendingAudio.clear();
    final platformSubscription = _platformSubscription;
    final clientSubscription = _clientSubscription;
    final client = _client;
    _platformSubscription = null;
    _clientSubscription = null;
    _client = null;
    unawaited(platformSubscription?.cancel());
    unawaited(clientSubscription?.cancel());
    unawaited(client?.close());
    unawaited(_platform.stopRecording());
    super.dispose();
  }

  static const int maximumLevels = 28;
  static const int maximumPendingChunks = 12;
}
