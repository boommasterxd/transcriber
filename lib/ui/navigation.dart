import 'package:flutter/material.dart';

import '../data/models/transcript_note.dart';
import 'screens/detail/transcript_detail_screen.dart';
import 'screens/processing/processing_screen.dart';
import 'screens/record/record_screen.dart';
import 'screens/settings/settings_screen.dart';

/// Global navigator key so background events (share intents) can navigate.
final navigatorKey = GlobalKey<NavigatorState>();

/// Centralized navigation so screens don't depend on each other's constructors.
class AppNavigator {
  const AppNavigator._();

  static Future<void> openSettings(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));

  static Future<void> openRecord(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecordScreen()));

  static Future<void> openDetail(BuildContext context, String noteId) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => TranscriptDetailScreen(noteId: noteId)));

  /// Starts processing of [audioPath]; the processing screen routes to the
  /// detail screen on success.
  static Future<void> startProcessing(
    BuildContext context, {
    required String audioPath,
    required NoteSource source,
    String? fileName,
    int? knownDurationSec,
  }) =>
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProcessingScreen(
            audioPath: audioPath,
            source: source,
            fileName: fileName,
            knownDurationSec: knownDurationSec,
          ),
        ),
      );

  /// Same as [startProcessing] but using the root navigator (for share intents).
  static Future<void> startProcessingFromRoot({
    required String audioPath,
    required NoteSource source,
    String? fileName,
  }) {
    final nav = navigatorKey.currentState;
    if (nav == null) return Future.value();
    return nav.push(
      MaterialPageRoute(
        builder: (_) => ProcessingScreen(audioPath: audioPath, source: source, fileName: fileName),
      ),
    );
  }
}
