import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  Future<void> _begin() async {
    try {
      final ok = await ref.read(recordingControllerProvider.notifier).start();
      if (!ok && mounted) _showPermissionError();
    } catch (_) {
      if (mounted) _showRecordingError();
    }
  }

  void _showRecordingError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ref.read(stringsProvider).recFailure)),
    );
  }

  void _showPermissionError() {
    final t = ref.read(stringsProvider);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${t.micPermissionTitle}: ${t.micPermissionBody}'),
      ),
    );
  }

  Future<void> _stop() async {
    if (_busy) return;
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
    if (_busy) return;
    try {
      await ref.read(recordingControllerProvider.notifier).cancel();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _showRecordingError();
    }
  }

  Future<void> _togglePause() async {
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
                child: RecordBody(paused: paused, strings: strings),
              ),
              RecordControls(
                paused: paused,
                strings: strings,
                actions: RecordingActions(
                  cancel: _busy ? null : _cancel,
                  stop: _busy ? null : _stop,
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
