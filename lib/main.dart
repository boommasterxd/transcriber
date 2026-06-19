import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/repositories/settings_repository.dart';
import 'share_entrypoint.dart';
import 'state/providers.dart';

/// Entry point for the translucent ShareActivity (the see-through share
/// overlay). Defined here in the main library — not in share_entrypoint.dart —
/// because Flutter resolves a named Dart entrypoint against the root library in
/// AOT/release builds; a named entrypoint in another file is unreliable there.
@pragma('vm:entry-point')
Future<void> shareMain() => runShareEntrypoint();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Sets up the port used to receive results from the foreground-service
  // isolate that runs on-device summarization in the background.
  FlutterForegroundTask.initCommunicationPort();

  // Background model downloads with a foreground-service notification so they
  // survive the app being backgrounded.
  FileDownloader().configureNotification(
    running: const TaskNotification('{filename}', 'Wird geladen… {progress}'),
    complete: const TaskNotification('{filename}', 'Fertig geladen'),
    error: const TaskNotification('{filename}', 'Download fehlgeschlagen'),
    progressBar: true,
  );

  final prefs = await SharedPreferences.getInstance();
  final settingsRepo = SettingsRepository(prefs);
  final settings = await settingsRepo.load();
  final connections = await settingsRepo.connectedProviders();

  // Required before any flutter_gemma use; both engines are registered so the
  // app can run .litertlm (LiteRT-LM FFI) and .task (MediaPipe) models.
  try {
    await FlutterGemma.initialize(
      inferenceEngines: const [LiteRtLmEngine(), MediaPipeEngine()],
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
