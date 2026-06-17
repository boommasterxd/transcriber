import 'dart:async';
import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/transcript_note.dart';
import '../service_exceptions.dart';
import 'processing_pipeline.dart';

const _jobKey = 'processing_job';
const _serviceId = 2718;
const _channelId = 'processing';

/// Entry point for the foreground-service isolate. Must be a top-level function
/// annotated with `vm:entry-point` so it survives tree-shaking in AOT builds.
@pragma('vm:entry-point')
void processingForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_ProcessingTaskHandler());
}

/// Runs the full pipeline (transcription + summarization) inside the
/// foreground-service isolate, so whisper_kit and flutter_gemma never run on the
/// main UI thread. Step/progress events and the assembled note (or an error) are
/// sent back to the main isolate.
class _ProcessingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      final raw = await FlutterForegroundTask.getData<String>(key: _jobKey);
      if (raw == null) {
        FlutterForegroundTask.sendDataToMain(
          const {'type': 'error', 'error': 'No processing job found'},
        );
        return;
      }
      final job = jsonDecode(raw) as Map<String, dynamic>;
      final hfToken = job['hfToken'] as String? ?? '';
      final settings = AppSettings.fromJson(
        (job['settings'] as Map).cast<String, dynamic>(),
        hfToken: hfToken,
      );
      final strings = AppStrings.of(settings.language);

      if (settings.summarizeEnabled && settings.summaryMode.isLocal) {
        try {
          await FlutterGemma.initialize(
            huggingFaceToken: hfToken.isEmpty ? null : hfToken,
          );
        } catch (_) {
          // Best-effort; summarize() surfaces any real load error below.
        }
      }

      final note = await runProcessingCore(
        audioPath: job['audioPath'] as String,
        source: NoteSource.fromId(job['source'] as String?),
        settings: settings,
        strings: strings,
        asrApiKey: job['asrApiKey'] as String? ?? '',
        summaryApiKey: job['summaryApiKey'] as String? ?? '',
        knownDurationSec: (job['knownDurationSec'] as num?)?.toInt(),
        onStep: (step) =>
            FlutterForegroundTask.sendDataToMain({'type': 'step', 'step': step.name}),
        onModelProgress: (p) =>
            FlutterForegroundTask.sendDataToMain({'type': 'modelProgress', 'value': p}),
      );

      FlutterForegroundTask.sendDataToMain(
        {'type': 'done', 'note': jsonEncode(note.toJson())},
      );
    } catch (e) {
      FlutterForegroundTask.sendDataToMain({'type': 'error', 'error': e.toString()});
    }
    // The main isolate stops the service once it has the result.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}
}

/// Runs the on-device processing pipeline inside an Android foreground service,
/// off the main UI thread and surviving the app being backgrounded. A persistent
/// notification is shown for the run.
///
/// Started while the app is in the foreground (Android 12+ forbids starting a
/// foreground service from the background). Job in via [FlutterForegroundTask.saveData];
/// progress + result back via [FlutterForegroundTask.sendDataToMain].
class ProcessingForegroundService {
  ProcessingForegroundService({
    required this.notificationTitle,
    required this.notificationText,
    required this.notificationTextSummary,
    required this.channelName,
    required this.channelDescription,
  });

  final String notificationTitle;
  final String notificationText;
  final String notificationTextSummary;
  final String channelName;
  final String channelDescription;

  Future<TranscriptNote> run({
    required String audioPath,
    required NoteSource source,
    required AppSettings settings,
    required String asrApiKey,
    required String summaryApiKey,
    int? knownDurationSec,
    void Function(ProcessingStep step)? onStep,
    void Function(double progress)? onModelProgress,
  }) async {
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
        allowAutoRestart: false,
      ),
    );

    await FlutterForegroundTask.saveData(
      key: _jobKey,
      value: jsonEncode({
        'audioPath': audioPath,
        'source': source.id,
        'settings': settings.toJson(),
        'hfToken': settings.hfToken,
        'asrApiKey': asrApiKey,
        'summaryApiKey': summaryApiKey,
        'knownDurationSec': knownDurationSec,
      }),
    );

    final completer = Completer<TranscriptNote>();
    void onData(Object data) {
      if (data is! Map) return;
      switch (data['type']) {
        case 'step':
          final name = data['step'] as String?;
          if (name != null) onStep?.call(ProcessingStep.values.byName(name));
          // Also reflect the stage in the notification.
          if (name == ProcessingStep.summarizing.name) {
            FlutterForegroundTask.updateService(notificationText: notificationTextSummary);
          }
        case 'modelProgress':
          final value = data['value'];
          if (value is num) onModelProgress?.call(value.toDouble());
        case 'done':
          if (completer.isCompleted) return;
          completer.complete(
            TranscriptNote.fromJson(
              jsonDecode(data['note'] as String) as Map<String, dynamic>,
            ),
          );
        case 'error':
          if (completer.isCompleted) return;
          completer.completeError(
            ProcessingException(data['error']?.toString() ?? 'Processing failed'),
          );
      }
    }

    FlutterForegroundTask.addTaskDataCallback(onData);
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      await FlutterForegroundTask.requestNotificationPermission();

      final started = await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        notificationTitle: notificationTitle,
        notificationText: notificationText,
        notificationIcon: const NotificationIcon(
          metaDataName: 'com.transcriber.app.notification_icon',
        ),
        callback: processingForegroundCallback,
      );
      if (started is ServiceRequestFailure) {
        throw ProcessingException(
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
