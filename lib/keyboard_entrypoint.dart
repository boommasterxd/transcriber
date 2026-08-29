import 'package:flutter/widgets.dart';

import 'data/database/app_database.dart';
import 'data/models/app_settings.dart';
import 'data/repositories/settings_repository.dart';
import 'ui/keyboard/keyboard_app.dart';

/// Starts the lightweight app surface embedded in Android's input method.
Future<void> runKeyboardEntrypoint() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase.defaults();
  final repository = SettingsRepository(database);
  var settings = AppSettings.initial();
  try {
    settings = await repository.load();
  } catch (_) {
    // Keep the input surface available if persisted settings cannot be loaded.
  }
  runApp(
    KeyboardApp(
      database: database,
      settingsRepository: repository,
      initialSettings: settings,
    ),
  );
}
