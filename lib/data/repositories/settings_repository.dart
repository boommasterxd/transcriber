import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';
import '../models/remote_provider.dart';

/// Persists [AppSettings] in shared preferences and API keys / HF token in
/// secure storage (never written to plain prefs).
class SettingsRepository {
  SettingsRepository(this._prefs, {FlutterSecureStorage? secureStorage})
    : _secure = secureStorage ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  static const _settingsKey = 'app_settings';
  static const _hfTokenKey = 'hf_token';
  static String _apiKeyKey(RemoteProviderId p) => 'api_key_${p.id}';

  Future<AppSettings> load() async {
    final raw = _prefs.getString(_settingsKey);
    final hfToken = await _secure.read(key: _hfTokenKey) ?? '';
    if (raw == null) return AppSettings.initial().copyWith(hfToken: hfToken);
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(json, hfToken: hfToken);
    } catch (_) {
      return AppSettings.initial().copyWith(hfToken: hfToken);
    }
  }

  Future<void> save(AppSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
    await _secure.write(key: _hfTokenKey, value: settings.hfToken);
  }

  Future<String?> apiKey(RemoteProviderId provider) =>
      _secure.read(key: _apiKeyKey(provider));

  Future<void> setApiKey(RemoteProviderId provider, String key) =>
      _secure.write(key: _apiKeyKey(provider), value: key);

  Future<void> deleteApiKey(RemoteProviderId provider) =>
      _secure.delete(key: _apiKeyKey(provider));

  Future<Map<RemoteProviderId, bool>> connectedProviders() async {
    final result = <RemoteProviderId, bool>{};
    for (final p in RemoteProviderId.values) {
      final key = await _secure.read(key: _apiKeyKey(p));
      result[p] = key != null && key.isNotEmpty;
    }
    return result;
  }
}
