import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/catalog/remote_catalog.dart';
import '../../../../state/settings_controller.dart';
import 'remote_stage_settings.dart';

/// Independently configurable cloud transcription provider and model.
class TranscriptionSection extends ConsumerWidget {
  const TranscriptionSection({super.key, this.showCredentials = false});

  final bool showCredentials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(
      settingsControllerProvider.select((settings) {
        final provider = settings.asrProvider;
        return (provider: provider, modelId: settings.asrModelId(provider));
      }),
    );
    final controller = ref.read(settingsControllerProvider.notifier);
    return RemoteStageSettings(
      selection: RemoteStageSelection(
        stage: RemoteStage.transcription,
        allowedProviders: RemoteCatalog.asrProviders,
        provider: selection.provider,
        modelId: selection.modelId,
      ),
      actions: RemoteStageActions(
        selectProvider: controller.setAsrProvider,
        selectModel: (modelId) =>
            controller.setAsrModel(selection.provider, modelId),
      ),
      showCredentials: showCredentials,
    );
  }
}
