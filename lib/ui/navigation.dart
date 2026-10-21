import 'package:flutter/material.dart';

import 'navigation_routes.dart';
import 'processing_navigation.dart';
import 'screens/detail/transcript_detail_screen.dart';
import 'screens/record/record_screen.dart';

export 'processing_navigation.dart' show ProcessingNavigationRequest;

/// Global navigator key so background events (share intents) can navigate.
final navigatorKey = GlobalKey<NavigatorState>();

/// Centralized navigation so screens don't depend on each other's constructors.
class AppNavigator {
  const AppNavigator._();

  static Future<void> openSettings(BuildContext context) {
    return openSettingsRoute(context);
  }

  static Future<void> openRecord(BuildContext context) =>
      Navigator.of(context).push(fadeSlideRoute(const RecordScreen()));

  static Future<void> openDetail(BuildContext context, String noteId) =>
      Navigator.of(
        context,
      ).push(fadeSlideRoute(TranscriptDetailScreen(noteId: noteId)));

  /// Starts the processing [request]; the processing screen routes to the
  /// detail screen on success. When [replace] is true the current route is
  /// replaced (used by the record screen so it doesn't linger underneath and
  /// swallow the back-from-detail pop).
  static Future<void> startProcessing(
    BuildContext context,
    ProcessingNavigationRequest request, {
    bool replace = false,
  }) {
    return startProcessingRoute(context, request, replace: replace);
  }
}
