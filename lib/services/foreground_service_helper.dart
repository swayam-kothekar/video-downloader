import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyTaskHandler());
}

class MyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Just start the foreground task to keep the main isolate alive
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // No periodic background processing needed
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Cleanup if needed
  }
}

class ForegroundServiceHelper {
  static bool _initialized = false;

  static void init() {
    if (_initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'video_downloader_bg',
        channelName: 'Background Downloads',
        channelDescription: 'Keeps your video downloads running in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true, // Keep Wi-Fi active for fast speeds and no stalls
      ),
    );

    _initialized = true;
  }

  static Future<void> start(String title, String text) async {
    init();
    if (await FlutterForegroundTask.isRunningService) {
      await update(title, text);
      return;
    }

    await FlutterForegroundTask.startService(
      serviceId: 101,
      notificationTitle: title,
      notificationText: text,
      callback: startCallback,
    );
  }

  static Future<void> update(String title, String text) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    }
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
