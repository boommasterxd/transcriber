import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/app.dart';
import 'package:transcriber/main.dart' as application;

import 'support/app_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bootstrap initializes models and renders the application', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.7;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ReceiveSharingIntent.setMockValues(
      initialMedia: const [],
      mediaStream: const Stream.empty(),
    );
    final permissions = TestPermissionChannel();
    permissions.install();
    addTearDown(permissions.uninstall);

    var initialized = false;
    await application.bootstrapApplication(
      initializePlatformServices: () {},
      initializeModels: (token) async {
        expect(token, isNull);
        initialized = true;
      },
    );
    await tester.pump();

    expect(initialized, isTrue);
    expect(find.byType(TranscriberApp), findsOneWidget);
  });

  testWidgets('bootstrap tolerates local model initialization failures', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    ReceiveSharingIntent.setMockValues(
      initialMedia: const [],
      mediaStream: const Stream.empty(),
    );

    await application.bootstrapApplication(
      initializePlatformServices: () {},
      initializeModels: (_) async => throw StateError('unavailable'),
    );
    await tester.pump();

    expect(find.byType(TranscriberApp), findsOneWidget);
  });
}
