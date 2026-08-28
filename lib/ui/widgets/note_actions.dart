import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/toast.dart';
import '../../data/models/transcript_note.dart';
import '../../state/notes_controller.dart';

/// Deletes [note] and shows an "undo" snackbar via the app-wide messenger, so it
/// works whether or not the originating screen is still mounted (e.g. after the
/// detail screen pops). Undo re-adds the note in its original place.
Future<void> deleteNoteWithUndo(
  WidgetRef ref,
  TranscriptNote note,
  AppStrings strings,
) async {
  await ref.read(notesControllerProvider.notifier).delete(note.id);
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) return;
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      content: Text(strings.noteDeleted),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: strings.undo,
        onPressed: () => ref.read(notesControllerProvider.notifier).add(note),
      ),
    ),
  );
}

/// Confirms deletion in a dialog. Returns true if the user chose to delete.
Future<bool> confirmDeleteNote(BuildContext context, AppStrings strings) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(strings.deleteNoteTitle),
      content: Text(strings.deleteNoteBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(strings.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}
