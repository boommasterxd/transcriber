import 'dart:convert';

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
  static const _settingsKey = 'app_settings';
  static const _notesKey = 'notes';
  static const _hfTokenKey = 'hf_token';
  static const _obsoleteProviderKeys = [
    'api_key_anthropic',
    'api_key_openrouter',
  ];

  Future<void> migrate() async {
    final imported = await database.transaction<_LegacyData?>(() async {
      final existing = await (database.select(
        database.migrationStateTable,
      )..where((table) => table.key.equals(marker))).getSingleOrNull();
      if (existing != null) return null;

      final imported = _readLegacyData();
      await database
          .into(database.migrationStateTable)
          .insert(
            MigrationStateTableCompanion.insert(
              key: marker,
              completedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await SettingsRepository(database).save(imported.settings);
      await NotesRepository(database).replaceAllInTransaction(imported.notes);
      return imported;
    });

    if (imported?.settingsCanBeRemoved ?? false) {
      await preferences.remove(_settingsKey);
    }
    if (imported?.notesCanBeRemoved ?? false) {
      await preferences.remove(_notesKey);
    }
    await secureStorage.delete(key: _hfTokenKey);
    for (final key in _obsoleteProviderKeys) {
      await secureStorage.delete(key: key);
    }
  }

  _LegacyData _readLegacyData() => _LegacyData(
    settings: _readSettings(),
    notes: _readNotes(),
    settingsCanBeRemoved: _settingsCanBeRemoved,
    notesCanBeRemoved: _notesCanBeRemoved,
  );

  bool _settingsCanBeRemoved = true;
  bool _notesCanBeRemoved = true;

  AppSettings _readSettings() {
    final raw = preferences.getString(_settingsKey);
    if (raw == null) return AppSettings.initial();
    try {
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
      return AppSettings(
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
    } catch (_) {
      _settingsCanBeRemoved = false;
      return AppSettings.initial();
    }
  }

  List<TranscriptNote> _readNotes() {
    final raw = preferences.getString(_notesKey);
    if (raw == null) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) throw const FormatException('notes list');
      final result = <TranscriptNote>[];
      final ids = <String>{};
      for (final value in decoded) {
        final note = _tryReadNote(value, ids);
        if (note == null) continue;
        result.add(note);
      }
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return result;
    } catch (_) {
      _notesCanBeRemoved = false;
      return const [];
    }
  }

  TranscriptNote? _tryReadNote(Object? value, Set<String> ids) {
    try {
      final json = _validatedNoteJson(value);
      final note = TranscriptNote.fromJson(json);
      if (!ids.add(note.id)) throw const FormatException('duplicate note id');
      return note;
    } catch (_) {
      _notesCanBeRemoved = false;
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

final class _LegacyData {
  const _LegacyData({
    required this.settings,
    required this.notes,
    required this.settingsCanBeRemoved,
    required this.notesCanBeRemoved,
  });

  final AppSettings settings;
  final List<TranscriptNote> notes;
  final bool settingsCanBeRemoved;
  final bool notesCanBeRemoved;
}
