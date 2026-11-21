import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/storage/managed_audio_file.dart';
import '../../../state/recording_controller.dart';
import '../../../state/settings_controller.dart';
import '../../processing_navigation.dart';
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
  bool _busy = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    if (!mounted || _cancelling) return;
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
      if (mounted && !_cancelling) _showRecordingError();
    }
  }

  void _showRecordingError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(stringsProvider).recFailure)),
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
    final result = await ref.read(recordingControllerProvider.notifier).stop();
    if (!mounted) return;
    if (result == null) {
      Navigator.of(context).pop();
      return;
    }
    // Replace the record screen with processing so that, after processing swaps
    // itself for the detail screen, back from detail returns to home, not to a
    // lingering record screen.
    await startProcessingRoute(
      context,
      ProcessingNavigationRequest(
        audioPath: result.path,
        ownership: AudioOwnership.temporary,
        source: NoteSource.recording,
        knownDurationSec: result.durationSec,
      ),
      replace: true,
    );
  }

  Future<void> _cancel() async {
    if (_busy || _cancelling) return;
    _cancelling = true;
    try {
      await ref.read(recordingControllerProvider.notifier).cancel();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _cancelling = false;
      if (mounted) _showRecordingError();
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
