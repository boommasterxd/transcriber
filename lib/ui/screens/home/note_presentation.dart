import '../../../core/l10n/app_strings.dart';
import '../../../core/utils/formatting.dart';
import '../../../data/models/transcript_note.dart';
import '../../../data/models/note_history.dart';
import 'history_logic.dart';

String historyPeriodLabel(HistoryPeriod period, AppStrings strings) =>
    switch (period) {
      HistoryPeriod.today => strings.secToday,
      HistoryPeriod.recent => strings.secWeek,
      HistoryPeriod.earlier => strings.secEarlier,
    };

String noteSubtitle(NoteHistoryEntry note, {required AppStrings strings}) {
  final source = switch (note.source) {
    NoteSource.recording => strings.recordingLabel,
    NoteSource.file => strings.tabFile,
    NoteSource.shared => strings.voiceNote,
  };
  final duration = formatDuration(note.durationSec);
  final age = timeAgo(note.createdAt, t: strings);
  return '$source · $duration · $age';
}
