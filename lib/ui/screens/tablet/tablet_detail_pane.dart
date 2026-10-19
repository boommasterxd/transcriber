import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/formatting.dart';
import '../../../data/models/transcript_note.dart';
import '../../../state/notes_controller.dart';
import '../../../state/note_detail_provider.dart';
import '../../../state/settings_controller.dart';
import '../../widgets/buttons.dart';
import '../../widgets/surfaces.dart';
import '../../widgets/waveforms.dart';
import '../detail/widgets/audio_deleted_notice.dart';
import '../detail/widgets/detail_audio_player.dart';
import '../detail/widgets/detail_transcript_block.dart';
import '../detail/widgets/note_content_widgets.dart';
import '../detail/widgets/note_detail_interactions.dart';
import '../detail/widgets/note_summary_metadata_widgets.dart';
import '../detail/widgets/processed_with_card.dart';
import '../detail/widgets/summary_failure_notice.dart';
import '../detail/widgets/note_detail_status.dart';

/// The right-hand detail pane of the tablet split view: a two-column layout for
/// the selected note (no navigation). Mirrors the phone detail content.
class TabletDetailPane extends ConsumerStatefulWidget {
  const TabletDetailPane({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<TabletDetailPane> createState() => _TabletDetailPaneState();
}

class _TabletDetailPaneState extends ConsumerState<TabletDetailPane>
    with NoteDetailInteractionState<TabletDetailPane> {
  Future<void> _delete(TranscriptNote note) async {
    await confirmAndDeleteNote(note, ref.read(stringsProvider));
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final detail = ref.watch(noteDetailProvider(widget.noteId));
    if (detail.isLoading || detail.hasError) {
      return NoteDetailStatus(
        loading: detail.isLoading,
        strings: t,
        retry: () => ref.invalidate(noteDetailProvider(widget.noteId)),
      );
    }
    final note = watchNote(widget.noteId);
    if (note == null) return const SizedBox.shrink();

    return Column(
      children: [
        _Header(
          note: note,
          t: t,
          onShare: () => shareNote(note),
          onDelete: () => _delete(note),
        ),
        Expanded(
          child: FadeEdges(
            topHeight: 16,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 30),
              children: [
                if (note.summaryError != null) ...[
                  SummaryFailureNotice(error: note.summaryError!, strings: t),
                  const SizedBox(height: 20),
                ],
                _responsiveColumns(note, t),
                const SizedBox(height: 20),
                DetailTranscriptToggle.tablet(
                  strings: t,
                  isOpen: transcriptOpen,
                  onTap: toggleTranscript,
                ),
                if (transcriptOpen) ...[
                  const SizedBox(height: 18),
                  DetailTranscriptBlock(
                    note: note,
                    strings: t,
                    copied: copied,
                    actions: DetailTranscriptActions(
                      onCopy: () => copyNote(note),
                    ),
                    style: const DetailTranscriptStyle(
                      rowBottomPadding: 14,
                      rowFontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _responsiveColumns(TranscriptNote note, AppStrings strings) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final left = _LeftColumn(note: note, strings: strings);
        final right = _RightColumn(
          note: note,
          strings: strings,
          onToggleTodo: (index) => ref
              .read(notesControllerProvider.notifier)
              .toggleTodo(note.id, index),
        );
        if (constraints.maxWidth < 640) {
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
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.note,
    required this.t,
    required this.onShare,
    required this.onDelete,
  });
  final TranscriptNote note;
  final AppStrings t;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 26, 28, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _HeaderIdentity(note: note, strings: t),
          ),
          const SizedBox(width: 8),
          IconCircleButton(
            icon: Icons.delete_outline_rounded,
            size: 44,
            onTap: onDelete,
          ),
          const SizedBox(width: 8),
          IconCircleButton(
            icon: Icons.ios_share_rounded,
            size: 44,
            onTap: onShare,
          ),
        ],
      ),
    );
  }
}

class _HeaderIdentity extends StatelessWidget {
  const _HeaderIdentity({required this.note, required this.strings});

  final TranscriptNote note;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: palette.accentSoft,
            borderRadius: BorderRadius.circular(15),
          ),
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
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                ),
              ),
              Text(
                '${note.speaker} · ${timeAgo(note.createdAt, t: strings)}',
                style: TextStyle(fontSize: 13, color: palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LeftColumn extends StatelessWidget {
  const _LeftColumn({required this.note, required this.strings});
  final TranscriptNote note;
  final AppStrings strings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.audioPath != null)
          DetailAudioPlayer(
            audioPath: note.audioPath!,
            durationSec: note.durationSec,
          )
        else
          AudioDeletedNotice(strings: strings),
        if (note.summaryError == null && note.gist.isNotEmpty) ...[
          const SizedBox(height: 16),
          NoteSummaryCard(
            gist: note.gist,
            label: strings.shSummary,
            textSize: 15,
          ),
        ],
        const SizedBox(height: 16),
        NoteSectionLabel(strings.processedWith),
        const SizedBox(height: 12),
        ProcessedWithCard(note: note, strings: strings),
      ],
    );
  }
}

class _RightColumn extends StatelessWidget {
  const _RightColumn({
    required this.note,
    required this.strings,
    required this.onToggleTodo,
  });
  final TranscriptNote note;
  final AppStrings strings;
  final ValueChanged<int> onToggleTodo;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (note.summaryError == null && note.points.isNotEmpty) ...[
          NoteSectionLabel(strings.shPoints),
          const SizedBox(height: 12),
          NoteKeyPoints(points: note.points, bottomPadding: 13, fontSize: 14),
          const SizedBox(height: 8),
        ],
        if (note.summaryError == null && note.todos.isNotEmpty) ...[
          EditableNoteTodos.tablet(
            todos: note.todos,
            strings: strings,
            onToggle: onToggleTodo,
          ),
        ],
      ],
    );
  }
}
