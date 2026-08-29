import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/dictation/dictation_platform.dart';
import 'package:transcriber/ui/screens/onboarding/keyboard_onboarding_screen.dart';

import '../../keyboard/keyboard_settings_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/onboarding/keyboard');
  late FakeKeyboardSettingsChannel fakeChannel;

  setUp(() {
    fakeChannel = FakeKeyboardSettingsChannel(channel)..install();
  });

  tearDown(() => fakeChannel.uninstall());

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

    expect(find.text('Tastatur ist eingerichtet'), findsOneWidget);
    expect(find.text('Einrichtung starten'), findsNothing);
    final doneButton = find.widgetWithText(FilledButton, 'Fertig');
    expect(tester.widget<FilledButton>(doneButton).onPressed, isNotNull);
    expect(
      fakeChannel.methods,
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
