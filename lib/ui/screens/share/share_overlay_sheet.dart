import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/toast.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/processing/processing_profile.dart';
import '../../../services/processing/processing_request.dart';
import '../../../services/storage/managed_audio_file.dart';
import '../../../state/processing_controller.dart';
import '../../../state/settings_controller.dart';
import '../../navigation.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../processing/widgets/processing_error_view.dart';
import '../processing/widgets/processing_controller_lifecycle.dart';
import '../processing/widgets/processing_status_content.dart';
import 'widgets/share_processing_confirmation.dart';
import 'widgets/share_result_body.dart';

Future<void> presentShareSheet({
  required BuildContext context,
  required ManagedAudioFile audio,
  String? fileName,
}) {
  return showAppBottomSheet<void>(
    context,
    builder: (sheetContext) => ShareSheetContent(
      audio: audio,
      fileName: fileName,
      onFinished: () {
        if (sheetContext.mounted &&
            ModalRoute.of(sheetContext)?.isCurrent == true) {
          Navigator.of(sheetContext).pop();
        }
      },
    ),
  );
}

/// Runs a non-persisting share pipeline and requires explicit confirmation
/// before committing the resulting note.
class ShareSheetContent extends ConsumerStatefulWidget {
  const ShareSheetContent({
    super.key,
    required this.audio,
    required this.onFinished,
    this.fileName,
  });

  final ManagedAudioFile audio;
  final String? fileName;
  final VoidCallback onFinished;

  @override
  ConsumerState<ShareSheetContent> createState() => _ShareSheetContentState();
}

class _ShareSheetContentState extends ConsumerState<ShareSheetContent>
    with ProcessingControllerLifecycle<ShareSheetContent> {
  AppSettings? _approvedSettings;
  bool _submitted = false;
  bool _saving = false;
  bool _finishing = false;
  bool _openingSettings = false;
  bool _checkingSettings = false;

  @override
  bool get startsProcessingOnMount => false;

  Future<void> _approve(AppSettings settings) async {
    if (_checkingSettings || _finishing || _saving) return;
    _checkingSettings = true;
    try {
      final current = await ref
          .read(settingsControllerProvider.notifier)
          .readCurrent();
      if (!mounted || _finishing || ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      final matches =
          _processingChoices(current) == _processingChoices(settings);
      setState(() => _approvedSettings = matches ? settings : null);
      if (matches) startProcessing();
    } catch (_) {
      if (!_finishing) _showError();
    } finally {
      _checkingSettings = false;
    }
  }

  // Compare the inputs that change recipients, provider work, or audio retention.
  Object _processingChoices(AppSettings settings) => (
    settings.asrProvider,
    settings.asrModelId(settings.asrProvider),
    settings.transcriptionLanguage,
    settings.language,
    settings.summarizeEnabled
        ? (
            settings.summaryProvider,
            settings.summaryModelId(settings.summaryProvider),
          )
        : null,
    settings.autoDeleteAudio,
  );

  @override
  void startProcessing() {
    final settings = _approvedSettings;
    if (settings == null || _finishing) return;
    _submitted = true;
    processingController
      ..reset()
      ..run(
        ProcessingInput(
          audio: widget.audio,
          source: NoteSource.shared,
          settings: settings,
        ),
        fileName: widget.fileName,
        save: false,
        owner: processingOwner,
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
      if (_submitted) {
        await processingController.discardCurrent(owner: processingOwner);
      }
      if (mounted) widget.onFinished();
    } catch (_) {
      _finishing = false;
      _showError();
    }
  }

  @override
  void discardProcessing() {
    if (!_finishing && _submitted) super.discardProcessing();
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
    if (_saving || _finishing || _openingSettings) return;
    _openingSettings = true;
    try {
      await AppNavigator.openSettings(context);
      if (mounted) setState(() => _approvedSettings = null);
    } finally {
      _openingSettings = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(processingControllerProvider);
    final body = _selectBody(state);
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: AppBottomSheetFrame(expand: body.fill, child: body.content),
    );
  }

  _ShareBody _selectBody(ProcessingState state) {
    final approvedSettings = _approvedSettings;
    if (approvedSettings == null) {
      final settings = ref.watch(settingsControllerProvider);
      return _ShareBody(
        content: ShareProcessingConfirmation(
          settings: settings,
          onConfirm: () => _approve(settings),
          onCancel: _finish,
        ),
      );
    }
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
              onRetry: () => _approve(approvedSettings),
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
    return _ShareBody(
      content: _ShareProcessingBody(settings: approvedSettings),
    );
  }
}

class _ShareBody {
  const _ShareBody({required this.content, this.fill = false});

  final Widget content;
  final bool fill;
}

class _ShareProcessingBody extends ConsumerWidget {
  const _ShareProcessingBody({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final state = ref.watch(processingControllerProvider);
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
