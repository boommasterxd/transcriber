import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

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
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<DetailPlaybackState>? _playbackSubscription;
  bool _hasAudio = false;
  bool _ready = false;
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

  int get _totalSeconds => _effectiveTotal.inSeconds;

  @override
  void initState() {
    super.initState();
    _hasAudio = File(widget.audioPath).existsSync();
    if (_hasAudio) unawaited(_initialize());
  }

  Future<void> _initialize() async {
    final player = widget.playerFactory();
    _player = player;
    try {
      final duration = await player.load(widget.audioPath);
      if (!mounted || !identical(_player, player)) return;
      _total = duration ?? Duration(seconds: widget.durationSec);
      _positionSubscription = player.positionStream.listen(_handlePosition);
      _playbackSubscription = player.playbackStateStream.listen(
        (state) => _handlePlaybackState(player, state),
      );
      setState(() => _ready = true);
    } catch (_) {
      if (!identical(_player, player)) return;
      _player = null;
      await player.dispose();
      if (mounted) setState(() => _ready = false);
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
    if (state.completed) unawaited(_resetCompletedPlayback(player));
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
    unawaited(_positionSubscription?.cancel());
    unawaited(_playbackSubscription?.cancel());
    final player = _player;
    _player = null;
    if (player != null) unawaited(player.dispose());
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player == null || !_ready) return;
    if (_playing) {
      await player.pause();
      return;
    }
    if (_position >= _effectiveTotal) await player.seek(Duration.zero);
    await player.play();
  }

  void _seek(double fraction) {
    final player = _player;
    if (player == null || !_ready) return;
    final clampedFraction = fraction.clamp(0.0, 1.0);
    unawaited(player.seek(_effectiveTotal * clampedFraction));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final totalSec = _totalSeconds;
    final progress = totalSec == 0
        ? 0.0
        : (_position.inMilliseconds / (totalSec * 1000)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: palette.chip,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _hasAudio ? _toggle : null,
            child: Opacity(
              opacity: _hasAudio ? 1 : 0.5,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          PlayerWave(progress: progress, onSeek: _hasAudio ? _seek : null),
          const SizedBox(width: 12),
          // The waveform shrinks instead of wrapping this timestamp.
          Text(
            '${formatDuration((progress * totalSec).round())} / ${formatDuration(totalSec)}',
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.right,
            style: AppTheme.mono(color: palette.muted, size: 11.5),
          ),
        ],
      ),
    );
  }
}
