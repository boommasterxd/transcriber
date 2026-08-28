import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/model_tile.dart';
import '../../../widgets/provider_logo.dart';
import '../../../widgets/surfaces.dart';

/// Selectable list of cloud providers (optionally filtered, e.g. ASR-capable
/// providers only).
class ProviderPicker extends ConsumerWidget {
  const ProviderPicker({
    super.key,
    required this.allowed,
    required this.selected,
    required this.forTranscription,
    required this.onSelect,
  });

  final List<RemoteProviderId> allowed;
  final RemoteProviderId selected;
  final bool forTranscription;
  final ValueChanged<RemoteProviderId> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final providers = RemoteCatalog.providers
        .where((p) => allowed.contains(p.id))
        .toList();
    return SurfaceCard(
      clip: true,
      child: Column(
        children: [
          for (final (i, p) in providers.indexed)
            ModelTile(
              leading: ProviderLogo(provider: p.id),
              leadingColor: Colors.transparent,
              title: p.name,
              subtitle: _description(strings, p.id),
              isLast: i == providers.length - 1,
              trailing: SelectionIndicator(selected: selected == p.id),
              onTap: () => onSelect(p.id),
            ),
        ],
      ),
    );
  }

  String _description(AppStrings strings, RemoteProviderId provider) {
    if (forTranscription) {
      return provider == RemoteProviderId.openai
          ? strings.transcriptionOpenAiDescription
          : strings.transcriptionGoogleDescription;
    }
    return provider == RemoteProviderId.openai
        ? strings.summaryOpenAiDescription
        : strings.summaryGoogleDescription;
  }
}
