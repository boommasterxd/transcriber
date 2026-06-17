import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatting.dart';
import '../../../data/models/transcript_note.dart';
import '../../../state/notes_controller.dart';
import '../../../state/settings_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/note_actions.dart';
import '../../widgets/surfaces.dart';
import '../../widgets/todo_tile.dart';
import 'widgets/audio_deleted_notice.dart';
import 'widgets/detail_audio_player.dart';
import 'widgets/processed_with_card.dart';

/// In-app screen showing a fully processed note: audio, summary, key points,
/// to-dos, the models used, and the expandable transcript.
class TranscriptDetailScreen extends ConsumerStatefulWidget {
  const TranscriptDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<TranscriptDetailScreen> createState() => _TranscriptDetailScreenState();
}

class _TranscriptDetailScreenState extends ConsumerState<TranscriptDetailScreen> {
  bool _transcriptOpen = false;
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  void _copy(TranscriptNote note) {
    Clipboard.setData(ClipboardData(text: note.fullTranscriptText));
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _share(TranscriptNote note) {
    final body = '${note.title}\n\n${note.gist}\n\n${note.fullTranscriptText}';
    SharePlus.instance.share(ShareParams(text: body, subject: note.title));
  }

  Future<void> _delete(TranscriptNote note) async {
    final t = ref.read(stringsProvider);
    if (await confirmDeleteNote(context, t)) {
      await deleteNoteWithUndo(ref, note, t);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final notes = ref.watch(notesControllerProvider);
    final matches = notes.where((n) => n.id == widget.noteId);
    final note = matches.isEmpty ? null : matches.first;

    if (note == null) {
      return Scaffold(
        backgroundColor: palette.bg,
        appBar: AppBar(backgroundColor: palette.bg, elevation: 0),
        body: Center(child: Text(t.errorTitle, style: TextStyle(color: palette.muted))),
      );
    }

    return Scaffold(
      backgroundColor: palette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              note: note,
              german: t.isDe,
              onBack: () => Navigator.of(context).pop(),
              onShare: () => _share(note),
              onDelete: () => _delete(note),
            ),
            Expanded(
              child: FadeEdges(
                topHeight: 16,
                builder: (context, controller) => ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                  children: [
                    if (note.audioPath != null)
                      DetailAudioPlayer(audioPath: note.audioPath!, durationSec: note.durationSec)
                    else
                      AudioDeletedNotice(strings: t),
                    const SizedBox(height: 18),
                    if (note.gist.isNotEmpty) ...[
                      _SummaryCard(gist: note.gist, label: t.shSummary),
                      const SizedBox(height: 16),
                    ],
                    _MetaChips(note: note, strings: t),
                    const SizedBox(height: 20),
                    _Label(t.processedWith),
                    const SizedBox(height: 12),
                    ProcessedWithCard(note: note, strings: t),
                    const SizedBox(height: 22),
                    if (note.points.isNotEmpty) ...[
                      _Label(t.shPoints),
                      const SizedBox(height: 12),
                      _KeyPoints(points: note.points),
                      const SizedBox(height: 22),
                    ],
                    if (note.todos.isNotEmpty) ...[
                      _TodosHeader(count: note.todos.length, label: t.shActions),
                      const SizedBox(height: 12),
                      for (var i = 0; i < note.todos.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TodoTile(
                            text: note.todos[i].text,
                            done: note.todos[i].done,
                            onToggle: () =>
                                ref.read(notesControllerProvider.notifier).toggleTodo(note.id, i),
                          ),
                        ),
                      const SizedBox(height: 12),
                    ],
                    // For transcript-only notes (summary off) show the
                    // transcript directly instead of hiding it behind a toggle.
                    if (note.gist.isNotEmpty)
                      PillButton(
                        label: _transcriptOpen ? t.shHide : t.shShow,
                        icon: Icons.subject_rounded,
                        trailingIcon: _transcriptOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        height: 52,
                        outlined: true,
                        onTap: () => setState(() => _transcriptOpen = !_transcriptOpen),
                      ),
                    if (note.gist.isEmpty || _transcriptOpen) ...[
                      const SizedBox(height: 18),
                      _TranscriptBlock(
                        note: note,
                        strings: t,
                        copied: _copied,
                        onCopy: () => _copy(note),
                        onShare: () => _share(note),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.note,
    required this.german,
    required this.onBack,
    required this.onShare,
    required this.onDelete,
  });
  final TranscriptNote note;
  final bool german;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          IconCircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: palette.ink),
                ),
                Text(
                  '${note.speaker} · ${timeAgo(note.createdAt, german: german)}',
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconCircleButton(icon: Icons.delete_outline_rounded, onTap: onDelete),
          const SizedBox(width: 8),
          IconCircleButton(icon: Icons.ios_share_rounded, onTap: onShare),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.gist, required this.label});
  final String gist;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.accentSoft2, palette.accentSoft],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 17, color: palette.accent),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: palette.accentDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            gist,
            style: TextStyle(fontSize: 15.5, height: 1.5, fontWeight: FontWeight.w500, color: palette.body),
          ),
        ],
      ),
    );
  }
}

class _MetaChips extends StatelessWidget {
  const _MetaChips({required this.note, required this.strings});
  final TranscriptNote note;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(icon: Icons.schedule_rounded, label: formatDuration(note.durationSec)),
        _Chip(icon: Icons.person_outline_rounded, label: strings.mSpkTemplate.replaceAll('{n}', '1')),
        _Chip(icon: Icons.language_rounded, label: strings.autoLang),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: palette.chip, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.muted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.body)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: context.palette.ink,
      ),
    );
  }
}

class _KeyPoints extends StatelessWidget {
  const _KeyPoints({required this.points});
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final point in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(top: 7),
                  decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(point, style: TextStyle(fontSize: 14.5, height: 1.45, color: palette.body)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TodosHeader extends StatelessWidget {
  const _TodosHeader({required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        _Label(label),
        const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(minWidth: 20),
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(color: palette.coral, borderRadius: BorderRadius.circular(9999)),
          child: Center(
            child: Text(
              '$count',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _TranscriptBlock extends StatelessWidget {
  const _TranscriptBlock({
    required this.note,
    required this.strings,
    required this.copied,
    required this.onCopy,
    required this.onShare,
  });

  final TranscriptNote note;
  final AppStrings strings;
  final bool copied;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Label(strings.shTranscript),
            Row(
              children: [
                _ActionChip(
                  icon: copied ? Icons.check_rounded : Icons.copy_rounded,
                  label: copied ? strings.shCopied : strings.shCopy,
                  highlight: copied,
                  onTap: onCopy,
                ),
                const SizedBox(width: 8),
                _ActionChip(icon: Icons.ios_share_rounded, label: strings.shShare, onTap: onShare),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final line in note.transcript)
          Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text(line.time, style: AppTheme.mono(color: palette.accent, size: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(line.text, style: TextStyle(fontSize: 14.5, height: 1.5, color: palette.body)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.icon, required this.label, required this.onTap, this.highlight = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = highlight ? palette.mint : palette.body;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(color: palette.chip, borderRadius: BorderRadius.circular(9999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
