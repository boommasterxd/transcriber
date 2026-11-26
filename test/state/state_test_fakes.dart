import 'dart:async';

import 'package:drift/native.dart';
import 'package:record/record.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/repositories/settings_repository.dart';
import 'package:transcriber/services/audio/audio_recorder_service.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';

class FakeSettingsRepository extends SettingsRepository {
  FakeSettingsRepository(super.database);

  final Map<RemoteProviderId, String> keys = {};
  final List<RemoteProviderId> requestedProviders = [];

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

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

class FakeAudioRecorderService extends AudioRecorderService {
  FakeAudioRecorderService(AudioCacheManager cacheManager)
    : super(cacheManager: cacheManager);

  bool permission = true;
  Completer<String>? startRequest;
  final String path = '/recordings/fake.wav';
  int startCalls = 0;
  int resumeCalls = 0;
  int cancelCalls = 0;
  int? recordingMaxBytes;
  final progress = StreamController<RecordingProgress>.broadcast(sync: true);
  final StreamController<Amplitude> amplitudes =
      StreamController<Amplitude>.broadcast(sync: true);

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<String> start({int maxBytes = 100 * 1024 * 1024}) async {
    startCalls++;
    recordingMaxBytes = maxBytes;
    return startRequest?.future ?? path;
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {
    resumeCalls++;
  }

  @override
  Future<String?> stop() async => path;

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
