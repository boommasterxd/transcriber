import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/inference_backend.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/segmented_control.dart';
import '../../../widgets/surfaces.dart';

/// Global compute-backend selector for on-device processing. Controls the Gemma
/// summary backend (Auto/GPU/CPU/NPU); transcription (Whisper) is CPU-only by
/// the underlying library, which the hint makes explicit.
class BackendSection extends ConsumerWidget {
  const BackendSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final backend = ref.watch(settingsControllerProvider.select((s) => s.gemmaBackend));
    final ctrl = ref.read(settingsControllerProvider.notifier);

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSegmentedControl(
            options: [for (final b in InferenceBackend.values) SegmentOption(b.label)],
            selectedIndex: InferenceBackend.values.indexOf(backend),
            onChanged: (i) => ctrl.setGemmaBackend(InferenceBackend.values[i]),
          ),
          const SizedBox(height: 10),
          Text(
            t.isDe
                ? 'Steuert die On-Device-Zusammenfassung (Gemma). Transkription (Whisper) läuft immer auf der CPU. NPU ist geräteabhängig.'
                : 'Controls the on-device summary (Gemma). Transcription (Whisper) always runs on the CPU. NPU is device-dependent.',
            style: TextStyle(fontSize: 12.5, height: 1.4, color: palette.muted),
          ),
        ],
      ),
    );
  }
}
