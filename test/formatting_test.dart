import 'package:test/test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/utils/formatting.dart';

void main() {
  group('formatDuration', () {
    test('formats seconds as m:ss', () {
      expect(formatDuration(0), '0:00');
      expect(formatDuration(5), '0:05');
      expect(formatDuration(65), '1:05');
      expect(formatDuration(600), '10:00');
    });
  });

  group('formatBytes', () {
    test('formats MB and GB', () {
      expect(formatBytes(75 * 1024 * 1024, german: false), '75 MB');
      expect(formatBytes(1500 * 1024 * 1024, german: false), '1.5 GB');
    });

    test('uses comma decimal separator in German', () {
      expect(formatBytes(1500 * 1024 * 1024, german: true), '1,5 GB');
    });
  });

  group('timeAgo', () {
    final de = AppStrings.of(AppLanguage.de);
    final en = AppStrings.of(AppLanguage.en);

    test('returns just now for recent times', () {
      final now = DateTime(2026, 6, 15, 12, 0, 0);
      expect(
        timeAgo(now.subtract(const Duration(seconds: 10)), t: en, now: now),
        'just now',
      );
      expect(
        timeAgo(now.subtract(const Duration(minutes: 5)), t: de, now: now),
        'vor 5 Min',
      );
    });
  });
}
