import 'package:flutter/material.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../services/processing/processing_pipeline.dart';
import '../../../../services/processing/processing_profile.dart';
import '../../../../state/processing_controller.dart';
import '../../../widgets/effects.dart';

class ProcessingStatusPresentation {
  const ProcessingStatusPresentation({
    required this.title,
    required this.statusText,
    required this.isLocal,
    required this.showSteps,
    required this.activeStepIsSecond,
  });

  factory ProcessingStatusPresentation.forScreen({
    required AppStrings strings,
    required ProcessingState state,
    required ProcessingProfile profile,
    required bool summarizeEnabled,
  }) {
    final stage = _stageFor(state, profile);
    return ProcessingStatusPresentation(
      title: _titleFor(strings, state),
      statusText:
          _downloadStatus(strings, state) ?? '${stage.name} · ${stage.sub}',
      isLocal: stage.isLocal,
      showSteps: summarizeEnabled,
      activeStepIsSecond: state.step == ProcessingStep.summarizing,
    );
  }

  factory ProcessingStatusPresentation.forShareSheet({
    required AppStrings strings,
    required ProcessingState state,
    required ProcessingProfile profile,
    required bool summarizeEnabled,
  }) {
    final stage = _stageFor(state, profile);
    final stageStatus = stage.isLocal
        ? '${strings.runningLocal} · ${stage.name}'
        : '${stage.name} · ${stage.sub}';
    return ProcessingStatusPresentation(
      title: _titleFor(strings, state),
      statusText: _downloadStatus(strings, state) ?? stageStatus,
      isLocal: stage.isLocal,
      showSteps: summarizeEnabled,
      activeStepIsSecond: state.step == ProcessingStep.summarizing,
    );
  }

  final String title;
  final String statusText;
  final bool isLocal;
  final bool showSteps;
  final bool activeStepIsSecond;

  static StageInfo _stageFor(ProcessingState state, ProcessingProfile profile) {
    return state.step == ProcessingStep.transcribing
        ? profile.asr
        : profile.summary;
  }

  static String _titleFor(AppStrings strings, ProcessingState state) {
    return state.step == ProcessingStep.transcribing
        ? strings.shTranscribe
        : strings.shSummarize;
  }

  static String? _downloadStatus(AppStrings strings, ProcessingState state) {
    final progress = state.modelProgress;
    if (progress == null) return null;
    return '${strings.downloading} ${(progress * 100).round()}%';
  }
}

class ProcessingStatusContent extends StatelessWidget {
  const ProcessingStatusContent({
    super.key,
    required this.presentation,
    required this.strings,
    this.fileName,
  });

  final ProcessingStatusPresentation presentation;
  final AppStrings strings;
  final String? fileName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PulseRingHero(),
        SizedBox(height: fileName == null ? 18 : 14),
        if (fileName != null) ...[
          ProcessingFileChip(name: fileName!),
          const SizedBox(height: 18),
        ],
        _StatusText(presentation: presentation),
        if (presentation.showSteps) ...[
          const SizedBox(height: 28),
          StepIndicator(
            step1Label: strings.shStep1,
            step2Label: strings.shStep2,
            activeStepIsSecond: presentation.activeStepIsSecond,
          ),
        ],
      ],
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.presentation});

  final ProcessingStatusPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Text(
          presentation.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: presentation.isLocal ? palette.mint : palette.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                presentation.statusText,
                style: TextStyle(fontSize: 13, color: palette.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ProcessingFileChip extends StatelessWidget {
  const ProcessingFileChip({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (name.isEmpty) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_outlined,
            size: 14,
            color: palette.accent,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
