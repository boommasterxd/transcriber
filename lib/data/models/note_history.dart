import 'transcript_note.dart';

/// Lightweight history data without transcript, summary, or child collections.
final class NoteHistoryEntry with NoteDisplayMetadata {
  const NoteHistoryEntry({
    required this.metadata,
    required this.origins,
    required this.todoCount,
  });

  factory NoteHistoryEntry.fromNote(TranscriptNote note) => NoteHistoryEntry(
    metadata: note.metadata,
    origins: note.origins,
    todoCount: note.todos.length,
  );

  @override
  final NoteMetadata metadata;
  @override
  final NoteOrigins origins;
  final int todoCount;
}

/// Stable boundary for descending creation date and ID ordering.
final class HistoryCursor {
  const HistoryCursor({required this.createdAt, required this.id});

  factory HistoryCursor.fromEntry(NoteHistoryEntry entry) =>
      HistoryCursor(createdAt: entry.createdAt, id: entry.id);

  final DateTime createdAt;
  final String id;
}

final class HistoryPage {
  const HistoryPage({
    required this.entries,
    required this.hasNext,
    required this.hasPrevious,
    required this.totalCount,
  });

  final List<NoteHistoryEntry> entries;
  final bool hasNext;
  final bool hasPrevious;
  final int totalCount;
}
