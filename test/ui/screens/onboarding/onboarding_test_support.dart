import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';

class OnboardingTestSettingsController extends SettingsController {
  OnboardingTestSettingsController(this.initial);

  final AppSettings initial;

  @override
  AppSettings build() => initial;

  Future<void> _replace(AppSettings next) async {
    state = next;
  }

  @override
  Future<void> setAsrProvider(RemoteProviderId provider) =>
      _replace(state.copyWith(asrProvider: provider));

  @override
  Future<void> setSummaryProvider(RemoteProviderId provider) =>
      _replace(state.copyWith(summaryProvider: provider));

  @override
  Future<void> setAsrModel(RemoteProviderId provider, String modelId) =>
      _replace(
        state.copyWith(
          asrModelByProvider: {...state.asrModelByProvider, provider: modelId},
        ),
      );

  @override
  Future<void> setSummaryModel(RemoteProviderId provider, String modelId) =>
      _replace(
        state.copyWith(
          chatModelByProvider: {
            ...state.chatModelByProvider,
            provider: modelId,
          },
        ),
      );

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

class OnboardingPermissionChannel {
  static const _channel = MethodChannel(
    'flutter.baseflow.com/permissions/methods',
  );

  PermissionStatus microphone = PermissionStatus.denied;
  PermissionStatus requestedMicrophone = PermissionStatus.denied;
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
    if (call.method == 'checkPermissionStatus') return microphone.index;
    if (call.method == 'requestPermissions') {
      requestCalls++;
      microphone = requestedMicrophone;
      return {
        for (final permission in (call.arguments as List).cast<int>())
          permission: microphone.index,
      };
    }
    if (call.method == 'openAppSettings') {
      settingsCalls++;
      return true;
    }
    return null;
  }
}

void useGrantedOnboardingPermissions() {
  late OnboardingPermissionChannel permissions;
  setUp(() {
    permissions = OnboardingPermissionChannel()
      ..microphone = PermissionStatus.granted
      ..install();
  });
  tearDown(() => permissions.uninstall());
}

class OnboardingTestConfig {
  const OnboardingTestConfig({
    this.settings,
    this.connections = const {},
    this.settingsController,
  });

  final AppSettings? settings;
  final Map<RemoteProviderId, bool> connections;
  final OnboardingTestSettingsController? settingsController;
}

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
      remoteModelsProvider.overrideWith((ref, query) async => const []),
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
