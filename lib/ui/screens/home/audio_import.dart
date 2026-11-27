import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/toast.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/audio_import_selection.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/storage/audio_cache_manager.dart';
import '../../../services/storage/managed_audio_file.dart';
import '../../../state/providers.dart';
import '../../../state/settings_controller.dart';
import '../../navigation.dart';
import '../../widgets/processing_approval_dialog.dart';

export '../../../data/models/audio_import_selection.dart';

typedef AudioImportPicker = Future<AudioImportSelection?> Function();
typedef AudioImportStarter = Future<void> Function(
  BuildContext context,
  ProcessingNavigationRequest request,
);

final _liveImports = <AudioCacheManager>{};

Future<void> pickHomeAudio(BuildContext context, WidgetRef ref) =>
    startAudioImport(
      context,
      cacheManager: ref.read(audioCacheManagerProvider),
      readSettings: () =>
          ref.read(settingsControllerProvider.notifier).readCurrent(),
      picker: ref.read(audioImportPickerProvider).pick,
    );

Future<void> startAudioImport(
  BuildContext context, {
  required AudioCacheManager cacheManager,
  required Future<AppSettings> Function() readSettings,
  required AudioImportPicker picker,
  AudioImportStarter starter = AppNavigator.startProcessing,
  bool Function()? recoveryIsCurrent,
}) async {
  final isRecovery = recoveryIsCurrent != null;
  if (!isRecovery && !_liveImports.add(cacheManager)) return;
  try {
    final selection = await picker();
    if (selection == null) return;
    if (!context.mounted) {
      await discardPickedAudio(cacheManager, selection);
      return;
    }
    await _approveImport(
      context,
      cacheManager,
      selection,
      readSettings,
      starter,
      recoveryIsCurrent,
    );
  } on Object {
    if (!context.mounted) return;
    final language = AppLanguage.fromCode(
      Localizations.localeOf(context).languageCode,
    );
    showAppToast(
      AppStrings.of(language).audioImportFailed,
      isError: true,
      messenger: ScaffoldMessenger.maybeOf(context),
    );
  } finally {
    if (!isRecovery) _liveImports.remove(cacheManager);
  }
}

Future<void> _approveImport(
  BuildContext context,
  AudioCacheManager cacheManager,
  AudioImportSelection selection,
  Future<AppSettings> Function() readSettings,
  AudioImportStarter starter,
  bool Function()? recoveryIsCurrent,
) async {
  bool canContinue() =>
      ModalRoute.of(context)?.isCurrent == true &&
      recoveryIsCurrent?.call() != false;

  var handedOff = false;
  try {
    if (!context.mounted || !canContinue()) return;
    final imported = await cacheManager.registerShared(selection.path);
    if (!context.mounted || !canContinue()) return;
    final settings = await readSettings();
    if (!context.mounted || !canContinue()) return;
    final approved = await showProcessingApproval(
      context,
      settings: settings,
      recovered: recoveryIsCurrent != null,
    );
    if (!approved || !context.mounted || !canContinue()) return;
    await starter(
      context,
      ProcessingNavigationRequest(
        audio: imported,
        source: NoteSource.file,
        settings: settings,
        fileName: selection.fileName,
      ),
    );
    handedOff = true;
  } finally {
    if (!handedOff) await discardPickedAudio(cacheManager, selection);
  }
}

Future<void> discardPickedAudio(
  AudioCacheManager cacheManager,
  AudioImportSelection selection,
) async {
  try {
    await cacheManager.discard(
      ManagedAudioFile(
        path: selection.path,
        ownership: AudioOwnership.temporary,
      ),
    );
  } on Object {
    // The native cache can retry a failed discard.
  }
}
