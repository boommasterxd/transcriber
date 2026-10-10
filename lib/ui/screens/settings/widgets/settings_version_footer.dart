import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/app_version_provider.dart';
import '../../../../state/settings_controller.dart';

/// Installed package version shown below the settings overview.
class SettingsVersionFooter extends ConsumerWidget {
  const SettingsVersionFooter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final version = ref.watch(appVersionProvider);
    return Text(
      version.when(
        data: (value) => 'Transcriber · ${strings.appVersion} $value',
        loading: () => 'Transcriber',
        error: (_, _) => 'Transcriber · ${strings.versionUnavailable}',
      ),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12.5, color: context.palette.body),
    );
  }
}
