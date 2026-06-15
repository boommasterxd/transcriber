import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatting.dart';
import '../../../widgets/waveforms.dart';

/// Audio player card with a seekable waveform. Falls back to a disabled state
/// when the source audio was auto-deleted after processing.
class DetailAudioPlayer extends StatefulWidget {
  const DetailAudioPlayer({super.key, required this.audioPath, required this.durationSec});

  final String audioPath;
  final int durationSec;

  @override
  State<DetailAudioPlayer> createState() => _DetailAudioPlayerState();
}

class _DetailAudioPlayerState extends State<DetailAudioPlayer> {
  AudioPlayer? _player;
  bool _ready = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  bool get _hasAudio => File(widget.audioPath).existsSync();

  @override
  void initState() {
    super.initState();
    if (_hasAudio) _init();
  }

  Future<void> _init() async {
    final player = AudioPlayer();
    _player = player;
    try {
      final duration = await player.setFilePath(widget.audioPath);
      _total = duration ?? Duration(seconds: widget.durationSec);
      player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      player.playerStateStream.listen((s) {
        if (!mounted) return;
        setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
        if (s.processingState == ProcessingState.completed) {
          player.seek(Duration.zero);
          player.pause();
        }
      });
      setState(() => _ready = true);
    } catch (_) {
      setState(() => _ready = false);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player == null || !_ready) return;
    if (_playing) {
      await player.pause();
    } else {
      if (_position >= _total) await player.seek(Duration.zero);
      await player.play();
    }
  }

  void _seek(double fraction) {
    if (!_ready) return;
    _player?.seek(_total * fraction);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final totalSec = _total.inSeconds == 0 ? widget.durationSec : _total.inSeconds;
    final progress = totalSec == 0 ? 0.0 : (_position.inMilliseconds / (totalSec * 1000)).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: palette.chip, borderRadius: BorderRadius.circular(18)),
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
                child: Icon(_playing ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          PlayerWave(progress: progress, onSeek: _hasAudio ? _seek : null),
          const SizedBox(width: 12),
          SizedBox(
            width: 62,
            child: Text(
              '${formatDuration((progress * totalSec).round())} / ${formatDuration(totalSec)}',
              textAlign: TextAlign.right,
              style: AppTheme.mono(color: palette.muted, size: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
