import 'package:drift/drift.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_accent.dart';
import '../database/app_database.dart';
import '../models/app_settings.dart';
import '../models/remote_provider.dart';
import '../models/transcription_language.dart';

/// Persists non-secret settings in Drift and provider keys in secure storage.
class SettingsRepository {
  SettingsRepository(this._database, {FlutterSecureStorage? secureStorage})
    : _secure = secureStorage ?? const FlutterSecureStorage();

  final AppDatabase _database;
  final FlutterSecureStorage _secure;

  static const _settingsId = 1;
  static String _apiKeyKey(RemoteProviderId provider) =>
      'api_key_${provider.id}';

  Future<AppSettings> load() async {
    final row = await (_database.select(
      _database.appSettingsTable,
    )..where((table) => table.id.equals(_settingsId))).getSingleOrNull();
    return row == null ? AppSettings.initial() : _fromRow(row);
  }

  Future<void> save(AppSettings settings) => _database
      .into(_database.appSettingsTable)
      .insert(_toCompanion(settings), mode: InsertMode.insertOrReplace);

  Future<String?> apiKey(RemoteProviderId provider) {
    _ensureSupported(provider);
    return _secure.read(key: _apiKeyKey(provider));
  }

  Future<void> setApiKey(RemoteProviderId provider, String key) {
    _ensureSupported(provider);
    return _secure.write(key: _apiKeyKey(provider), value: key);
  }

  Future<void> deleteApiKey(RemoteProviderId provider) {
    _ensureSupported(provider);
    return _secure.delete(key: _apiKeyKey(provider));
  }

  Future<Map<RemoteProviderId, bool>> connectedProviders() async {
    final result = <RemoteProviderId, bool>{};
    for (final provider in RemoteProviderId.values) {
      final key = await apiKey(provider);
      result[provider] = key != null && key.isNotEmpty;
    }
    return result;
  }

  AppSettings _fromRow(AppSettingsTableData row) {
    final asrProvider = RemoteProviderId.fromId(row.asrProvider);
    final summaryProvider = RemoteProviderId.fromId(row.summaryProvider);
    return AppSettings(
      themeMode: _themeMode(row.themeMode),
      accent: AppAccent.fromId(row.accent),
      language: AppLanguage.fromCode(row.language),
      transcriptionLanguage: TranscriptionLanguage.fromCode(
        row.transcriptionLanguage,
      ),
      asrProvider: asrProvider,
      summaryProvider: summaryProvider,
      asrModelByProvider: {asrProvider: row.asrModel},
      chatModelByProvider: {summaryProvider: row.summaryModel},
      autoDeleteAudio: row.autoDeleteAudio,
      summarizeEnabled: row.summarizeEnabled,
      onboarded: row.onboarded,
    );
  }

  AppSettingsTableCompanion _toCompanion(AppSettings settings) =>
      AppSettingsTableCompanion.insert(
        id: const Value(_settingsId),
        themeMode: settings.themeMode.name,
        accent: settings.accent.id,
        language: settings.language.code,
        transcriptionLanguage: settings.transcriptionLanguage.code,
        asrProvider: settings.asrProvider.id,
        summaryProvider: settings.summaryProvider.id,
        asrModel: settings.asrModelId(settings.asrProvider),
        summaryModel: settings.summaryModelId(settings.summaryProvider),
        autoDeleteAudio: settings.autoDeleteAudio,
        summarizeEnabled: settings.summarizeEnabled,
        onboarded: settings.onboarded,
      );

  void _ensureSupported(RemoteProviderId provider) {
    if (!RemoteProviderId.values.contains(provider)) {
      throw ArgumentError.value(provider, 'provider', 'Unsupported provider');
    }
  }

  ThemeMode _themeMode(String value) => ThemeMode.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => ThemeMode.system,
  );
}
