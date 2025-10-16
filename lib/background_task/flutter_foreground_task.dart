// lib/background/foreground_helper.dart
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'start_callback.dart';

class ForegroundHelper {
  static Future<void> init() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'yenpos_foreground',
        channelName: 'YenPOS Foreground Service',
        channelDescription: 'Keeps the WebSocket/UDP server alive',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        enableVibration: false,
        playSound: false,
        showWhen: false,
        showBadge: false,
        onlyAlertOnce: true,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> startIfNotRunning() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (!isRunning) {
      await FlutterForegroundTask.startService(
        serviceId: 1001, // 👈 use this instead of AndroidNotificationOptions.id
        notificationTitle: 'YenPOS server is running',
        notificationText: 'Tap to open',
        callback: startCallback,
      );
    }
  }

  static Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}
