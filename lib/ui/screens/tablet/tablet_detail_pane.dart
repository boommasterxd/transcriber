import 'package:material_ui/material_ui.dart';
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
  static const _contentPadding = EdgeInsets.fromLTRB(28, 22, 28, 30);

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
          onDelete: () => confirmAndDeleteNote(note, t),
        ),
        Expanded(child: _noteScroll(note, t)),
      ],
    );
  }

  Widget _noteScroll(TranscriptNote note, AppStrings strings) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth - _contentPadding.horizontal >= 640;
        return FadeEdges(
          topHeight: 16,
          builder: (context, controller) => CustomScrollView(
            controller: controller,
            slivers: [
              SliverPadding(
                padding: _contentPadding,
                sliver: SliverMainAxisGroup(
                  slivers: _noteSections(note, strings, wide: wide),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _noteSections(
    TranscriptNote note,
    AppStrings strings, {
    required bool wide,
  }) {
    return [
      if (note.summaryError case final error?) ...[
        SliverToBoxAdapter(
          child: SummaryFailureNotice(error: error, strings: strings),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
      _responsiveColumns(note, strings, wide: wide),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
      SliverToBoxAdapter(
        child: DetailTranscriptToggle.tablet(
          strings: strings,
          isOpen: transcriptOpen,
          onTap: toggleTranscript,
        ),
      ),
      if (transcriptOpen) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 18)),
        DetailTranscriptBlock(
          note: note,
          strings: strings,
          copied: copied,
          actions: DetailTranscriptActions(onCopy: () => copyNote(note)),
          style: const DetailTranscriptStyle(
            rowBottomPadding: 14,
            rowFontSize: 14,
          ),
        ),
      ],
    ];
  }

  Widget _responsiveColumns(
    TranscriptNote note,
    AppStrings strings, {
    required bool wide,
  }) {
    final left = SliverToBoxAdapter(
      child: _LeftColumn(note: note, strings: strings),
    );
    final right = SliverMainAxisGroup(
      slivers: [
        if (note.summaryError == null && note.points.isNotEmpty) ...[
          NoteKeyPoints(
            points: note.points,
            label: strings.shPoints,
            bottomPadding: 13,
            fontSize: 14,
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],
        if (note.summaryError == null && note.todos.isNotEmpty)
          NoteTodos.tablet(
            todos: note.todos,
            strings: strings,
            onToggle: (index) => ref
                .read(notesControllerProvider.notifier)
                .toggleTodo(note.id, index),
          ),
      ],
    );
    if (wide) {
      return SliverCrossAxisGroup(
        slivers: [
          left,
          const SliverConstrainedCrossAxis(
            maxExtent: 18,
            sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
          ),
          right,
        ],
      );
    }
    return SliverMainAxisGroup(
      slivers: [
        left,
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        right,
      ],
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
          NoteSummaryCard(note: note, strings: strings, textSize: 15),
        ],
        const SizedBox(height: 16),
        NoteSectionLabel(strings.processedWith),
        const SizedBox(height: 12),
        ProcessedWithCard(note: note, strings: strings),
      ],
    );
  }
}
