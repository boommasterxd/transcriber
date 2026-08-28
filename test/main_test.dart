import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:transcriber/app.dart';
import 'package:transcriber/app_bootstrap.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/main.dart' as application;

import 'support/app_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bootstrap loads dependencies and renders the application', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 0.7;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    ReceiveSharingIntent.setMockValues(
      initialMedia: const [],
      mediaStream: const Stream.empty(),
    );
    final permissions = TestPermissionChannel();
    permissions.install();
    addTearDown(permissions.uninstall);

    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    var loads = 0;
    await application.bootstrapApplication(
      loadBootstrap: () async {
        loads++;
        return AppBootstrapData(
          database: database,
          settings: AppSettings.initial(),
          connections: const {},
          notes: const [],
          cacheManager: AudioCacheManager(),
        );
      },
    );
    await tester.pump();

    expect(loads, 1);
    expect(find.byType(TranscriberApp), findsOneWidget);
  });
}
