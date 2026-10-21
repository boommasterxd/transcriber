import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/ui/screens/onboarding/widgets/onboarding_cloud_step.dart';
import 'package:transcriber/ui/screens/settings/widgets/provider_connect_card.dart';

import '../onboarding/onboarding_test_support.dart';

const _motionDuration = Duration(milliseconds: 220);
const _unrelatedInput = ValueKey('unrelated-input');

void main() {
  _registerRapidToggleTest();
  _registerDraftFocusTest();
  _registerUnrelatedFocusTest();
  _registerAccordionTest();
  _registerReducedMotionTest();
}

void _registerRapidToggleTest() {
  testWidgets('rapid credential toggles keep the editor lifecycle usable', (
    tester,
  ) async {
    await _pumpMotionApp(tester);

    await _toggle(tester);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(_motionDuration);

    await _toggle(tester);
    expect(find.byType(TextField), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    await _toggle(tester);
    await tester.pump(const Duration(milliseconds: 60));
    await _toggle(tester);
    await tester.pump(_motionDuration);
    await _toggle(tester);
    await tester.pump(_motionDuration);
    expect(tester.takeException(), isNull);
  });
}

void _registerDraftFocusTest() {
  testWidgets('collapse removes editor focus and retains masked draft', (
    tester,
  ) async {
    await _pumpMotionApp(tester);
    await _toggle(tester);
    await tester.pump(_motionDuration);
    final input = _credentialInput();
    await tester.enterText(input, 'draft-credential');
    final editor = tester.widget<TextField>(input).controller;
    final focus = tester
        .widget<EditableText>(
          find.descendant(of: input, matching: find.byType(EditableText)),
        )
        .focusNode;
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await _toggle(tester);
    expect(_credentialInput(), findsNothing);
    expect(focus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.pump(_motionDuration);
    await _toggle(tester);
    await tester.pump(_motionDuration);
    final reopened = tester.widget<TextField>(_credentialInput());
    expect(reopened.controller, same(editor));
    expect(reopened.controller!.text, 'draft-credential');
    expect(reopened.obscureText, isTrue);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}

void _registerUnrelatedFocusTest() {
  testWidgets('collapse preserves unrelated focus without restoring it', (
    tester,
  ) async {
    await _pumpMotionApp(tester);
    final unrelated = find.byKey(_unrelatedInput);
    await tester.showKeyboard(unrelated);
    await _toggle(tester);
    await tester.pump(_motionDuration);
    expect(tester.testTextInput.isVisible, isTrue);
    await _toggle(tester);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.pump(_motionDuration);

    await _toggle(tester);
    await tester.pump(_motionDuration);
    await tester.showKeyboard(_credentialInput());
    await _toggle(tester);
    await tester.pump(_motionDuration);
    final unrelatedEditor = tester.widget<EditableText>(
      find.descendant(of: unrelated, matching: find.byType(EditableText)),
    );
    expect(unrelatedEditor.focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}

void _registerAccordionTest() {
  testWidgets(
    'controlled onboarding retains drafts when switching provider cards',
    (tester) async {
      await _pumpMotionApp(tester, child: const OnboardingCloudStep());
      await _toggle(tester);
      await tester.pump(_motionDuration);
      await tester.enterText(_credentialInput(), 'onboarding-draft');

      await _toggle(tester, last: true);
      expect(_credentialInput(), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
      await _toggle(tester, last: true);
      await tester.pump(_motionDuration);
      expect(_credentialInput(), findsNothing);
      await _toggle(tester);
      await tester.pump(_motionDuration);
      expect(
        tester.widget<TextField>(_credentialInput()).controller!.text,
        'onboarding-draft',
      );
      expect(tester.testTextInput.isVisible, isFalse);
    },
  );
}

void _registerReducedMotionTest() {
  testWidgets('disabled animations reach target height in the first frame', (
    tester,
  ) async {
    await _pumpMotionApp(tester, disableAnimations: true);
    final card = find.byType(ProviderConnectCard);
    final compact = tester.getSize(card).height;
    await _toggle(tester);
    final full = tester.getSize(card).height;
    expect(full, greaterThan(compact));
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getSize(card).height, full);
    await _toggle(tester);
    expect(tester.getSize(card).height, compact);
    expect(_credentialInput(), findsNothing);
  });
}

Finder _credentialInput() => find.descendant(
  of: find.byType(ProviderConnectCard),
  matching: find.byType(TextField),
);

Future<void> _toggle(WidgetTester tester, {bool last = false}) async {
  final headers = find.byType(ListTile);
  await tester.tap(last ? headers.last : headers.first);
  await tester.pump();
}

Future<void> _pumpMotionApp(
  WidgetTester tester, {
  Widget child = const ProviderConnectCard(provider: RemoteProviderId.openai),
  bool disableAnimations = false,
}) async {
  await pumpOnboardingTestApp(
    tester,
    child: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: disableAnimations),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const TextField(key: _unrelatedInput),
                child,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
