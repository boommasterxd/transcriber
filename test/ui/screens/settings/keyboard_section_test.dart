import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/services/dictation/dictation_platform.dart';
import 'package:transcriber/ui/screens/settings/widgets/keyboard_section.dart';

import '../../keyboard/keyboard_settings_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/settings/keyboard');
  final methods = <String>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          if (call.method == 'getStatus') {
            return {'enabled': true, 'selected': true};
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('shows status and opens the guided keyboard setup', (
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
    await tester.tap(find.text('Einrichtung starten'));
    await tester.pumpAndSettle();
    expect(find.text('Transcriber-Tastatur einrichten'), findsOneWidget);
    expect(find.text('Live-Anbieter prüfen'), findsOneWidget);
    expect(methods.where((method) => method == 'getStatus'), hasLength(2));
  });
}
