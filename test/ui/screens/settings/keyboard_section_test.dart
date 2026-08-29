import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/dictation/dictation_platform.dart';
import 'package:transcriber/ui/screens/settings/widgets/keyboard_section.dart';

import '../../keyboard/keyboard_settings_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/settings/keyboard');
  late FakeKeyboardSettingsChannel fakeChannel;

  setUp(() {
    fakeChannel = FakeKeyboardSettingsChannel(
      channel,
      enabled: true,
      selected: true,
    )..install();
  });

  tearDown(() => fakeChannel.uninstall());

  testWidgets('shows completed status and opens keyboard management', (
    tester,
  ) async {
    await pumpKeyboardSettingsSurface(
      tester,
      child: const Scaffold(
        body: KeyboardSection(
          platform: KeyboardSettingsPlatform(channel: channel),
        ),
      ),
    );

    expect(find.text('Aktuell ausgewählt'), findsOneWidget);
    expect(find.textContaining('gemini-3.5-transcribe-live'), findsOneWidget);
    expect(find.textContaining('nicht gespeichert'), findsOneWidget);
    expect(find.text('Einrichtung starten'), findsNothing);
    await tester.tap(find.text('Tastatur verwalten'));
    await tester.pumpAndSettle();
    expect(find.text('Tastatur ist eingerichtet'), findsOneWidget);
    expect(find.text('Fertig'), findsOneWidget);
    expect(
      fakeChannel.methods.where((method) => method == 'getStatus'),
      hasLength(2),
    );
  });

  testWidgets('refreshes settings after setup finishes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    fakeChannel.enabled = false;
    fakeChannel.selected = false;
    await pumpKeyboardSettingsSurface(
      tester,
      child: const Scaffold(
        body: KeyboardSection(
          platform: KeyboardSettingsPlatform(channel: channel),
        ),
      ),
    );

    await tester.tap(find.text('Einrichtung starten'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Aktivieren'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Tastatur auswählen'));
    await tester.tap(find.text('Tastatur auswählen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();

    expect(find.text('Tastatur verwalten'), findsOneWidget);
    expect(find.text('Einrichtung starten'), findsNothing);
  });
}
