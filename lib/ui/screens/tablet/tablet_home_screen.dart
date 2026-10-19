import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../state/history_controller.dart';
import '../../../state/providers.dart';
import '../home/audio_import.dart';
import '../home/widgets/tablet_empty_pane.dart';
import '../home/widgets/tablet_sidebar.dart';
import 'tablet_detail_pane.dart';

/// Tablet master-detail layout with a persistent history sidebar.
class TabletHomeScreen extends ConsumerStatefulWidget {
  const TabletHomeScreen({super.key});

  @override
  ConsumerState<TabletHomeScreen> createState() => _TabletHomeScreenState();
}

class _TabletHomeScreenState extends ConsumerState<TabletHomeScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 344,
              child: TabletSidebar(
                selectedId: _selectedId,
                actions: TabletSidebarActions(
                  onQueryChanged: (query) {
                    ref.read(historyControllerProvider.notifier).search(query);
                  },
                  onSelect: (id) => setState(() => _selectedId = id),
                  onPickFile: () => startAudioImport(
                    context,
                    cacheManager: ref.read(audioCacheManagerProvider),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _selectedId == null
                  ? const TabletEmptyPane()
                  : TabletDetailPane(
                      key: ValueKey(_selectedId),
                      noteId: _selectedId!,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
