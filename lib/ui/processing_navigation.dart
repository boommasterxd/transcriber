import 'package:flutter/material.dart';

import '../data/models/transcript_note.dart';
import '../services/storage/managed_audio_file.dart';
import 'navigation_routes.dart';
import 'screens/processing/processing_screen.dart';

/// Input needed to open the processing flow for one managed audio file.
final class ProcessingNavigationRequest {
  const ProcessingNavigationRequest({
    required this.audioPath,
    required this.ownership,
    required this.source,
    this.fileName,
    this.knownDurationSec,
  });

  final String audioPath;
  final AudioOwnership ownership;
  final NoteSource source;
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
      audioPath: request.audioPath,
      ownership: request.ownership,
      source: request.source,
      fileName: request.fileName,
      knownDurationSec: request.knownDurationSec,
    ),
  );
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement(route) : nav.push(route);
}
