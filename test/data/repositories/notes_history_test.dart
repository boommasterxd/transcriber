import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/note_history.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';

import '../../support/note_test_fixtures.dart';
import '../../support/database_query_trace.dart';

void main() {
  final fixture = _HistoryFixture();
  setUp(fixture.setUp);
  tearDown(() => fixture.database.close());
  _registerPageTests(fixture);
  _registerQueryTests(fixture);
  _registerProjectionTests(fixture);
  _registerCursorPlanTest(fixture);
  _registerMutationTests(fixture);
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
      expect(first.totalCount, 5);
      final second = await repository.loadHistoryPage(
        cursor: HistoryCursor.fromEntry(first.entries.last),
        limit: 2,
      );
      expect(second.entries.map((entry) => entry.id), ['c', 'b']);
      expect(second.hasNext, isTrue);
      expect(second.hasPrevious, isTrue);
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

  test('new inserts do not repeat or skip the next keyset boundary', () async {
    final first = await fixture.repository.loadHistoryPage(limit: 2);
    await fixture.repository.add(_note('f', title: 'New'));
    final next = await fixture.repository.loadHistoryPage(
      cursor: HistoryCursor.fromEntry(first.entries.last),
      limit: 2,
    );
    expect(next.entries.map((entry) => entry.id), ['c', 'b']);
    expect(next.totalCount, 6);
  });

  test(
    'empty and exact-size pages report their end without extra rows',
    () async {
      final page = await fixture.repository.loadHistoryPage(limit: 5);
      expect(page.entries, hasLength(5));
      expect(page.hasNext, isFalse);
      final missing = await fixture.repository.loadHistoryPage(
        query: 'missing',
      );
      expect(missing.entries, isEmpty);
      expect(missing.totalCount, 0);
      expect(missing.hasNext, isFalse);
      expect(missing.hasPrevious, isFalse);
    },
  );

  test('page size and backwards cursor requirements fail closed', () async {
    for (final limit in [-1, 0, 51]) {
      await expectLater(
        fixture.repository.loadHistoryPage(limit: limit),
        throwsRangeError,
      );
    }
    await expectLater(
      fixture.repository.loadHistoryPage(previous: true),
      throwsArgumentError,
    );
  });
}

void _registerQueryTests(_HistoryFixture fixture) {
  test('title filtering treats SQL wildcards and escapes literally', () async {
    final repository = fixture.repository;
    await repository.add(_note('literal', title: r'100%_\meeting'));
    final page = await repository.loadHistoryPage(query: r'%_\MEETING');
    expect(page.entries.single.id, 'literal');
    expect(page.totalCount, 1);
    final injection = await repository.loadHistoryPage(query: "' OR 1=1 --");
    expect(injection.entries, isEmpty);
    expect(
      (await repository.loadHistoryPage(query: ' Note e ')).entries,
      isEmpty,
    );
  });

  test('title filtering preserves Unicode lowercase semantics', () async {
    await fixture.repository.add(
      _note('unicode', title: 'Ärger über ÖL und Übung'),
    );
    final page = await fixture.repository.loadHistoryPage(
      query: 'ÄRGER ÜBER öl',
    );
    expect(page.entries.single.id, 'unicode');
    expect(page.entries.single.title, 'Ärger über ÖL und Übung');
    await fixture.repository.add(_note('unicode', title: 'Neue Größe'));
    expect(
      (await fixture.repository.loadHistoryPage(query: 'ärger')).entries,
      isEmpty,
    );
    expect(
      (await fixture.repository.loadHistoryPage(
        query: 'GRÖßE',
      )).entries.single.id,
      'unicode',
    );
  });
}

void _registerProjectionTests(_HistoryFixture fixture) {
  test(
    'default pages stay capped at fifty when history is much larger',
    () async {
      await fixture.repository.saveAll([
        for (var index = 0; index < 120; index++)
          _note(
            'note-${index.toString().padLeft(3, '0')}',
            title: 'Note $index',
          ),
      ]);
      fixture.trace.selects.clear();
      final page = await fixture.repository.loadHistoryPage();
      expect(page.entries, hasLength(50));
      expect(page.totalCount, 120);
      expect(page.hasNext, isTrue);
      expect(fixture.trace.selects.last.$2.last, 51);
    },
  );

  test('metadata fixtures retain origins and display properties', () {
    final source = _note('mapped', title: 'Mapped');
    final entry = NoteHistoryEntry.fromNote(source);
    expect(entry.id, source.id);
    expect(entry.title, source.title);
    expect(entry.createdAt, source.createdAt);
    expect(entry.todoCount, 2);
    expect(entry.metadata, same(source.metadata));
    expect(entry.origins, same(source.origins));
  });

  test(
    'history queries only metadata, bounded todo counts and note totals',
    () async {
      fixture.trace.selects.clear();
      final page = await fixture.repository.loadHistoryPage(limit: 2);
      expect(page.entries.first.todoCount, 2);
      expect(page.entries.first.isRemote, isTrue);
      expect(
        page.entries.first.modelShort,
        'gpt-transcribe · gemini-3.7-flash',
      );
      expect(page.entries.first.speaker, 'Speaker');
      expect(page.entries.first.durationSec, 12);
      expect(page.entries.first.source, NoteSource.file);
      final statements = fixture.trace.selects
          .map((query) => query.$1)
          .join('\n');
      for (final excluded in [
        'gist',
        'transcript_segments',
        'note_points',
        'SELECT *',
      ]) {
        expect(statements, isNot(contains(excluded)));
      }
      expect(fixture.trace.selects, hasLength(2));
      final historyQuery = fixture.trace.selects.last;
      expect(historyQuery.$2.last, 3);
      final plans = await fixture.database
          .customSelect(
            'EXPLAIN QUERY PLAN ${historyQuery.$1}',
            variables: historyQuery.$2.map(Variable.new).toList(),
          )
          .get();
      final details = plans.map((row) => row.read<String>('detail')).join('\n');
      expect(details, contains('notes_history_order'));
      expect(details, contains('SEARCH t USING COVERING INDEX'));
      expect(details, isNot(contains('TEMP B-TREE')));
      expect(details, isNot(contains('SCAN t')));
    },
  );
}

void _registerMutationTests(_HistoryFixture fixture) {
  test('details and committed mutations never select whole history', () async {
    fixture.trace.selects.clear();
    final repository = fixture.repository;
    final detail = await repository.findById('e');
    expect(detail!.transcript.map((line) => line.text), ['First', 'Second']);
    expect(detail.points, ['Point']);
    expect(detail.todos.map((todo) => todo.text), ['One', 'Two']);
    final added = await repository.add(_note('target', title: 'Target'));
    expect(added.id, 'target');
    final toggled = await repository.toggleTodo('e', 0);
    expect(toggled!.todos.first.done, isTrue);
    expect((await repository.toggleTodo('e', 99))!.todos.last.done, isFalse);
    final deleted = await repository.remove('target');
    expect(deleted.deleted!.id, 'target');
    expect(deleted.deleted!.audioPath, '/external/target.m4a');
    expect(await repository.findById('target'), isNull);
    expect(await repository.toggleTodo('missing', 0), isNull);
    expect((await repository.remove('missing')).deleted, isNull);
    for (final (sql, args) in fixture.trace.selects) {
      expect(sql, contains('WHERE'));
      expect(args.any({'e', 'target', 'missing'}.contains), isTrue);
    }
  });

  test(
    'deleted metadata query does not retrieve generated note content',
    () async {
      fixture.trace.selects.clear();
      await fixture.repository.remove('e');
      expect(fixture.trace.selects, hasLength(1));
      expect(fixture.trace.selects.single.$1, isNot(contains('gist')));
      expect(fixture.trace.selects.single.$1, isNot(contains('transcript')));
      expect(await fixture.repository.findById('e'), isNull);
      expect((await fixture.repository.loadHistoryPage()).totalCount, 4);
    },
  );
}

void _registerCursorPlanTest(_HistoryFixture fixture) {
  test(
    'next and previous pages use an indexed keyset range without offset',
    () async {
      final initial = await fixture.repository.loadHistoryPage(limit: 2);
      for (final previous in [false, true]) {
        fixture.trace.selects.clear();
        await fixture.repository.loadHistoryPage(
          cursor: HistoryCursor.fromEntry(initial.entries.last),
          previous: previous,
          limit: 2,
        );
        final (sql, args) = fixture.trace.selects.last;
        expect(sql, isNot(contains('OFFSET')));
        final plan = await fixture.database
            .customSelect(
              'EXPLAIN QUERY PLAN $sql',
              variables: args.map(Variable.new).toList(),
            )
            .get();
        final details = plan
            .map((row) => row.read<String>('detail'))
            .join('\n');
        expect(details, contains('SEARCH n USING INDEX notes_history_order'));
        expect(details, isNot(contains('TEMP B-TREE')));
        expect(details, isNot(contains('SCAN t')));
      }
    },
  );
}

final class _HistoryFixture {
  late AppDatabase database;
  late NotesRepository repository;
  late DatabaseQueryTrace trace;

  Future<void> setUp() async {
    trace = DatabaseQueryTrace();
    database = AppDatabase(NativeDatabase.memory().interceptWith(trace));
    repository = NotesRepository(database);
    await repository.saveAll([
      for (final id in ['a', 'e', 'c', 'b', 'd']) _note(id, title: 'Note $id'),
    ]);
  }
}

TranscriptNote _note(String id, {required String title}) => TranscriptNote(
  metadata: NoteMetadata(
    id: id,
    title: title,
    speaker: 'Speaker',
    source: NoteSource.file,
    durationSec: 12,
    createdAt: DateTime.utc(2026),
  ),
  origins: cloudNoteOrigins,
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
);
