import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/toast.dart';
import '../../../state/providers.dart';
import '../../../state/settings_controller.dart';
import 'audio_import.dart';

/// Offers a lost Android pick once the normal entry point is ready.
class AudioImportRecoveryGate extends ConsumerStatefulWidget {
  const AudioImportRecoveryGate({
    super.key,
    required this.ready,
    required this.child,
  });

  final bool ready;
  final Widget child;

  @override
  ConsumerState<AudioImportRecoveryGate> createState() =>
      _AudioImportRecoveryGateState();
}

class _AudioImportRecoveryGateState
    extends ConsumerState<AudioImportRecoveryGate> {
  AudioImportSelection? _selection;
  bool _failed = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_recover());
  }

  Future<void> _recover() async {
    try {
      _selection = await ref
          .read(audioImportPickerProvider)
          .recoverInterruptedPick();
    } on Object {
      _failed = true;
    }
    if (mounted) _scheduleOffer();
  }

  @override
  void didUpdateWidget(AudioImportRecoveryGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleOffer();
  }

  void _scheduleOffer() {
    if (!widget.ready || _scheduled || (_selection == null && !_failed)) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted && widget.ready) unawaited(_offer());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _offer() async {
    final selection = _selection;
    _selection = null;
    if (ref.read(audioImportPickerProvider).recoverySuperseded ||
        ModalRoute.of(context)?.isCurrent != true) {
      _failed = false;
      return;
    }
    final strings = ref.read(stringsProvider);
    if (_failed) {
      _failed = false;
      showAppToast(strings.audioImportFailed, isError: true);
      return;
    }
    if (selection == null) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.recoveredAudioTitle),
        content: Text(strings.recoveredAudioBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(strings.recoveredAudioContinue),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted || !widget.ready) return;
    await startAudioImport(
      context,
      cacheManager: ref.read(audioCacheManagerProvider),
      strings: ref.read(stringsProvider),
      picker: () async => selection,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
