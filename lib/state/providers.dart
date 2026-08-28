import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/app_settings.dart';
import '../data/models/remote_provider.dart';
import '../data/repositories/notes_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../services/audio/audio_recorder_service.dart';
import '../services/models/local_model_runtime.dart';
import '../services/processing/processing_pipeline.dart';
import '../services/share/share_intent_service.dart';

/// Overridden in `main()` once SharedPreferences has been initialized.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

/// Seed values resolved before `runApp` so the controllers can start synchronously.
final initialSettingsProvider = Provider<AppSettings>((ref) {
  throw UnimplementedError('initialSettingsProvider must be overridden');
});

final initialConnectionsProvider = Provider<Map<RemoteProviderId, bool>>((ref) {
  throw UnimplementedError('initialConnectionsProvider must be overridden');
});

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(sharedPreferencesProvider)),
);

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => NotesRepository(ref.watch(sharedPreferencesProvider)),
);

final localModelRuntimeProvider = Provider<LocalModelRuntime>(
  (ref) => EngineLocalModelRuntime(),
);

final processingPipelineProvider = Provider<ProcessingPipeline>(
  (ref) => ProcessingPipeline(),
);

final audioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final service = AudioRecorderService();
  ref.onDispose(service.dispose);
  return service;
});

final shareIntentServiceProvider = Provider<ShareIntentService>((ref) {
  final service = ShareIntentService();
  ref.onDispose(service.dispose);
  return service;
});
