import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/services/service_exceptions.dart';
import 'package:transcriber/ui/screens/processing/widgets/processing_error_view.dart';
import 'processing_widget_test_support.dart';

void main() {
  final strings = AppStrings.of(AppLanguage.en);

  testWidgets('normal error invokes retry and dismiss actions', (tester) async {
    var retried = false;
    var closed = false;
    final presentation = ProcessingErrorPresentation.resolve(
      const RemoteApiException('Provider unavailable'),
      strings,
    );

    await tester.pumpWidget(
      buildProcessingTestApp(
        ProcessingErrorContent(
          presentation: presentation,
          actions: ProcessingErrorActions(
            onRetry: () => retried = true,
            onClose: () => closed = true,
            onOpenSettings: () {},
          ),
          layout: ProcessingErrorLayout.screen,
        ),
      ),
    );

    expect(find.text(strings.errorTitle), findsOneWidget);
    expect(find.text('Provider unavailable'), findsOneWidget);
    await tester.tap(find.text(strings.retry));
    await tester.tap(find.text(strings.dismiss));

    expect(retried, isTrue);
    expect(closed, isTrue);
  });

  testWidgets('missing API key invokes settings action and keeps safe copy', (
    tester,
  ) async {
    var openedSettings = false;
    final presentation = ProcessingErrorPresentation.resolve(
      const MissingApiKeyException('private key detail'),
      strings,
    );

    await tester.pumpWidget(
      buildProcessingTestApp(
        ProcessingErrorContent(
          presentation: presentation,
          actions: ProcessingErrorActions(
            onRetry: () {},
            onClose: () {},
            onOpenSettings: () => openedSettings = true,
          ),
          layout: ProcessingErrorLayout.screen,
        ),
      ),
    );

    expect(find.text(strings.keyMissing), findsOneWidget);
    expect(find.text(strings.connectFirst), findsOneWidget);
    expect(find.text('private key detail'), findsNothing);
    await tester.tap(find.text(strings.goToSettings));

    expect(openedSettings, isTrue);
  });

  testWidgets('sheet layout uses a text button for dismiss', (tester) async {
    var closed = false;
    final presentation = ProcessingErrorPresentation.resolve(
      const RemoteApiException('Temporary failure'),
      strings,
    );

    await tester.pumpWidget(
      buildProcessingTestApp(
        ProcessingErrorContent(
          presentation: presentation,
          actions: ProcessingErrorActions(
            onRetry: () {},
            onClose: () => closed = true,
            onOpenSettings: () {},
          ),
          layout: ProcessingErrorLayout.sheet,
        ),
      ),
    );

    expect(find.byType(TextButton), findsOneWidget);
    await tester.tap(find.text(strings.dismiss));
    expect(closed, isTrue);
  });
}
