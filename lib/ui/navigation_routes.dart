import 'package:flutter/material.dart';

import 'screens/settings/settings_screen.dart';

/// A shared fade and slide-up transition for in-app navigation.
Route<T> fadeSlideRoute<T>(Widget page) {
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

Future<void> openSettingsRoute(BuildContext context) {
  FocusManager.instance.primaryFocus?.unfocus();
  return Navigator.of(context).push(fadeSlideRoute(const SettingsScreen()));
}
