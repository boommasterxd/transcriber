import 'package:flutter/material.dart';

import '../../../../state/model_manager_controller.dart';
import '../../../widgets/surfaces.dart';
import 'downloadable_model_tile.dart';

typedef LocalStageModelOption = ({
  String id,
  String title,
  String subtitle,
  ModelStatus status,
  bool selected,
});

class LocalStageModelActions {
  const LocalStageModelActions({
    required this.select,
    required this.download,
    required this.delete,
  });

  final ValueChanged<String> select;
  final Future<void> Function(String id) download;
  final Future<void> Function(String id) delete;
}

/// Downloadable on-device models for one processing stage.
class LocalStageModelList extends StatelessWidget {
  const LocalStageModelList({
    super.key,
    required this.icon,
    required this.downloadLabel,
    required this.options,
    required this.actions,
  });

  final IconData icon;
  final String downloadLabel;
  final List<LocalStageModelOption> options;
  final LocalStageModelActions actions;

  @override
  Widget build(BuildContext context) => SurfaceCard(
    clip: true,
    child: Column(
      children: [
        for (final (index, option) in options.indexed)
          DownloadableModelTile(
            copy: (
              icon: icon,
              title: option.title,
              subtitle: option.subtitle,
              downloadLabel: downloadLabel,
            ),
            selection: (
              status: option.status,
              selected: option.selected,
              isLast: index == options.length - 1,
            ),
            actions: (
              select: () => actions.select(option.id),
              download: () => actions.download(option.id),
              delete: () => actions.delete(option.id),
            ),
          ),
      ],
    ),
  );
}
