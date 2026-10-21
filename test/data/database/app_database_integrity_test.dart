import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';

import '../../support/note_test_fixtures.dart';

void main() {
  test(
    'new databases reject orphaned children for every note relation',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);

      for (final table in [
        'note_points',
        'note_todos',
        'transcript_segments',
      ]) {
        final done = table == 'note_todos' ? ', 0' : '';
        await expectLater(
          database.customStatement(
            "INSERT INTO $table VALUES ('missing', 0, 'Orphan'$done)",
          ),
          throwsA(
            isA<SqliteException>().having(
              (error) => error.message,
              'message',
              contains('FOREIGN KEY constraint failed'),
            ),
          ),
        );
        expect(
          await database.customSelect('SELECT * FROM $table').get(),
          isEmpty,
        );
      }
    },
  );

  test(
    'reopened databases cascade parent deletion to all note children',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'transcriber-integrity-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/notes.sqlite');
      final initial = AppDatabase(NativeDatabase(file));
      await NotesRepository(initial).add(_noteWithChildren());
      await initial.close();

      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      expect(
        (await reopened.customSelect('PRAGMA foreign_keys').getSingle())
            .read<int>('foreign_keys'),
        1,
      );
      for (final table in [
        'note_points',
        'note_todos',
        'transcript_segments',
      ]) {
        expect(
          await reopened.customSelect('SELECT * FROM $table').get(),
          hasLength(1),
        );
      }

      await (reopened.delete(
        reopened.notesTable,
      )..where((table) => table.id.equals('parent'))).go();

      expect(await NotesRepository(reopened).findById('parent'), isNull);
      for (final table in [
        'note_points',
        'note_todos',
        'transcript_segments',
      ]) {
        expect(
          await reopened.customSelect('SELECT * FROM $table').get(),
          isEmpty,
        );
      }
      expect(
        await reopened.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
}

TranscriptNote _noteWithChildren() => TranscriptNote(
  metadata: NoteMetadata(
    id: 'parent',
    title: 'Note with children',
    speaker: 'Speaker',
    source: NoteSource.recording,
    durationSec: 1,
    createdAt: DateTime.utc(2025),
  ),
  origins: cloudNoteOrigins,
  content: NoteContent(
    gist: 'Summary',
    points: ['Point'],
    todos: [TodoItem(text: 'Todo', done: false)],
    transcript: const [TranscriptLine(text: 'Transcript')],
  ),
);
