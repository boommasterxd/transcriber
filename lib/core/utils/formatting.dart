import '../l10n/app_strings.dart';

/// Formats [seconds] as `m:ss` (e.g. 65 -> "1:05").
String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Formats a byte count as a compact human readable size (MB / GB).
/// [german] controls whether a comma is used as the decimal separator.
String formatBytes(int bytes, {bool german = true}) {
  const mb = 1024 * 1024;
  const gb = mb * 1024;
  String fmt(double v) {
    final s = v.toStringAsFixed(v >= 10 || v == v.roundToDouble() ? 0 : 1);
    return german ? s.replaceAll('.', ',') : s;
  }

  if (bytes >= gb) return '${fmt(bytes / gb)} GB';
  return '${fmt(bytes / mb)} MB';
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
