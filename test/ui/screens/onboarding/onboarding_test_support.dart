import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/processing_mode.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/model_manager_controller.dart';
import 'package:transcriber/state/settings_controller.dart';

class OnboardingTestSettingsController extends SettingsController {
  OnboardingTestSettingsController(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;

  Future<void> _replace(AppSettings next) {
    state = next;
    return Future.value();
  }

  @override
  Future<void> setAsrMode(ProcessingMode mode) =>
      _replace(state.copyWith(asrMode: mode));

  @override
  Future<void> setSummaryMode(ProcessingMode mode) =>
      _replace(state.copyWith(summaryMode: mode));

  @override
  Future<void> setWhisperModel(String id) =>
      _replace(state.copyWith(whisperModelId: id));

  @override
  Future<void> setGemmaModel(String id) =>
      _replace(state.copyWith(gemmaModelId: id));

  @override
  Future<void> setSummarizeEnabled(bool value) =>
      _replace(state.copyWith(summarizeEnabled: value));

  @override
  Future<void> completeOnboarding() =>
      _replace(state.copyWith(onboarded: true));
}

class OnboardingTestConnectionsController extends ConnectionsController {
  OnboardingTestConnectionsController(this.initial);

  final Map<RemoteProviderId, bool> initial;

  @override
  Map<RemoteProviderId, bool> build() => Map.of(initial);

  @override
  Future<String> apiKey(RemoteProviderId provider) async => '';
}

class OnboardingTestModelController extends ModelManagerController {
  OnboardingTestModelController(this.initial);

  final ModelManagerState initial;
  final List<String> whisperDownloads = [];
  final List<String> gemmaDownloads = [];

  @override
  ModelManagerState build() => initial;

  @override
  Future<void> downloadWhisper(String id) async {
    whisperDownloads.add(id);
    state = state.copyWith(
      whisper: {
        ...state.whisper,
        id: const ModelStatus(status: DownloadStatus.downloaded, progress: 1),
      },
    );
  }

  @override
  Future<void> downloadGemma(String id) async {
    gemmaDownloads.add(id);
    state = state.copyWith(
      gemma: {
        ...state.gemma,
        id: const ModelStatus(status: DownloadStatus.downloaded, progress: 1),
      },
    );
  }
}

class OnboardingPermissionChannel {
  static const _channel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  PermissionStatus microphone = PermissionStatus.denied;
  PermissionStatus notification = PermissionStatus.denied;
  PermissionStatus requestedMicrophone = PermissionStatus.denied;
  PermissionStatus requestedNotification = PermissionStatus.denied;
  int requestCalls = 0;
  int settingsCalls = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _handle);
  }

  Future<void> uninstall() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }

  Future<Object?> _handle(MethodCall call) async {
    if (call.method == 'checkPermissionStatus') {
      return _statusFor(call.arguments as int).index;
    }
    if (call.method == 'requestPermissions') {
      requestCalls++;
      final permissions = (call.arguments as List).cast<int>();
      return {
        for (final permission in permissions)
          permission: _request(permission).index,
      };
    }
    if (call.method == 'openAppSettings') {
      settingsCalls++;
      return true;
    }
    return null;
  }

  PermissionStatus _statusFor(int permission) =>
      permission == Permission.microphone.value ? microphone : notification;

  PermissionStatus _request(int permission) {
    if (permission == Permission.microphone.value) {
      microphone = requestedMicrophone;
      return microphone;
    }
    notification = requestedNotification;
    return notification;
  }
}

void useGrantedOnboardingPermissions() {
  late OnboardingPermissionChannel permissions;
  setUp(() {
    permissions = OnboardingPermissionChannel()
      ..microphone = PermissionStatus.granted
      ..notification = PermissionStatus.granted
      ..install();
  });
  tearDown(() => permissions.uninstall());
}

class OnboardingTestConfig {
  const OnboardingTestConfig({
    this.settings,
    this.models = const ModelManagerState(),
    this.connections = const {},
    this.settingsController,
    this.modelController,
  });

  final AppSettings? settings;
  final ModelManagerState models;
  final Map<RemoteProviderId, bool> connections;
  final OnboardingTestSettingsController? settingsController;
  final OnboardingTestModelController? modelController;
}

OnboardingTestConfig connectedCloudOnboardingConfig() => OnboardingTestConfig(
  settings: AppSettings.initial().copyWith(
    asrMode: ProcessingMode.cloud,
    summarizeEnabled: false,
  ),
  connections: const {RemoteProviderId.openai: true},
);

Future<ProviderContainer> pumpOnboardingTestApp(
  WidgetTester tester, {
  required Widget child,
  OnboardingTestConfig config = const OnboardingTestConfig(),
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 1100));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final initial = config.settings ?? AppSettings.initial();
  final container = ProviderContainer(
    overrides: [
      settingsControllerProvider.overrideWith(
        () =>
            config.settingsController ??
            OnboardingTestSettingsController(initial),
      ),
      connectionsControllerProvider.overrideWith(
        () => OnboardingTestConnectionsController(config.connections),
      ),
      modelManagerControllerProvider.overrideWith(
        () =>
            config.modelController ??
            OnboardingTestModelController(config.models),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(Brightness.light, AppAccent.blue),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.7)),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pump();
  return container;
}

ModelManagerState downloadedModels(AppSettings settings) => ModelManagerState(
  whisper: {
    settings.whisperModelId: const ModelStatus(
      status: DownloadStatus.downloaded,
    ),
  },
  gemma: {
    settings.gemmaModelId: const ModelStatus(status: DownloadStatus.downloaded),
  },
);
