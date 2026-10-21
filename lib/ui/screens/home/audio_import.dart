import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/toast.dart';
import '../../../data/models/transcript_note.dart';
import '../../../services/storage/audio_cache_manager.dart';
import '../../../services/storage/managed_audio_file.dart';
import '../../navigation.dart';

class AudioImportSelection {
  const AudioImportSelection({required this.path, required this.fileName});

  final String path;
  final String fileName;
}

typedef AudioImportPicker = Future<AudioImportSelection?> Function();
typedef AudioImportStarter =
    Future<void> Function(BuildContext context, AudioImportSelection selection);

Future<AudioImportSelection?> pickAudioImport() async {
  final file = await FilePicker.pickFile(type: FileType.audio);
  final path = file?.path;
  if (file == null || path == null) return null;
  return AudioImportSelection(path: path, fileName: file.name);
}

Future<void> startAudioImport(
  BuildContext context, {
  required AudioCacheManager cacheManager,
  required AppStrings strings,
  AudioImportPicker picker = pickAudioImport,
  AudioImportStarter starter = _startProcessing,
}) async {
  try {
    final selection = await picker();
    if (selection == null || !context.mounted) return;
    final imported = await cacheManager.importExternal(
      selection.path,
      displayName: selection.fileName,
    );
    if (!context.mounted) {
      await cacheManager.discard(imported);
      return;
    }
    try {
      await starter(
        context,
        AudioImportSelection(path: imported.path, fileName: selection.fileName),
      );
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
