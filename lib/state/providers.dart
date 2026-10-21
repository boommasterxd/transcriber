import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/models/app_settings.dart';
import '../data/models/remote_provider.dart';
import '../data/models/transcript_note.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/audio/audio_recorder_service.dart';
import '../services/processing/processing_pipeline.dart';
import '../services/remote/remote_client_factory.dart';
import '../services/share/share_intent_service.dart';
import '../services/storage/audio_cache_manager.dart';
import '../services/storage/pending_audio_deletion_recovery.dart';

/// Overridden after the Drift database has been initialized.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden');
});

/// Seed values resolved before `runApp` so the controllers can start synchronously.
final initialSettingsProvider = Provider<AppSettings>((ref) {
  throw UnimplementedError('initialSettingsProvider must be overridden');
});

final initialConnectionsProvider = Provider<Map<RemoteProviderId, bool>>((ref) {
  throw UnimplementedError('initialConnectionsProvider must be overridden');
});

final initialNotesProvider = Provider<List<TranscriptNote>>((ref) {
  throw UnimplementedError('initialNotesProvider must be overridden');
});

final audioCacheManagerProvider = Provider<AudioCacheManager>(
  (ref) => AudioCacheManager(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(ref.watch(databaseProvider)),
);

final pendingAudioDeletionRecoveryProvider =
    Provider<PendingAudioDeletionRecovery>(
      (ref) => PendingAudioDeletionRecovery(
        ref.watch(notesRepositoryProvider),
        ref.watch(audioCacheManagerProvider),
      ),
    );

typedef ProviderCredentialTester =
    Future<void> Function(RemoteProviderId provider, String apiKey);

final providerCredentialTesterProvider = Provider<ProviderCredentialTester>(
  (ref) => (provider, apiKey) async {
    final client = RemoteClientFactory.create(provider, apiKey);
    try {
      await client.testConnection();
    } finally {
      client.close();
    }
  },
);

final processingPipelineProvider = Provider<ProcessingPipeline>(
  (ref) =>
      ProcessingPipeline(cacheManager: ref.watch(audioCacheManagerProvider)),
);

final audioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService(
    cacheManager: ref.watch(audioCacheManagerProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final shareIntentServiceProvider = Provider<ShareIntentService>((ref) {
  final service = ShareIntentService();
  ref.onDispose(service.dispose);
  return service;
});
