import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/app_bootstrap.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/share_entrypoint.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ShareChannel channel;
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    channel = _ShareChannel();
    channel.install();
  });

  tearDown(() async {
    await channel.uninstall();
    await database.close();
  });

  testWidgets('finishes the translucent activity when no shared path exists', (
    tester,
  ) async {
    channel.initialPath = null;

    await runShareEntrypoint(loadBootstrap: () async => _bootstrap(database));
    await tester.pump();
    await tester.pump();

    expect(channel.calls, ['getInitialSharedPath', 'finish']);
  });

  testWidgets(
    'finishes the translucent activity when the native lookup fails',
    (tester) async {
      channel.error = PlatformException(code: 'lookup_failed');

      await runShareEntrypoint(loadBootstrap: () async => _bootstrap(database));
      await tester.pump();
      await tester.pump();

      expect(channel.calls, ['getInitialSharedPath', 'finish']);
    },
  );
}

AppBootstrapData _bootstrap(AppDatabase database) => AppBootstrapData(
  database: database,
  settings: AppSettings.initial(),
  connections: const {},
  notes: const [],
  cacheManager: AudioCacheManager(),
);

final class _ShareChannel {
  final _channel = const MethodChannel('app/share');
  final List<String> calls = [];
  String? initialPath;
  Object? error;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call.method);
          final failure = error;
          if (failure != null && call.method == 'getInitialSharedPath') {
            throw failure;
          }
          if (call.method == 'getInitialSharedPath') return initialPath;
          return null;
        });
  }

  Future<void> uninstall() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}
