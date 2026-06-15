import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatting.dart';
import '../../../../data/catalog/gemma_catalog.dart';
import '../../../../data/catalog/whisper_catalog.dart';
import '../../../../data/models/processing_mode.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/model_tile.dart';
import '../../../widgets/segmented_control.dart';
import '../../../widgets/surfaces.dart';
import '../../settings/widgets/stage_explainer.dart';
import '../../settings/widgets/summary_section.dart';
import '../../settings/widgets/transcription_section.dart';

/// Onboarding model step with a simple recommended path and an advanced mode.
class OnboardingModelsStep extends ConsumerStatefulWidget {
  const OnboardingModelsStep({super.key});

  @override
  ConsumerState<OnboardingModelsStep> createState() => _OnboardingModelsStepState();
}

class _OnboardingModelsStepState extends ConsumerState<OnboardingModelsStep> {
  bool _advanced = false;

  static const _whisperId = WhisperCatalog.defaultId; // Whisper Base (recommended)
  static const _gemmaId = GemmaCatalog.defaultId; // Gemma 3 1B (recommended)

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _downloadRecommended() async {
    final settingsCtrl = ref.read(settingsControllerProvider.notifier);
    final managerCtrl = ref.read(modelManagerControllerProvider.notifier);
    // Lock in the recommended on-device setup, then download both models.
    await settingsCtrl.setAsrMode(ProcessingMode.onDevice);
    await settingsCtrl.setSummaryMode(ProcessingMode.onDevice);
    await settingsCtrl.setWhisperModel(_whisperId);
    await settingsCtrl.setGemmaModel(_gemmaId);
    await _guard(() => managerCtrl.downloadWhisper(_whisperId));
    await _guard(() => managerCtrl.downloadGemma(_gemmaId));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSegmentedControl(
          options: [SegmentOption(t.obSimple), SegmentOption(t.obAdvanced)],
          selectedIndex: _advanced ? 1 : 0,
          onChanged: (i) => setState(() => _advanced = i == 1),
        ),
        const SizedBox(height: 16),
        if (_advanced)
          const Column(
            children: [
              TranscriptionSection(),
              SizedBox(height: 20),
              SummarySection(),
            ],
          )
        else
          _RecommendedCard(
            whisperId: _whisperId,
            gemmaId: _gemmaId,
            onDownload: _downloadRecommended,
          ),
      ],
    );
  }
}

class _RecommendedCard extends ConsumerWidget {
  const _RecommendedCard({required this.whisperId, required this.gemmaId, required this.onDownload});

  final String whisperId;
  final String gemmaId;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final manager = ref.watch(modelManagerControllerProvider);
    final whisper = WhisperCatalog.byId(whisperId);
    final gemma = GemmaCatalog.byId(gemmaId);
    final wStatus = manager.whisperStatus(whisperId);
    final gStatus = manager.gemmaStatus(gemmaId);
    final german = t.isDe;

    final bothDone = wStatus.isDownloaded && gStatus.isDownloaded;
    final downloading = wStatus.isDownloading || gStatus.isDownloading;

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.obRecommendedSetup,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: palette.ink),
          ),
          const SizedBox(height: 10),
          StageExplainer(text: t.asrExplain),
          const SizedBox(height: 6),
          StageExplainer(text: t.summaryExplain),
          const SizedBox(height: 14),
          _RecRow(
            icon: Icons.graphic_eq_rounded,
            name: whisper.displayName,
            sub: '${formatBytes(whisper.sizeBytes, german: german)} · ${whisper.badge.label(t.language)}',
            status: wStatus,
          ),
          const SizedBox(height: 8),
          _RecRow(
            icon: Icons.auto_awesome_outlined,
            name: gemma.displayName,
            sub: '${formatBytes(gemma.sizeBytes, german: german)} · ${gemma.badge.label(t.language)}',
            status: gStatus,
          ),
          const SizedBox(height: 16),
          if (bothDone)
            Row(
              children: [
                Icon(Icons.check_circle_rounded, size: 18, color: palette.mint),
                const SizedBox(width: 8),
                Text(
                  german ? 'Modelle bereit' : 'Models ready',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.mint),
                ),
              ],
            )
          else
            PillButton(
              label: downloading ? t.downloading : t.obDownloadGo,
              icon: downloading ? null : Icons.download_rounded,
              height: 52,
              onTap: downloading ? () {} : () => onDownload(),
            ),
        ],
      ),
    );
  }
}

class _RecRow extends StatelessWidget {
  const _RecRow({required this.icon, required this.name, required this.sub, required this.status});

  final IconData icon;
  final String name;
  final String sub;
  final ModelStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget trailing;
    switch (status.status) {
      case DownloadStatus.downloading:
        trailing = ProgressRing(progress: status.progress);
      case DownloadStatus.downloaded:
        trailing = Icon(Icons.check_circle_rounded, size: 22, color: palette.mint);
      case DownloadStatus.notDownloaded:
        trailing = Icon(Icons.arrow_downward_rounded, size: 18, color: palette.faint);
    }
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: palette.accentSoft2, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, size: 18, color: palette.accent),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.ink)),
              Text(sub, style: TextStyle(fontSize: 12, color: palette.muted)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        trailing,
      ],
    );
  }
}
