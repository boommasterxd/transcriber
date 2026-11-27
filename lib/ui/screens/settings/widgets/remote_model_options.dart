import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../services/remote/remote_api_client.dart';
import 'remote_model_option.dart';

/// Scrollable, accessible choices from the provider's live task-specific catalog.
class RemoteModelOptions extends StatelessWidget {
  const RemoteModelOptions({
    super.key,
    required this.catalog,
    required this.selectedModelId,
    required this.onSelect,
    required this.onRefresh,
    required this.strings,
  });

  final AsyncValue<List<RemoteModelInfo>> catalog;
  final String? selectedModelId;
  final ValueChanged<String> onSelect;
  final VoidCallback onRefresh;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final models = catalog.isLoading || catalog.hasError
        ? const <RemoteModelInfo>[]
        : catalog.requireValue;
    final message = _statusMessage(models);
    final retry = message != null && !catalog.isLoading;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(retry ? strings.retry : strings.refreshModels),
            ),
          ),
        ),
        if (message != null)
          SliverToBoxAdapter(child: _CatalogMessage(message: message))
        else
          SliverList.separated(
            itemCount: models.length,
            separatorBuilder: (_, _) => Divider(color: context.palette.line),
            itemBuilder: (context, index) {
              final model = models[index];
              return RemoteModelOption(
                key: ValueKey(model.id),
                model: model,
                selected: model.id == selectedModelId,
                onActivate: () => onSelect(model.id),
              );
            },
          ),
      ],
    );
  }

  String? _statusMessage(List<RemoteModelInfo> models) {
    if (catalog.isLoading) return strings.modelsLoading;
    if (catalog.hasError) return strings.modelLoadFailed;
    return models.isEmpty ? strings.noModels : null;
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.palette.body),
      ),
    ),
  );
}
