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
import 'data/repositories/settings_repository.dart';
import 'services/storage/audio_cache_manager.dart';
import 'state/notes_controller.dart';
import 'state/providers.dart';
import 'ui/screens/startup/bootstrap_status.dart';

/// Fully initialized application dependencies and synchronous seed state.
final class AppBootstrapData {
  const AppBootstrapData({
    required this.database,
    required this.settings,
    required this.connections,
    required this.notes,
    required this.cacheManager,
    this.lifecycle = (
      runMaintenance: null,
      ownsDatabase: false,
      recoverPendingAudioDeletes: false,
    ),
  });

  final AppDatabase database;
  final AppSettings settings;
  final Map<RemoteProviderId, bool> connections;
  final List<TranscriptNote> notes;
  final AudioCacheManager cacheManager;
  final ({
    Future<void> Function()? runMaintenance,
    bool ownsDatabase,
    bool recoverPendingAudioDeletes,
  })
  lifecycle;
}

final class BootstrapShutdown {
  const BootstrapShutdown({required this.drain, required this.finish});

  final Future<void> Function(ProviderContainer) drain;
  final Future<void> Function() finish;
}

final closeBootstrappedAppProvider = Provider<Future<void> Function()>((ref) {
  throw StateError('This app has no explicit shutdown.');
});

/// Mounts the startup view and exposes dependencies once loading succeeds.
Future<void> runBootstrappedApp({
  required Widget app,
  Future<AppBootstrapData> Function()? loadBootstrap,
  bool recoverPendingAudioDeletes = true,
  bool enforceAudioCacheQuota = true,
  BootstrapShutdown? shutdown,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    _BootstrapGate(
      app: app,
      load:
          loadBootstrap ??
          () => loadAppBootstrap(
            recoverPendingAudioDeletes: recoverPendingAudioDeletes,
            enforceAudioCacheQuota: enforceAudioCacheQuota,
          ),
      shutdown: shutdown,
    ),
  );
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate({
    required this.app,
    required this.load,
    required this.shutdown,
  });

  final Widget app;
  final Future<AppBootstrapData> Function() load;
  final BootstrapShutdown? shutdown;

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  AppBootstrapData? _bootstrap;
  ProviderContainer? _container;
  AppLifecycleListener? _lifecycle;
  Future<void>? _maintenance;
  Future<void>? _closing;
  late Future<void> _attempt;
  bool _failed = false;
  bool _detached = false;

  @override
  void initState() {
    super.initState();
    _attempt = _load();
    if (widget.shutdown != null) {
      _lifecycle = AppLifecycleListener(onDetach: _detach);
    }
  }

  Future<void> _load() async {
    try {
      final data = await widget.load();
      if (mounted && _closing == null) {
        setState(() => _bootstrap = data);
      } else {
        _bootstrap = data;
      }
    } catch (_) {
      if (mounted && _closing == null) setState(() => _failed = true);
    }
  }

  void _retry() {
    if (!_failed || _closing != null) return;
    setState(() => _failed = false);
    _attempt = _load();
  }

  void _attachMaintenance(BuildContext context, AppBootstrapData data) {
    if (_container != null) return;
    final container = ProviderScope.containerOf(context, listen: false);
    _container = container;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _closing == null) {
        _maintenance = _runMaintenance(data, container);
        unawaited(_maintenance);
      }
    });
  }

  Future<void> _runMaintenance(
    AppBootstrapData data,
    ProviderContainer container,
  ) async {
    final maintenance = data.lifecycle.runMaintenance;
    try {
      await Future.wait<void>([
        if (maintenance != null) Future<void>.sync(maintenance),
        if (data.lifecycle.recoverPendingAudioDeletes)
          container
              .read(notesControllerProvider.notifier)
              .recoverPendingAudioDeletions(),
      ]);
    } catch (_) {
      // Maintenance can retry on another startup.
    }
  }

  Future<void> _requestClose() => _closing ??= _close();

  Future<void> _close() async {
    final shutdown = widget.shutdown;
    await _attempt;
    final container = _container;
    try {
      if (shutdown != null && container != null) {
        await shutdown.drain(container);
      }
    } catch (_) {
      // Dismissal still releases the owned database.
    }
    await _maintenance;
    final data = _bootstrap;
    if (data != null && data.lifecycle.ownsDatabase) {
      await _closeDatabase(data.database);
    }
    if (!_detached && mounted) await shutdown?.finish();
  }

  void _detach() {
    _detached = true;
    unawaited(_requestClose());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _bootstrap;
    if (data == null || (_closing != null && _container == null)) {
      return BootstrapStatus(
        failed: _failed,
        retry: _retry,
        close: widget.shutdown == null ? null : _requestClose,
      );
    }
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(data.database),
        initialSettingsProvider.overrideWithValue(data.settings),
        initialConnectionsProvider.overrideWithValue(data.connections),
        initialNotesProvider.overrideWithValue(data.notes),
        audioCacheManagerProvider.overrideWithValue(data.cacheManager),
        if (widget.shutdown != null)
          closeBootstrappedAppProvider.overrideWithValue(_requestClose),
      ],
      child: Builder(
        builder: (context) {
          _attachMaintenance(context, data);
          return widget.app;
        },
      ),
    );
  }
}

/// Opens Drift and loads the state needed to mount the main app surface.
Future<AppBootstrapData> loadAppBootstrap({
  AppDatabase? database,
  SharedPreferences? preferences,
  FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  AudioCacheManager? cacheManager,
  bool recoverPendingAudioDeletes = true,
  bool enforceAudioCacheQuota = true,
}) async {
  final resolvedDatabase = database ?? AppDatabase.defaults();
  try {
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
      lifecycle: (
        ownsDatabase: database == null,
        recoverPendingAudioDeletes: recoverPendingAudioDeletes,
        runMaintenance: () async {
          await Future.wait<void>([
            if (cleanupLegacyCredentials) migrator.cleanupObsoleteCredentials(),
            resolvedCacheManager.cleanup(enforceQuota: enforceAudioCacheQuota),
          ]);
        },
      ),
    );
  } catch (_) {
    if (database == null) await _closeDatabase(resolvedDatabase);
    rethrow;
  }
}

Future<void> _closeDatabase(AppDatabase database) async {
  try {
    await database.close();
  } catch (_) {
    // A connection that failed to open may also fail to close.
  }
}
