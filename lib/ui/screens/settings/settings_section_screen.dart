import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/settings_controller.dart';
import '../../widgets/surfaces.dart';
import 'widgets/appearance_section.dart';
import 'widgets/keyboard_section.dart';
import 'widgets/keyboard_guide.dart';
import 'widgets/language_section.dart';
import 'widgets/privacy_section.dart';
import 'widgets/settings_page.dart';

enum SettingsCategory { keyboard, general }

/// A focused page for an existing group of settings.
class SettingsSectionScreen extends ConsumerWidget {
  const SettingsSectionScreen({super.key, required this.category});

  final SettingsCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final (title, sections) = switch (category) {
      SettingsCategory.keyboard => (
        strings.keyboardSection,
        const <Widget>[
          KeyboardSection(),
          SizedBox(height: 28),
          KeyboardGuide(),
        ],
      ),
      SettingsCategory.general => (
        strings.setGeneral,
        <Widget>[
          SectionLabel(strings.setLang),
          const LanguageSection(),
          SectionLabel(strings.setAppear),
          const AppearanceSection(),
          SectionLabel(strings.setPriv),
          const PrivacySection(),
        ],
      ),
    };
    return SettingsPage(title: title, children: sections);
  }
}
