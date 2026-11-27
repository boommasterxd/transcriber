import 'package:material_ui/material_ui.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_palette.dart';
import '../../data/models/app_settings.dart';
import '../../services/processing/processing_profile.dart';

/// Shows where audio and, when enabled, transcript text will be sent.
class ProcessingRecipients extends StatelessWidget {
  const ProcessingRecipients({
    super.key,
    required this.settings,
    required this.strings,
  });

  final AppSettings settings;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final profile = ProcessingProfile.resolve(settings);
    final style = TextStyle(color: context.palette.body);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.shareAudioRecipient(profile.asr.providerName),
          style: style,
        ),
        if (settings.summarizeEnabled)
          Text(
            strings.shareTranscriptRecipient(profile.summary.providerName),
            style: style,
          ),
      ],
    );
  }
}
