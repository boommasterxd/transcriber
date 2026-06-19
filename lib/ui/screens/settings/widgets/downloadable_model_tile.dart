import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../state/model_manager_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/model_tile.dart';

/// A model row that shows a selection indicator when downloaded, a progress ring
/// while downloading, or a download chip otherwise. Downloaded models also get a
/// delete button (with confirmation). Tapping the row selects (if ready) or
/// starts the download; errors surface as a snackbar.
class DownloadableModelTile extends ConsumerWidget {
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
    this.onDelete,
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
  final Future<void> Function()? onDelete;

  Future<void> _guard(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final t = ref.read(stringsProvider);
    final palette = context.palette;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(title, style: TextStyle(color: palette.ink, fontSize: 17, fontWeight: FontWeight.w800)),
        content: Text(t.deleteModelConfirm, style: TextStyle(color: palette.body, fontSize: 14, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel, style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.delete, style: TextStyle(color: palette.coralInk, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) await _guard(context, onDelete!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    Widget trailing;
    switch (status.status) {
      case DownloadStatus.downloading:
        trailing = ProgressRing(progress: status.progress);
      case DownloadStatus.downloaded:
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onDelete != null)
              GestureDetector(
                onTap: () => _confirmDelete(context, ref),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.delete_outline_rounded, size: 20, color: palette.coralInk),
                ),
              ),
            SelectionIndicator(selected: selected),
          ],
        );
      case DownloadStatus.notDownloaded:
        trailing = DownloadChip(label: downloadLabel, onTap: () => _guard(context, onDownload));
    }

    return ModelTile(
      leading: Icon(icon, size: 18, color: palette.accent),
      title: title,
      subtitle: subtitle,
      isLast: isLast,
      trailing: trailing,
      onTap: () {
        if (status.isDownloaded) {
          onSelect();
        } else if (!status.isDownloading) {
          _guard(context, onDownload);
        }
      },
    );
  }
}
