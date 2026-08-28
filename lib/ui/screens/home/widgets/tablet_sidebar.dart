import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../../state/notes_controller.dart';
import '../../../../state/settings_controller.dart';
import '../../../navigation.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/surfaces.dart';
import '../../../widgets/waveforms.dart';
import '../history_logic.dart';
import '../note_presentation.dart';
import 'active_model_pill.dart';
import 'home_search_bar.dart';
import 'note_badges.dart';
import 'swipe_delete_background.dart';

class TabletSidebarActions {
  const TabletSidebarActions({
    required this.onQueryChanged,
    required this.onSelect,
    required this.onPickFile,
  });

  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelect;
  final VoidCallback onPickFile;
}

class TabletSidebar extends ConsumerWidget {
  const TabletSidebar({
    super.key,
    required this.query,
    required this.selectedId,
    required this.actions,
  });

  final String query;
  final String? selectedId;
  final TabletSidebarActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(stringsProvider);
    final notes = ref.watch(notesControllerProvider);
    final filtered = filterNotesByTitle(notes, query);
    final groups = groupNotesByAge(filtered, now: DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: context.palette.surface,
        border: Border(right: BorderSide(color: context.palette.line)),
      ),
      child: Column(
        children: [
          _TabletControls(
            noteCount: notes.length,
            strings: strings,
            status: ref.watch(homeModelStatusProvider),
            actions: actions,
          ),
          Expanded(
            child: _TabletHistory(
              groups: groups,
              strings: strings,
              selectedId: selectedId,
              onSelect: actions.onSelect,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletControls extends StatelessWidget {
  const _TabletControls({
    required this.noteCount,
    required this.strings,
    required this.status,
    required this.actions,
  });

  final int noteCount;
  final AppStrings strings;
  final HomeModelStatus status;
  final TabletSidebarActions actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabletHeader(noteCount: noteCount, strings: strings),
          const SizedBox(height: 16),
          HomeSearchBar(
            hint: strings.search,
            onChanged: actions.onQueryChanged,
            style: HomeSearchStyle.tablet,
          ),
          const SizedBox(height: 14),
          _TabletPrimaryActions(strings: strings, actions: actions),
          const SizedBox(height: 14),
          ActiveModelPill(
            label: status.label,
            warning: status.warning,
            onTap: () => AppNavigator.openSettings(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _TabletHeader extends StatelessWidget {
  const _TabletHeader({required this.noteCount, required this.strings});

  final int noteCount;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.homeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                ),
              ),
              Text(
                strings.homeSub(noteCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: palette.muted),
              ),
            ],
          ),
        ),
        IconCircleButton(
          icon: Icons.settings_outlined,
          onTap: () => AppNavigator.openSettings(context),
        ),
      ],
    );
  }
}

class _TabletPrimaryActions extends StatelessWidget {
  const _TabletPrimaryActions({required this.strings, required this.actions});

  final AppStrings strings;
  final TabletSidebarActions actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PillButton(
          label: strings.tabRecord,
          icon: Icons.mic_rounded,
          height: 50,
          onTap: () => AppNavigator.openRecord(context),
        ),
        const SizedBox(height: 10),
        PillButton(
          label: strings.pickTitle,
          icon: Icons.file_upload_outlined,
          height: 48,
          outlined: true,
          onTap: actions.onPickFile,
        ),
      ],
    );
  }
}

class _TabletHistory extends StatelessWidget {
  const _TabletHistory({
    required this.groups,
    required this.strings,
    required this.selectedId,
    required this.onSelect,
  });

  final List<HistoryGroup> groups;
  final AppStrings strings;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return FadeEdges(
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        children: [
          for (final group in groups)
            _TabletHistoryGroup(
              group: group,
              strings: strings,
              selectedId: selectedId,
              onSelect: onSelect,
            ),
        ],
      ),
    );
  }
}

class _TabletHistoryGroup extends StatelessWidget {
  const _TabletHistoryGroup({
    required this.group,
    required this.strings,
    required this.selectedId,
    required this.onSelect,
  });

  final HistoryGroup group;
  final AppStrings strings;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabletGroupLabel(text: historyPeriodLabel(group.period, strings)),
        for (final note in group.notes)
          DismissibleHistoryNote(
            note: note,
            strings: strings,
            style: SwipeDeleteStyle.tablet,
            child: TabletHistoryRow(
              note: note,
              strings: strings,
              selected: note.id == selectedId,
              onTap: () => onSelect(note.id),
            ),
          ),
      ],
    );
  }
}

class _TabletGroupLabel extends StatelessWidget {
  const _TabletGroupLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: context.palette.faint,
        ),
      ),
    ),
  );
}

class TabletHistoryRow extends StatelessWidget {
  const TabletHistoryRow({
    super.key,
    required this.note,
    required this.strings,
    required this.selected,
    required this.onTap,
  });

  final TranscriptNote note;
  final AppStrings strings;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? palette.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Center(child: MiniWave()),
            ),
            const SizedBox(width: 12),
            Expanded(child: _TabletNoteText(note: note)),
            const SizedBox(width: 8),
            TodoCountBadge(
              count: note.todos.length,
              strings: strings,
              density: TodoBadgeDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabletNoteText extends StatelessWidget {
  const _TabletNoteText({required this.note});

  final TranscriptNote note;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        note.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w700,
          color: context.palette.ink,
        ),
      ),
      const SizedBox(height: 3),
      NoteModelBadge(note: note),
    ],
  );
}
