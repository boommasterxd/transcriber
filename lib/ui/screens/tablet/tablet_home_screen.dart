import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/transcript_note.dart';
import '../../../state/notes_controller.dart';
import '../../../state/settings_controller.dart';
import '../../navigation.dart';
import '../../widgets/buttons.dart';
import '../../widgets/note_actions.dart';
import '../../widgets/surfaces.dart';
import '../../widgets/waveforms.dart';
import 'tablet_detail_pane.dart';

/// Tablet master–detail layout: a persistent sidebar (actions + history) and a
/// detail pane that updates in place when a transcript is selected.
class TabletHomeScreen extends ConsumerStatefulWidget {
  const TabletHomeScreen({super.key});

  @override
  ConsumerState<TabletHomeScreen> createState() => _TabletHomeScreenState();
}

class _TabletHomeScreenState extends ConsumerState<TabletHomeScreen> {
  String? _selectedId;
  String _query = '';

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    final file = result?.files.single;
    if (file?.path == null || !mounted) return;
    await AppNavigator.startProcessing(
      context,
      audioPath: file!.path!,
      source: NoteSource.file,
      fileName: file.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final notes = ref.watch(notesControllerProvider);
    if (_selectedId != null && !notes.any((n) => n.id == _selectedId)) {
      _selectedId = null;
    }

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 344,
              child: _Sidebar(
                query: _query,
                selectedId: _selectedId,
                onQuery: (v) => setState(() => _query = v),
                onSelect: (id) => setState(() => _selectedId = id),
                onPickFile: _pickFile,
              ),
            ),
            Expanded(
              child: _selectedId == null
                  ? const _EmptyPane()
                  : TabletDetailPane(key: ValueKey(_selectedId), noteId: _selectedId!),
            ),
          ],
        ),
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.query,
    required this.selectedId,
    required this.onQuery,
    required this.onSelect,
    required this.onPickFile,
  });

  final String query;
  final String? selectedId;
  final ValueChanged<String> onQuery;
  final ValueChanged<String> onSelect;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final notes = ref.watch(notesControllerProvider);
    final status = ref.watch(homeModelStatusProvider);

    final filtered = query.isEmpty
        ? notes
        : notes.where((n) => n.title.toLowerCase().contains(query.toLowerCase())).toList();
    final groups = _group(filtered, t);

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(right: BorderSide(color: palette.line)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.homeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: palette.ink),
                          ),
                          Text(
                            t.homeSub(notes.length),
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
                ),
                const SizedBox(height: 16),
                _SearchField(hint: t.search, onChanged: onQuery),
                const SizedBox(height: 14),
                PillButton(label: t.tabRecord, icon: Icons.mic_rounded, height: 50, onTap: () => AppNavigator.openRecord(context)),
                const SizedBox(height: 10),
                PillButton(
                  label: t.pickTitle,
                  icon: Icons.file_upload_outlined,
                  height: 48,
                  outlined: true,
                  onTap: onPickFile,
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => AppNavigator.openSettings(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                    decoration: BoxDecoration(
                      color: status.warning ? palette.coralSoft : palette.accentSoft,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        status.warning
                            ? Icon(Icons.warning_amber_rounded, size: 13, color: palette.coral)
                            : Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: status.fullyLocal ? palette.mint : palette.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            status.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: status.warning ? palette.coralInk : palette.accentDeep,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Expanded(
            child: FadeEdges(
              builder: (context, controller) => ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
                children: [
                  for (final group in groups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                      child: Text(
                        group.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: palette.faint,
                        ),
                      ),
                    ),
                    for (final note in group.notes)
                      Dismissible(
                        key: ValueKey(note.id),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => deleteNoteWithUndo(ref, note, t),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: palette.coral,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                        ),
                        child: _SidebarRow(
                          note: note,
                          strings: t,
                          selected: note.id == selectedId,
                          onTap: () => onSelect(note.id),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_Group> _group(List<TranscriptNote> notes, AppStrings t) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final today = _Group(t.secToday);
    final week = _Group(t.secWeek);
    final earlier = _Group(t.secEarlier);
    for (final n in notes) {
      if (!n.createdAt.isBefore(startOfToday)) {
        today.notes.add(n);
      } else if (now.difference(n.createdAt).inDays < 7) {
        week.notes.add(n);
      } else {
        earlier.notes.add(n);
      }
    }
    return [today, week, earlier].where((g) => g.notes.isNotEmpty).toList();
  }
}

class _SidebarRow extends StatelessWidget {
  const _SidebarRow({required this.note, required this.strings, required this.selected, required this.onTap});
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
              decoration: BoxDecoration(color: palette.accentSoft, borderRadius: BorderRadius.circular(13)),
              child: const Center(child: MiniWave()),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: palette.ink),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: note.isRemote ? palette.accent : palette.mint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          note.modelShort,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.muted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: palette.coralSoft, borderRadius: BorderRadius.circular(9999)),
              child: Text(
                strings.todoLabel(note.todos.length),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: palette.coralInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged});
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: palette.bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: palette.faint),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              style: TextStyle(fontSize: 14, color: palette.ink),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(fontSize: 14, color: palette.faint),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPane extends ConsumerWidget {
  const _EmptyPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(color: palette.accentSoft, borderRadius: BorderRadius.circular(32)),
              child: Icon(Icons.graphic_eq_rounded, size: 42, color: palette.accent),
            ),
            const SizedBox(height: 22),
            Text(
              t.tabEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: palette.ink),
            ),
            const SizedBox(height: 8),
            Text(
              t.tabEmptySub,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.5, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group {
  _Group(this.label) : notes = [];
  final String label;
  final List<TranscriptNote> notes;
}
