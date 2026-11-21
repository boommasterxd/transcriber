import 'dart:async';

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
import 'services/storage/pending_audio_deletion_recovery.dart';
import 'state/providers.dart';

/// Fully initialized application dependencies and synchronous seed state.
final class AppBootstrapData {
  const AppBootstrapData({
    required this.database,
    required this.settings,
    required this.connections,
    required this.notes,
    required this.cacheManager,
    this.runMaintenance,
  });

  final AppDatabase database;
  final AppSettings settings;
  final Map<RemoteProviderId, bool> connections;
  final List<TranscriptNote> notes;
  final AudioCacheManager cacheManager;
  final Future<void> Function()? runMaintenance;
}

/// Loads application dependencies and exposes them to the selected root app.
Future<void> runBootstrappedApp({
  required Widget app,
  Future<AppBootstrapData> Function()? loadBootstrap,
  bool recoverPendingAudioDeletes = true,
  bool enforceAudioCacheQuota = true,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final bootstrap = loadBootstrap == null
      ? await loadAppBootstrap(
          recoverPendingAudioDeletes: recoverPendingAudioDeletes,
          enforceAudioCacheQuota: enforceAudioCacheQuota,
        )
      : await loadBootstrap();
  final maintenance = bootstrap.runMaintenance;

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(bootstrap.database),
        initialSettingsProvider.overrideWithValue(bootstrap.settings),
        initialConnectionsProvider.overrideWithValue(bootstrap.connections),
        initialNotesProvider.overrideWithValue(bootstrap.notes),
        audioCacheManagerProvider.overrideWithValue(bootstrap.cacheManager),
      ],
      child: maintenance == null
          ? app
          : _StartupMaintenance(run: maintenance, child: app),
    ),
  );
}

class _StartupMaintenance extends StatefulWidget {
  const _StartupMaintenance({required this.run, required this.child});

  final Future<void> Function() run;
  final Widget child;

  @override
  State<_StartupMaintenance> createState() => _StartupMaintenanceState();
}

class _StartupMaintenanceState extends State<_StartupMaintenance> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.run());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Opens Drift and loads the state needed for the first frame.
Future<AppBootstrapData> loadAppBootstrap({
  AppDatabase? database,
  SharedPreferences? preferences,
  FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  AudioCacheManager? cacheManager,
  bool recoverPendingAudioDeletes = true,
  bool enforceAudioCacheQuota = true,
}) async {
  final resolvedDatabase = database ?? AppDatabase.defaults();
  final legacyPreferences =
      preferences ?? await SharedPreferences.getInstance();
  final migrator = LegacyPreferencesMigrator(
    database: resolvedDatabase,
    preferences: legacyPreferences,
    secureStorage: secureStorage,
  );
  final cleanupLegacyCredentials = await migrator.migrate();

  final settingsRepository = SettingsRepository(
    resolvedDatabase,
    secureStorage: secureStorage,
  );
  final resolvedCacheManager = cacheManager ?? AudioCacheManager();
  return AppBootstrapData(
    database: resolvedDatabase,
    settings: await settingsRepository.load(),
    connections: await settingsRepository.connectedProviders(),
    notes: const [],
    cacheManager: resolvedCacheManager,
    runMaintenance: () async {
      await Future.wait([
        if (cleanupLegacyCredentials) migrator.cleanupObsoleteCredentials(),
        resolvedCacheManager.cleanup(enforceQuota: enforceAudioCacheQuota),
        if (recoverPendingAudioDeletes)
          PendingAudioDeletionRecovery(
            NotesRepository(resolvedDatabase),
            resolvedCacheManager,
          ).recover(),
      ]).onError((_, _) => []);
    },
  );
}
