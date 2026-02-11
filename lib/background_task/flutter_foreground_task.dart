import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart' as fg;
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'start_callback.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    as ln;

class ForegroundHelper {
  static final _notifications = ln.FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;
  static bool _foregroundInitialized = false;
  static bool _serverNotificationShown = false;

  /// Initialize local notifications (once only)
  static Future<void> initNotifications() async {
    if (_notificationsInitialized) return;
    _notificationsInitialized = true;

    const android = ln.AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = ln.InitializationSettings(android: android);
    await _notifications.initialize(initSettings);
    print('✅ Local notifications initialized');
  }

  /// Show local notification
  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    try {
      const android = ln.AndroidNotificationDetails(
        'yenpos_channel',
        'YENPOS Notifications',
        channelDescription: 'General notifications for YENPOS',
        importance: ln.Importance.max,
        priority: ln.Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );
      const platform = ln.NotificationDetails(android: android);
      await _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platform,
      );
      print('🔔 Local notification shown: $title - $body');
    } catch (e, stack) {
      print('❌ Error showing notification: $e');
      print(stack);
    }
  }

  /// Initialize Foreground Task (once only)
  static Future<void> init() async {
    if (_foregroundInitialized) return;
    _foregroundInitialized = true;

    print('🟡 ForegroundHelper.init() called');
    try {
      if (Platform.isAndroid) {
        final notificationStatus = await Permission.notification.status;
        if (notificationStatus.isDenied) {
          await Permission.notification.request();
        }
      }

      fg.FlutterForegroundTask.init(
        androidNotificationOptions: fg.AndroidNotificationOptions(
          channelId: 'YENPOS_foreground',
          channelName: 'YENPOS Foreground Service',
          channelDescription: 'Keeps the WebSocket server alive for YENPOS',
          channelImportance: fg.NotificationChannelImportance.HIGH,
          priority: fg.NotificationPriority.HIGH,
          enableVibration: false,
          playSound: false,
          showWhen: true,
          showBadge: false,
          onlyAlertOnce: true,
          visibility: fg.NotificationVisibility.VISIBILITY_PUBLIC,
        ),
        iosNotificationOptions: const fg.IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: fg.ForegroundTaskOptions(
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: true,
          eventAction: fg.ForegroundTaskEventAction.repeat(15000),
        ),
      );

      print('✅ Foreground task initialized successfully');
    } catch (e, stack) {
      print('❌ Error during ForegroundHelper.init(): $e');
      print(stack);
      final box = await Hive.openBox('configBox');
      await box.put('lastInitError', e.toString());
    }
  }

  /// Start Foreground service only once
  static Future<void> startIfNotRunning({required String appType}) async {
    print('🟡 ForegroundHelper.startIfNotRunning($appType)');
    if (!Platform.isAndroid) return;

    try {
      final isRunning = await fg.FlutterForegroundTask.isRunningService;
      if (isRunning) {
        print('⚙️ Foreground service already running — skipping start');
        return;
      }

      await init();
      await initNotifications();

      const title = '🚀 YENPOS Server Running';
      const text = 'This device is acting as the server. Tap to open.';

      await fg.FlutterForegroundTask.startService(
        serviceId: 1001,
        notificationTitle: title,
        notificationText: text,
        callback: startCallback,
        notificationInitialRoute: '/',
      );

      if (appType == 'server' && !_serverNotificationShown) {
        _serverNotificationShown = true;
        await showLocalNotification(
          title: '🚀 Server Started',
          body: 'This device is now running as the YENPOS server.',
        );
      }

      print('✅ Foreground service started successfully');
    } catch (e, stack) {
      print('❌ Error starting foreground service: $e');
      print(stack);
      final box = await Hive.openBox('configBox');
      await box.put('lastServiceError', e.toString());
    }
  }

  static Future<void> stop() async {
    print('🛑 ForegroundHelper.stop() called');
    try {
      final isRunning = await fg.FlutterForegroundTask.isRunningService;
      if (isRunning) {
        await fg.FlutterForegroundTask.stopService();
        print('🛑 Foreground service stopped');
        _serverNotificationShown = false;
      }
    } catch (e, stack) {
      print('❌ Error stopping service: $e');
      print(stack);
    }
  }
}
