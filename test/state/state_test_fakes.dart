import 'dart:async';

import 'package:drift/native.dart';
import 'package:record/record.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/note_history.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';
import 'package:transcriber/services/audio/audio_recorder_service.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';

class FakeSettingsRepository extends SettingsRepository {
  FakeSettingsRepository(super.database);

  AppSettings loaded = AppSettings.initial();
  final List<AppSettings> saved = [];
  final Map<RemoteProviderId, String> keys = {};
  final List<RemoteProviderId> requestedProviders = [];
  bool failOnSave = false;

  @override
  Future<AppSettings> load() async => loaded;

  @override
  Future<void> save(AppSettings settings) async {
    saved.add(settings);
    if (failOnSave) throw StateError('save failed');
    loaded = settings;
  }

  @override
  Future<String?> apiKey(RemoteProviderId provider) async {
    requestedProviders.add(provider);
    return keys[provider];
  }

  @override
  Future<void> setApiKey(RemoteProviderId provider, String key) async {
    keys[provider] = key;
  }

  @override
  Future<void> deleteApiKey(RemoteProviderId provider) async {
    keys.remove(provider);
  }
}

class FakeNotesRepository extends NotesRepository {
  FakeNotesRepository(super.database);

  List<TranscriptNote> loaded = [];
  final List<List<TranscriptNote>> saved = [];
  bool failOnLoad = false;
  bool failOnSave = false;

  @override
  Future<List<TranscriptNote>> load() async {
    if (failOnLoad) throw StateError('load failed');
    return List.of(loaded);
  }

  @override
  Future<void> saveAll(List<TranscriptNote> notes) async {
    _save(notes);
  }

  @override
  Future<TranscriptNote> add(TranscriptNote note) async {
    _save(
      [note, ...loaded.where((existing) => existing.id != note.id)]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
    return note;
  }

  @override
  Future<TranscriptNote?> findById(String id) async =>
      loaded.where((note) => note.id == id).firstOrNull;

  @override
  Future<HistoryPage> loadHistoryPage({
    String query = '',
    HistoryCursor? cursor,
    bool previous = false,
    int limit = 50,
  }) async {
    if (failOnLoad) throw StateError('load failed');
    final notes =
        loaded
            .where(
              (note) => note.title.toLowerCase().contains(query.toLowerCase()),
            )
            .toList()
          ..sort((a, b) {
            final date = b.createdAt.compareTo(a.createdAt);
            return date == 0 ? b.id.compareTo(a.id) : date;
          });
    final boundary = cursor == null
        ? 0
        : notes.indexWhere((note) => note.id == cursor.id);
    final start = cursor == null
        ? 0
        : previous
        ? (boundary - limit).clamp(0, notes.length)
        : boundary + 1;
    final end = previous ? boundary : (start + limit).clamp(0, notes.length);
    return HistoryPage(
      entries: notes
          .sublist(start, end)
          .map(NoteHistoryEntry.fromNote)
          .toList(),
      hasNext: end < notes.length,
      hasPrevious: start > 0,
      totalCount: notes.length,
    );
  }

  @override
  Future<NotesDeletion> remove(String id) async {
    final deleted = loaded.where((note) => note.id == id).firstOrNull;
    _save(loaded.where((note) => note.id != id).toList());
    return NotesDeletion(
      deleted == null
          ? null
          : DeletedNoteAudio(
              id: deleted.id,
              audioPath: deleted.audioPath,
              audioOwnership: deleted.audioOwnership,
            ),
    );
  }

  @override
  Future<TranscriptNote?> toggleTodo(String noteId, int index) async {
    _save(
      loaded.map((note) {
        if (note.id != noteId) return note;
        return note.copyWith(
          todos: [
            for (var position = 0; position < note.todos.length; position++)
              if (position == index)
                TodoItem(
                  text: note.todos[position].text,
                  done: !note.todos[position].done,
                )
              else
                note.todos[position],
          ],
        );
      }).toList(),
    );
    return findById(noteId);
  }

  List<TranscriptNote> _save(List<TranscriptNote> notes) {
    saved.add(List.of(notes));
    if (failOnSave) throw StateError('save failed');
    loaded = List.of(notes);
    return List.of(loaded);
  }
}

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

class FakeAudioRecorderService extends AudioRecorderService {
  FakeAudioRecorderService(AudioCacheManager cacheManager)
    : super(cacheManager: cacheManager);

  bool permission = true;
  Completer<bool>? permissionRequest;
  Completer<String>? startRequest;
  String path = '/recordings/fake.wav';
  String? stoppedPath = '/recordings/fake.wav';
  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  int? recordingMaxBytes;
  Object? stopError;
  final progress = StreamController<RecordingProgress>.broadcast(sync: true);
  final StreamController<Amplitude> amplitudes =
      StreamController<Amplitude>.broadcast(sync: true);

  @override
  Future<bool> hasPermission() async => permissionRequest?.future ?? permission;

  @override
  Future<String> start({int maxBytes = 100 * 1024 * 1024}) async {
    startCalls++;
    recordingMaxBytes = maxBytes;
    return startRequest?.future ?? path;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  @override
  Future<String?> stop() async {
    stopCalls++;
    if (stopError case final error?) throw error;
    return stoppedPath;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  Stream<Amplitude> amplitudeStream() => amplitudes.stream;

  @override
  Stream<RecordingProgress> get progressStream => progress.stream;

  @override
  Future<void> dispose() async {
    await amplitudes.close();
    await progress.close();
  }
}
