import 'package:flutter/material.dart';

/// The five selectable accent colors from the design system.
enum AppAccent {
  violet('violet', Color(0xFF6C5CE7)),
  blue('blue', Color(0xFF2F7BF6)),
  emerald('emerald', Color(0xFF12A36B)),
  amber('amber', Color(0xFFE8883A)),
  magenta('magenta', Color(0xFFC13D9E));

  const AppAccent(this.id, this.color);

  /// Stable identifier used for persistence.
  final String id;

  /// Base accent color.
  final Color color;

  static AppAccent fromId(String? id) => AppAccent.values.firstWhere(
    (a) => a.id == id,
    orElse: () => AppAccent.blue,
  );
}
