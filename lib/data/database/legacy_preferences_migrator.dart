import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_accent.dart';
import '../models/app_language.dart';
import '../models/app_settings.dart';
import '../models/remote_provider.dart';
import '../models/transcript_note.dart';
import '../models/transcription_language.dart';
import '../repositories/notes_repository.dart';
import '../repositories/settings_repository.dart';
import 'app_database.dart';

/// Imports the pre-Drift SharedPreferences payload exactly once.
class LegacyPreferencesMigrator {
  LegacyPreferencesMigrator({
    required this.database,
    required this.preferences,
    FlutterSecureStorage? secureStorage,
  }) : secureStorage = secureStorage ?? const FlutterSecureStorage();

  final AppDatabase database;
  final SharedPreferences preferences;
  final FlutterSecureStorage secureStorage;

  static const marker = 'shared_preferences_v1';
  static const rejectedNotesRecoveryKey = 'legacy_unimported_notes_v1';
  static const _cleanupClassified = '${marker}_cleanup_classified';
  static const _notesClassified = '${marker}_note_partition_classified';
  static const _credentialsCleaned = '${marker}_credentials_cleaned';
  static const _settingsKey = 'app_settings';
  static const _notesKey = 'notes';
  static const _pendingPreferenceMarkers = {
    _settingsKey: '${marker}_cleanup_settings',
    _notesKey: '${marker}_cleanup_notes',
  };
  static const _obsoleteCredentialKeys = [
    'hf_token',
    'api_key_anthropic',
    'api_key_openrouter',
  ];

  /// Imports legacy data and returns whether deferred credential cleanup is due.
  Future<bool> migrate() async {
    final markers = await database.transaction(_classifyLegacyPreferences);

    final removed = <String>[];
    for (final entry in _pendingPreferenceMarkers.entries) {
      if (markers.contains(entry.value) && await _removePreference(entry.key)) {
        removed.add(entry.value);
      }
    }
    if (removed.isNotEmpty) {
      await (database.delete(
        database.migrationStateTable,
      )..where((row) => row.key.isIn(removed))).go();
    }
    return !markers.contains(_credentialsCleaned);
  }

  Future<Set<String>> _classifyLegacyPreferences() async {
    final markers = await _readMarkers();
    final checkSettings = !markers.contains(_cleanupClassified);
    final checkNotes = !markers.contains(_notesClassified);
    if (!checkSettings && !checkNotes) return markers;

    final settings = checkSettings ? _readSettings() : null;
    final notes = checkNotes ? _readNotes() : null;
    final needsImport = !markers.contains(marker);
    if (needsImport) {
      await SettingsRepository(database).save(settings!.value);
      await NotesRepository(database).replaceAllInTransaction(notes!.values);
    }

    final rejected = notes?.rejected;
    final ready = rejected == null || await _storeRejectedNotes(rejected);
    // The successful import marker is independent of platform cleanup. Once
    // it commits, a retry only partitions and removes legacy preferences.
    final added = [
      if (needsImport) marker,
      if (checkSettings) _cleanupClassified,
      if (settings?.canRemove ?? false)
        _pendingPreferenceMarkers[_settingsKey]!,
      if (checkNotes && ready) _notesClassified,
      if (rejected != null && ready) _pendingPreferenceMarkers[_notesKey]!,
    ];
    await _recordMarkers(added);
    return markers..addAll(added);
  }

  Future<Set<String>> _readMarkers() async {
    final table = database.migrationStateTable;
    final query = database.selectOnly(table)
      ..addColumns([table.key])
      ..where(
        table.key.isIn([
          marker,
          _cleanupClassified,
          _notesClassified,
          _credentialsCleaned,
          ..._pendingPreferenceMarkers.values,
        ]),
      );
    return {for (final row in await query.get()) row.read(table.key)!};
  }

  Future<void> _recordMarkers(Iterable<String> keys) async {
    final completedAt = DateTime.now().millisecondsSinceEpoch;
    await database.batch((batch) {
      batch.insertAll(database.migrationStateTable, [
        for (final key in keys)
          MigrationStateTableCompanion.insert(
            key: key,
            completedAt: completedAt,
          ),
      ], mode: InsertMode.insertOrIgnore);
    });
  }

  Future<bool> _removePreference(String key) async {
    try {
      return await preferences.remove(key);
    } catch (_) {
      return false;
    }
  }

  /// Removes obsolete keys after bootstrap and retries on a later startup.
  Future<void> cleanupObsoleteCredentials() async {
    try {
      if ((await _readMarkers()).contains(_credentialsCleaned)) return;
      var allRemoved = true;
      for (final key in _obsoleteCredentialKeys) {
        if (!await _removeCredential(key)) allRemoved = false;
      }
      if (allRemoved) await _recordMarkers([_credentialsCleaned]);
    } catch (_) {
      // A failed cleanup or marker write must not interrupt an active app.
    }
  }

  Future<bool> _removeCredential(String key) async {
    try {
      await secureStorage.delete(key: key);
      return true;
    } catch (_) {
      return false;
    }
  }

  _LegacyValue<AppSettings> _readSettings() {
    try {
      final raw = preferences.getString(_settingsKey);
      if (raw == null) return _LegacyValue(AppSettings.initial());
      final decoded = jsonDecode(raw);
      if (decoded is! Map) throw const FormatException('settings object');
      final json = decoded.cast<String, dynamic>();
      final asrProvider = _provider(
        json['asrProvider'],
        RemoteProviderId.google,
      );
      final summaryProvider = _provider(
        json['summaryProvider'],
        RemoteProviderId.google,
      );
      final settings = AppSettings(
        appearance: AppearanceSettings(
          themeMode: _themeMode(json),
          accent: AppAccent.fromId(json['accent'] as String?),
          language: AppLanguage.fromCode(json['language'] as String?),
        ),
        transcription: TranscriptionSettings(
          language: TranscriptionLanguage.fromCode(
            json['transcriptionLanguage'] as String?,
          ),
          provider: asrProvider,
          models: _selectedModel(json['asrModelByProvider'], asrProvider),
        ),
        summary: SummarySettings(
          provider: summaryProvider,
          models: _selectedModel(json['chatModelByProvider'], summaryProvider),
          enabled: json['summarizeEnabled'] as bool? ?? true,
        ),
        autoDeleteAudio: json['autoDeleteAudio'] as bool? ?? false,
        onboarded: json['onboarded'] as bool? ?? false,
      );
      return _LegacyValue(settings, canRemove: true);
    } catch (_) {
      return _LegacyValue(AppSettings.initial());
    }
  }

  _LegacyNotes _readNotes() {
    try {
      final raw = preferences.getString(_notesKey);
      if (raw == null) return (values: const [], rejected: null);
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('notes list');
      final result = <TranscriptNote>[];
      final rejected = <Object?>[];
      final ids = <String>{};
      for (final value in decoded) {
        final note = _tryReadNote(value, ids);
        if (note == null) {
          rejected.add(value);
        } else {
          result.add(note);
        }
      }
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return (
        values: result,
        rejected: result.isEmpty && rejected.isNotEmpty ? null : rejected,
      );
    } catch (_) {
      return (values: const [], rejected: null);
    }
  }

  Future<bool> _storeRejectedNotes(List<Object?> rejected) async {
    if (rejected.isEmpty) return true;
    try {
      // Another engine may already have written the recovery preference.
      await preferences.reload();
      final current = preferences.get(rejectedNotesRecoveryKey);
      final existing = _readRecoveryRecords(current);
      final seen = existing.map(jsonEncode).toSet();
      final additions = rejected.where(
        (record) => seen.add(jsonEncode(record)),
      );
      // Commit a readable recovery copy before marking the original removable.
      return await preferences.setString(
        rejectedNotesRecoveryKey,
        jsonEncode([...existing, ...additions]),
      );
    } catch (_) {
      return false;
    }
  }

  List<Object?> _readRecoveryRecords(Object? value) {
    if (value == null) return [];
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) return decoded;
      } on FormatException {
        // Preserve unfamiliar prior recovery data as a separate record.
      }
    }
    return [
      {'unparsedRecoveryValue': value.toString()},
    ];
  }

  TranscriptNote? _tryReadNote(Object? value, Set<String> ids) {
    try {
      final json = _validatedNoteJson(value);
      final note = TranscriptNote.fromJson(json);
      if (!ids.add(note.id)) throw const FormatException('duplicate note id');
      return note;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _validatedNoteJson(Object? value) {
    if (value is! Map) throw const FormatException('note object');
    final json = value.cast<String, dynamic>();
    final id = json['id'];
    if (id is! String || id.isEmpty) throw const FormatException('note id');
    final createdAt = json['createdAt'];
    if (createdAt is! String || DateTime.tryParse(createdAt) == null) {
      throw const FormatException('note timestamp');
    }
    return json;
  }

  Map<RemoteProviderId, String> _selectedModel(
    Object? value,
    RemoteProviderId provider,
  ) {
    if (value is! Map) return const {};
    final model = value[provider.id];
    return model is String && model.isNotEmpty ? {provider: model} : const {};
  }

  RemoteProviderId _provider(Object? value, RemoteProviderId fallback) =>
      value == RemoteProviderId.openai.id
      ? RemoteProviderId.openai
      : value == RemoteProviderId.google.id
      ? RemoteProviderId.google
      : fallback;

  AppThemeMode _themeMode(Map<String, dynamic> json) {
    final value = json['themeMode'];
    if (value is String) {
      return AppThemeMode.values.firstWhere(
        (mode) => mode.name == value,
        orElse: () => AppThemeMode.system,
      );
    }
    return switch (json['brightness']) {
      'dark' => AppThemeMode.dark,
      'light' => AppThemeMode.light,
      _ => AppThemeMode.system,
    };
  }
}

final class _LegacyValue<T> {
  const _LegacyValue(this.value, {this.canRemove = false});

  final T value;
  final bool canRemove;
}

typedef _LegacyNotes = ({List<TranscriptNote> values, List<Object?>? rejected});
