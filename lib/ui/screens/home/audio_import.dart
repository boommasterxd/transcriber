import 'package:material_ui/material_ui.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/toast.dart';
import '../../../data/models/audio_import_selection.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/storage/audio_cache_manager.dart';
import '../../../services/storage/managed_audio_file.dart';
import '../../navigation.dart';

export '../../../data/models/audio_import_selection.dart';

typedef AudioImportPicker = Future<AudioImportSelection?> Function();
typedef AudioImportStarter = Future<void> Function(
  BuildContext context,
  AudioImportSelection selection,
);

Future<void> startAudioImport(
  BuildContext context, {
  required AudioCacheManager cacheManager,
  required AppStrings strings,
  required AudioImportPicker picker,
  AudioImportStarter starter = _startProcessing,
}) async {
  try {
    final selection = await picker();
    if (selection == null) return;
    final imported = await cacheManager.registerShared(selection.path);
    if (!context.mounted) {
      await cacheManager.discard(imported);
      return;
    }
    try {
      await starter(context, selection);
    } catch (_) {
      await cacheManager.discard(imported);
      rethrow;
    }
  } catch (_) {
    if (!context.mounted) return;
    showAppToast(
      strings.audioImportFailed,
      isError: true,
      messenger: ScaffoldMessenger.maybeOf(context),
    );
  }
}

Future<void> discardPickedAudio(
  AudioCacheManager cacheManager,
  AudioImportSelection selection,
) async {
  try {
    await cacheManager.discard(
      await cacheManager.registerShared(selection.path),
    );
  } on Object {
    // A missing or unverified path cannot be deleted as a picker file.
  }
}

Future<void> _startProcessing(
  BuildContext context,
  AudioImportSelection selection,
) {
  return AppNavigator.startProcessing(
    context,
    ProcessingNavigationRequest(
      audioPath: selection.path,
      ownership: AudioOwnership.temporary,
      source: NoteSource.file,
      fileName: selection.fileName,
    ),
  );
}
