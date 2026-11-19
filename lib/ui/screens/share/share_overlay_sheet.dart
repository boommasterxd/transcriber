import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/toast.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/processing/processing_profile.dart';
import '../../../services/processing/processing_request.dart';
import '../../../services/storage/audio_cache_manager.dart';
import '../../../services/storage/managed_audio_file.dart';
import '../../../state/processing_controller.dart';
import '../../../state/providers.dart';
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
  required String audioPath,
  String? fileName,
}) {
  return showAppBottomSheet<void>(
    context,
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
  late final AudioCacheManager _cacheManager;
  late final ManagedAudioFile _audio;
  AppSettings? _approvedSettings;
  bool _submitted = false;
  bool _saving = false;
  bool _finishing = false;
  bool _openingSettings = false;

  @override
  bool get startsProcessingOnMount => false;

  @override
  void initState() {
    super.initState();
    _cacheManager = ref.read(audioCacheManagerProvider);
    _audio = ManagedAudioFile(
      path: widget.audioPath,
      ownership: AudioOwnership.temporary,
    );
  }

  void _approve(AppSettings settings) {
    if (_approvedSettings != null || _finishing) return;
    setState(() => _approvedSettings = settings);
    startProcessing();
  }

  @override
  void startProcessing() {
    final settings = _approvedSettings;
    if (settings == null || _finishing) return;
    _submitted = true;
    processingController
      ..reset()
      ..run(
        ProcessingInput(
          audio: _audio,
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
      } else {
        await _cacheManager.discard(_audio);
      }
      if (mounted) widget.onFinished();
    } catch (_) {
      _finishing = false;
      _showError();
    }
  }

  @override
  void discardProcessing() {
    if (_finishing) return;
    if (_submitted) {
      super.discardProcessing();
    } else {
      unawaited(_cacheManager.discard(_audio).catchError((Object _) {}));
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
