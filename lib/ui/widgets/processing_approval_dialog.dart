import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/app_settings.dart';
import 'processing_recipients.dart';

Future<bool> showProcessingApproval(
  BuildContext context, {
  required AppSettings settings,
  bool recovered = false,
}) async {
  final strings = AppStrings.of(settings.language);
  final accepted = await showDialog<bool>(
    context: context,
    useRootNavigator: false,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(
        recovered ? strings.recoveredAudioTitle : strings.shareConfirmTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recovered) ...[
            Text(strings.recoveredAudioBody),
            const SizedBox(height: 8),
          ],
          ProcessingRecipients(settings: settings, strings: strings),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _closeApproval(dialogContext, accepted: false),
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: () => _closeApproval(dialogContext, accepted: true),
          child: Text(
            recovered
                ? strings.recoveredAudioContinue
                : strings.shareConfirmAction,
          ),
        ),
      ],
    ),
  );
  return accepted == true;
}

void _closeApproval(BuildContext context, {required bool accepted}) {
  if (ModalRoute.of(context)?.isCurrent == true) {
    Navigator.of(context).pop(accepted);
  }
}
