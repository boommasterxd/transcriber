import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/remote_provider.dart';
import '../../../../state/remote_models_provider.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/model_tile.dart';
import '../../../widgets/surfaces.dart';

/// Live, selectable list of a cloud provider's models for one stage.
class RemoteModelList extends ConsumerWidget {
  const RemoteModelList({
    super.key,
    required this.provider,
    required this.forTranscription,
    required this.selectedId,
    required this.onSelect,
  });

  final RemoteProviderId provider;
  final bool forTranscription;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final async = ref.watch(
      remoteModelsProvider((provider: provider, forTranscription: forTranscription)),
    );

    Widget card(Widget child) => SurfaceCard(padding: const EdgeInsets.all(20), child: Center(child: child));

    return async.when(
      loading: () => card(
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(palette.accent)),
        ),
      ),
      error: (e, _) => card(
        Text(
          e.toString(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: palette.coralInk),
        ),
      ),
      data: (models) {
        if (models.isEmpty) {
          return card(Text(t.connectFirst, style: TextStyle(fontSize: 13.5, color: palette.muted)));
        }
        return SurfaceCard(
          clip: true,
          child: Column(
            children: [
              for (final (i, m) in models.indexed)
                ModelTile(
                  leading: Icon(
                    forTranscription ? Icons.graphic_eq_rounded : Icons.auto_awesome_outlined,
                    size: 18,
                    color: palette.accent,
                  ),
                  title: m.display,
                  subtitle: m.display == m.id ? '' : m.id,
                  isLast: i == models.length - 1,
                  trailing: SelectionIndicator(selected: selectedId == m.id),
                  onTap: () => onSelect(m.id),
                ),
            ],
          ),
        );
      },
    );
  }
}
