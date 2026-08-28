import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../data/models/transcript_note.dart';
import '../../../state/notes_controller.dart';
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
  String _query = '';

  void _clearMissingSelection(List<TranscriptNote> notes) {
    final selectedId = _selectedId;
    if (selectedId == null || notes.any((note) => note.id == selectedId)) {
      return;
    }
    setState(() => _selectedId = null);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notesControllerProvider, (_, notes) {
      _clearMissingSelection(notes);
    });

    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 344,
              child: TabletSidebar(
                query: _query,
                selectedId: _selectedId,
                actions: TabletSidebarActions(
                  onQueryChanged: (query) => setState(() => _query = query),
                  onSelect: (id) => setState(() => _selectedId = id),
                  onPickFile: () => startAudioImport(context),
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
