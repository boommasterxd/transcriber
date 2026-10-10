import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/ui/screens/settings/widgets/remote_model_option.dart';

import '../onboarding/onboarding_test_support.dart';

void main() {
  testWidgets('checkmark choices remain mutually exclusive and cannot clear', (
    tester,
  ) async {
    await _pumpChoices(tester);
    _expectSelection(tester, 'first');
    await tester.tap(find.text('Second model'));
    await tester.pumpAndSettle();
    _expectSelection(tester, 'second');
    await tester.tap(find.text('Second model'));
    await tester.pumpAndSettle();
    _expectSelection(tester, 'second');
    final node = tester.getSemantics(find.byKey(const ValueKey('second')));
    expect(
      node,
      matchesSemantics(
        label: 'Second model\nsecond',
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
        hasTapAction: true,
      ),
    );
  });

  testWidgets('Tab, arrows and Space retain native radio group navigation', (
    tester,
  ) async {
    await _pumpChoices(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectSelection(tester, 'second');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    _expectSelection(tester, 'second');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    _expectSelection(tester, 'first');
  });
}

Future<void> _pumpChoices(WidgetTester tester) async {
  var selection = 'first';
  await pumpOnboardingTestApp(
    tester,
    child: Scaffold(
      body: StatefulBuilder(
        builder: (context, setState) => RadioGroup<String>(
          groupValue: selection,
          onChanged: (value) => setState(() => selection = value!),
          child: const Column(
            children: [
              RemoteModelOption(
                key: ValueKey('first'),
                model: RemoteModelInfo(id: 'first'),
              ),
              RemoteModelOption(
                key: ValueKey('second'),
                model: RemoteModelInfo(id: 'second', label: 'Second model'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _expectSelection(WidgetTester tester, String selected) {
  final radios = tester.widgetList<RawRadio<String>>(
    find.byType(RawRadio<String>),
  );
  expect(
    radios
        .where((radio) => radio.groupRegistry!.groupValue == radio.value)
        .map((radio) => radio.value),
    [selected],
  );
  expect(find.byIcon(Icons.check), findsOneWidget);
}
