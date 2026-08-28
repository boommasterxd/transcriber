import 'package:flutter/material.dart';

import '../data/models/transcript_note.dart';
import 'screens/detail/transcript_detail_screen.dart';
import 'screens/processing/processing_screen.dart';
import 'screens/record/record_screen.dart';
import 'screens/settings/settings_screen.dart';

/// Global navigator key so background events (share intents) can navigate.
final navigatorKey = GlobalKey<NavigatorState>();

/// A shared fade + slide-up page transition used for all in-app navigation.
Route<T> _fadeSlideRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// Centralized navigation so screens don't depend on each other's constructors.
class AppNavigator {
  const AppNavigator._();

  static Future<void> openSettings(BuildContext context) =>
      Navigator.of(context).push(_fadeSlideRoute(const SettingsScreen()));

  static Future<void> openRecord(BuildContext context) =>
      Navigator.of(context).push(_fadeSlideRoute(const RecordScreen()));

  static Future<void> openDetail(BuildContext context, String noteId) =>
      Navigator.of(
        context,
      ).push(_fadeSlideRoute(TranscriptDetailScreen(noteId: noteId)));

  /// Starts processing of [audioPath]; the processing screen routes to the
  /// detail screen on success. When [replace] is true the current route is
  /// replaced (used by the record screen so it doesn't linger underneath and
  /// swallow the back-from-detail pop).
  static Future<void> startProcessing(
    BuildContext context, {
    required String audioPath,
    required NoteSource source,
    String? fileName,
    int? knownDurationSec,
    bool replace = false,
  }) {
    final route = _fadeSlideRoute(
      ProcessingScreen(
        audioPath: audioPath,
        source: source,
        fileName: fileName,
        knownDurationSec: knownDurationSec,
      ),
    );
    final nav = Navigator.of(context);
    return replace ? nav.pushReplacement(route) : nav.push(route);
  }
}
