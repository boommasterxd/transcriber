import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/inference_backend.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/segmented_control.dart';
import '../../../widgets/surfaces.dart';

/// On-device performance controls: the Gemma summary compute backend
/// (Auto/GPU/CPU/NPU) and the Whisper transcription thread count. Each part
/// only shows when the corresponding stage runs on-device.
class BackendSection extends ConsumerWidget {
  const BackendSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final visibility = ref.watch(
      settingsControllerProvider.select(
        (settings) => (
          showSummary:
              settings.summarizeEnabled && settings.summaryMode.isLocal,
          showTranscription: settings.asrMode.isLocal,
        ),
      ),
    );
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visibility.showSummary) const _SummaryBackendControl(),
          if (visibility.showSummary && visibility.showTranscription)
            Divider(height: 28, color: palette.line),
          if (visibility.showTranscription)
            const _TranscriptionThreadsControl(),
        ],
      ),
    );
  }
}

class _SummaryBackendControl extends ConsumerWidget {
  const _SummaryBackendControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final backend = ref.watch(
      settingsControllerProvider.select((settings) => settings.gemmaBackend),
    );
    final controller = ref.read(settingsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.backendSummary,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSegmentedControl(
          options: [
            for (final value in InferenceBackend.values)
              SegmentOption(value.label),
          ],
          selectedIndex: InferenceBackend.values.indexOf(backend),
          onChanged: (index) =>
              controller.setGemmaBackend(InferenceBackend.values[index]),
        ),
        const SizedBox(height: 8),
        Text(
          t.backendHint,
          style: TextStyle(fontSize: 12.5, color: palette.muted),
        ),
      ],
    );
  }
}

class _TranscriptionThreadsControl extends ConsumerWidget {
  const _TranscriptionThreadsControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final threads = ref.watch(
      settingsControllerProvider.select((settings) => settings.whisperThreads),
    );
    final controller = ref.read(settingsControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ThreadCountHeader(label: t.whisperThreads, count: threads),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: palette.accent,
            inactiveTrackColor: palette.line2,
            thumbColor: palette.accent,
            overlayColor: palette.accent.withValues(alpha: 0.12),
            trackHeight: 4,
          ),
          child: Slider(
            value: threads.toDouble().clamp(1, 8),
            min: 1,
            max: 8,
            divisions: 7,
            label: '$threads',
            onChanged: (value) => controller.setWhisperThreads(value.round()),
          ),
        ),
        Text(
          t.whisperThreadsHint,
          style: TextStyle(fontSize: 12.5, color: palette.muted),
        ),
      ],
    );
  }
}

class _ThreadCountHeader extends StatelessWidget {
  const _ThreadCountHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: palette.ink,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: palette.accentSoft,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Text(
            '$count',
            style: AppTheme.mono(
              color: palette.accentDeep,
              size: 13,
              weight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
