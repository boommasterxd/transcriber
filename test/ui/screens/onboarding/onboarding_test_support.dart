import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/core/theme/app_accent.dart';
import 'package:transcriber/core/theme/app_theme.dart';
import 'package:transcriber/data/models/app_settings.dart';
import 'package:transcriber/data/models/remote_provider.dart';
import 'package:transcriber/state/connections_controller.dart';
import 'package:transcriber/state/remote_models_provider.dart';
import 'package:transcriber/state/settings_controller.dart';
import 'package:transcriber/services/remote/remote_api_client.dart';
import 'package:transcriber/ui/screens/onboarding/onboarding_screen.dart';

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
  Future<void> setAsrSelection(RemoteProviderId provider, String modelId) =>
      _replace(
        state.copyWith(
          asrProvider: provider,
          asrModelByProvider: {...state.asrModelByProvider, provider: modelId},
        ),
      );

  @override
  Future<void> setSummarySelection(RemoteProviderId provider, String modelId) =>
      _replace(
        state.copyWith(
          summaryProvider: provider,
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
  OnboardingTestConnectionsController(this.config) : keys = Map.of(config.keys);

  final OnboardingTestConfig config;
  final Map<RemoteProviderId, String> keys;

  @override
  Map<RemoteProviderId, bool> build() => Map.of(config.connections);

  @override
  Future<String> apiKey(RemoteProviderId provider) async =>
      keys[provider] ?? '';

  @override
  Future<void> connect(RemoteProviderId provider, String key) async {
    if (key.trim().isEmpty) throw ArgumentError('Empty test key');
    if (config.failedConnections.contains(provider)) {
      throw StateError('Test provider rejected connection');
    }
    keys[provider] = key.trim();
    state = {...state, provider: true};
  }

  @override
  Future<void> test(RemoteProviderId provider) async {
    if ((keys[provider] ?? '').isEmpty) throw StateError('Missing test key');
  }

  @override
  Future<void> disconnect(RemoteProviderId provider) async {
    keys.remove(provider);
    state = {...state, provider: false};
  }
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
    this.keys = const {},
    this.settingsController,
    this.surfaceSize = const Size(800, 1100),
    this.textScale = 0.7,
    this.modelCatalog = defaultOnboardingModels,
    this.failedConnections = const {},
  });

  final AppSettings? settings;
  final Map<RemoteProviderId, bool> connections;
  final Map<RemoteProviderId, String> keys;
  final OnboardingTestSettingsController? settingsController;
  final Size surfaceSize;
  final double textScale;
  final Future<List<RemoteModelInfo>> Function(RemoteModelsQuery) modelCatalog;
  final Set<RemoteProviderId> failedConnections;
}

Future<List<RemoteModelInfo>> defaultOnboardingModels(
  RemoteModelsQuery query,
) async {
  final id = switch ((query.provider, query.forTranscription)) {
    (RemoteProviderId.openai, true) => 'gpt-transcribe',
    (RemoteProviderId.openai, false) => 'gpt-5.6-luna',
    (RemoteProviderId.google, true) => 'gemini-3.5-transcribe',
    (RemoteProviderId.google, false) => 'gemini-3.7-flash',
  };
  return [RemoteModelInfo(id: id)];
}

Future<ProviderContainer> pumpOnboardingTestApp(
  WidgetTester tester, {
  required Widget child,
  OnboardingTestConfig config = const OnboardingTestConfig(),
}) async {
  await tester.binding.setSurfaceSize(config.surfaceSize);
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
        () => OnboardingTestConnectionsController(config),
      ),
      remoteModelsProvider.overrideWith((ref, query) {
        ref.watch(connectionsControllerProvider);
        return config.modelCatalog(query);
      }),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.build(Brightness.light, AppAccent.blue),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: config.surfaceSize,
            textScaler: TextScaler.linear(config.textScale),
          ),
          child: child!,
        ),
        home: child,
      ),
    ),
  );
  await tester.pump();
  return container;
}

Future<ProviderContainer> openOnboardingStep(
  WidgetTester tester,
  int step, {
  OnboardingTestConfig config = const OnboardingTestConfig(),
}) async {
  final container = await pumpOnboardingTestApp(
    tester,
    config: config,
    child: const OnboardingScreen(),
  );
  for (var index = 0; index < step; index++) {
    await tapOnboardingText(tester, container.read(stringsProvider).obNext);
  }
  return container;
}

Future<void> tapOnboardingText(
  WidgetTester tester,
  String text, {
  Finder? within,
}) async {
  final target = within == null
      ? find.text(text)
      : find.descendant(of: within, matching: find.text(text));
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  if (text == AppStrings.of(AppLanguage.de).obNext) {
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump();
  } else {
    await tester.pumpAndSettle();
  }
}

Future<void> backOnboardingStep(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
