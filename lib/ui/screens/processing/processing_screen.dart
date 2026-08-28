import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/processing/processing_profile.dart';
import '../../../services/processing/processing_request.dart';
import '../../../state/processing_controller.dart';
import '../../../state/settings_controller.dart';
import '../../navigation.dart';
import '../detail/transcript_detail_screen.dart';
import 'widgets/processing_error_view.dart';
import 'widgets/processing_status_content.dart';

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
    ref
        .read(processingControllerProvider.notifier)
        .run(
          ProcessingInput(
            audioPath: widget.audioPath,
            source: widget.source,
            knownDurationSec: widget.knownDurationSec,
          ),
          fileName: widget.fileName,
        );
  }

  void _onResult(TranscriptNote note) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TranscriptDetailScreen(noteId: note.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final state = ref.watch(processingControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final profile = ProcessingProfile.resolve(settings);
    final presentation = ProcessingStatusPresentation.forScreen(
      strings: t,
      state: state,
      profile: profile,
      summarizeEnabled: settings.summarizeEnabled,
    );

    ref.listen(processingControllerProvider, (prev, next) {
      if (next.result != null) _onResult(next.result!);
    });

    if (state.hasError) {
      return ProcessingErrorView(
        presentation: ProcessingErrorPresentation.resolve(state.error!, t),
        actions: ProcessingErrorActions(
          onRetry: () {
            ref.read(processingControllerProvider.notifier).reset();
            _start();
          },
          onClose: () => Navigator.of(context).pop(),
          onOpenSettings: () => AppNavigator.openSettings(context),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 34),
          child: Center(
            child: ProcessingStatusContent(
              presentation: presentation,
              strings: t,
              fileName: state.fileName.isEmpty
                  ? (widget.fileName ?? '')
                  : state.fileName,
            ),
          ),
        ),
      ),
    );
  }
}
