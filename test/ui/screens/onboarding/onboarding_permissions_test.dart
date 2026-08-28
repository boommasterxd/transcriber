import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/ui/screens/onboarding/widgets/onboarding_permissions_step.dart';

import 'onboarding_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final strings = AppStrings.of(AppLanguage.de);
  late OnboardingPermissionChannel permissions;

  setUp(() {
    permissions = OnboardingPermissionChannel()..install();
  });

  tearDown(() => permissions.uninstall());

  testWidgets('initial permission state reflects microphone access', (
    tester,
  ) async {
    permissions.microphone = PermissionStatus.granted;
    final container = await _pumpPermissions(tester);

    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.circle_outlined), findsNothing);
    expect(find.text(strings.obPermGranted), findsOneWidget);
    expect(container.read(onboardingPermissionsReadyProvider), isTrue);
  });

  testWidgets('request denial explains that permissions remain required', (
    tester,
  ) async {
    permissions.requestedMicrophone = PermissionStatus.denied;
    final container = await _pumpPermissions(tester);

    await tester.tap(find.text(strings.obPermEnable));
    await tester.pump();
    await tester.pump();

    expect(permissions.requestCalls, 1);
    expect(find.text(strings.obPermDeniedNote), findsOneWidget);
    expect(find.text(strings.obPermRequiredHint), findsOneWidget);
    expect(container.read(onboardingPermissionsReadyProvider), isFalse);
  });

  testWidgets('successful requests update the gate and approved state', (
    tester,
  ) async {
    permissions.requestedMicrophone = PermissionStatus.granted;
    final container = await _pumpPermissions(tester);

    await tester.tap(find.text(strings.obPermEnable));
    await tester.pump();
    await tester.pump();

    expect(find.text(strings.obPermGranted), findsOneWidget);
    expect(find.text(strings.obPermRequiredHint), findsNothing);
    expect(container.read(onboardingPermissionsReadyProvider), isTrue);
  });

  testWidgets('permanent denial opens application settings', (tester) async {
    permissions.microphone = PermissionStatus.permanentlyDenied;
    await _pumpPermissions(tester);

    expect(find.text(strings.obPermBlockedNote), findsOneWidget);
    expect(find.text(strings.obPermEnable), findsNothing);
    await tester.tap(find.text(strings.obPermOpenSettings));
    await tester.pump();

    expect(permissions.settingsCalls, 1);
  });

  testWidgets('resume refreshes permissions changed in system settings', (
    tester,
  ) async {
    permissions.microphone = PermissionStatus.permanentlyDenied;
    final container = await _pumpPermissions(tester);

    permissions.microphone = PermissionStatus.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(find.text(strings.obPermGranted), findsOneWidget);
    expect(container.read(onboardingPermissionsReadyProvider), isTrue);
  });
}

Future<ProviderContainer> _pumpPermissions(WidgetTester tester) async {
  final container = await pumpOnboardingTestApp(
    tester,
    child: const Scaffold(
      body: SingleChildScrollView(child: OnboardingPermissionsStep()),
    ),
  );
  await tester.pump();
  return container;
}
