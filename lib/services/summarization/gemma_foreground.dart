import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../../data/catalog/gemma_catalog.dart';
import '../service_exceptions.dart';
import 'gemma_engine.dart';
import 'summarization_service.dart';
import 'summary_result.dart';

const _jobKey = 'gemma_summary_job';
const _serviceId = 2718;
const _channelId = 'gemma_summary';

/// Entry point for the foreground-service isolate. Must be a top-level function
/// annotated with `vm:entry-point` so it survives tree-shaking in AOT builds.
@pragma('vm:entry-point')
void gemmaForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_GemmaTaskHandler());
}

/// Runs a single on-device summarization inside the foreground-service isolate,
/// then sends the structured result (or an error) back to the main isolate.
///
/// The job (model id, transcript, options) is handed over via
/// [FlutterForegroundTask.saveData] before the service starts and read here.
class _GemmaTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      final raw = await FlutterForegroundTask.getData<String>(key: _jobKey);
      if (raw == null) {
        FlutterForegroundTask.sendDataToMain(
          const {'ok': false, 'error': 'No summarization job found'},
        );
        return;
      }
      final job = jsonDecode(raw) as Map<String, dynamic>;
      final hfToken = job['hfToken'] as String?;

      // flutter_gemma must be initialized in this isolate before any use
      // (this mirrors main()). The litertlm path runs via Dart FFI, so it works
      // here regardless of platform-channel availability.
      try {
        await FlutterGemma.initialize(
          huggingFaceToken: (hfToken == null || hfToken.isEmpty) ? null : hfToken,
        );
      } catch (_) {
        // Best-effort; summarize() surfaces any real load error below.
      }

      final result = await GemmaEngine.instance.summarize(
        GemmaCatalog.byId(job['modelId'] as String),
        job['transcript'] as String,
        german: job['german'] as bool? ?? true,
        fallbackTitle: job['fallbackTitle'] as String? ?? '',
        hfToken: hfToken,
        backendId: job['backendId'] as String? ?? 'auto',
      );

      FlutterForegroundTask.sendDataToMain({'ok': true, 'result': result.toMap()});
    } catch (e) {
      FlutterForegroundTask.sendDataToMain({'ok': false, 'error': e.toString()});
    }
    // The main isolate stops the service once it has received the result.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}
}

/// [SummarizationService] that runs on-device Gemma inference inside an Android
/// foreground service, so summarization keeps running while the user leaves the
/// app. A persistent notification is shown for the duration of the run.
///
/// Each call starts a fresh service isolate, loads the model there, summarizes,
/// and stops the service. Cross-isolate handoff uses
/// [FlutterForegroundTask.saveData] (job in) and [FlutterForegroundTask.sendDataToMain]
/// (result out).
class GemmaForegroundService implements SummarizationService {
  GemmaForegroundService({
    required this.modelId,
    required this.fallbackTitle,
    required this.notificationTitle,
    required this.notificationText,
    required this.channelName,
    required this.channelDescription,
    this.hfToken,
    this.backendId = 'auto',
  });

  final String modelId;
  final String fallbackTitle;
  final String notificationTitle;
  final String notificationText;
  final String channelName;
  final String channelDescription;
  final String? hfToken;
  final String backendId;

  @override
  Future<SummaryResult> summarize(String transcript, {required bool german}) async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: channelName,
        channelDescription: channelDescription,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: false,
        autoRunOnBoot: false,
        // One-shot job: don't let the OS restart it and re-summarize.
        allowAutoRestart: false,
      ),
    );

    await FlutterForegroundTask.saveData(
      key: _jobKey,
      value: jsonEncode({
        'modelId': modelId,
        'transcript': transcript,
        'german': german,
        'fallbackTitle': fallbackTitle,
        'hfToken': hfToken,
        'backendId': backendId,
      }),
    );

    final completer = Completer<SummaryResult>();
    void onData(Object data) {
      if (data is! Map) return;
      if (completer.isCompleted) return;
      if (data['ok'] == true) {
        completer.complete(
          SummaryResult.fromMap(Map<String, dynamic>.from(data['result'] as Map)),
        );
      } else {
        completer.completeError(
          SummarizationException(data['error']?.toString() ?? 'Summarization failed'),
        );
      }
    }

    FlutterForegroundTask.addTaskDataCallback(onData);
    try {
      // A stale service from a previous run would make startService fail.
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      // Needed for the foreground-service notification on Android 13+.
      await FlutterForegroundTask.requestNotificationPermission();

      final started = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: notificationTitle,
        notificationText: notificationText,
        callback: gemmaForegroundCallback,
      );
      if (started is ServiceRequestFailure) {
        throw SummarizationException(
          'Could not start background service: ${started.error}',
        );
      }
      return await completer.future;
    } finally {
      FlutterForegroundTask.removeTaskDataCallback(onData);
      await FlutterForegroundTask.stopService();
    }
  }
}
