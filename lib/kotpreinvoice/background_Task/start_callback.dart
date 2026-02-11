// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:udp/udp.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:flutter/material.dart';
// import '../services/hive_service.dart';
// import '../services/websocket_handlers.dart';
// import '../services/serverreachable.dart';
// import 'package:yen_pos/Global/globals_data.dart';

// class ServerTaskHandler extends TaskHandler {
//   HttpServer? _wsServer;
//   UDP? _udpSender;
//   int _retryCount = 0;
//   static const int _maxRetries = 5;
//   late Box configBox;
//   late Box serverBox;

//   @override
//   Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
//     print("🟢 Initializing Hive in background...");
//     try {
//       final appDocDir = await getApplicationDocumentsDirectory();
//       await Hive.initFlutter(appDocDir.path);
//       await initHiveInBackground();
//       configBox = await Hive.openBox('configBox');
//       serverBox = await Hive.openBox('serverBox');
//       print("🟢 Hive initialized.");
//     } catch (e) {
//       print("❌ Error initializing Hive: $e");
//       await configBox.put('lastError', 'Failed to initialize Hive: $e');
//       return;
//     }

//     while (_retryCount < _maxRetries) {
//       try {
//         if (!Hive.isBoxOpen('settings')) {
//           final appDocDir = await getApplicationDocumentsDirectory();
//           Hive.init(appDocDir.path);
//         }

//         final appType = configBox.get('appType') ?? '';
//         if (appType != 'server') {
//           print("⚠️ Not in server mode, exiting task handler.");
//           return;
//         }

//         final ip = await getLocalIp();
//         if (ip == null) {
//           print("❌ Failed to get local IP, retrying...");
//           _retryCount++;
//           await Future.delayed(const Duration(seconds: 5));
//           continue;
//         }
//         serverip = ip;
//         await serverBox.put('serverIp', ip);
//         await serverBox.put('serverPort', port);

//         // Close any existing server to prevent binding conflicts
//         await _wsServer?.close(force: true);
//         _wsServer = null;

//         // Start WebSocket server with shared: true
//         _wsServer = await HttpServer.bind(
//           InternetAddress.anyIPv4,
//           8090,
//           shared: true, // Allow multiple bindings to the same address/port
//         );
//         print("🟢 WebSocket server started on $serverip:8090");
//         _wsServer!.transform(WebSocketTransformer()).listen((WebSocket socket) {
//           handleWebSocket(socket, (data) {
//             receivedData.add(data);
//             print("📥 Received data in background: $data");
//           });
//         }, onError: (e) {
//           print("❌ WebSocket server error: $e");
//         });

//         // Start UDP responder
//         await startUdpResponder();

//         _retryCount = 0; // Reset on success
//         break;
//       } catch (e) {
//         print("❌ Error starting server (attempt ${_retryCount + 1}): $e");
//         _retryCount++;
//         await Future.delayed(Duration(seconds: 5 * _retryCount)); // Exponential backoff
//       }
//     }
//     if (_retryCount >= _maxRetries) {
//       print("💥 Max retries exceeded, server failed to start");
//       await configBox.put('lastError', 'Max retries exceeded for server start');
//     }
//   }

//   Future<void> startUdpResponder() async {
//     try {
//       // Close any existing UDP socket
//       _udpSender?.close();
//       _udpSender = null;

//       _udpSender = await UDP.bind(Endpoint.any(port: const Port(44556)));
//       print("🟢 UDP responder started on port 44556");

//       // Listen for incoming UDP messages
//       _udpSender!.asStream().listen((datagram) async {
//         if (datagram != null) {
//           final message = utf8.decode(datagram.data);
//           print("📩 Received UDP message: $message");

//           if (message == 'WHO_IS_SERVER') {
//             final ip = serverip;
//             final response = 'SERVER:$ip:8090';
//             await _udpSender!.send(
//               utf8.encode(response),
//               Endpoint.broadcast(port: const Port(44556)),
//             );
//             print("📡 Broadcasted: $response");
//           }
//         }
//       }, onError: (e) {
//         print("❌ UDP listener error: $e");
//         configBox.put('lastError', 'UDP listener error: $e');
//       });
//     } catch (e) {
//       print("❌ Error starting UDP responder: $e");
//       await configBox.put('lastError', 'Failed to start UDP responder: $e');
//     }
//   }

//   @override
//   void onRepeatEvent(DateTime timestamp) async {
//     if (_wsServer == null) {
//       print("⚠️ WebSocket server down, restarting...");
//       await onStart(timestamp, TaskStarter.system);
//     } else {
//       print("🟢 WebSocket server running, checking connectivity...");
//       final ip = await getLocalIp();
//       if (ip != serverip) {
//         print("⚠️ IP changed, restarting server...");
//         await _wsServer?.close(force: true);
//         _wsServer = null;
//         _udpSender?.close();
//         _udpSender = null;
//         await onStart(timestamp, TaskStarter.system);
//       }
//     }

//     if (_udpSender == null) {
//       print("⚠️ UDP responder down, restarting...");
//       await startUdpResponder();
//     }
//   }

//   @override
//   Future<void> onDestroy(DateTime timestamp) async {
//     print("🛑 Stopping WebSocket server and UDP responder...");
//     await _wsServer?.close(force: true);
//     _wsServer = null;
//     _udpSender?.close();
//     _udpSender = null;
//     await Hive.close();
//     print("🛑 Foreground service destroyed");
//   }
// }

// // for background running
// @pragma('vm:entry-point') // 👈 must keep this
// void startCallback() {
//   WidgetsFlutterBinding.ensureInitialized();
//   FlutterForegroundTask.setTaskHandler(ServerTaskHandler());
// }
