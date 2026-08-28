import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/transcript_note.dart';
import '../../../state/notes_controller.dart';
import '../../../state/settings_controller.dart';
import '../../widgets/surfaces.dart';
import 'widgets/audio_deleted_notice.dart';
import 'widgets/detail_audio_player.dart';
import 'widgets/detail_header.dart';
import 'widgets/detail_transcript_block.dart';
import 'widgets/note_content_widgets.dart';
import 'widgets/note_detail_interactions.dart';
import 'widgets/note_summary_metadata_widgets.dart';
import 'widgets/processed_with_card.dart';

/// In-app screen showing a fully processed note: audio, summary, key points,
/// to-dos, the models used, and the expandable transcript.
class TranscriptDetailScreen extends ConsumerStatefulWidget {
  const TranscriptDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<TranscriptDetailScreen> createState() =>
      _TranscriptDetailScreenState();
}

class _TranscriptDetailScreenState extends ConsumerState<TranscriptDetailScreen>
    with NoteDetailInteractionState<TranscriptDetailScreen> {
  Future<void> _delete(TranscriptNote note) async {
    final deleted = await confirmAndDeleteNote(note, ref.read(stringsProvider));
    if (deleted && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    final note = watchNote(widget.noteId);

    return note == null ? _missingNote(t) : _detailScreen(note, t);
  }

  Widget _missingNote(AppStrings strings) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(backgroundColor: palette.bg, elevation: 0),
      body: Center(
        child: Text(strings.errorTitle, style: TextStyle(color: palette.muted)),
      ),
    );
  }

  Widget _detailScreen(TranscriptNote note, AppStrings strings) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DetailHeader(
              note: note,
              strings: strings,
              actions: DetailHeaderActions(
                onBack: () => Navigator.of(context).pop(),
                onShare: () => shareNote(note),
                onDelete: () => _delete(note),
              ),
            ),
            Expanded(
              child: FadeEdges(
                topHeight: 16,
                builder: (context, controller) => ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
                  children: _noteSections(note, strings),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _noteSections(TranscriptNote note, AppStrings strings) {
    return [
      ..._leadingSections(note, strings),
      if (note.points.isNotEmpty) ...[
        NoteSectionLabel(strings.shPoints),
        const SizedBox(height: 12),
        NoteKeyPoints(points: note.points),
        const SizedBox(height: 22),
      ],
      if (note.todos.isNotEmpty) ...[
        EditableNoteTodos.phone(
          todos: note.todos,
          strings: strings,
          onToggle: (index) => ref
              .read(notesControllerProvider.notifier)
              .toggleTodo(note.id, index),
        ),
        const SizedBox(height: 12),
      ],
      if (note.gist.isNotEmpty)
        DetailTranscriptToggle.phone(
          strings: strings,
          isOpen: transcriptOpen,
          onTap: toggleTranscript,
        ),
      if (note.gist.isEmpty || transcriptOpen) ...[
        const SizedBox(height: 18),
        DetailTranscriptBlock(
          note: note,
          strings: strings,
          copied: copied,
          actions: DetailTranscriptActions(
            onCopy: () => copyNote(note),
            onShare: () => shareNote(note),
          ),
        ),
      ],
    ];
  }

  List<Widget> _leadingSections(TranscriptNote note, AppStrings strings) {
    return [
      if (note.audioPath != null)
        DetailAudioPlayer(
          audioPath: note.audioPath!,
          durationSec: note.durationSec,
        )
      else
        AudioDeletedNotice(strings: strings),
      const SizedBox(height: 18),
      if (note.gist.isNotEmpty) ...[
        NoteSummaryCard(gist: note.gist, label: strings.shSummary),
        const SizedBox(height: 16),
      ],
      NoteMetadataChips(note: note, strings: strings),
      const SizedBox(height: 20),
      NoteSectionLabel(strings.processedWith),
      const SizedBox(height: 12),
      ProcessedWithCard(note: note, strings: strings),
      const SizedBox(height: 22),
    ];
  }
}
