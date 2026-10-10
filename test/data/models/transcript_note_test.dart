import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/audio_ownership.dart';
import 'package:transcriber/data/models/transcript_note.dart';

void main() {
  _testNoteSource();
  _testTranscriptLine();
  _testTodoItem();
  _testDerivedValues();
  _testCopyWith();
  _testJsonRoundTripAndDefaults();
  _testLegacyJson();
  _testInvalidJson();
}

void _testNoteSource() {
  group('NoteSource', () {
    test('round-trips every stable source id', () {
      expect(NoteSource.values.map((source) => source.id), [
        'shared',
        'file',
        'recording',
      ]);
      for (final source in NoteSource.values) {
        expect(NoteSource.fromId(source.id), source);
      }
    });

    test('falls back to file for absent or invalid source ids', () {
      for (final value in <String?>[null, '', 'Shared', 'unknown']) {
        expect(NoteSource.fromId(value), NoteSource.file);
      }
    });
  });
}

void _testTranscriptLine() {
  group('TranscriptLine', () {
    test('round-trips text', () {
      const line = TranscriptLine(text: 'A transcript line.');

      expect(TranscriptLine.fromJson(line.toJson()).text, line.text);
    });

    test('defaults missing text and ignores legacy timestamps', () {
      final line = TranscriptLine.fromJson(const {});
      final legacyLine = TranscriptLine.fromJson(const {
        'time': '01:02',
        'text': 'Legacy line',
      });

      expect(line.text, isEmpty);
      expect(line.toJson(), {'text': ''});
      expect(legacyLine.toJson(), {'text': 'Legacy line'});
    });
  });
}

void _testTodoItem() {
  group('TodoItem', () {
    test('round-trips mutable completion state', () {
      final todo = TodoItem(text: 'Send notes');
      expect(todo.done, isFalse);

      todo.done = true;
      final restored = TodoItem.fromJson(todo.toJson());
      expect(restored.text, 'Send notes');
      expect(restored.done, isTrue);
    });

    test('defaults missing values safely', () {
      final todo = TodoItem.fromJson(const {});

      expect(todo.text, isEmpty);
      expect(todo.done, isFalse);
      expect(todo.toJson(), {'text': '', 'done': false});
    });
  });
}

void _testDerivedValues() {
  group('TranscriptNote derived values', () {
    test('is remote when either processing stage used cloud', () {
      expect(_note(localStages: (asr: false, summary: false)).isRemote, isTrue);
      expect(_note(localStages: (asr: false, summary: true)).isRemote, isTrue);
      expect(_note(localStages: (asr: true, summary: false)).isRemote, isTrue);
      // The local combination remains meaningful for historical notes.
      expect(_note(localStages: (asr: true, summary: true)).isRemote, isFalse);
    });

    test('builds compact cloud model label from the first LLM segment', () {
      expect(_note().modelShort, 'GPT Transcribe · GPT-5.6 Luna');
      expect(
        _note(llmName: 'Custom Model').modelShort,
        'GPT Transcribe · Custom Model',
      );
      expect(_note(llmName: '').modelShort, 'GPT Transcribe · ');
    });

    test('formats transcript lines in their original order', () {
      final note = _note(
        transcript: const [
          TranscriptLine(text: 'First'),
          TranscriptLine(text: 'Second'),
        ],
      );

      expect(note.fullTranscriptText, 'First\nSecond');
      expect(_note(transcript: const []).fullTranscriptText, isEmpty);
    });
  });
}

void _testCopyWith() {
  group('TranscriptNote.copyWith', () {
    test('replaces todos while preserving every other field', () {
      final original = _note(todos: [TodoItem(text: 'Original')]);
      final replacements = [TodoItem(text: 'Replacement', done: true)];

      final copied = original.copyWith(todos: replacements);

      expect(copied.todos, same(replacements));
      final copiedWithoutTodos = copied.toJson()..remove('todos');
      final originalWithoutTodos = original.toJson()..remove('todos');
      expect(copiedWithoutTodos, originalWithoutTodos);
    });

    test('preserves the existing todo list when omitted', () {
      final originalTodos = [TodoItem(text: 'Keep')];
      final copied = _note(todos: originalTodos).copyWith();

      expect(copied.todos, same(originalTodos));
    });

    test('preserves and replaces a summary failure message', () {
      final original = _note().copyWith(summaryError: 'Summary failed');

      expect(original.copyWith().summaryError, 'Summary failed');
      expect(
        original.copyWith(summaryError: 'Try again').summaryError,
        'Try again',
      );
    });
  });
}

void _testJsonRoundTripAndDefaults() {
  group('TranscriptNote JSON', () {
    test('round-trips all fields and nested values', () {
      final original = _note(
        source: NoteSource.shared,
        localStages: (asr: false, summary: false),
        audioOwnership: AudioOwnership.retained,
        todos: [TodoItem(text: 'Follow up', done: true)],
        transcript: const [TranscriptLine(text: 'Hello')],
      );

      final json = original.toJson();
      final restored = TranscriptNote.fromJson(json);

      expect(restored.toJson(), json);
      expect(restored.createdAt, original.createdAt);
      expect(restored.todos.single.done, isTrue);
      expect(restored.transcript.single.text, 'Hello');
      expect(restored.audioOwnership, AudioOwnership.retained);
    });

    test('uses deterministic defaults for absent optional fields', () {
      final note = TranscriptNote.fromJson({
        'id': 'minimal',
        'createdAt': '2024-01-02T03:04:05.000Z',
      });

      expect(note.title, isEmpty);
      expect(note.speaker, isEmpty);
      expect(note.source, NoteSource.file);
      expect(note.durationSec, 0);
      expect(note.createdAt, DateTime.utc(2024, 1, 2, 3, 4, 5));
      expect(note.asrIsLocal, isTrue);
      expect(note.summaryIsLocal, isTrue);
      expect(note.asrName, isEmpty);
      expect(note.asrSub, isEmpty);
      expect(note.llmName, isEmpty);
      expect(note.llmSub, isEmpty);
      expect(note.gist, isEmpty);
      expect(note.points, isEmpty);
      expect(note.todos, isEmpty);
      expect(note.transcript, isEmpty);
      expect(note.audioPath, isNull);
      expect(note.summaryError, isNull);
      // Missing ownership keeps the safe external default for old notes.
      expect(note.audioOwnership, AudioOwnership.external);
    });

    test('normalizes numeric duration and point values', () {
      final note = TranscriptNote.fromJson({
        'id': 'normalized',
        'createdAt': '2024-01-02T03:04:05Z',
        'durationSec': 12.9,
        'points': [1, true, 'text'],
      });

      expect(note.durationSec, 12);
      expect(note.points, ['1', 'true', 'text']);
    });

    test('round-trips a summary failure without losing transcript content', () {
      final original = _note().copyWith(summaryError: 'Summary failed');

      final restored = TranscriptNote.fromJson(original.toJson());

      expect(restored.summaryError, 'Summary failed');
      expect(restored.fullTranscriptText, original.fullTranscriptText);
    });
  });
}

void _testLegacyJson() {
  group('TranscriptNote legacy JSON', () {
    test('migrates legacy remote mode to both processing stages', () {
      final note = TranscriptNote.fromJson({
        'id': 'legacy',
        'createdAt': '2024-01-02T03:04:05Z',
        'mode': 'remote',
      });

      expect(note.asrIsLocal, isFalse);
      expect(note.summaryIsLocal, isFalse);
      expect(note.isRemote, isTrue);
    });

    test('preserves independent historical stage provenance', () {
      final note = TranscriptNote.fromJson({
        'id': 'mixed',
        'createdAt': '2024-01-02T03:04:05Z',
        'mode': 'remote',
        'asrIsLocal': true,
        'summaryIsLocal': false,
      });

      expect(note.asrIsLocal, isTrue);
      expect(note.summaryIsLocal, isFalse);
    });
  });
}

void _testInvalidJson() {
  group('TranscriptNote invalid JSON', () {
    test('rejects a missing required id', () {
      expect(
        () => TranscriptNote.fromJson({'createdAt': '2024-01-02T03:04:05Z'}),
        throwsA(isA<TypeError>()),
      );
    });

    test('rejects malformed nested todo and transcript entries', () {
      expect(
        () => TranscriptNote.fromJson({
          'id': 'bad-todo',
          'createdAt': '2024-01-02T03:04:05Z',
          'todos': ['not-a-map'],
        }),
        throwsA(isA<TypeError>()),
      );
      expect(
        () => TranscriptNote.fromJson({
          'id': 'bad-line',
          'createdAt': '2024-01-02T03:04:05Z',
          'transcript': [1],
        }),
        throwsA(isA<TypeError>()),
      );
    });
  });
}

TranscriptNote _note({
  NoteSource source = NoteSource.recording,
  ({bool asr, bool summary}) localStages = (asr: false, summary: false),
  String llmName = 'GPT-5.6 Luna · Cloud',
  AudioOwnership audioOwnership = AudioOwnership.external,
  List<TodoItem>? todos,
  List<TranscriptLine>? transcript,
}) => TranscriptNote(
  id: 'note-1',
  title: 'Planning',
  speaker: 'Speaker',
  source: source,
  durationSec: 65,
  createdAt: DateTime.utc(2024, 1, 2, 3, 4, 5),
  asrIsLocal: localStages.asr,
  summaryIsLocal: localStages.summary,
  asrName: 'GPT Transcribe',
  asrSub: 'OpenAI',
  llmName: llmName,
  llmSub: 'Provider',
  gist: 'Summary',
  points: const ['Point one', 'Point two'],
  todos: todos ?? [TodoItem(text: 'Default todo')],
  transcript: transcript ?? const [TranscriptLine(text: 'Default')],
  audioPath: '/audio/note.m4a',
  audioOwnership: audioOwnership,
);
