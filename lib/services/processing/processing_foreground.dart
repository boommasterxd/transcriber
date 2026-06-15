import 'package:flutter_foreground_task/flutter_foreground_task.dart';

const _serviceId = 2718;
const _channelId = 'processing';

/// Entry point for the keep-alive service isolate. Must be a top-level function
/// annotated with `vm:entry-point` so it survives tree-shaking in AOT builds.
@pragma('vm:entry-point')
void processingKeepAliveCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveHandler());
}

/// Idle task handler: the foreground service exists only to keep the app process
/// alive (and hold a wake lock) while the pipeline runs on the MAIN isolate. The
/// heavy work is deliberately NOT moved into this isolate — whisper_kit spawns
/// its own isolate and is unreliable when nested inside a background isolate.
class _KeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onReceiveData(Object data) {}
}

/// Starts/stops a bare Android foreground service so on-device processing keeps
/// running while the app is backgrounded. The service itself does no work; it
/// just prevents the OS from suspending the process (the main isolate keeps
/// executing because the process stays in foreground importance).
class ProcessingKeepAlive {
  const ProcessingKeepAlive._();

  static Future<void> start({
    required String notificationTitle,
    required String notificationText,
    required String channelName,
    required String channelDescription,
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
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.requestNotificationPermission();
    await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      notificationTitle: notificationTitle,
      notificationText: notificationText,
      callback: processingKeepAliveCallback,
    );
  }

  /// Updates the notification text to reflect the current stage.
  static Future<void> update(String notificationText) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(notificationText: notificationText);
    }
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
