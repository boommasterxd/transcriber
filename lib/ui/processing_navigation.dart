import 'package:material_ui/material_ui.dart';

import '../data/models/app_settings.dart';
import '../data/models/transcript_note.dart';
import '../services/storage/managed_audio_file.dart';
import 'navigation_routes.dart';
import 'screens/processing/processing_screen.dart';

/// Input needed to open the processing flow for one managed audio file.
final class ProcessingNavigationRequest {
  const ProcessingNavigationRequest({
    required this.audio,
    required this.source,
    required this.settings,
    this.fileName,
    this.knownDurationSec,
  });

  final ManagedAudioFile audio;
  final NoteSource source;
  final AppSettings settings;
  final String? fileName;
  final int? knownDurationSec;
}

/// Replaces the recording route so a completed note returns directly home.
Future<void> startProcessingRoute(
  BuildContext context,
  ProcessingNavigationRequest request, {
  bool replace = false,
}) {
  final route = fadeSlideRoute(
    ProcessingScreen(
      audio: request.audio,
      source: request.source,
      settings: request.settings,
      fileName: request.fileName,
      knownDurationSec: request.knownDurationSec,
    ),
  );
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}
