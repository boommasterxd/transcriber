import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/toast.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../../services/share/note_share_payload.dart';
import '../../../../state/note_detail_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/note_actions.dart';

const _clipboardChannel = MethodChannel('app/clipboard');

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

  Future<void> copyNote(TranscriptNote note) async {
    try {
      await _clipboardChannel.invokeMethod<void>(
        'setSensitiveText',
        note.fullTranscriptText,
      );
    } on Exception {
      if (mounted) {
        showAppToast(ref.read(stringsProvider).copyFailed, isError: true);
      }
      return;
    }
    if (!mounted) return;
    setState(() => copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => copied = false);
    });
  }

  void shareNote(TranscriptNote note) {
    final strings = ref.read(stringsProvider);
    final subject = note.titleIsAiGenerated == false
        ? note.title
        : strings.voiceNote;
    SharePlus.instance.share(
      ShareParams(text: noteShareText(note, strings), subject: subject),
    );
  }

  Future<bool> confirmAndDeleteNote(
    TranscriptNote note,
    AppStrings strings,
  ) async {
    if (!await confirmDeleteNote(context, strings) || !mounted) return false;
    return deleteNoteWithUndo(context, ref, note.id, strings);
  }
}
