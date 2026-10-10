import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/settings_controller.dart';
import 'remote_stage.dart';

/// Gives a task its own hierarchy and keeps the optional switch inside its card.
class ModelTaskHeader extends ConsumerWidget {
  const ModelTaskHeader({
    super.key,
    required this.stage,
    required this.enabled,
    required this.onToggle,
  });

  final RemoteStage stage;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final transcription = stage.forTranscription;
    final title = transcription
        ? strings.transcriptionTaskTitle
        : strings.setLlm;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(
              transcription ? Icons.graphic_eq_rounded : Icons.list_alt_rounded,
              color: context.palette.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: context.palette.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  transcription
                      ? strings.transcriptionTaskDescription
                      : strings.summaryTaskDescription,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: context.palette.body,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  transcription ? strings.alwaysActive : strings.optionalTask,
                  style: TextStyle(fontSize: 11.5, color: context.palette.body),
                ),
              ],
            ),
          ),
          if (!transcription)
            Semantics(
              label: title,
              child: Switch(value: enabled, onChanged: onToggle),
            ),
        ],
      ),
    );
  }
}
