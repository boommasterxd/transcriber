import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';

import '../../../data/models/transcript_note.dart';
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
  AudioImportPicker picker = pickAudioImport,
  AudioImportStarter starter = _startProcessing,
}) async {
  final selection = await picker();
  if (selection == null || !context.mounted) return;
  await starter(context, selection);
}

Future<void> _startProcessing(
  BuildContext context,
  AudioImportSelection selection,
) {
  return AppNavigator.startProcessing(
    context,
    audioPath: selection.path,
    source: NoteSource.file,
    fileName: selection.fileName,
  );
}
