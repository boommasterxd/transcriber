import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/catalog/remote_catalog.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/model_tile.dart';
import '../../../widgets/surfaces.dart';

/// Selectable list of cloud providers (optionally filtered, e.g. ASR-capable
/// providers only).
class ProviderPicker extends ConsumerWidget {
  const ProviderPicker({
    super.key,
    required this.allowed,
    required this.selected,
    required this.onSelect,
  });

  final List<RemoteProviderId> allowed;
  final RemoteProviderId selected;
  final ValueChanged<RemoteProviderId> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final providers = RemoteCatalog.providers
        .where((p) => allowed.contains(p.id))
        .toList();
    return SurfaceCard(
      clip: true,
      child: Column(
        children: [
          for (final (i, p) in providers.indexed)
            ModelTile(
              leading: Text(
                p.glyph,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              leadingColor: p.color,
              title: p.name,
              subtitle: p.id == RemoteProviderId.openrouter
                  ? t.providerSubOpenRouter
                  : p.sub,
              isLast: i == providers.length - 1,
              trailing: SelectionIndicator(selected: selected == p.id),
              onTap: () => onSelect(p.id),
            ),
        ],
      ),
    );
  }
}
