import 'package:test/test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/utils/formatting.dart';

void main() {
  group('formatDuration', () {
    test('pads seconds and rolls over at each minute', () {
      expect(formatDuration(0), '0:00');
      expect(formatDuration(1), '0:01');
      expect(formatDuration(59), '0:59');
      expect(formatDuration(60), '1:00');
      expect(formatDuration(61), '1:01');
    });

    test('keeps elapsed minutes unbounded for long durations', () {
      expect(formatDuration(60 * 60), '60:00');
      expect(formatDuration(24 * 60 * 60 + 7), '1440:07');
    });
  });

  group('formatBytes', () {
    test('formats zero, fractional, and integral megabytes', () {
      const mb = 1024 * 1024;

      expect(formatBytes(0, german: false), '0 MB');
      expect(formatBytes(mb ~/ 2, german: false), '0.5 MB');
      expect(formatBytes(9 * mb + mb ~/ 2, german: false), '9.5 MB');
      expect(formatBytes(10 * mb, german: false), '10 MB');
    });

    test('uses a decimal comma only for fractional German values', () {
      const mb = 1024 * 1024;

      expect(formatBytes(mb ~/ 2), '0,5 MB');
      expect(formatBytes(10 * mb), '10 MB');
    });

    test('switches to gigabytes at the exact unit boundary', () {
      const mb = 1024 * 1024;
      const gb = 1024 * mb;

      expect(formatBytes(gb - 1, german: false), '1024 MB');
      expect(formatBytes(gb, german: false), '1 GB');
      expect(formatBytes(gb + gb ~/ 2, german: false), '1.5 GB');
      expect(formatBytes(gb + gb ~/ 2, german: true), '1,5 GB');
      expect(formatBytes(10 * gb + gb ~/ 2, german: true), '11 GB');
    });
  });

  group('timeAgo', () {
    final de = AppStrings.of(AppLanguage.de);
    final en = AppStrings.of(AppLanguage.en);
    final now = DateTime(2026, 6, 15, 12);

    test('returns just-now labels for current and future times', () {
      expect(timeAgo(now, t: en, now: now), 'just now');
      expect(
        timeAgo(now.add(const Duration(seconds: 20)), t: de, now: now),
        'gerade eben',
      );
    });

    test('uses localized minute and hour labels at their boundaries', () {
      expect(
        timeAgo(now.subtract(const Duration(minutes: 1)), t: en, now: now),
        '1 min ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(minutes: 59)), t: de, now: now),
        'vor 59 Min',
      );
      expect(
        timeAgo(now.subtract(const Duration(hours: 1)), t: en, now: now),
        '1h ago',
      );
      expect(
        timeAgo(now.subtract(const Duration(hours: 23)), t: de, now: now),
        'vor 23 Std',
      );
    });

    test('uses weekday labels for ages from one to six days', () {
      expect(
        timeAgo(now.subtract(const Duration(days: 1)), t: en, now: now),
        'Sun',
      );
      expect(
        timeAgo(now.subtract(const Duration(days: 6)), t: de, now: now),
        'Di',
      );
    });

    test('uses localized date labels from seven days onward', () {
      final when = DateTime(2026, 5, 31, 12);

      expect(timeAgo(when, t: en, now: now), '05/31');
      expect(timeAgo(when, t: de, now: now), '31.05.');
    });

    test('uses the current clock when now is omitted', () {
      expect(timeAgo(DateTime.now(), t: en), 'just now');
    });
  });
}
