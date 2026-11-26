import '../l10n/app_strings.dart';

/// Formats [seconds] as `m:ss` (e.g. 65 -> "1:05").
String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Relative "time ago" label, resolved via [AppStrings] for full l10n.
String timeAgo(DateTime when, {required AppStrings t, DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(when);
  if (diff.inMinutes < 1) return t.justNow;
  if (diff.inMinutes < 60) return t.minutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return t.hoursAgo(diff.inHours);
  if (diff.inDays < 7) return t.weekdayShort(when.weekday);
  return t.dateMonthDay(when.day, when.month);
}
