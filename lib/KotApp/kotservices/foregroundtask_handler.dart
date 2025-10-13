// import 'dart:convert';
// import 'dart:io';
// import 'dart:isolate';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:udp/udp.dart';

// class MyForegroundTaskHandler extends TaskHandler {
//   HttpServer? server;
//   UDP? udp;

//   @override
//   Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
//     print('Background service started');
//     final ip = await _getLocalIp();
//     if (ip != null) {
//       await _startUdpResponder(ip);
//       _startWebSocketServer(ip);
//     }
//   }

//   Future<String?> _getLocalIp() async {
//     for (var interface in await NetworkInterface.list()) {
//       for (var addr in interface.addresses) {
//         if (!addr.isLoopback && addr.address.startsWith('192.')) {
//           return addr.address;
//         }
//       }
//     }
//     return null;
//   }

//   void _startWebSocketServer(String ip) async {
//     server = await HttpServer.bind(InternetAddress.anyIPv4, 8383);
//     print(
//         'WebSocket Server started on ${server!.address.address}:${server!.port}');

//     server!.transform(WebSocketTransformer()).listen((WebSocket socket) {
//       socket.listen((message) {
//         print('Message from client: $message');
//         socket.add('Acknowledged: $message');
//       });
//     });
//   }

//   Future<void> _startUdpResponder(String ip) async {
//     udp = await UDP.bind(Endpoint.any(port: const Port(33441)));
//     print('Listening for UDP WHO_IS_SERVER...');

//     udp!.asStream().listen((datagram) {
//       final message = utf8.decode(datagram!.data);
//       if (message == 'WHO_IS_SERVER') {
//         final response = utf8.encode('SERVER:$ip:8383');
//         udp!.send(response,
//             Endpoint.unicast(datagram.address, port: Port(datagram.port)));
//       }
//     });
//   }

//   @override
//   Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
//     await server?.close(force: true);
//     udp?.close();
//     print('Server stopped');
//   }

//   @override
//   Future<void> onButtonPressed(String id) async {}

//   @override
//   Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {}

//   @override
//   Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
//     // Optional: add periodic logging or heartbeat
//     print("onRepeatEvent called at $timestamp");
//   }
// }
