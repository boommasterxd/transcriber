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
import '../../widgets/waveforms.dart';
import '../detail/widgets/audio_deleted_notice.dart';
import '../detail/widgets/detail_audio_player.dart';
import '../detail/widgets/processed_with_card.dart';

/// The right-hand detail pane of the tablet split view: a two-column layout for
/// the selected note (no navigation). Mirrors the phone detail content.
class TabletDetailPane extends ConsumerStatefulWidget {
  const TabletDetailPane({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<TabletDetailPane> createState() => _TabletDetailPaneState();
}

class _TabletDetailPaneState extends ConsumerState<TabletDetailPane> {
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
    SharePlus.instance.share(
      ShareParams(text: '${note.title}\n\n${note.gist}\n\n${note.fullTranscriptText}', subject: note.title),
    );
  }

  Future<void> _delete(TranscriptNote note) async {
    final t = ref.read(stringsProvider);
    if (await confirmDeleteNote(context, t)) {
      // The tablet home clears the selection automatically once the note is gone.
      await deleteNoteWithUndo(ref, note, t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final t = ref.watch(stringsProvider);
    final notes = ref.watch(notesControllerProvider);
    final matches = notes.where((n) => n.id == widget.noteId);
    if (matches.isEmpty) return const SizedBox.shrink();
    final note = matches.first;

    return Column(
      children: [
        _Header(note: note, german: t.isDe, onShare: () => _share(note), onDelete: () => _delete(note)),
        Expanded(
          child: FadeEdges(
            topHeight: 16,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 30),
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    final twoCol = c.maxWidth >= 640;
                    final left = _LeftColumn(note: note, strings: t);
                    final right = _RightColumn(
                      note: note,
                      strings: t,
                      onToggleTodo: (i) =>
                          ref.read(notesControllerProvider.notifier).toggleTodo(note.id, i),
                    );
                    if (!twoCol) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [left, const SizedBox(height: 16), right],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 18),
                        Expanded(child: right),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                PillButton(
                  label: _transcriptOpen ? t.shHide : t.shShow,
                  icon: Icons.subject_rounded,
                  height: 50,
                  outlined: true,
                  onTap: () => setState(() => _transcriptOpen = !_transcriptOpen),
                ),
                if (_transcriptOpen) ...[
                  const SizedBox(height: 18),
                  _TranscriptBlock(
                    note: note,
                    strings: t,
                    copied: _copied,
                    onCopy: () => _copy(note),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.note,
    required this.german,
    required this.onShare,
    required this.onDelete,
  });
  final TranscriptNote note;
  final bool german;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: palette.line))),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: palette.accentSoft, borderRadius: BorderRadius.circular(15)),
            child: const Center(child: MiniWave()),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: palette.ink),
                ),
                Text(
                  '${note.speaker} · ${timeAgo(note.createdAt, german: german)}',
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconCircleButton(icon: Icons.delete_outline_rounded, size: 44, onTap: onDelete),
          const SizedBox(width: 8),
          IconCircleButton(icon: Icons.ios_share_rounded, size: 44, onTap: onShare),
        ],
      ),
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.note, required this.strings});
  final TranscriptNote note;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.audioPath != null)
          DetailAudioPlayer(audioPath: note.audioPath!, durationSec: note.durationSec)
        else
          AudioDeletedNotice(strings: strings),
        if (note.gist.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
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
                    strings.shSummary.toUpperCase(),
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
                note.gist,
                style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w500, color: palette.body),
              ),
            ],
          ),
          ),
        ],
        const SizedBox(height: 16),
        _Label(strings.processedWith),
        const SizedBox(height: 12),
        ProcessedWithCard(note: note, strings: strings),
      ],
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({required this.note, required this.strings, required this.onToggleTodo});
  final TranscriptNote note;
  final AppStrings strings;
  final ValueChanged<int> onToggleTodo;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.points.isNotEmpty) ...[
          _Label(strings.shPoints),
          const SizedBox(height: 12),
          for (final point in note.points)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
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
                    child: Text(point, style: TextStyle(fontSize: 14, height: 1.45, color: palette.body)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
        if (note.todos.isNotEmpty) ...[
          Row(
            children: [
              _Label(strings.shActions),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(color: palette.coral, borderRadius: BorderRadius.circular(9999)),
                child: Center(
                  child: Text(
                    '${note.todos.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < note.todos.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: TodoTile(
                text: note.todos[i].text,
                done: note.todos[i].done,
                onToggle: () => onToggleTodo(i),
              ),
            ),
        ],
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
  });
  final TranscriptNote note;
  final AppStrings strings;
  final bool copied;
  final VoidCallback onCopy;

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
            GestureDetector(
              onTap: onCopy,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(color: palette.chip, borderRadius: BorderRadius.circular(9999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(copied ? Icons.check_rounded : Icons.copy_rounded,
                        size: 13, color: copied ? palette.mint : palette.body),
                    const SizedBox(width: 6),
                    Text(
                      copied ? strings.shCopied : strings.shCopy,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: copied ? palette.mint : palette.body,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final line in note.transcript)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text(line.time, style: AppTheme.mono(color: palette.accent, size: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(line.text, style: TextStyle(fontSize: 14, height: 1.5, color: palette.body)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: context.palette.ink,
        ),
      );
}
