import 'package:material_ui/material_ui.dart';

import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../data/models/transcript_note.dart';
import 'note_content_widgets.dart';
import 'note_summary_metadata_widgets.dart';

class DetailTranscriptActions {
  const DetailTranscriptActions({required this.onCopy, this.onShare});

  final VoidCallback onCopy;
  final VoidCallback? onShare;
}

class DetailTranscriptStyle {
  const DetailTranscriptStyle({
    this.rowBottomPadding = 15,
    this.rowFontSize = 14.5,
  });

  final double rowBottomPadding;
  final double rowFontSize;
}

class DetailTranscriptBlock extends StatelessWidget {
  const DetailTranscriptBlock({
    super.key,
    required this.note,
    required this.strings,
    required this.copied,
    required this.actions,
    this.style = const DetailTranscriptStyle(),
  });

  final TranscriptNote note;
  final AppStrings strings;
  final bool copied;
  final DetailTranscriptActions actions;
  final DetailTranscriptStyle style;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: _heading()),
        const SliverToBoxAdapter(child: SizedBox(height: 14)),
        TranscriptRows(
          lines: note.transcript,
          bottomPadding: style.rowBottomPadding,
          fontSize: style.rowFontSize,
        ),
      ],
    );
  }

  Widget _heading() {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      spacing: 8,
      children: [
        NoteSectionLabel(strings.shTranscript),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            NotePillChip.action(
              icon: copied ? Icons.check_rounded : Icons.copy_rounded,
              label: copied ? strings.shCopied : strings.shCopy,
              highlight: copied,
              onTap: actions.onCopy,
            ),
            if (actions.onShare case final onShare?)
              NotePillChip.action(
                icon: Icons.ios_share_rounded,
                label: strings.shShare,
                onTap: onShare,
              ),
          ],
        ),
      ],
    );
  }
}

class DetailTranscriptToggle extends StatelessWidget {
  const DetailTranscriptToggle.phone({
    super.key,
    required this.strings,
    required this.isOpen,
    required this.onTap,
  }) : height = 52,
       showChevron = true;

  const DetailTranscriptToggle.tablet({
    super.key,
    required this.strings,
    required this.isOpen,
    required this.onTap,
  }) : height = 50,
       showChevron = false;

  final AppStrings strings;
  final bool isOpen;
  final VoidCallback onTap;
  final double height;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      expanded: isOpen,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: double.infinity,
          minHeight: height,
        ),
        child: OutlinedButton.icon(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: palette.accentDeep,
            side: BorderSide(color: palette.line2, width: 1.5),
            shape: const StadiumBorder(),
          ),
          icon: const Icon(Icons.subject_rounded, size: 19),
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: Text(isOpen ? strings.shHide : strings.shShow)),
              if (showChevron) ...[
                const SizedBox(width: 9),
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 19,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class TranscriptRows extends StatefulWidget {
  const TranscriptRows({
    super.key,
    required this.lines,
    this.bottomPadding = 15,
    this.fontSize = 14.5,
  });

  final List<TranscriptLine> lines;
  final double bottomPadding;
  final double fontSize;

  @override
  State<TranscriptRows> createState() => _TranscriptRowsState();
}

class _TranscriptRowsState extends State<TranscriptRows> {
  late var _segments = _transcriptSegments(widget.lines);

  @override
  void didUpdateWidget(TranscriptRows oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.lines, oldWidget.lines)) {
      _segments = _transcriptSegments(widget.lines);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: widget.fontSize,
      height: 1.5,
      color: context.palette.body,
    );
    return SliverList.builder(
      itemCount: _segments.length,
      itemBuilder: (context, index) {
        final segment = _segments[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: segment.endsLine ? widget.bottomPadding : 0,
          ),
          child: Text(
            widget.lines[segment.line].text.substring(
              segment.start,
              segment.end,
            ),
            style: style,
          ),
        );
      },
    );
  }
}

const _segmentSize = 640;
const _wordBoundaryLookback = 160;

typedef _TranscriptSegment = ({int line, int start, int end, bool endsLine});

/// Providers can return a single large paragraph. Index its display ranges once
/// so the viewport lays out only nearby text and the original stays intact.
List<_TranscriptSegment> _transcriptSegments(List<TranscriptLine> lines) {
  final segments = <_TranscriptSegment>[];
  for (var line = 0; line < lines.length; line++) {
    final text = lines[line].text;
    final start = text.length > _segmentSize
        ? _indexLongLine(segments, text, line)
        : 0;
    segments.add((line: line, start: start, end: text.length, endsLine: true));
  }
  return segments;
}

int _indexLongLine(List<_TranscriptSegment> segments, String text, int line) {
  final characters = CharacterRange(text);
  var start = 0;
  var wordEnd = 0;
  while (characters.moveNext()) {
    final end = text.length - characters.stringAfterLength;
    final unit = text.codeUnitAt(end - 1);
    if (unit == 0x20 || unit == 0x09) wordEnd = end;
    if (end - start < _segmentSize || end == text.length) continue;

    final limit = start + _segmentSize;
    final split = wordEnd >= limit - _wordBoundaryLookback ? wordEnd : end;
    segments.add((line: line, start: start, end: split, endsLine: false));
    start = split;
  }
  return start;
}
