import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_palette.dart';
import 'package:transcriber/state/recording_controller.dart';
import 'package:transcriber/ui/screens/record/widgets/record_limit_hint.dart';

void main() {
  for (final language in AppLanguage.values) {
    _registerHintTests(language);
  }
}

void _registerHintTests(AppLanguage language) {
  final strings = AppStrings.of(language);
  for (final example in [
    (const RecordingState(), ''),
    (
      const RecordingState(boundary: RecordingBoundary(maxDurationSec: 655)),
      strings.recLimit('10:55'),
    ),
    (
      const RecordingState(
        elapsedSec: 595,
        boundary: RecordingBoundary(maxDurationSec: 655),
      ),
      strings.recLimitWarning('1:00'),
    ),
    (
      const RecordingState(
        elapsedSec: 655,
        boundary: RecordingBoundary(maxDurationSec: 655, reached: true),
      ),
      strings.recLimitReached,
    ),
    (
      const RecordingState(
        elapsedSec: 32,
        boundary: RecordingBoundary(maxDurationSec: 655, failed: true),
      ),
      strings.recFailure,
    ),
  ]) {
    testWidgets('${language.name} recording boundary: ${example.$2}', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            recordingControllerProvider.overrideWith(
              () => _RecordingStateController(example.$1),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: [AppPalette.light(AppAccent.violet)]),
            home: Scaffold(body: RecordLimitHint(strings: strings)),
          ),
        ),
      );
      if (example.$2.isEmpty) {
        expect(find.byType(Text), findsNothing);
      } else {
        expect(find.text(example.$2), findsOneWidget);
      }
    });
  }
}

class _RecordingStateController extends RecordingController {
  _RecordingStateController(this.initial);
  final RecordingState initial;
  @override
  RecordingState build() => initial;
}
