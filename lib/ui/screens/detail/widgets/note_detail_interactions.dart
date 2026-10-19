import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../../state/note_detail_provider.dart';
import '../../../widgets/note_actions.dart';

mixin NoteDetailInteractionState<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool transcriptOpen = false;
  bool copied = false;
  Timer? _copyTimer;

  TranscriptNote? watchNote(String noteId) {
    return ref.watch(noteDetailProvider(noteId)).asData?.value;
  }

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void toggleTranscript() {
    setState(() => transcriptOpen = !transcriptOpen);
  }

  void copyNote(TranscriptNote note) {
    Clipboard.setData(ClipboardData(text: note.fullTranscriptText));
    setState(() => copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => copied = false);
    });
  }

  void shareNote(TranscriptNote note) {
    final body = '${note.title}\n\n${note.gist}\n\n${note.fullTranscriptText}';
    SharePlus.instance.share(ShareParams(text: body, subject: note.title));
  }

  Future<bool> confirmAndDeleteNote(
    TranscriptNote note,
    AppStrings strings,
  ) async {
    if (!await confirmDeleteNote(context, strings)) return false;
    await deleteNoteWithUndo(ref, note, strings);
    return true;
  }
}
