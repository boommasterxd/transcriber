import 'dart:convert';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';
import 'package:flutter_gemma_mediapipe/flutter_gemma_mediapipe.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/transcript_note.dart';
import '../service_exceptions.dart';
import 'processing_foreground_event.dart';
import 'processing_pipeline.dart';

const _jobKey = 'processing_job';
const _serviceId = 2718;
const _channelId = 'processing';

/// Entry point for the foreground-service isolate.
@pragma('vm:entry-point')
void processingForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(_ProcessingTaskHandler());
}

final class _ProcessingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      final request = await _loadRequest();
      if (request == null) return;
      await _initializeLocalSummary(request.settings);
      final note = await runProcessingCore(
        request,
        callbacks: ProcessingCallbacks(
          onStep: _sendStep,
          onModelProgress: _sendModelProgress,
        ),
      );
      _sendDone(note);
    } catch (error) {
      _sendError(error.toString());
    }
  }

  Future<ProcessingRequest?> _loadRequest() async {
    final raw = await FlutterForegroundTask.getData<String>(key: _jobKey);
    if (raw == null) {
      _sendError('No processing job found');
      return null;
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return ProcessingRequest.fromJson(json);
  }

  Future<void> _initializeLocalSummary(AppSettings settings) async {
    if (!settings.summarizeEnabled || !settings.summaryMode.isLocal) return;
    try {
      await FlutterGemma.initialize(
        inferenceEngines: const [LiteRtLmEngine(), MediaPipeEngine()],
        huggingFaceToken: settings.hfToken.isEmpty ? null : settings.hfToken,
      );
    } catch (_) {
      // Best-effort; summarize() surfaces any real load error below.
    }
  }

  void _sendStep(ProcessingStep step) {
    FlutterForegroundTask.sendDataToMain({'type': 'step', 'step': step.name});
  }

  void _sendModelProgress(double progress) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'modelProgress',
      'value': progress,
    });
  }

  void _sendDone(TranscriptNote note) {
    FlutterForegroundTask.sendDataToMain({
      'type': 'done',
      'note': jsonEncode(note.toJson()),
    });
  }

  void _sendError(String error) {
    FlutterForegroundTask.sendDataToMain({'type': 'error', 'error': error});
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}
}

/// Runs processing inside an Android foreground-service isolate.
class ProcessingForegroundService {
  ProcessingForegroundService({
    required this.notificationTitle,
    required this.notificationText,
    required this.notificationTextSummary,
    required this.channelName,
    required this.channelDescription,
  });

  factory ProcessingForegroundService.fromStrings(AppStrings strings) =>
      ProcessingForegroundService(
        notificationTitle: strings.processingTitle,
        notificationText: strings.shTranscribe,
        notificationTextSummary: strings.shSummarize,
        channelName: strings.svcChannelName,
        channelDescription: strings.svcChannelDesc,
      );

  final String notificationTitle;
  final String notificationText;
  final String notificationTextSummary;
  final String channelName;
  final String channelDescription;

  Future<TranscriptNote> run(
    ProcessingRequest request, {
    ProcessingCallbacks callbacks = const ProcessingCallbacks(),
  }) async {
    _initializeService();
    await _saveRequest(request);
    final session = ProcessingForegroundSession(
      callbacks: callbacks,
      onSummaryStep: _updateSummaryNotification,
    );
    FlutterForegroundTask.addTaskDataCallback(session.onData);
    try {
      await _startService();
      return await session.result;
    } finally {
      FlutterForegroundTask.removeTaskDataCallback(session.onData);
      await FlutterForegroundTask.stopService();
    }
  }

  void _initializeService() {
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
  }

  Future<void> _saveRequest(ProcessingRequest request) {
    return FlutterForegroundTask.saveData(
      key: _jobKey,
      value: jsonEncode(request.toJson()),
    );
  }

  void _updateSummaryNotification() {
    FlutterForegroundTask.updateService(
      notificationText: notificationTextSummary,
    );
  }

  Future<void> _startService() async {
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
  }
}
