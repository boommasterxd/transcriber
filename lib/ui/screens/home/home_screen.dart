import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/history_controller.dart';
import 'audio_import.dart';
import 'widgets/phone_home_view.dart';

/// App home: search, active model, manual file import, history, and recording.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PhoneHomeView(
      onQueryChanged: (query) {
        ref.read(historyControllerProvider.notifier).search(query);
      },
      onPickFile: () => pickHomeAudio(context, ref),
    );
  }
}
