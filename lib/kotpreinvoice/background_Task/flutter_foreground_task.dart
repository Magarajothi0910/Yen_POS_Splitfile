// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:hive/hive.dart';
// import 'start_callback.dart';
// import 'dart:io';
// import 'package:permission_handler/permission_handler.dart';

// class ForegroundHelper {
//   static Future<void> init() async {
//     try {
//       print("🛠️ Initializing Foreground Service...");
//       if (Platform.isAndroid && (await Permission.notification.isDenied)) {
//         final result = await Permission.notification.request();
//         print("🔔 Notification permission request result: $result");
//       }

//       FlutterForegroundTask.init(
//         androidNotificationOptions: AndroidNotificationOptions(
//           channelId: 'yenkot_foreground',
//           channelName: 'YenKOT Foreground Service',
//           channelDescription: 'Keeps the WebSocket server alive for YenKOT',
//           channelImportance: NotificationChannelImportance.HIGH,
//           priority: NotificationPriority.HIGH,
//           enableVibration: false,
//           playSound: false,
//           showWhen: true,
//           showBadge: true,
//           onlyAlertOnce: true,
//           visibility: NotificationVisibility.VISIBILITY_PUBLIC,
//         ),
//         iosNotificationOptions: const IOSNotificationOptions(
//           showNotification: true,
//           playSound: false,
//         ),
//         foregroundTaskOptions: ForegroundTaskOptions(
//           autoRunOnBoot: true,
//           allowWakeLock: true,
//           allowWifiLock: true,
//           eventAction: ForegroundTaskEventAction.repeat(15000),
//         ),
//       );
//       print("✅ Foreground Service initialized successfully.");
//     } catch (e, stack) {
//       print("❌ Error initializing Foreground Service: $e");
//       print("🐞 Stacktrace: $stack");
//     }
//   }

//   static Future<void> startIfNotRunning({
//     required String appType,
//     String? serverIp,
//     String? serverPort,
//   }) async {
//     try {
//       final isRunning = await FlutterForegroundTask.isRunningService;

//       if (isRunning) {
//         print("⚡ Foreground Service is already running.");
//         return;
//       }

//       if (appType.toLowerCase() != 'server') {
//         print("⚠️ Foreground service not started: Only server mode is supported.");
//         return;
//       }

//       String title = 'YenKOT Server Running';
//       String text = 'Tap to open YenKOT app';

//       print("🚀 Starting Foreground Service notification...");
//       await FlutterForegroundTask.startService(
//         serviceId: 1001,
//         notificationTitle: title,
//         notificationText: text,
//         callback: startCallback,
//         notificationInitialRoute: '/',
//       );
//       print("✅ Foreground Service notification started successfully.");

//       // Log to Hive for debugging
//       final configBox = await Hive.openBox('configBox');
//       await configBox.put('lastServiceStart', DateTime.now().toIso8601String());
//     } catch (e, stack) {
//       print("❌ Error starting Foreground Service: $e");
//       print("🐞 Stacktrace: $stack");
//       final configBox = await Hive.openBox('configBox');
//       await configBox.put('lastServiceError', 'Failed to start service: $e');
//     }
//   }

//   static Future<void> stop() async {
//     try {
//       if (await FlutterForegroundTask.isRunningService) {
//         print("🛑 Stopping Foreground Service...");
//         await FlutterForegroundTask.stopService();
//         print("✅ Foreground Service stopped successfully.");
//       } else {
//         print("⚡ Foreground Service is not running.");
//       }
//     } catch (e, stack) {
//       print("❌ Error stopping Foreground Service: $e");
//       print("🐞 Stacktrace: $stack");
//     }
//   }

//   static Future<void> checkServiceHealth() async {
//     try {
//       final isRunning = await FlutterForegroundTask.isRunningService;
//       if (!isRunning) {
//         print("⚠️ Foreground service not running, attempting to restart...");
//         final configBox = await Hive.openBox('configBox');
//         final appType = configBox.get('appType') ?? '';
//         if (appType == 'server') {
//           await startIfNotRunning(appType: 'server');
//           print("✅ Foreground service restarted.");
//         } else {
//           print("⚠️ Not restarting service: appType is not server.");
//         }
//       } else {
//         print("🟢 Foreground service is healthy.");
//       }
//     } catch (e) {
//       print("❌ Error checking service health: $e");
//       final configBox = await Hive.openBox('configBox');
//       await configBox.put('lastServiceError', 'Service health check failed: $e');
//     }
//   }
// }
