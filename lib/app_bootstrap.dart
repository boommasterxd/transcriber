import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/database/app_database.dart';
import 'data/database/legacy_preferences_migrator.dart';
import 'data/models/app_settings.dart';
import 'data/models/remote_provider.dart';
import 'data/models/transcript_note.dart';
import 'data/repositories/notes_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'services/storage/audio_cache_manager.dart';
import 'state/providers.dart';

/// Fully initialized application dependencies and synchronous seed state.
final class AppBootstrapData {
  const AppBootstrapData({
    required this.database,
    required this.settings,
    required this.connections,
    required this.notes,
    required this.cacheManager,
  });

  final AppDatabase database;
  final AppSettings settings;
  final Map<RemoteProviderId, bool> connections;
  final List<TranscriptNote> notes;
  final AudioCacheManager cacheManager;
}

/// Loads application dependencies and exposes them to the selected root app.
Future<void> runBootstrappedApp({
  required Widget app,
  Future<AppBootstrapData> Function()? loadBootstrap,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = await (loadBootstrap ?? loadAppBootstrap)();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(bootstrap.database),
        initialSettingsProvider.overrideWithValue(bootstrap.settings),
        initialConnectionsProvider.overrideWithValue(bootstrap.connections),
        initialNotesProvider.overrideWithValue(bootstrap.notes),
        audioCacheManagerProvider.overrideWithValue(bootstrap.cacheManager),
      ],
      child: app,
    ),
  );
}

/// Opens Drift, imports legacy preferences once, and cleans stale app cache.
Future<AppBootstrapData> loadAppBootstrap({
  AppDatabase? database,
  SharedPreferences? preferences,
  FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  AudioCacheManager? cacheManager,
}) async {
  final resolvedDatabase = database ?? AppDatabase.defaults();
  final legacyPreferences =
      preferences ?? await SharedPreferences.getInstance();
  await LegacyPreferencesMigrator(
    database: resolvedDatabase,
    preferences: legacyPreferences,
    secureStorage: secureStorage,
  ).migrate();

  final settingsRepository = SettingsRepository(
    resolvedDatabase,
    secureStorage: secureStorage,
  );
  final notesRepository = NotesRepository(resolvedDatabase);
  final resolvedCacheManager = cacheManager ?? AudioCacheManager();
  await resolvedCacheManager.cleanup();

  return AppBootstrapData(
    database: resolvedDatabase,
    settings: await settingsRepository.load(),
    connections: await settingsRepository.connectedProviders(),
    notes: await notesRepository.load(),
    cacheManager: resolvedCacheManager,
  );
}
