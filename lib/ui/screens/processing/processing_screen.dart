import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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
import '../../navigation_routes.dart';
import '../../widgets/processing_approval_dialog.dart';
import '../detail/transcript_detail_screen.dart';
import 'widgets/processing_controller_lifecycle.dart';
import 'widgets/processing_error_view.dart';
import 'widgets/processing_screen_frame.dart';
import 'widgets/processing_status_content.dart';

/// Full-screen processing view. Runs the pipeline and, on success, replaces
/// itself with the transcript detail screen.
class ProcessingScreen extends ConsumerStatefulWidget {
  const ProcessingScreen({
    super.key,
    required this.audio,
    required this.source,
    required this.settings,
    this.fileName,
    this.knownDurationSec,
  });

  final ManagedAudioFile audio;
  final NoteSource source;
  final AppSettings settings;
  final String? fileName;
  final int? knownDurationSec;

  @override
  ConsumerState<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends ConsumerState<ProcessingScreen>
    with ProcessingControllerLifecycle<ProcessingScreen> {
  late final AudioCacheManager _cacheManager;
  late AppSettings _approvedSettings = widget.settings;
  bool _submitted = false;
  bool _discardedBeforeSubmission = false;
  bool _retrying = false;

  bool get _ownsProcessing => processingController.isOwnedBy(processingOwner);

  @override
  void initState() {
    super.initState();
    _cacheManager = ref.read(audioCacheManagerProvider);
  }

  @override
  void startProcessing() {
    if (_discardedBeforeSubmission) return;
    processingController.run(
      ProcessingInput(
        audio: widget.audio,
        source: widget.source,
        knownDurationSec: widget.knownDurationSec,
        settings: _approvedSettings,
      ),
      fileName: widget.fileName,
      owner: processingOwner,
    );
    _submitted = _ownsProcessing;
  }

  @override
  void discardProcessing() {
    if (_submitted) {
      super.discardProcessing();
    } else if (!_discardedBeforeSubmission) {
      _discardedBeforeSubmission = true;
      unawaited(_cacheManager.discard(widget.audio).catchError((Object _) {}));
    }
  }

  bool get _canRetryCloud =>
      _ownsProcessing &&
      ref.read(processingControllerProvider).hasError &&
      !processingController.canRetryLocalSave(processingOwner) &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _retryCloud({bool openSettings = false}) async {
    if (_retrying || !_canRetryCloud) return;
    _retrying = true;
    try {
      if (openSettings) {
        await openSettingsRoute(context);
        if (!mounted || !_canRetryCloud) return;
      }
      final settings = await ref
          .read(settingsControllerProvider.notifier)
          .readCurrent();
      if (!mounted || !_canRetryCloud) return;
      if (openSettings ||
          !hasSameProcessingRecipients(_approvedSettings, settings)) {
        final approved = await showProcessingApproval(
          context,
          settings: settings,
        );
        if (!mounted || !approved || !_canRetryCloud) return;
        _approvedSettings = settings;
      }
      startProcessing();
    } on Object {
      if (!mounted || !_canRetryCloud) return;
      showAppToast(
        ref.read(stringsProvider).errorTitle,
        isError: true,
        messenger: ScaffoldMessenger.maybeOf(context),
      );
    } finally {
      _retrying = false;
    }
  }

  void _onResult(TranscriptNote note) {
    if (ModalRoute.of(context)?.isCurrent != true) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TranscriptDetailScreen(noteId: note.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final current = ref.watch(processingControllerProvider);
    final state = _ownsProcessing ? current : const ProcessingState();
    final settings = state.settings ?? _approvedSettings;
    final profile = ProcessingProfile.resolve(settings);
    final presentation = ProcessingStatusPresentation.forScreen(
      strings: t,
      state: state,
      profile: profile,
      summarizeEnabled: settings.summarizeEnabled,
    );

    ref.listen(processingControllerProvider, (prev, next) {
      if (next.result != null && _ownsProcessing) {
        _onResult(next.result!);
      }
    });

    final Widget content;
    if (state.hasError) {
      final canRetryLocalSave = processingController.canRetryLocalSave(
        processingOwner,
      );
      content = ProcessingErrorView(
        presentation: ProcessingErrorPresentation.resolve(state.error!, t),
        actions: ProcessingErrorActions(
          onRetry: canRetryLocalSave
              ? () => processingController.retryLocalSave(processingOwner)
              : _retryCloud,
          onClose: () => Navigator.of(context).pop(),
          onOpenSettings: () => _retryCloud(openSettings: true),
        ),
      );
    } else {
      content = ProcessingScreenFrame(
        child: ProcessingStatusContent(
          presentation: presentation,
          strings: t,
          fileName: state.fileName.isEmpty
              ? (widget.fileName ?? '')
              : state.fileName,
        ),
      );
    }
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) discardProcessing();
      },
      child: content,
    );
  }
}
