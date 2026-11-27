import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/toast.dart';
import '../../data/models/transcript_note.dart';
import '../../state/notes_controller.dart';

Future<void> Function()? _dismissOpenUndo;

/// Offers undo for the version that was actually removed from storage.
Future<bool> deleteNoteWithUndo(
  BuildContext context,
  WidgetRef ref,
  String noteId,
  AppStrings strings,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final controller = ref.read(notesControllerProvider.notifier);
  final TranscriptNote? note;
  try {
    note = await controller.deleteForUndo(noteId);
  } catch (_) {
    showAppToast(strings.errorTitle, isError: true);
    return false;
  }
  if (note == null) return false;
  final messenger = scaffoldMessengerKey.currentState;
  if (messenger == null) {
    await _finalizeDeletion(controller, note);
    return true;
  }
  _offerUndo(messenger, navigator, controller, note, strings);
  return true;
}

void _offerUndo(
  ScaffoldMessengerState messenger,
  NavigatorState navigator,
  NotesController controller,
  TranscriptNote note,
  AppStrings strings,
) {
  unawaited(_dismissOpenUndo?.call());
  messenger.clearSnackBars();
  var resolved = false;

  Future<void> resolveUndo({required bool restore}) async {
    if (resolved) return;
    resolved = true;
    _dismissOpenUndo = null;
    if (restore) {
      await _restoreOrRetry(controller, note, navigator, strings);
    } else {
      await _finalizeDeletion(controller, note);
    }
  }

  _dismissOpenUndo = () => resolveUndo(restore: false);
  final snackbar = messenger.showSnackBar(
    SnackBar(
      content: Text(strings.noteDeleted),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: strings.undo,
        onPressed: () => unawaited(resolveUndo(restore: true)),
      ),
    ),
  );
  unawaited(
    snackbar.closed.then((reason) {
      if (reason != SnackBarClosedReason.action) {
        return resolveUndo(restore: false);
      }
    }),
  );
}

Future<void> _restoreOrRetry(
  NotesController controller,
  TranscriptNote note,
  NavigatorState navigator,
  AppStrings strings,
) async {
  while (navigator.mounted) {
    try {
      await controller.restoreDeletedNote(note);
      return;
    } catch (_) {
      final overlay = navigator.overlay;
      if (overlay == null || !overlay.mounted) return;
      if (!await _retryRestore(overlay.context, strings)) {
        await _finalizeDeletion(controller, note);
        return;
      }
    }
  }
}

Future<bool> _retryRestore(BuildContext context, AppStrings strings) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: Text(strings.errorTitle),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(strings.dismiss),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(strings.retry),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> _finalizeDeletion(
  NotesController controller,
  TranscriptNote note,
) async {
  try {
    await controller.finalizeDeletion(note);
  } catch (_) {
    // The durable deletion candidate can be recovered on the next startup.
  }
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
