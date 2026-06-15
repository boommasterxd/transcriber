import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../widgets/model_tile.dart';

/// A model row that shows a selection indicator when downloaded, a progress ring
/// while downloading, or a download chip otherwise. Tapping selects (if ready)
/// or starts the download; download errors surface as a snackbar.
class DownloadableModelTile extends StatelessWidget {
  const DownloadableModelTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.downloadLabel,
    required this.status,
    required this.selected,
    required this.isLast,
    required this.onSelect,
    required this.onDownload,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String downloadLabel;
  final ModelStatus status;
  final bool selected;
  final bool isLast;
  final VoidCallback onSelect;
  final Future<void> Function() onDownload;

  Future<void> _download(BuildContext context) async {
    try {
      await onDownload();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModelTile(
      leading: Icon(icon, size: 18, color: context.palette.accent),
      title: title,
      subtitle: subtitle,
      isLast: isLast,
      trailing: switch (status.status) {
        DownloadStatus.downloading => ProgressRing(progress: status.progress),
        DownloadStatus.downloaded => SelectionIndicator(selected: selected),
        DownloadStatus.notDownloaded => DownloadChip(label: downloadLabel, onTap: () => _download(context)),
      },
      onTap: () {
        if (status.isDownloaded) {
          onSelect();
        } else if (!status.isDownloading) {
          _download(context);
        }
      },
    );
  }
}
