import 'dart:async';

import 'package:record/record.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/data/repositories/notes_repository.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';
import 'package:transcriber/services/audio/audio_recorder_service.dart';

class FakeSettingsRepository extends SettingsRepository {
  FakeSettingsRepository(super.preferences);

  AppSettings loaded = AppSettings.initial();
  final List<AppSettings> saved = [];
  final Map<RemoteProviderId, String> keys = {};
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
  Future<String?> apiKey(RemoteProviderId provider) async => keys[provider];

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
  FakeNotesRepository(super.preferences);

  List<TranscriptNote> loaded = [];
  final List<List<TranscriptNote>> saved = [];
  bool failOnSave = false;

  @override
  List<TranscriptNote> load() => List.of(loaded);

  @override
  Future<void> saveAll(List<TranscriptNote> notes) async {
    saved.add(List.of(notes));
    if (failOnSave) throw StateError('save failed');
    loaded = List.of(notes);
  }
}

class FakeAudioRecorderService extends AudioRecorderService {
  FakeAudioRecorderService() : super();

  bool permission = true;
  String path = '/recordings/fake.wav';
  String? stoppedPath = '/recordings/fake.wav';
  int startCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int stopCalls = 0;
  int cancelCalls = 0;
  final StreamController<Amplitude> amplitudes =
      StreamController<Amplitude>.broadcast(sync: true);

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<String> start() async {
    startCalls++;
    return path;
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
    return stoppedPath;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  Stream<Amplitude> amplitudeStream() => amplitudes.stream;

  @override
  Future<void> dispose() async {
    await amplitudes.close();
  }
}
