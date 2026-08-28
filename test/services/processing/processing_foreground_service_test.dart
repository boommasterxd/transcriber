import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/core/l10n/app_strings.dart';
import 'package:transcriber/services/processing/processing_foreground.dart';
import 'package:transcriber/services/processing/processing_request.dart';
import 'package:transcriber/services/service_exceptions.dart';

import 'processing_test_support.dart';

late _ForegroundChannelHarness _harness;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProcessingForegroundService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterForegroundTask.resetStatic();
      FlutterForegroundTask.skipServiceResponseCheck = true;
      _harness = _ForegroundChannelHarness();
      _harness.install();
    });

    tearDown(() async {
      await _harness.uninstall();
      FlutterForegroundTask.resetStatic();
    });

    _registerSuccessfulRunTest();
    _registerRunningServiceTest();
    _registerStartFailureTest();
    _registerProcessingErrorTest();
    _registerLocalizedStringsTest();
  });
}

void _registerSuccessfulRunTest() {
  test('starts an idle service, saves data, and delivers all events', () async {
    final steps = <ProcessingStep>[];
    final progress = <double>[];
    _harness.events = [
      {'type': 'step', 'step': 'transcribing'},
      {'type': 'modelProgress', 'value': 0.4},
      {'type': 'step', 'step': 'summarizing'},
      _doneEvent(),
    ];

    final note = await _service().run(
      testProcessingRequest(),
      callbacks: ProcessingCallbacks(
        onStep: steps.add,
        onModelProgress: progress.add,
      ),
    );

    expect(note.id, 'note-id');
    expect(steps, [ProcessingStep.transcribing, ProcessingStep.summarizing]);
    expect(progress, [0.4]);
    expect(_harness.calls, containsAllInOrder(_successfulCallOrder));
    expect(_harness.startArguments?['serviceId'], 2718);
    expect(_harness.startArguments?['notificationContentTitle'], 'Title');
    expect(_harness.updateArguments?['notificationContentText'], 'Summary');
    expect(FlutterForegroundTask.dataCallbacks, isEmpty);
    await _expectSavedRequest();
  });
}

const _successfulCallOrder = [
  'requestNotificationPermission',
  'startService',
  'updateService',
  'stopService',
];

void _registerRunningServiceTest() {
  test('stops a running service before starting a new one', () async {
    _harness.running = true;
    _harness.events = [_doneEvent()];

    await _service().run(testProcessingRequest());

    expect(_harness.calls.where((call) => call == 'stopService'), hasLength(2));
    expect(
      _harness.calls,
      containsAllInOrder([
        'stopService',
        'requestNotificationPermission',
        'startService',
        'stopService',
      ]),
    );
    expect(_harness.permissionRequests, 1);
  });
}

void _registerStartFailureTest() {
  test('surfaces service start failures and removes its callback', () async {
    _harness.startError = PlatformException(
      code: 'start_failed',
      message: 'native start failed',
    );

    await expectLater(
      _service().run(testProcessingRequest()),
      throwsA(
        isA<ProcessingException>().having(
          (error) => error.message,
          'message',
          contains('native start failed'),
        ),
      ),
    );

    expect(_harness.permissionRequests, 1);
    expect(_harness.calls, isNot(contains('stopService')));
    expect(FlutterForegroundTask.dataCallbacks, isEmpty);
    await _expectSavedRequest();
  });
}

void _registerProcessingErrorTest() {
  test('propagates foreground error events and stops the service', () async {
    _harness.events = [
      {'type': 'error', 'error': 'processing failed'},
    ];

    await expectLater(
      _service().run(testProcessingRequest()),
      throwsA(
        isA<ProcessingException>().having(
          (error) => error.message,
          'message',
          'processing failed',
        ),
      ),
    );

    expect(_harness.calls, contains('stopService'));
    expect(FlutterForegroundTask.dataCallbacks, isEmpty);
  });
}

void _registerLocalizedStringsTest() {
  test('builds notification copy from localized strings', () {
    final strings = AppStrings.of(AppLanguage.en);
    final service = ProcessingForegroundService.fromStrings(strings);

    expect(service.notificationTitle, strings.processingTitle);
    expect(service.notificationText, strings.shTranscribe);
    expect(service.notificationTextSummary, strings.shSummarize);
    expect(service.channelName, strings.svcChannelName);
    expect(service.channelDescription, strings.svcChannelDesc);
  });
}

ProcessingForegroundService _service() => ProcessingForegroundService(
  notificationTitle: 'Title',
  notificationText: 'Transcribing',
  notificationTextSummary: 'Summary',
  channelName: 'Channel',
  channelDescription: 'Description',
);

Map<String, Object> _doneEvent() => {
  'type': 'done',
  'note': jsonEncode(testTranscriptNote().toJson()),
};

Future<void> _expectSavedRequest() async {
  final saved = await FlutterForegroundTask.getData<String>(
    key: 'processing_job',
  );
  expect(saved, isNotNull);
  expect(
    ProcessingRequest.fromJson(jsonDecode(saved!) as Map<String, dynamic>),
    isA<ProcessingRequest>(),
  );
}

final class _ForegroundChannelHarness {
  static const _channel = MethodChannel('flutter_foreground_task/methods');

  final List<String> calls = [];
  List<Object> events = [];
  bool running = false;
  Object? startError;
  int permissionRequests = 0;
  Map<Object?, Object?>? startArguments;
  Map<Object?, Object?>? updateArguments;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _handleCall);
  }

  Future<void> uninstall() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }

  Future<Object?> _handleCall(MethodCall call) async {
    calls.add(call.method);
    switch (call.method) {
      case 'isRunningService':
        return running;
      case 'requestNotificationPermission':
        permissionRequests++;
        return NotificationPermission.granted.index;
      case 'startService':
        await _start(call);
        return null;
      case 'updateService':
        updateArguments = (call.arguments as Map).cast<Object?, Object?>();
        return null;
      case 'stopService':
        running = false;
        return null;
      default:
        throw PlatformException(code: 'unexpected', message: call.method);
    }
  }

  Future<void> _start(MethodCall call) async {
    if (startError case final error?) throw error;
    startArguments = (call.arguments as Map).cast<Object?, Object?>();
    running = true;
    unawaited(
      Future<void>(() async {
        for (final event in events) {
          for (final callback in FlutterForegroundTask.dataCallbacks.toList()) {
            callback(event);
          }
          await Future<void>.value();
        }
      }),
    );
  }
}
