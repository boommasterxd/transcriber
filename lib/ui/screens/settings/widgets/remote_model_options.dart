import 'package:flutter/material.dart';
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
    required this.onRetry,
    required this.strings,
  });

  final AsyncValue<List<RemoteModelInfo>> catalog;
  final VoidCallback onRetry;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    if (catalog.isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(
              semanticsLabel: strings.modelsLoading,
            ),
          ),
        ),
      );
    }
    if (catalog.hasError) {
      return SliverToBoxAdapter(
        child: _CatalogMessage(
          message: strings.modelLoadFailed,
          retry: (label: strings.retry, action: onRetry),
        ),
      );
    }
    final models = catalog.requireValue;
    if (models.isEmpty) {
      return SliverToBoxAdapter(
        child: _CatalogMessage(
          message: strings.noModels,
          retry: (label: strings.retry, action: onRetry),
        ),
      );
    }
    return SliverList.separated(
      itemCount: models.length,
      separatorBuilder: (_, _) => Divider(color: context.palette.line),
      itemBuilder: (context, index) => RemoteModelOption(
        key: ValueKey(models[index].id),
        model: models[index],
      ),
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage({required this.message, required this.retry});

  final String message;
  final ({String label, VoidCallback action}) retry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.palette.body),
        ),
      ),
      TextButton.icon(
        onPressed: retry.action,
        icon: const Icon(Icons.refresh_rounded),
        label: Text(retry.label),
      ),
    ],
  );
}
