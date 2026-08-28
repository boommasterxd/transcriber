import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/share_entrypoint.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _ShareChannel channel;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    channel = _ShareChannel();
    channel.install();
  });

  tearDown(() => channel.uninstall());

  testWidgets('finishes the translucent activity when no shared path exists', (
    tester,
  ) async {
    channel.initialPath = null;

    await runShareEntrypoint();
    await tester.pump();
    await tester.pump();

    expect(channel.calls, ['getInitialSharedPath', 'finish']);
  });

  testWidgets(
    'finishes the translucent activity when the native lookup fails',
    (tester) async {
      channel.error = PlatformException(code: 'lookup_failed');

      await runShareEntrypoint();
      await tester.pump();
      await tester.pump();

      expect(channel.calls, ['getInitialSharedPath', 'finish']);
    },
  );
}

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
