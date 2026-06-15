import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatting.dart';
import '../../../data/models/transcript_note.dart';
import '../../../state/notes_controller.dart';
import '../../../state/settings_controller.dart';
import '../../navigation.dart';
import '../../widgets/buttons.dart';
import '../../widgets/surfaces.dart';
import 'widgets/active_model_pill.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/note_list_item.dart';

/// App home: search, active model, manual file import, history, and the
/// floating record button.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _query = '';

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    await AppNavigator.startProcessing(
      context,
      audioPath: path,
      source: NoteSource.file,
      fileName: result!.files.single.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final notes = ref.watch(notesControllerProvider);
    final activeLabel = ref.watch(activeModelLabelProvider);
    final isLocal = ref.watch(settingsControllerProvider.select((s) => s.isFullyLocal));

    final filtered = _query.isEmpty
        ? notes
        : notes.where((n) => n.title.toLowerCase().contains(_query.toLowerCase())).toList();
    final groups = _groupNotes(filtered, t.secToday, t.secWeek, t.secEarlier);

    return Scaffold(
      backgroundColor: palette.bg,
      body: Stack(
        children: [
          FadeEdges(
            topHeight: 54,
            bottomHeight: 92,
            child: ListView(
              padding: const EdgeInsets.only(top: 56, bottom: 104),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.homeTitle,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              t.homeSub(notes.length),
                              style: TextStyle(fontSize: 13.5, color: palette.muted),
                            ),
                          ],
                        ),
                      ),
                      IconCircleButton(
                        icon: Icons.settings_outlined,
                        size: 44,
                        onTap: () => AppNavigator.openSettings(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: HomeSearchBar(
                    hint: t.search,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: ActiveModelPill(
                    label: activeLabel,
                    activeText: t.modelActive,
                    isLocal: isLocal,
                    onTap: () => AppNavigator.openSettings(context),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: _FilePickTile(title: t.pickTitle, subtitle: t.pickSub, onTap: _pickFile),
                ),
                if (filtered.isEmpty)
                  _EmptyState(title: t.emptyTitle, subtitle: t.emptySub)
                else
                  for (final group in groups) ...[
                    SectionLabel(group.label, padding: const EdgeInsets.fromLTRB(24, 24, 24, 10)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: SurfaceCard(
                        clip: true,
                        child: Column(
                          children: [
                            for (var i = 0; i < group.notes.length; i++)
                              NoteListItem(
                                note: group.notes[i],
                                strings: t,
                                isLast: i == group.notes.length - 1,
                                onTap: () => AppNavigator.openDetail(context, group.notes[i].id),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
              ],
            ),
          ),
          Positioned(
            bottom: 26,
            left: 0,
            right: 0,
            child: Center(child: _RecordFab(onTap: () => AppNavigator.openRecord(context))),
          ),
        ],
      ),
    );
  }
}

class _FilePickTile extends StatelessWidget {
  const _FilePickTile({required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.line2, width: 1.5, style: BorderStyle.solid),
          boxShadow: [BoxShadow(color: palette.shadow, blurRadius: 12, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.file_upload_outlined, color: palette.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: palette.ink)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12.5, color: palette.muted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: palette.faint),
          ],
        ),
      ),
    );
  }
}

class _RecordFab extends StatelessWidget {
  const _RecordFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          color: palette.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.48),
              blurRadius: 32,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: const Icon(Icons.mic_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(34, 64, 34, 0),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: palette.accentSoft, borderRadius: BorderRadius.circular(24)),
            child: Icon(Icons.graphic_eq_rounded, color: palette.accent, size: 32),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: palette.ink),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.5, color: palette.muted),
          ),
        ],
      ),
    );
  }
}

class _NoteGroup {
  _NoteGroup(this.label) : notes = [];
  final String label;
  final List<TranscriptNote> notes;
}

List<_NoteGroup> _groupNotes(List<TranscriptNote> notes, String today, String week, String earlier) {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  final groupToday = _NoteGroup(today);
  final groupWeek = _NoteGroup(week);
  final groupEarlier = _NoteGroup(earlier);
  for (final note in notes) {
    if (!note.createdAt.isBefore(startOfToday)) {
      groupToday.notes.add(note);
    } else if (now.difference(note.createdAt).inDays < 7) {
      groupWeek.notes.add(note);
    } else {
      groupEarlier.notes.add(note);
    }
  }
  return [groupToday, groupWeek, groupEarlier].where((g) => g.notes.isNotEmpty).toList();
}

// Re-exported for [NoteListItem] subtitle formatting.
String noteSubtitle(TranscriptNote note, {required bool german}) {
  final src = switch (note.source) {
    NoteSource.recording => german ? 'Aufnahme' : 'Recording',
    NoteSource.file => german ? 'Datei' : 'File',
    NoteSource.shared => german ? 'Sprachnachricht' : 'Voice note',
  };
  return '$src · ${formatDuration(note.durationSec)} · ${timeAgo(note.createdAt, german: german)}';
}
