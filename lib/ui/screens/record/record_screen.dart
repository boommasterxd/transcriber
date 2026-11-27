import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/storage/managed_audio_file.dart';
import '../../../state/providers.dart';
import '../../../state/recording_controller.dart';
import '../../../state/settings_controller.dart';
import '../../processing_navigation.dart';
import '../../widgets/processing_approval_dialog.dart';
import '../../widgets/recording_controls.dart';
import 'widgets/record_body.dart';
import 'widgets/record_header.dart';

/// In-app recording screen with a live timer + waveform. Stopping flows into the
/// same processing → detail pipeline as file import and share.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  bool _starting = false;
  bool _startFailed = false;
  bool _busy = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    if (!mounted || _starting || _cancelling) return;
    setState(() => _starting = true);
    var startFailed = false;
    try {
      final permission = await Permission.microphone.request();
      if (!mounted || _cancelling) return;
      if (!permission.isGranted) {
        _showPermissionError(openSettings: permission.isPermanentlyDenied);
        return;
      }
      final ok = await ref.read(recordingControllerProvider.notifier).start();
      if (!ok && mounted && !_cancelling) _showPermissionError();
    } catch (_) {
      startFailed = true;
    } finally {
      if (mounted) {
        setState(() {
          _starting = false;
          if (!_cancelling) _startFailed = startFailed;
        });
      }
    }
  }

  void _showRecordingError() {
    final strings = ref.read(stringsProvider);
    final hasAudio = ref.read(recordingControllerProvider).path != null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hasAudio ? strings.recFailure : strings.errorTitle),
      ),
    );
  }

  void _showPermissionError({bool openSettings = false}) {
    final t = ref.read(stringsProvider);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.micPermissionBody),
        action: openSettings
            ? SnackBarAction(
                label: t.micPermissionSettings,
                onPressed: openAppSettings,
              )
            : null,
      ),
    );
  }

  Future<void> _stop() async {
    if (_busy || _cancelling) return;
    setState(() => _busy = true);
    try {
      await _finishRecording();
    } catch (_) {
      if (mounted) _showRecordingError();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finishRecording() async {
    final cacheManager = ref.read(audioCacheManagerProvider);
    final result = await ref.read(recordingControllerProvider.notifier).stop();
    if (result == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    var handedOff = false;
    try {
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final audio = await cacheManager.registerRecording(result.path);
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final settings = await ref
          .read(settingsControllerProvider.notifier)
          .readCurrent();
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      final approved = await showProcessingApproval(
        context,
        settings: settings,
      );
      if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
      if (!approved) {
        Navigator.of(context).pop();
        return;
      }
      final processing = startProcessingRoute(
        context,
        ProcessingNavigationRequest(
          audio: audio,
          source: NoteSource.recording,
          settings: settings,
          knownDurationSec: result.durationSec,
        ),
        replace: true,
      );
      handedOff = true;
      await processing;
    } finally {
      if (!handedOff) {
        await cacheManager
            .discard(
              ManagedAudioFile(
                path: result.path,
                ownership: AudioOwnership.temporary,
              ),
            )
            .catchError((Object _) {
              // The native cache can retry a failed discard.
            });
      }
    }
  }

  Future<void> _cancel() async {
    if (_busy || _cancelling) return;
    setState(() => _cancelling = true);
    try {
      await ref.read(recordingControllerProvider.notifier).cancel();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      _showRecordingError();
    }
  }

  Future<void> _togglePause() async {
    if (_cancelling) return;
    try {
      await ref.read(recordingControllerProvider.notifier).togglePause();
    } catch (_) {
      if (mounted) _showRecordingError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final strings = ref.watch(stringsProvider);
    final paused = ref.watch(
      recordingControllerProvider.select((state) => state.paused),
    );
    final active = ref.watch(
      recordingControllerProvider.select((state) => state.active),
    );
    final captured = ref.watch(
      recordingControllerProvider.select((state) => state.path != null),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: palette.bg,
        body: SafeArea(
          child: Column(
            children: [
              RecordHeader(title: strings.recTitle, onCancel: _cancel),
              Expanded(
                child: captured
                    ? RecordBody(paused: paused, strings: strings)
                    : _startFailed
                    ? _RecordingStartFailure(
                        message: strings.recStartFailure,
                        retryLabel: strings.retry,
                        onRetry: _starting || _cancelling ? null : _begin,
                      )
                    : const SizedBox.shrink(),
              ),
              RecordControls(
                paused: paused,
                strings: strings,
                actions: RecordingActions(
                  cancel: _busy ? null : _cancel,
                  stop: captured && !_busy ? _stop : null,
                  togglePause: active && !_busy ? _togglePause : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordingStartFailure extends StatelessWidget {
  const _RecordingStartFailure({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            container: true,
            liveRegion: true,
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}
