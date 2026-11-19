import 'package:material_ui/material_ui.dart';
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
            builder: (context, controller) => CustomScrollView(
              controller: controller,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  sliver: SliverMainAxisGroup(
                    slivers: _resultSections(note, strings, hasSummary),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: PillButton.status(
            label: widget.saving ? strings.shareSaving : strings.shSave,
            icon: Icons.check_rounded,
            onTap: widget.saving ? null : widget.onSave,
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
      SliverList.list(children: _leadingSections(note, strings, hasSummary)),
      if (note.summaryError == null && note.points.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 22)),
        NoteKeyPoints(points: note.points, label: strings.shPoints),
      ],
      if (note.summaryError == null && note.todos.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: 22)),
        NoteTodos.preview(todos: note.todos, strings: strings),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: 22)),
      if (hasSummary || note.summaryError != null)
        SliverToBoxAdapter(child: _transcriptToggle(strings)),
      if ((!hasSummary && note.summaryError == null) || _transcriptOpen) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 12),
            child: NoteSectionLabel(strings.shTranscript),
          ),
        ),
        TranscriptRows(lines: note.transcript, bottomPadding: 14),
      ],
    ];
  }

  List<Widget> _leadingSections(
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
        NoteSummaryCard(note: note, strings: strings),
        const SizedBox(height: 16),
      ],
      NoteMetadataChips(note: note, strings: strings),
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
