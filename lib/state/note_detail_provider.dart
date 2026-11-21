import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/transcript_note.dart';
import 'notes_controller.dart';
import 'providers.dart';

/// Detail data lives only while its route/pane is observed.
final noteDetailProvider = FutureProvider.autoDispose
    .family<TranscriptNote?, String>(retry: (_, _) => null, (ref, id) {
      final cached = ref.watch(notesControllerProvider);
      for (final note in cached) {
        if (note.id == id) return note;
      }
      return ref.read(notesRepositoryProvider).findById(id);
    });
