import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/transcript_note.dart';
import '../../../../state/settings_controller.dart';
import '../../../widgets/buttons.dart';
import '../../../widgets/surfaces.dart';
import '../../../widgets/waveforms.dart';
import '../../detail/widgets/detail_audio_player.dart';
import '../../detail/widgets/detail_transcript_block.dart';
import '../../detail/widgets/note_content_widgets.dart';
import '../../detail/widgets/note_summary_metadata_widgets.dart';
import '../../detail/widgets/summary_failure_notice.dart';

class ShareResultBody extends ConsumerStatefulWidget {
  const ShareResultBody({
    super.key,
    required this.note,
    required this.saving,
    required this.onClose,
    required this.onSave,
  });

  final TranscriptNote note;
  final bool saving;
  final VoidCallback onClose;
  final VoidCallback onSave;

  @override
  ConsumerState<ShareResultBody> createState() => _ShareResultBodyState();
}

class _ShareResultBodyState extends ConsumerState<ShareResultBody> {
  bool _transcriptOpen = false;

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    final note = widget.note;
    final hasSummary = note.summaryError == null && note.gist.isNotEmpty;

    return Column(
      children: [
        _ResultHeader(
          title: note.title,
          label: strings.shFrom,
          onClose: widget.onClose,
        ),
        Expanded(
          child: FadeEdges(
            topHeight: 10,
            builder: (context, controller) => ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              children: _resultSections(note, strings, hasSummary),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: PillButton(
            label: strings.shSave,
            icon: Icons.check_rounded,
            onTap: widget.saving ? () {} : widget.onSave,
          ),
        ),
      ],
    );
  }

  List<Widget> _resultSections(
    TranscriptNote note,
    AppStrings strings,
    bool hasSummary,
  ) {
    return [
      if (note.summaryError != null) ...[
        SummaryFailureNotice(error: note.summaryError!, strings: strings),
        const SizedBox(height: 16),
      ],
      if (note.audioPath != null)
        DetailAudioPlayer(
          audioPath: note.audioPath!,
          durationSec: note.durationSec,
        ),
      const SizedBox(height: 16),
      if (hasSummary) ...[
        NoteSummaryCard(gist: note.gist, label: strings.shSummary),
        const SizedBox(height: 16),
      ],
      NoteMetadataChips(note: note, strings: strings),
      if (note.summaryError == null && note.points.isNotEmpty) ...[
        const SizedBox(height: 22),
        NoteSectionLabel(strings.shPoints),
        const SizedBox(height: 12),
        NoteKeyPoints(points: note.points),
      ],
      if (note.summaryError == null && note.todos.isNotEmpty) ...[
        const SizedBox(height: 22),
        _TodosPreview(todos: note.todos, label: strings.shActions),
      ],
      const SizedBox(height: 22),
      if (hasSummary || note.summaryError != null) _transcriptToggle(strings),
      if ((!hasSummary && note.summaryError == null) || _transcriptOpen) ...[
        const SizedBox(height: 14),
        _TranscriptPreview(note: note, label: strings.shTranscript),
      ],
    ];
  }

  Widget _transcriptToggle(AppStrings strings) {
    return DetailTranscriptToggle.phone(
      strings: strings,
      isOpen: _transcriptOpen,
      onTap: () => setState(() => _transcriptOpen = !_transcriptOpen),
    );
  }
}

/// Read-only to-do list shown in the share preview (editable after saving).
class _TodosPreview extends StatelessWidget {
  const _TodosPreview({required this.todos, required this.label});

  final List<TodoItem> todos;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteTodoHeader(count: todos.length, label: label),
        const SizedBox(height: 12),
        for (final todo in todos)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 18,
                  color: palette.coral,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    todo.text,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: palette.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TranscriptPreview extends StatelessWidget {
  const _TranscriptPreview({required this.note, required this.label});

  final TranscriptNote note;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NoteSectionLabel(label),
        const SizedBox(height: 12),
        TranscriptRows(lines: note.transcript, bottomPadding: 14),
      ],
    );
  }
}

class _ResultHeader extends StatelessWidget {
  const _ResultHeader({
    required this.title,
    required this.label,
    required this.onClose,
  });

  final String title;
  final String label;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(child: MiniWave()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12.5, color: palette.muted),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconCircleButton(icon: Icons.close_rounded, size: 38, onTap: onClose),
        ],
      ),
    );
  }
}
