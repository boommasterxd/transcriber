import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/repositories/settings_repository.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SettingsRepository(prefs);
  final settings = await settingsRepo.load();
  final connections = await settingsRepo.connectedProviders();

  // Required before any flutter_gemma use; the HF token enables gated downloads.
  try {
    await FlutterGemma.initialize(
      huggingFaceToken: settings.hfToken.isEmpty ? null : settings.hfToken,
    );
  } catch (_) {
    // Initialization is best-effort; downloads surface their own errors.
  }

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialSettingsProvider.overrideWithValue(settings),
        initialConnectionsProvider.overrideWithValue(connections),
      ],
      child: const TranscriberApp(),
    ),
  );
}
