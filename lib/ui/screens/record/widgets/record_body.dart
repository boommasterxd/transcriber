import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../state/recording_controller.dart';
import '../../../widgets/waveforms.dart';

/// Main recording content, including status, timer, waveform and privacy hint.
class RecordBody extends StatelessWidget {
  const RecordBody({super.key, required this.paused, required this.strings});

  final bool paused;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RecordStatusPill(paused: paused, strings: strings),
          const SizedBox(height: 26),
          const _RecordTimer(),
          const SizedBox(height: 26),
          _RecordWaveform(paused: paused),
          const SizedBox(height: 24),
          _RecordHint(text: strings.recHint),
        ],
      ),
    );
  }
}

/// Displays whether recording is active or paused.
class RecordStatusPill extends StatelessWidget {
  const RecordStatusPill({
    super.key,
    required this.paused,
    required this.strings,
  });

  final bool paused;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = paused ? palette.muted : palette.coralInk;
    final dot = paused ? palette.faint : palette.coral;
    final background = paused ? palette.chip : palette.coralSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            paused ? strings.recPaused : strings.recording,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordTimer extends ConsumerWidget {
  const _RecordTimer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seconds = ref.watch(
      recordingControllerProvider.select((state) => state.elapsedSec),
    );
    return Text(
      formatDuration(seconds),
      style: AppTheme.mono(
        color: context.palette.ink,
        size: 54,
        weight: FontWeight.w800,
      ),
    );
  }
}

class _RecordWaveform extends ConsumerWidget {
  const _RecordWaveform({required this.paused});

  final bool paused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levels = ref.watch(
      recordingControllerProvider.select((state) => state.levels),
    );
    return RecordWave(levels: levels, paused: paused);
  }
}

class _RecordHint extends StatelessWidget {
  const _RecordHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.shield_outlined, size: 14, color: palette.mint),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.muted),
          ),
        ),
      ],
    );
  }
}
