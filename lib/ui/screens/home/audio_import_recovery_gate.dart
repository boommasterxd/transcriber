import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/toast.dart';
import '../../../services/storage/audio_cache_manager.dart';
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
  late final AudioCacheManager _cacheManager;
  AudioImportSelection? _selection;
  bool _failed = false;
  bool _scheduled = false;

  @override
  void initState() {
    super.initState();
    _cacheManager = ref.read(audioCacheManagerProvider);
    unawaited(_recover());
  }

  @override
  void dispose() {
    if (_selection case final selection?) {
      unawaited(discardPickedAudio(_cacheManager, selection));
    }
    super.dispose();
  }

  Future<void> _recover() async {
    final picker = ref.read(audioImportPickerProvider);
    try {
      final selection = await picker.recoverInterruptedPick();
      if (selection != null && (!mounted || picker.recoverySuperseded)) {
        await discardPickedAudio(_cacheManager, selection);
        return;
      }
      _selection = selection;
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
    final picker = ref.read(audioImportPickerProvider);
    if (picker.recoverySuperseded ||
        ModalRoute.of(context)?.isCurrent != true) {
      _failed = false;
      if (selection != null) await discardPickedAudio(_cacheManager, selection);
      return;
    }
    final strings = ref.read(stringsProvider);
    if (_failed) {
      _failed = false;
      showAppToast(strings.audioImportFailed, isError: true);
      return;
    }
    if (selection == null) return;
    await startAudioImport(
      context,
      cacheManager: _cacheManager,
      readSettings: () =>
          ref.read(settingsControllerProvider.notifier).readCurrent(),
      picker: () async => selection,
      recoveryIsCurrent: () => widget.ready && !picker.recoverySuperseded,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
