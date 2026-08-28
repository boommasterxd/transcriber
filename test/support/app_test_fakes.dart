import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/data/models/transcript_note.dart';
import 'package:transcriber/services/share/share_intent_service.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/model_manager_controller.dart';
import 'package:transcriber/state/notes_controller.dart';
import 'package:transcriber/state/providers.dart';
import 'package:transcriber/state/settings_controller.dart';

final class TestShareIntentService extends ShareIntentService {
  TestShareIntentService({this.initialPath, this.initialError});

  final String? initialPath;
  final Object? initialError;
  void Function(String path)? _listener;

  @override
  Future<String?> initialSharedAudio() async {
    final error = initialError;
    if (error != null) throw error;
    return initialPath;
  }

  @override
  void listen(void Function(String path) onAudio) => _listener = onAudio;

  void emit(String path) => _listener?.call(path);
}

final class TestSettingsController extends SettingsController {
  TestSettingsController([AppSettings? initial])
    : _initial = initial ?? AppSettings.initial();

  final AppSettings _initial;

  @override
  AppSettings build() => _initial;
}

final class TestConnectionsController extends ConnectionsController {
  TestConnectionsController([Map<RemoteProviderId, bool>? initial])
    : _initial = initial ?? const {};

  final Map<RemoteProviderId, bool> _initial;

  @override
  Map<RemoteProviderId, bool> build() => Map.of(_initial);
}

final class TestModelManagerController extends ModelManagerController {
  @override
  ModelManagerState build() => const ModelManagerState();
}

final class TestNotesController extends NotesController {
  @override
  List<TranscriptNote> build() => const [];
}

final class TestPermissionChannel {
  TestPermissionChannel({this.granted = true});

  bool granted;
  final _channel = const MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'checkPermissionStatus') {
            return granted ? 1 : 0;
          }
          return null;
        });
  }

  Future<void> uninstall() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

Future<SharedPreferences> testPreferences() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

Widget appScope({
  required SharedPreferences preferences,
  required AppSettings settings,
  TestShareIntentService? shareService,
  required Widget child,
}) => ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(preferences),
    initialSettingsProvider.overrideWithValue(settings),
    initialConnectionsProvider.overrideWithValue(const {}),
    settingsControllerProvider.overrideWith(
      () => TestSettingsController(settings),
    ),
    connectionsControllerProvider.overrideWith(TestConnectionsController.new),
    modelManagerControllerProvider.overrideWith(TestModelManagerController.new),
    notesControllerProvider.overrideWith(TestNotesController.new),
    if (shareService != null)
      shareIntentServiceProvider.overrideWithValue(shareService),
  ],
  child: child,
);
