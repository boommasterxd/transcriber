import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';

void main() {
  group('NotesRepository', () {
    late SharedPreferences preferences;
    late NotesRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      repository = NotesRepository(preferences);
    });

    test('loads an empty list when no notes are persisted', () {
      expect(repository.load(), isEmpty);
    });

    test('loads persisted notes newest first', () async {
      final oldest = _note('oldest', DateTime.utc(2025, 1, 1));
      final newest = _note('newest', DateTime.utc(2025, 3, 1));
      final middle = _note('middle', DateTime.utc(2025, 2, 1));
      await preferences.setString(
        'notes',
        jsonEncode([oldest.toJson(), newest.toJson(), middle.toJson()]),
      );

      final loaded = repository.load();

      expect(loaded.map((note) => note.id), ['newest', 'middle', 'oldest']);
      expect(loaded.first.todos.single.text, 'Follow up newest');
      expect(loaded.first.transcript.single.text, 'Transcript newest');
      expect(loaded.first.audioPath, '/audio/newest.m4a');
    });

    test('returns an empty list for malformed persisted data', () async {
      for (final malformed in <String>[
        'not-json',
        jsonEncode({'id': 'not-a-list'}),
        jsonEncode([
          {'title': 'missing-required-id'},
        ]),
      ]) {
        await preferences.setString('notes', malformed);

        expect(repository.load(), isEmpty, reason: malformed);
      }
    });

    test(
      'saves, updates, and deletes notes through complete snapshots',
      () async {
        final first = _note('first', DateTime.utc(2025, 1, 1));
        final second = _note('second', DateTime.utc(2025, 2, 1));
        await repository.saveAll([first, second]);

        final updatedFirst = first.copyWith(
          todos: [TodoItem(text: 'Updated action', done: true)],
        );
        await repository.saveAll([updatedFirst]);

        final loadedAfterUpdate = repository.load();
        expect(loadedAfterUpdate, hasLength(1));
        expect(loadedAfterUpdate.single.id, 'first');
        expect(loadedAfterUpdate.single.todos.single.text, 'Updated action');
        expect(loadedAfterUpdate.single.todos.single.done, isTrue);

        await repository.saveAll([]);

        expect(repository.load(), isEmpty);
        expect(jsonDecode(preferences.getString('notes')!), isEmpty);
      },
    );
  });
}

TranscriptNote _note(String id, DateTime createdAt) => TranscriptNote(
  id: id,
  title: 'Title $id',
  speaker: 'Speaker $id',
  source: NoteSource.recording,
  durationSec: 42,
  createdAt: createdAt,
  asrIsLocal: true,
  summaryIsLocal: false,
  asrName: 'ASR',
  asrSub: 'Local',
  llmName: 'LLM',
  llmSub: 'Cloud',
  gist: 'Gist $id',
  points: ['Point $id'],
  todos: [TodoItem(text: 'Follow up $id')],
  transcript: [TranscriptLine(time: '00:01', text: 'Transcript $id')],
  audioPath: '/audio/$id.m4a',
);
