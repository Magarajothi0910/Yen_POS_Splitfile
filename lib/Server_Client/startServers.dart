import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:udp/udp.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Server_Client/handlers/websocket_handler.dart';
import 'package:yen_pos/kotpreinvoice/services/serverreachable.dart';

UDP? _udp;
StreamSubscription? _udpSubscription;
Timer? _broadcastTimer;
HttpServer? _wsServer;

Future<void> startUdpResponder(String ip, int udpPort) async {
  // 🔁 Always stop before starting again
  stopUdpResponder();

  debugPrint("🟢 Starting UDP responder on $ip:$udpPort");

  _udp = await UDP.bind(Endpoint.any(port: Port(udpPort)));

  // 1. Listen for discovery requests
  _udpSubscription = _udp!.asStream().listen((datagram) {
    if (datagram == null) return;

    final message = utf8.decode(datagram.data);
    debugPrint("📩 UDP received: $message");

    if (message == 'WHO_IS_SERVER') {
      _udp!.send(
        utf8.encode('SERVER:$ip:$port'),
        Endpoint.unicast(datagram.address, port: Port(udpPort)),
      );
      debugPrint("📤 Responded to ${datagram.address.address}");
    }
  });

  // 2. Periodic broadcast
  _broadcastTimer = Timer.periodic(const Duration(seconds: 5), (_) {
    if (_udp == null) {
      debugPrint("🚫 UDP broadcast skipped (socket closed)");
      return;
    }

    if (ip.isEmpty) return;

    _udp!.send(
      utf8.encode('SERVER:$ip:$port'),
      Endpoint.broadcast(port: Port(udpPort)),
    );

    debugPrint("📡 Broadcasted: SERVER:$ip:$port");
  });
}

Future<void> stopUdpResponder() async {
  debugPrint("🔴 Stopping UDP responder...");

  _broadcastTimer?.cancel();
  _broadcastTimer = null;

  _udpSubscription?.cancel();
  _udpSubscription = null;

  _udp?.close();
  _udp = null;

  debugPrint("✅ UDP responder stopped cleanly");
}

bool isSameSubnet(String ip1, String ip2) {
  final p1 = ip1.split('.');
  final p2 = ip2.split('.');

  if (p1.length != 4 || p2.length != 4) return false;

  // Compare first 3 octets
  return p1[0] == p2[0] && p1[1] == p2[1] && p1[2] == p2[2];
}

void _showInfoDialog({
  required String title,
  required String message,
  required VoidCallback onOk,
}) {
  final context = navigatorKey.currentState?.overlay?.context;
  if (context == null) return;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title),
      content: Text(message, textAlign: TextAlign.center),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
            onOk();
          },
          child: Text("OK", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

Future<void> startServer(
  Set<WebSocketChannel> clients,
  // Function(Map<String, dynamic>, WebSocketChannel) onDataReceived,
) async {
  final ip = await getLocalIp();
  final allowed = isSameSubnet(locSubnetIp.value, ip!);
  if (_wsServer != null) {
    return;
  }
  if (allowed) {
    debugPrint('Local: ${locSubnetIp.value} | Client: $ip');

    try {
      _wsServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        // shared: true,
      );
      _wsServer!
          .transform(WebSocketTransformer())
          .listen(
            (WebSocket socket) {
              final channel = IOWebSocketChannel(socket);
              handleWebSocket(channel, clients, (data) {
                // onDataReceived(data, channel);
              });
            },
            onError: (e) async {
              final ip = await getLocalIp();
              // removeDisconnectedDevice(ip!);
            },
          );
    } catch (e) {
      debugPrint('Failed to start server: $e');
    }
  } else {
    _showInfoDialog(message: '', title: '', onOk: () {});
  }
}

// final Set<WebSocketChannel> _serverClients = {};

// Future<void> startServer() async {
//   if (_wsServer != null) {
//     debugPrint('⚠️ Server already running');
//     return;
//   }

//   final localIp = await getLocalIp();
//   if (localIp == null) return;

//   final allowed = isSameSubnet(locSubnetIp.value, localIp);
//   if (!allowed) {
//     _showInfoDialog(message: '', title: '', onOk: () {});
//     return;
//   }

//   debugPrint('🟢 Starting server on $localIp');

//   try {
//     _wsServer = await HttpServer.bind(
//       InternetAddress.anyIPv4,
//       port,
//     );

//     _wsServer!.listen((HttpRequest request) async {
//       final clientIp =
//           request.connectionInfo?.remoteAddress.address;

//       debugPrint('🔌 Incoming client: $clientIp');

//       final socket = await WebSocketTransformer.upgrade(request);
//       final channel = IOWebSocketChannel(socket);

//       // 🔴 CRITICAL LINE
//       clients.add(channel);

//       debugPrint(
//         '✅ Client registered, total=${clients.length}',
//       );

//       channel.stream.listen(
//         (data) {
//           debugPrint('📩 From client: $data');

//           // reply (this already works for you)
//           channel.sink.add(data);
//         },
//         onDone: () {
//           clients.remove(channel);
//           debugPrint('❌ Client disconnected');
//         },
//         onError: (_) {
//           clients.remove(channel);
//         },
//       );
//     });
//   } catch (e) {
//     debugPrint('❌ Failed to start server: $e');
//     _wsServer = null;
//   }
// }
