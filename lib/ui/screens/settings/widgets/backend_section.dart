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
    final t = ref.watch(stringsProvider);
    final settings = ref.watch(settingsControllerProvider);
    final ctrl = ref.read(settingsControllerProvider.notifier);
    final german = t.isDe;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (settings.summarizeEnabled && settings.summaryMode.isLocal) ...[
            Text(
              german ? 'Backend (Zusammenfassung)' : 'Backend (summary)',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink),
            ),
            const SizedBox(height: 10),
            AnimatedSegmentedControl(
              options: [for (final b in InferenceBackend.values) SegmentOption(b.label)],
              selectedIndex: InferenceBackend.values.indexOf(settings.gemmaBackend),
              onChanged: (i) => ctrl.setGemmaBackend(InferenceBackend.values[i]),
            ),
            const SizedBox(height: 8),
            Text(
              german ? 'GPU am schnellsten · NPU ist geräteabhängig' : 'GPU is fastest · NPU is device-dependent',
              style: TextStyle(fontSize: 12.5, color: palette.muted),
            ),
          ],
          if (settings.summarizeEnabled && settings.summaryMode.isLocal && settings.asrMode.isLocal)
            Divider(height: 28, color: palette.line),
          if (settings.asrMode.isLocal) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  german ? 'Whisper-Threads (CPU)' : 'Whisper threads (CPU)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: palette.ink),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: palette.accentSoft, borderRadius: BorderRadius.circular(9999)),
                  child: Text(
                    '${settings.whisperThreads}',
                    style: AppTheme.mono(color: palette.accentDeep, size: 13, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: palette.accent,
                inactiveTrackColor: palette.line2,
                thumbColor: palette.accent,
                overlayColor: palette.accent.withValues(alpha: 0.12),
                trackHeight: 4,
              ),
              child: Slider(
                value: settings.whisperThreads.toDouble().clamp(1, 8),
                min: 1,
                max: 8,
                divisions: 7,
                label: '${settings.whisperThreads}',
                onChanged: (v) => ctrl.setWhisperThreads(v.round()),
              ),
            ),
            Text(
              german
                  ? 'Mehr Threads = schneller, aber höhere CPU-Last. Transkription läuft immer auf der CPU.'
                  : 'More threads = faster, but higher CPU load. Transcription always runs on the CPU.',
              style: TextStyle(fontSize: 12.5, color: palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}
