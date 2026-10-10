import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../services/remote/remote_api_client.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/provider_logo.dart';
import 'remote_stage.dart';

/// Shows a valid catalog name or an actionable status, never a fabricated choice.
class SelectedModelRow extends ConsumerWidget {
  const SelectedModelRow({
    super.key,
    required this.selection,
    required this.catalog,
    required this.onTap,
  });

  final RemoteModelSelection selection;
  final AsyncValue<List<RemoteModelInfo>>? catalog;
  final VoidCallback? onTap;

  ({String title, String? issue}) _content(AppStrings strings) {
    if (catalog == null) {
      return (title: strings.chooseModel, issue: strings.connectFirst);
    }
    if (catalog!.isLoading) return (title: strings.modelsLoading, issue: null);
    if (catalog!.hasError) {
      return (title: strings.chooseModel, issue: strings.modelLoadFailed);
    }
    final models = catalog!.requireValue;
    for (final model in models) {
      if (model.id == selection.modelId) {
        return (title: model.display, issue: null);
      }
    }
    return (
      title: strings.chooseModel,
      issue: models.isEmpty
          ? strings.noModels
          : selection.modelId.isEmpty
          ? null
          : strings.modelUnavailable,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final content = _content(strings);
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.line)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.remoteModel,
              style: TextStyle(fontSize: 11.5, color: palette.body),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ProviderLogo(provider: selection.provider, size: 32),
                const SizedBox(width: 12),
                Expanded(child: _modelDetails(context, content.title)),
                const SizedBox(width: 12),
                if (catalog?.isLoading ?? false)
                  SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      semanticsLabel: strings.modelsLoading,
                    ),
                  )
                else if (onTap != null)
                  Icon(Icons.chevron_right_rounded, color: palette.muted),
              ],
            ),
            if (content.issue != null) ...[
              const SizedBox(height: 8),
              Text(
                content.issue!,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: palette.body,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _modelDetails(BuildContext context, String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: context.palette.ink,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        RemoteCatalog.provider(selection.provider).name,
        style: TextStyle(fontSize: 12.5, color: context.palette.body),
      ),
    ],
  );
}
