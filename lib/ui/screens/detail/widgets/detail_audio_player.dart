import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatting.dart';
import '../../../widgets/waveforms.dart';

typedef DetailAudioPlayerFactory = DetailAudioPlayerPort Function();

abstract interface class DetailAudioPlayerPort {
  Stream<Duration> get positionStream;

  Stream<DetailPlaybackState> get playbackStateStream;

  Future<Duration?> load(String path);

  Future<void> play();

  Future<void> pause();

  Future<void> seek(Duration position);

  Future<void> dispose();
}

class DetailPlaybackState {
  const DetailPlaybackState({required this.playing, required this.completed});

  final bool playing;
  final bool completed;
}

DetailAudioPlayerPort createDefaultDetailAudioPlayer() =>
    _JustAudioPlayerPort(AudioPlayer());

class _JustAudioPlayerPort implements DetailAudioPlayerPort {
  _JustAudioPlayerPort(this._player);

  final AudioPlayer _player;

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<DetailPlaybackState> get playbackStateStream =>
      _player.playerStateStream.map(
        (state) => DetailPlaybackState(
          playing: state.playing,
          completed: state.processingState == ProcessingState.completed,
        ),
      );

  @override
  Future<Duration?> load(String path) => _player.setFilePath(path);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}

/// Audio player card with a seekable waveform. Falls back to a disabled state
/// when the source audio was auto-deleted after processing.
class DetailAudioPlayer extends StatefulWidget {
  const DetailAudioPlayer({
    super.key,
    required this.audioPath,
    required this.durationSec,
    this.playerFactory = createDefaultDetailAudioPlayer,
  });

  final String audioPath;
  final int durationSec;
  final DetailAudioPlayerFactory playerFactory;

  @override
  State<DetailAudioPlayer> createState() => _DetailAudioPlayerState();
}

class _DetailAudioPlayerState extends State<DetailAudioPlayer> {
  DetailAudioPlayerPort? _player;
  Future<DetailAudioPlayerPort?>? _initialization;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<DetailPlaybackState>? _playbackSubscription;
  Future<void>? _completionOperation;
  Future<void>? _seekOperation;
  double? _pendingSeek;
  int _sourceGeneration = 0;
  bool _sourceAvailable = false;
  bool _preparingPlayback = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  /// Waveform bucket currently filled. Used to throttle rebuilds so the
  /// position stream only triggers a repaint when something visible changes.
  int _bucket = -1;

  Duration get _effectiveTotal {
    if (_total > Duration.zero) return _total;
    if (widget.durationSec <= 0) return Duration.zero;
    return Duration(seconds: widget.durationSec);
  }

  @override
  void initState() {
    super.initState();
    unawaited(_checkSource());
  }

  @override
  void didUpdateWidget(covariant DetailAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioPath == widget.audioPath) return;
    _sourceGeneration++;
    _releasePlayer();
    _sourceAvailable = false;
    _preparingPlayback = false;
    _seekOperation = null;
    _pendingSeek = null;
    _playing = false;
    _position = Duration.zero;
    _total = Duration.zero;
    _bucket = -1;
    unawaited(_checkSource());
  }

  Future<void> _checkSource() async {
    final generation = _sourceGeneration;
    try {
      if (await File(widget.audioPath).exists() && _isCurrent(generation)) {
        setState(() => _sourceAvailable = true);
      }
    } on FileSystemException {
      // An inaccessible file leaves playback disabled.
    }
  }

  bool _isCurrent(int generation) => mounted && _sourceGeneration == generation;

  Future<DetailAudioPlayerPort?> _loadPlayer() =>
      _initialization ??= _initialize(_sourceGeneration);

  Future<DetailAudioPlayerPort?> _initialize(int generation) async {
    try {
      final player = _player = widget.playerFactory();
      final duration = await player.load(widget.audioPath);
      if (!_isCurrent(generation)) return null;
      _positionSubscription = player.positionStream.listen((position) {
        if (identical(_player, player)) _handlePosition(position);
      });
      _playbackSubscription = player.playbackStateStream.listen(
        (state) => _handlePlaybackState(player, state),
      );
      setState(() => _total = duration ?? Duration.zero);
      return player;
    } catch (_) {
      if (_isCurrent(generation)) {
        _releasePlayer();
        setState(() => _sourceAvailable = false);
      }
      return null;
    }
  }

  void _handlePosition(Duration position) {
    if (!mounted) return;
    // The label and waveform only change at coarse visual boundaries. Skipping
    // intermediate stream ticks avoids repainting every bar.
    final bucket = _bucketFor(position);
    final secondsChanged = position.inSeconds != _position.inSeconds;
    _position = position;
    if (secondsChanged || bucket != _bucket) {
      _bucket = bucket;
      setState(() {});
    }
  }

  void _handlePlaybackState(
    DetailAudioPlayerPort player,
    DetailPlaybackState state,
  ) {
    if (!mounted || !identical(_player, player)) return;
    setState(() {
      _playing = state.playing && !state.completed;
      if (state.completed) {
        _position = Duration.zero;
        _bucket = 0;
      }
    });
    if (state.completed) {
      _completionOperation ??= _resetCompletedPlayback(player).whenComplete(() {
        if (identical(_player, player)) _completionOperation = null;
      });
    }
  }

  Future<void> _resetCompletedPlayback(DetailAudioPlayerPort player) async {
    try {
      await player.seek(Duration.zero);
      if (!mounted || !identical(_player, player)) return;
      await player.pause();
    } catch (_) {
      // Disposal can invalidate an in-flight platform operation.
    }
  }

  int _bucketFor(Duration position) {
    final totalMilliseconds = _effectiveTotal.inMilliseconds;
    if (totalMilliseconds == 0) return 0;
    return ((position.inMilliseconds / totalMilliseconds) *
            PlayerWave.defaultBars)
        .floor();
  }

  @override
  void dispose() {
    _sourceGeneration++;
    _releasePlayer();
    super.dispose();
  }

  void _releasePlayer() {
    final player = _player;
    _player = null;
    _initialization = null;
    _completionOperation = null;
    unawaited(_positionSubscription?.cancel());
    unawaited(_playbackSubscription?.cancel());
    _positionSubscription = null;
    _playbackSubscription = null;
    if (player != null) unawaited(_disposePlayer(player));
  }

  Future<void> _disposePlayer(DetailAudioPlayerPort player) async {
    try {
      await player.dispose();
    } catch (_) {
      // A platform load may still be unwinding during disposal.
    }
  }

  Future<void> _toggle() async {
    if (!_sourceAvailable || _preparingPlayback) return;
    final generation = _sourceGeneration;
    final player = await _preparePlayback(generation);
    if (!_isCurrent(generation) || player == null) return;
    try {
      await player.play();
    } catch (_) {
      // Playback may be interrupted when the route or source changes.
    }
  }

  Future<DetailAudioPlayerPort?> _preparePlayback(int generation) async {
    _preparingPlayback = true;
    try {
      final player = await _loadPlayer();
      await _completionOperation;
      if (player == null || !_isCurrent(generation)) return null;
      if (_playing) {
        await player.pause();
        return null;
      }
      await _seekOperation;
      if (!_isCurrent(generation)) return null;
      if (_effectiveTotal > Duration.zero && _position >= _effectiveTotal) {
        await player.seek(Duration.zero);
      }
      return player;
    } catch (_) {
      return null;
    } finally {
      if (_isCurrent(generation)) _preparingPlayback = false;
    }
  }

  void _seek(double fraction) {
    if (!_sourceAvailable) return;
    _pendingSeek = fraction.clamp(0.0, 1.0);
    _seekOperation ??= _applySeeks(_sourceGeneration);
  }

  Future<void> _applySeeks(int generation) async {
    try {
      final player = await _loadPlayer();
      await _completionOperation;
      if (player == null) return;
      while (_isCurrent(generation) && _pendingSeek != null) {
        final fraction = _pendingSeek!;
        _pendingSeek = null;
        try {
          await player.seek(_effectiveTotal * fraction);
        } catch (_) {
          // A later input can still be applied if this seek was interrupted.
        }
      }
    } finally {
      if (_isCurrent(generation)) {
        _seekOperation = null;
        _pendingSeek = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strings = AppStrings.of(
      Localizations.localeOf(context).languageCode == 'de'
          ? AppLanguage.de
          : AppLanguage.en,
    );
    final total = _effectiveTotal;
    final progress = total == Duration.zero
        ? 0.0
        : (_position.inMicroseconds / total.inMicroseconds).clamp(0.0, 1.0);
    String positionLabel(double fraction) => formatDuration(
      (fraction * total.inMicroseconds / Duration.microsecondsPerSecond)
          .round(),
    );
    final totalLabel = positionLabel(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton.filled(
            onPressed: _sourceAvailable ? _toggle : null,
            tooltip: _playing ? strings.audioPause : strings.audioPlay,
            style:
                IconButton.styleFrom(
                  minimumSize: const Size.square(48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                ).copyWith(
                  side: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.focused)
                        ? BorderSide(color: palette.ink, width: 2)
                        : null,
                  ),
                ),
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PlayerWave(
                  progress: progress,
                  label: strings.audioPosition,
                  semanticFormatterCallback: (fraction) => strings
                      .audioPositionValue(positionLabel(fraction), totalLabel),
                  onSeek: _sourceAvailable && total > Duration.zero
                      ? _seek
                      : null,
                ),
                ExcludeSemantics(
                  child: Text(
                    '${positionLabel(progress)} / $totalLabel',
                    textAlign: TextAlign.end,
                    style: AppTheme.mono(color: palette.muted, size: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
