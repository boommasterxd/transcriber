import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/ui/screens/detail/widgets/summary_failure_notice.dart';

void main() {
  for (final language in AppLanguage.values) {
    testWidgets('renders selectable summary diagnostic in ${language.name}', (
      tester,
    ) async {
      final strings = AppStrings.of(language);
      const diagnostic =
          '<b>Provider rejected request</b>\nDetails unavailable';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(Brightness.light, AppAccent.violet),
          home: Scaffold(
            body: SummaryFailureNotice(error: diagnostic, strings: strings),
          ),
        ),
      );

      expect(find.text(strings.summaryFailedTitle), findsOneWidget);
      expect(find.text(strings.summaryFailedBody), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        diagnostic,
      );
      final liveRegion = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      );
      expect(liveRegion, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
