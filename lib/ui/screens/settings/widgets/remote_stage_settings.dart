import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/remote_provider.dart';
import '../../../../state/connections_controller.dart';
import '../../../../state/remote_models_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/surfaces.dart';
import 'model_task_header.dart';
import 'remote_model_sheet.dart';
import 'remote_stage.dart';
import 'selected_model_row.dart';

/// One complete task card, shared by setup and everyday model settings.
class RemoteStageSettings extends ConsumerWidget {
  const RemoteStageSettings({
    super.key,
    required this.stage,
    this.allowedProviders,
  });

  final RemoteStage stage;
  final List<RemoteProviderId>? allowedProviders;

  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    RemoteModelSelection selection,
    List<RemoteProviderId> providers,
  ) async {
    final choice = await showRemoteModelSheet(
      context,
      stage: stage,
      selection: selection,
      allowedProviders: providers,
    );
    if (choice == null || !context.mounted) return;
    final connected =
        ref.read(connectionsControllerProvider)[choice.provider] ?? false;
    final catalog = ref.read(
      remoteModelsProvider((
        provider: choice.provider,
        forTranscription: stage.forTranscription,
      )),
    );
    if (!connected ||
        catalog.isLoading ||
        catalog.hasError ||
        !(catalog.asData?.value.any((model) => model.id == choice.modelId) ??
            false)) {
      return;
    }
    final controller = ref.read(settingsControllerProvider.notifier);
    if (stage.forTranscription) {
      await controller.setAsrSelection(choice.provider, choice.modelId);
    } else {
      await controller.setSummarySelection(choice.provider, choice.modelId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final connections = ref.watch(connectionsControllerProvider);
    final transcription = stage.forTranscription;
    final enabled = transcription || settings.summarizeEnabled;
    final provider = transcription
        ? settings.asrProvider
        : settings.summaryProvider;
    final selection = (
      provider: provider,
      modelId: transcription
          ? settings.asrModelId(provider)
          : settings.summaryModelId(provider),
    );
    final providers = (allowedProviders ?? RemoteProviderId.values)
        .where((provider) => connections[provider] ?? false)
        .toList();
    final catalog = enabled && (connections[provider] ?? false)
        ? ref.watch(
            remoteModelsProvider((
              provider: provider,
              forTranscription: transcription,
            )),
          )
        : null;
    return SurfaceCard(
      clip: true,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ModelTaskHeader(
              stage: stage,
              enabled: enabled,
              onToggle: ref
                  .read(settingsControllerProvider.notifier)
                  .setSummarizeEnabled,
            ),
            if (enabled)
              SelectedModelRow(
                key: ValueKey('model-row-${stage.name}'),
                selection: selection,
                catalog: catalog,
                onTap: providers.isEmpty
                    ? null
                    : () => _choose(context, ref, selection, providers),
              ),
          ],
        ),
      ),
    );
  }
}
