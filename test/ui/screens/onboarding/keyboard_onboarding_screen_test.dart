import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/services/dictation/dictation_platform.dart';
import 'package:transcriber/ui/screens/onboarding/keyboard_onboarding_screen.dart';

import '../../keyboard/keyboard_settings_test_support.dart';
import 'onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/onboarding/keyboard');
  final strings = AppStrings.of(AppLanguage.de);
  late FakeKeyboardSettingsChannel fakeChannel;
  late OnboardingPermissionChannel permissions;

  setUp(() {
    fakeChannel = FakeKeyboardSettingsChannel(channel)..install();
    permissions = OnboardingPermissionChannel()..install();
  });

  tearDown(() async {
    fakeChannel.uninstall();
    await permissions.uninstall();
  });

  testWidgets('guides keyboard activation and selection without prompting', (
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
    expect(permissions.requestCalls, 0);
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

  testWidgets('enables dictation microphone access only on request', (
    tester,
  ) async {
    permissions.requestedMicrophone = PermissionStatus.granted;
    await _pumpSelectedKeyboard(tester, fakeChannel);
    expect(permissions.requestCalls, 0);

    await tester.tap(find.text(strings.keyboardMicEnable));
    await tester.pumpAndSettle();
    expect(permissions.requestCalls, 1);
    expect(find.text(strings.keyboardMicGranted), findsOneWidget);
    expect(find.text(strings.keyboardMicEnable), findsNothing);
  });

  _registerMicrophoneSettingsTest(() => fakeChannel, () => permissions);
}

void _registerMicrophoneSettingsTest(
  FakeKeyboardSettingsChannel Function() currentChannel,
  OnboardingPermissionChannel Function() currentPermissions,
) {
  final strings = AppStrings.of(AppLanguage.de);
  testWidgets('allows retry after denial and recovers from Android settings', (
    tester,
  ) async {
    final permissions = currentPermissions();
    await _pumpSelectedKeyboard(tester, currentChannel());
    await tester.tap(find.text(strings.keyboardMicEnable));
    await tester.pumpAndSettle();
    expect(find.text(strings.keyboardMicDenied), findsOneWidget);
    expect(find.text(strings.micPermissionSettings), findsNothing);

    permissions.requestedMicrophone = PermissionStatus.permanentlyDenied;
    await tester.tap(find.text(strings.keyboardMicEnable));
    await tester.pumpAndSettle();
    expect(find.text(strings.keyboardMicEnable), findsNothing);
    expect(find.text(strings.keyboardMicMissing), findsOneWidget);

    await tester.tap(find.text(strings.micPermissionSettings));
    await tester.pumpAndSettle();
    expect(permissions.settingsCalls, 1);
    _resume(tester);
    await tester.pumpAndSettle();
    expect(find.text(strings.micPermissionSettings), findsOneWidget);

    permissions.microphone = PermissionStatus.granted;
    _resume(tester);
    await tester.pumpAndSettle();
    expect(find.text(strings.keyboardMicGranted), findsOneWidget);
    expect(find.text(strings.micPermissionSettings), findsNothing);
  });
}

Future<void> _pumpSelectedKeyboard(
  WidgetTester tester,
  FakeKeyboardSettingsChannel fakeChannel,
) async {
  fakeChannel
    ..enabled = true
    ..selected = true;
  await tester.binding.setSurfaceSize(const Size(400, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await pumpKeyboardSettingsSurface(
    tester,
    child: KeyboardOnboardingScreen(
      platform: KeyboardSettingsPlatform(channel: fakeChannel.channel),
    ),
  );
  await tester.pumpAndSettle();
}

void _resume(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}
