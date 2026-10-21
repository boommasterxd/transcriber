import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:transcriber/app_bootstrap.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/data/database/app_database.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/services/storage/audio_cache_manager.dart';
import 'package:transcriber/services/storage/storage_paths.dart';
import 'package:transcriber/share_entrypoint.dart';
import 'package:transcriber/ui/screens/settings/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ShareChannel channel;
  late AppDatabase database;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
    channel = _ShareChannel();
    channel.install();
  });

  _registerSettingsHostTest(() => channel, () => database);

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

  testWidgets('finishes the translucent activity for an empty shared path', (
    tester,
  ) async {
    channel.initialPath = '  ';

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

  testWidgets('waits for the native import before finishing the activity', (
    tester,
  ) async {
    channel.pendingPath = Completer<String?>();

    await runShareEntrypoint(loadBootstrap: () async => _bootstrap(database));
    await tester.pump();
    await tester.pump();
    expect(channel.calls, ['getInitialSharedPath']);

    channel.pendingPath!.complete(null);
    await tester.pump();
    await tester.pump();
    expect(channel.calls, ['getInitialSharedPath', 'finish']);
  });

  testWidgets('ignores a native result after the share host is disposed', (
    tester,
  ) async {
    channel.pendingPath = Completer<String?>();

    await runShareEntrypoint(loadBootstrap: () async => _bootstrap(database));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    channel.pendingPath!.complete('/cache/shared/late.wav');
    await tester.pump();
    expect(channel.calls, ['getInitialSharedPath']);
    expect(tester.takeException(), isNull);
  });
}

void _registerSettingsHostTest(
  _ShareChannel Function() currentChannel,
  AppDatabase Function() currentDatabase,
) {
  testWidgets('share host keeps audio and activity while settings are open', (
    tester,
  ) async {
    final channel = currentChannel();
    final fixture = (await tester.runAsync(_shareAudioFixture))!;
    addTearDown(
      () => tester.runAsync(() => fixture.root.delete(recursive: true)),
    );
    channel.initialPath = fixture.audio.path;
    final strings = AppStrings.of(AppSettings.initial().language);
    await runShareEntrypoint(
      loadBootstrap: () async =>
          _bootstrap(currentDatabase(), cacheManager: fixture.cacheManager),
    );
    await tester.pumpAndSettle();
    expect(find.text(strings.goToSettings), findsOneWidget);

    await tester.tap(find.text(strings.goToSettings));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(channel.calls, ['getInitialSharedPath']);
    expect(await tester.runAsync(fixture.audio.exists), isTrue);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(strings.goToSettings), findsOneWidget);
    expect(channel.calls, ['getInitialSharedPath']);
    expect(await tester.runAsync(fixture.audio.exists), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<({Directory root, File audio, AudioCacheManager cacheManager})>
_shareAudioFixture() async {
  final root = await Directory.systemTemp.createTemp('share-settings-');
  final audio = File('${root.path}/cache/shared/meeting.m4a');
  await audio.parent.create(recursive: true);
  await audio.writeAsBytes([1, 2, 3]);
  return (
    root: root,
    audio: audio,
    cacheManager: AudioCacheManager(
      paths: Future.value(
        StoragePaths(
          supportRoot: Directory('${root.path}/support'),
          cacheRoot: Directory('${root.path}/cache'),
        ),
      ),
    ),
  );
}

AppBootstrapData _bootstrap(
  AppDatabase database, {
  AudioCacheManager? cacheManager,
}) => AppBootstrapData(
  database: database,
  settings: AppSettings.initial(),
  connections: const {},
  notes: const [],
  cacheManager: cacheManager ?? AudioCacheManager(),
);

final class _ShareChannel {
  final _channel = const MethodChannel('app/share');
  final List<String> calls = [];
  String? initialPath;
  Completer<String?>? pendingPath;
  Object? error;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call.method);
          final failure = error;
          if (failure != null && call.method == 'getInitialSharedPath') {
            throw failure;
          }
          if (call.method == 'getInitialSharedPath') {
            return pendingPath?.future ?? initialPath;
          }
          return null;
        });
  }

  Future<void> uninstall() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}
