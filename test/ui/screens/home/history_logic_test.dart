import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/ui/screens/home/history_logic.dart';

import 'home_test_helpers.dart';

void main() {
  _registerFilterTests();
  _registerGroupingTests();
}

void _registerFilterTests() {
  final now = DateTime(2026, 8, 28, 12);
  final notes = [
    buildTestNote(id: 'one', title: 'Weekly Sync', createdAt: now),
    buildTestNote(id: 'two', title: 'Project update', createdAt: now),
  ];

  test('empty queries return every note', () {
    expect(filterNotesByTitle(notes, ''), notes);
  });

  test('title filtering is case-insensitive and order-preserving', () {
    expect(filterNotesByTitle(notes, 'UPDATE').map((note) => note.id), ['two']);
  });

  test('title filtering does not trim the query', () {
    expect(filterNotesByTitle(notes, ' sync '), isEmpty);
  });
}

void _registerGroupingTests() {
  test('supplied time controls all note age boundaries', () {
    final now = DateTime(2026, 8, 28, 12);
    final groups = groupNotesByAge(_notesAcrossAgeBoundaries(now), now: now);

    expect(groups.map((group) => group.period), HistoryPeriod.values);
    expect(groups[0].notes.map((note) => note.id), ['future', 'today']);
    expect(groups[1].notes.map((note) => note.id), ['recent']);
    expect(groups[2].notes.map((note) => note.id), ['earlier']);
  });

  test('empty groups are omitted without reordering notes', () {
    final now = DateTime(2026, 8, 28, 12);
    final notes = [
      buildTestNote(id: 'first', title: 'First', createdAt: now),
      buildTestNote(id: 'second', title: 'Second', createdAt: now),
    ];

    final groups = groupNotesByAge(notes, now: now);

    expect(groups, hasLength(1));
    expect(groups.single.period, HistoryPeriod.today);
    expect(groups.single.notes.map((note) => note.id), ['first', 'second']);
  });

  test('UTC is preserved when calculating the start of today', () {
    final now = DateTime.utc(2026, 8, 28, 12);
    final note = buildTestNote(
      id: 'midnight',
      title: 'Midnight',
      createdAt: DateTime.utc(2026, 8, 28),
    );

    expect(
      groupNotesByAge([note], now: now).single.period,
      HistoryPeriod.today,
    );
  });
}

List<TranscriptNote> _notesAcrossAgeBoundaries(DateTime now) => [
  buildTestNote(
    id: 'future',
    title: 'Future',
    createdAt: now.add(const Duration(hours: 1)),
  ),
  buildTestNote(id: 'today', title: 'Today', createdAt: DateTime(2026, 8, 28)),
  buildTestNote(
    id: 'recent',
    title: 'Recent',
    createdAt: now.subtract(const Duration(days: 6, hours: 23)),
  ),
  buildTestNote(
    id: 'earlier',
    title: 'Earlier',
    createdAt: now.subtract(const Duration(days: 7)),
  ),
];
