import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/core/toast.dart';

void main() {
  testWidgets('showAppToast is a no-op without a mounted messenger', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());

    showAppToast('ignored');
    await tester.pump();

    expect(find.text('ignored'), findsNothing);
  });

  testWidgets('showAppToast displays a normal toast for two seconds', (
    tester,
  ) async {
    await _pumpMessenger(tester);

    showAppToast('ready');
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(find.text('ready'), findsOneWidget);
    expect(snackBar.duration, const Duration(seconds: 2));
    expect(snackBar.behavior, SnackBarBehavior.floating);
  });

  testWidgets('showAppToast displays an error toast for four seconds', (
    tester,
  ) async {
    await _pumpMessenger(tester);

    showAppToast('failed', isError: true);
    await tester.pump();

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(find.text('failed'), findsOneWidget);
    expect(snackBar.duration, const Duration(seconds: 4));
  });

  testWidgets('showAppToast replaces the currently visible toast', (
    tester,
  ) async {
    await _pumpMessenger(tester);

    showAppToast('first');
    await tester.pump();
    showAppToast('second');
    await tester.pump();

    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });
}

Future<void> _pumpMessenger(WidgetTester tester) => tester.pumpWidget(
  MaterialApp(
    scaffoldMessengerKey: scaffoldMessengerKey,
    home: const Scaffold(body: SizedBox.shrink()),
  ),
);
