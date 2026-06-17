/// Formats [seconds] as `m:ss` (e.g. 65 -> "1:05").
String formatDuration(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Formats a byte count as a compact human readable size (MB / GB).
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

/// Relative "time ago" label, localized for DE/EN.
String timeAgo(DateTime when, {required bool german, DateTime? now}) {
  final ref = now ?? DateTime.now();
  final diff = ref.difference(when);
  if (diff.inMinutes < 1) return german ? 'gerade eben' : 'just now';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return german ? 'vor $m Min' : '$m min ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return german ? 'vor $h Std' : '${h}h ago';
  }
  if (diff.inDays < 7) {
    const de = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final idx = when.weekday - 1;
    return german ? de[idx] : en[idx];
  }
  final d = when.day.toString().padLeft(2, '0');
  final m = when.month.toString().padLeft(2, '0');
  return german ? '$d.$m.' : '$m/$d';
}
