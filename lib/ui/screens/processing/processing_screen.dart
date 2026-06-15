import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/processing/processing_pipeline.dart';
import '../../../services/processing/processing_profile.dart';
import '../../../services/service_exceptions.dart';
import '../../../state/processing_controller.dart';
import '../../../state/settings_controller.dart';
import '../../navigation.dart';
import '../../widgets/buttons.dart';
import '../../widgets/effects.dart';
import '../detail/transcript_detail_screen.dart';
import 'widgets/processing_error_view.dart';

/// Full-screen processing view. Runs the pipeline and, on success, replaces
/// itself with the transcript detail screen.
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({
    super.key,
    required this.audioPath,
    required this.source,
    this.fileName,
    this.knownDurationSec,
  });

  final String audioPath;
  final NoteSource source;
  final String? fileName;
  final int? knownDurationSec;

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  void _start() {
    ref.read(processingControllerProvider.notifier).run(
          audioPath: widget.audioPath,
          source: widget.source,
          fileName: widget.fileName,
          knownDurationSec: widget.knownDurationSec,
        );
  }

  void _onResult(TranscriptNote note) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TranscriptDetailScreen(noteId: note.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final state = ref.watch(processingControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final profile = ProcessingProfile.resolve(settings);
    final transcribing = state.step == ProcessingStep.transcribing;
    final stage = transcribing ? profile.asr : profile.summary;
    final modelLabel = '${stage.name} · ${stage.sub}';
    final isLocal = stage.isLocal;

    ref.listen(processingControllerProvider, (prev, next) {
      if (next.result != null) _onResult(next.result!);
    });

    if (state.hasError) {
      return ProcessingErrorView(
        error: state.error!,
        strings: t,
        isModelMissing: state.error is ModelNotDownloadedException,
        onRetry: () {
          ref.read(processingControllerProvider.notifier).reset();
          _start();
        },
        onClose: () => Navigator.of(context).pop(),
        onOpenSettings: () => AppNavigator.openSettings(context),
      );
    }

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const PulseRingHero(),
              const SizedBox(height: 14),
              _FileChip(name: state.fileName.isEmpty ? (widget.fileName ?? '') : state.fileName),
              const SizedBox(height: 18),
              Text(
                transcribing ? t.shTranscribe : t.shSummarize,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: palette.ink),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isLocal ? palette.mint : palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      state.modelProgress != null
                          ? '${t.downloading} ${(state.modelProgress! * 100).round()}%'
                          : modelLabel,
                      style: TextStyle(fontSize: 13, color: palette.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              StepIndicator(
                step1Label: t.shStep1,
                step2Label: t.shStep2,
                activeStepIsSecond: !transcribing,
              ),
              const SizedBox(height: 30),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: const SkeletonLines(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.name});
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
        boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 14, color: palette.accent),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}
