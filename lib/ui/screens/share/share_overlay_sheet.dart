import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/toast.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/processing/processing_profile.dart';
import '../../../services/processing/processing_request.dart';
import '../../../services/storage/managed_audio_file.dart';
import '../../../state/processing_controller.dart';
import '../../../state/settings_controller.dart';
import '../../navigation.dart';
import '../processing/widgets/processing_error_view.dart';
import '../processing/widgets/processing_controller_lifecycle.dart';
import '../processing/widgets/processing_status_content.dart';
import 'widgets/share_result_body.dart';

Future<void> presentShareSheet({
  required BuildContext context,
  required String audioPath,
  String? fileName,
}) {
  final isTablet = MediaQuery.of(context).size.width >= 720;
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    constraints: isTablet ? const BoxConstraints(maxWidth: 600) : null,
    builder: (sheetContext) => ShareSheetContent(
      audioPath: audioPath,
      fileName: fileName,
      onFinished: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

/// Presents the share overlay as an in-app modal bottom sheet when audio is
/// shared into or opened with the app.
abstract final class ShareOverlay {
  static Future<void> show({
    required String audioPath,
    String? fileName,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    await presentShareSheet(
      context: context,
      audioPath: audioPath,
      fileName: fileName,
    );
  }
}

/// Runs a non-persisting share pipeline and requires explicit confirmation
/// before committing the resulting note.
class ShareSheetContent extends ConsumerStatefulWidget {
  const ShareSheetContent({
    super.key,
    required this.audioPath,
    required this.onFinished,
    this.fileName,
  });

  final String audioPath;
  final String? fileName;
  final VoidCallback onFinished;

  @override
  ConsumerState<ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends ConsumerState<ShareSheetContent>
    with ProcessingControllerLifecycle<ShareSheetContent> {
  bool _saving = false;
  bool _finishing = false;

  @override
  void startProcessing() {
    processingController
      ..reset()
      ..run(
        ProcessingInput(
          audio: ManagedAudioFile(
            path: widget.audioPath,
            ownership: AudioOwnership.temporary,
          ),
          source: NoteSource.shared,
        ),
        fileName: widget.fileName,
        save: false,
      );
  }

  Future<void> _save() async {
    if (_saving || _finishing) return;
    setState(() => _saving = true);
    try {
      await processingController.commit();
    } catch (_) {
      _showError();
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
    if (!mounted) return;
    await _finish();
  }

  Future<void> _finish() async {
    if (_saving || _finishing) return;
    _finishing = true;
    try {
      await processingController.discardCurrent();
      if (mounted) widget.onFinished();
    } catch (_) {
      _finishing = false;
      _showError();
    }
  }

  void _showError() {
    if (!mounted) return;
    showAppToast(
      ref.read(stringsProvider).errorTitle,
      isError: true,
      messenger: ScaffoldMessenger.of(context),
    );
  }

  Future<void> _openSettings() async {
    await processingController.discardCurrent();
    if (!mounted) return;
    widget.onFinished();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) AppNavigator.openSettings(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(processingControllerProvider);
    final body = _selectBody(state);
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
        child: Container(
          decoration: BoxDecoration(
            color: context.palette.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: body.fill ? MainAxisSize.max : MainAxisSize.min,
              children: [
                const _DragHandle(),
                if (body.fill)
                  Expanded(child: body.content)
                else
                  Flexible(child: body.content),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ShareBody _selectBody(ProcessingState state) {
    if (state.hasError) {
      final strings = ref.watch(stringsProvider);
      return _ShareBody(
        content: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 24),
          child: ProcessingErrorContent(
            presentation: ProcessingErrorPresentation.resolve(
              state.error!,
              strings,
            ),
            actions: ProcessingErrorActions(
              onRetry: startProcessing,
              onClose: _finish,
              onOpenSettings: _openSettings,
            ),
            layout: ProcessingErrorLayout.sheet,
          ),
        ),
      );
    }
    if (state.result != null) {
      return _ShareBody(
        fill: true,
        content: ShareResultBody(
          note: state.result!,
          saving: _saving,
          onClose: _finish,
          onSave: _save,
        ),
      );
    }
    return const _ShareBody(content: _ShareProcessingBody());
  }
}

class _ShareBody {
  const _ShareBody({required this.content, this.fill = false});

  final Widget content;
  final bool fill;
}

class _ShareProcessingBody extends ConsumerWidget {
  const _ShareProcessingBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(processingControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final presentation = ProcessingStatusPresentation.forShareSheet(
      strings: strings,
      state: state,
      profile: ProcessingProfile.resolve(settings),
      summarizeEnabled: settings.summarizeEnabled,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(34, 18, 34, 28),
      child: ProcessingStatusContent(
        presentation: presentation,
        strings: strings,
      ),
    );
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.palette.line2,
          borderRadius: BorderRadius.circular(9999),
        ),
      ),
    );
  }
}
