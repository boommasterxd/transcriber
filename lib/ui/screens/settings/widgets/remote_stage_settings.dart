import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/remote_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/surfaces.dart';
import 'provider_connect_card.dart';
import 'provider_picker.dart';
import 'remote_model_list.dart';

enum RemoteStage { transcription, summary }

class RemoteStageSelection {
  const RemoteStageSelection({
    required this.stage,
    required this.allowedProviders,
    required this.provider,
    required this.modelId,
  });

  final RemoteStage stage;
  final List<RemoteProviderId> allowedProviders;
  final RemoteProviderId provider;
  final String modelId;
}

class RemoteStageActions {
  const RemoteStageActions({
    required this.selectProvider,
    required this.selectModel,
  });

  final ValueChanged<RemoteProviderId> selectProvider;
  final ValueChanged<String> selectModel;
}

/// Provider credentials and model selection for a cloud processing stage.
class RemoteStageSettings extends ConsumerWidget {
  const RemoteStageSettings({
    super.key,
    required this.selection,
    required this.actions,
  });

  final RemoteStageSelection selection;
  final RemoteStageActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProviderPicker(
          allowed: selection.allowedProviders,
          selected: selection.provider,
          onSelect: actions.selectProvider,
        ),
        const SizedBox(height: 12),
        ProviderConnectCard(provider: selection.provider),
        const SizedBox(height: 12),
        SectionLabel(
          t.remoteModel,
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 9),
        ),
        RemoteModelList(
          provider: selection.provider,
          forTranscription: selection.stage == RemoteStage.transcription,
          selectedId: selection.modelId,
          onSelect: actions.selectModel,
        ),
      ],
    );
  }
}
