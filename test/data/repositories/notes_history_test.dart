import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/note_history.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';

void main() {
  final fixture = _HistoryFixture();
  setUp(fixture.setUp);
  tearDown(() => fixture.database.close());
  _registerPageTests(fixture);
  _registerQueryTests(fixture);
}

void _registerPageTests(_HistoryFixture fixture) {
  test(
    'keyset pages order tied dates by ID and support both directions',
    () async {
      final repository = fixture.repository;
      final first = await repository.loadHistoryPage(limit: 2);
      expect(first.entries.map((entry) => entry.id), ['e', 'd']);
      expect(first.hasNext, isTrue);
      expect(first.hasPrevious, isFalse);
      expect(first.totalCount, isNull);
      expect(await repository.loadHistoryTotal(first), 5);
      final second = await repository.loadHistoryPage(
        cursor: HistoryCursor.fromEntry(first.entries.last),
        limit: 2,
      );
      expect(second.entries.map((entry) => entry.id), ['c', 'b']);
      expect(second.hasNext, isTrue);
      expect(second.hasPrevious, isTrue);
      expect(second.totalCount, 5);
      final last = await repository.loadHistoryPage(
        cursor: HistoryCursor.fromEntry(second.entries.last),
        limit: 2,
      );
      expect(last.entries.single.id, 'a');
      expect(last.hasNext, isFalse);
      final back = await repository.loadHistoryPage(
        cursor: HistoryCursor.fromEntry(last.entries.first),
        previous: true,
        limit: 2,
      );
      expect(back.entries.map((entry) => entry.id), ['c', 'b']);
      expect(back.hasNext, isTrue);
      expect(back.hasPrevious, isTrue);
      final start = await repository.loadHistoryPage(
        cursor: HistoryCursor.fromEntry(back.entries.first),
        previous: true,
        limit: 2,
      );
      expect(start.entries.map((entry) => entry.id), ['e', 'd']);
      expect(start.hasPrevious, isFalse);
    },
  );
}

void _registerQueryTests(_HistoryFixture fixture) {
  test('title filtering treats SQL wildcards and escapes literally', () async {
    final repository = fixture.repository;
    final note = _note(
      'literal',
      title: r'100%_\meeting',
      titleIsAiGenerated: true,
    );
    expect((await repository.add(note)).titleIsAiGenerated, isTrue);
    final page = await repository.loadHistoryPage(query: r'%_\MEETING');
    expect(page.entries.single.id, 'literal');
    expect(page.entries.single.titleIsAiGenerated, isTrue);
    expect(page.totalCount, isNull);
    expect(await repository.loadHistoryTotal(page), 1);
    final sameFilter = await repository.loadHistoryPage(query: r'%_\meeting');
    expect(sameFilter.totalCount, 1);
    await repository.remove(note.id);
    expect(await repository.loadHistoryTotal(page), isNull);
    final empty = await repository.loadHistoryPage(query: r'%_\meeting');
    expect(await repository.loadHistoryTotal(empty), 0);
    final injection = await repository.loadHistoryPage(query: "' OR 1=1 --");
    expect(injection.entries, isEmpty);
    expect(
      (await repository.loadHistoryPage(query: ' Note e ')).entries,
      isEmpty,
    );
  });
}

final class _HistoryFixture {
  late AppDatabase database;
  late NotesRepository repository;

  Future<void> setUp() async {
    database = AppDatabase(NativeDatabase.memory());
    repository = NotesRepository(database);
    await repository.saveAll([
      for (final id in ['a', 'e', 'c', 'b', 'd']) _note(id, title: 'Note $id'),
    ]);
  }
}

TranscriptNote _note(
  String id, {
  required String title,
  bool? titleIsAiGenerated,
}) => TranscriptNote(
  metadata: NoteMetadata(
    id: id,
    title: title,
    speaker: 'Speaker',
    source: NoteSource.file,
    durationSec: 12,
    createdAt: DateTime.utc(2026),
  ),
  origins: const NoteOrigins(
    asrIsLocal: false,
    summaryIsLocal: false,
    asrName: 'Transcription model',
    asrSub: 'OpenAI',
    llmName: 'Summary model',
    llmSub: 'Gemini',
  ),
  content: NoteContent(
    gist: 'Summary',
    points: const ['Point'],
    todos: [
      TodoItem(text: 'One'),
      TodoItem(text: 'Two'),
    ],
    transcript: const [
      TranscriptLine(text: 'First'),
      TranscriptLine(text: 'Second'),
    ],
  ),
  audioPath: '/external/$id.m4a',
  titleIsAiGenerated: titleIsAiGenerated,
);
