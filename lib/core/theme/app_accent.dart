import 'package:flutter/material.dart' show Color;

import '../../data/models/app_accent.dart';

export '../../data/models/app_accent.dart';

/// Design-system colors for framework-independent persisted accent choices.
extension AppAccentPresentation on AppAccent {
  Color get color => switch (this) {
    AppAccent.violet => const Color(0xFF6C5CE7),
    AppAccent.blue => const Color(0xFF2F7BF6),
    AppAccent.emerald => const Color(0xFF12A36B),
    AppAccent.amber => const Color(0xFFE8883A),
    AppAccent.magenta => const Color(0xFFC13D9E),
  };
}
