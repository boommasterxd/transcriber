import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/dictation/dictation_platform.dart';
import 'package:transcriber/ui/screens/onboarding/keyboard_onboarding_screen.dart';

import '../../keyboard/keyboard_settings_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/onboarding/keyboard');
  var enabled = false;
  var selected = false;
  final methods = <String>[];

  setUp(() {
    enabled = false;
    selected = false;
    methods.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          switch (call.method) {
            case 'getStatus':
              return {'enabled': enabled, 'selected': selected};
            case 'openInputMethodSettings':
              enabled = true;
            case 'showInputMethodPicker':
              selected = true;
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('guides activation and selection in three clear steps', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpKeyboardSettingsSurface(
      tester,
      child: const KeyboardOnboardingScreen(
        platform: KeyboardSettingsPlatform(channel: channel),
      ),
    );

    expect(find.text('Live-Anbieter prüfen'), findsOneWidget);
    expect(find.textContaining('gemini-3.5-transcribe-live'), findsOneWidget);
    expect(find.text('In Android aktivieren'), findsOneWidget);
    expect(find.text('Als Tastatur auswählen'), findsOneWidget);

    await tester.tap(find.text('Aktivieren'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tastatur auswählen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tastatur auswählen'));
    await tester.pumpAndSettle();

    expect(find.text('Aktuell ausgewählt'), findsOneWidget);
    final doneButton = find.widgetWithText(
      FilledButton,
      'Einrichtung abschließen',
    );
    expect(tester.widget<FilledButton>(doneButton).onPressed, isNotNull);
    expect(
      methods,
      containsAllInOrder([
        'getStatus',
        'openInputMethodSettings',
        'getStatus',
        'showInputMethodPicker',
        'getStatus',
      ]),
    );
  });
}
