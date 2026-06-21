import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../data/models/transcript_note.dart';
import '../../../state/recording_controller.dart';
import '../../../state/settings_controller.dart';
import '../../navigation.dart';
import '../../widgets/buttons.dart';
import '../../widgets/waveforms.dart';

/// In-app recording screen with a live timer + waveform. Stopping flows into the
/// same processing → detail pipeline as file import and share.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    final ok = await ref.read(recordingControllerProvider.notifier).start();
    if (!ok && mounted) {
      _showPermissionError();
    }
  }

  void _showPermissionError() {
    final t = ref.read(stringsProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${t.micPermissionTitle}: ${t.micPermissionBody}')),
    );
  }

  Future<void> _stop() async {
    final result = await ref.read(recordingControllerProvider.notifier).stop();
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop();
      return;
    }
    // Replace the record screen with processing so that, after processing swaps
    // itself for the detail screen, back from detail returns to home — not to a
    // lingering record screen.
    await AppNavigator.startProcessing(
      context,
      audioPath: result.path,
      source: NoteSource.recording,
      knownDurationSec: result.durationSec,
      replace: true,
    );
  }

  Future<void> _cancel() async {
    await ref.read(recordingControllerProvider.notifier).cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    // Only watch the fields that change rarely here. The elapsed timer and the
    // live waveform update several times per second, so they live in their own
    // [Consumer]s below — otherwise the whole screen (status pill, buttons with
    // shadows, the large mono timer) would rebuild on every amplitude tick.
    final paused = ref.watch(recordingControllerProvider.select((s) => s.paused));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: palette.bg,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 6),
                child: Row(
                  children: [
                    IconCircleButton(icon: Icons.close_rounded, onTap: _cancel),
                    Expanded(
                      child: Text(
                        t.recTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: palette.ink),
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatusPill(paused: paused, strings: t),
                      const SizedBox(height: 26),
                      Consumer(
                        builder: (context, ref, _) {
                          final sec = ref.watch(
                              recordingControllerProvider.select((s) => s.elapsedSec));
                          return Text(
                            formatDuration(sec),
                            style:
                                AppTheme.mono(color: palette.ink, size: 54, weight: FontWeight.w800),
                          );
                        },
                      ),
                      const SizedBox(height: 26),
                      Consumer(
                        builder: (context, ref, _) {
                          final levels = ref.watch(
                              recordingControllerProvider.select((s) => s.levels));
                          return RecordWave(levels: levels, paused: paused);
                        },
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 14, color: palette.mint),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              t.recHint,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: palette.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(36, 16, 36, 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _SmallAction(
                      icon: Icons.delete_outline_rounded,
                      label: t.recCancel,
                      color: palette.coralInk,
                      onTap: _cancel,
                    ),
                    _StopButton(label: t.recStopShort, onTap: _stop),
                    _SmallAction(
                      icon: paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      label: paused ? t.recResume : t.recPause,
                      color: palette.body,
                      onTap: ref.read(recordingControllerProvider.notifier).togglePause,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.paused, required this.strings});
  final bool paused;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = paused ? palette.muted : palette.coralInk;
    final dot = paused ? palette.faint : palette.coral;
    final bg = paused ? palette.chip : palette.coralSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            paused ? strings.recPaused : strings.recording,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: palette.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.45),
                  blurRadius: 32,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7)),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: palette.accent)),
        ],
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(color: palette.chip, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.muted)),
        ],
      ),
    );
  }
}
