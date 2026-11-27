import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/models/app_settings.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/processing_recipients.dart';

class ShareProcessingConfirmation extends ConsumerWidget {
  const ShareProcessingConfirmation({
    super.key,
    required this.settings,
    required this.onConfirm,
    required this.onCancel,
  });

  final AppSettings settings;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              strings.shareConfirmTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          ProcessingRecipients(settings: settings, strings: strings),
          const SizedBox(height: 20),
          PillButton(label: strings.shareConfirmAction, onTap: onConfirm),
          const SizedBox(height: 8),
          PillButton.outlined(label: strings.cancel, onTap: onCancel),
        ],
      ),
    );
  }
}
