import '../../../data/models/transcript_note.dart';

enum HistoryPeriod { today, recent, earlier }

class HistoryGroup {
  const HistoryGroup({required this.period, required this.notes});

  final HistoryPeriod period;
  final List<TranscriptNote> notes;
}

List<TranscriptNote> filterNotesByTitle(
  Iterable<TranscriptNote> notes,
  String query,
) {
  if (query.isEmpty) return List<TranscriptNote>.of(notes);
  final normalizedQuery = query.toLowerCase();
  return notes
      .where((note) => note.title.toLowerCase().contains(normalizedQuery))
      .toList();
}

List<HistoryGroup> groupNotesByAge(
  Iterable<TranscriptNote> notes, {
  required DateTime now,
}) {
  final startOfToday = now.isUtc
      ? DateTime.utc(now.year, now.month, now.day)
      : DateTime(now.year, now.month, now.day);
  final grouped = <HistoryPeriod, List<TranscriptNote>>{
    for (final period in HistoryPeriod.values) period: [],
  };

  for (final note in notes) {
    grouped[_periodFor(note.createdAt, now, startOfToday)]!.add(note);
  }

  return HistoryPeriod.values
      .where((period) => grouped[period]!.isNotEmpty)
      .map(
        (period) => HistoryGroup(
          period: period,
          notes: List<TranscriptNote>.unmodifiable(grouped[period]!),
        ),
      )
      .toList(growable: false);
}

HistoryPeriod _periodFor(
  DateTime createdAt,
  DateTime now,
  DateTime startOfToday,
) {
  if (!createdAt.isBefore(startOfToday)) return HistoryPeriod.today;
  if (now.difference(createdAt).inDays < 7) return HistoryPeriod.recent;
  return HistoryPeriod.earlier;
}
