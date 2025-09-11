import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';

import '../../screens/kot_screen/global/globals.dart';
import '../kotservices/kotwebsocketService.dart';
import '../models/globals.dart';

import 'dart:convert';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Future<void> showServerIpDialog(BuildContext context, String deviceCode) async {
//   final TextEditingController serverIpController = TextEditingController();

//   // Load stored server IP if available
//   var box = await Hive.openBox('settings');
//   serverIpController.text = box.get('serverip', defaultValue: serverip);

//   bool isDialogOpen = true;

//   // ignore: use_build_context_synchronously
//   await showDialog(
//     context: context,
//     barrierDismissible: false,
//     builder: (BuildContext dialogContext) {
//       return AlertDialog(
//         title: const Text('Enter Server IP Address'),
//         content: TextField(
//           controller: serverIpController,
//           keyboardType: TextInputType.number,
//           decoration: const InputDecoration(
//             labelText: 'Server IP',
//             hintText: 'e.g., 192.168.1.1',
//             border: OutlineInputBorder(),
//           ),
//         ),
//         actions: <Widget>[
//           TextButton(
//             child: const Text('Cancel'),
//             onPressed: () {
//               if (isDialogOpen) {
//                 Navigator.of(dialogContext).pop();
//                 isDialogOpen = false;
//               }
//             },
//           ),
//           TextButton(
//             child: const Text('Save'),
//             onPressed: () async {
//               String enteredIp = serverIpController.text.trim();

//               if (enteredIp.isEmpty || !_validateIpAddress(enteredIp)) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                       content: Text("Please enter a valid IP address.")),
//                 );
//                 return;
//               }

//               // Save server IP temporarily
//               serverip = enteredIp;
//               await box.put('serverip', serverip);

//               // Check if the server is online
//               bool isServerOnline = await _checkServerAvailability(serverip);

//               if (!isServerOnline) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                       content: Text(
//                           "Server is offline. Please check the IP and try again.")),
//                 );
//                 return;
//               }

//               // Proceed with WebSocket communication
//               try {
//                 Provider.of<WebSocketService>(context, listen: false)
//                     .sendDeviceCodeToServer(deviceCode);
//                 Provider.of<OrderProvider>(context, listen: false)
//                     .requestDataFromServer();

//                 if (isDialogOpen) {
//                   Navigator.of(dialogContext).pop();
//                   isDialogOpen = false;
//                 }

//                 // Navigate to LoginScreen only if server is online
//                 Navigator.pushAndRemoveUntil(
//                   context,
//                   MaterialPageRoute(builder: (context) => const ServerScreen()),
//                   (Route<dynamic> route) => false,
//                 );
//               } catch (e) {
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   const SnackBar(
//                       content: Text(
//                           "Failed to connect to the server. Please check the IP address.")),
//                 );
//               }
//             },
//           ),
//         ],
//       );
//     },
//   ).whenComplete(() {
//     serverIpController.dispose();
//   });
// }

/// Function to validate the IP address
bool _validateIpAddress(String ip) {
  final RegExp ipRegex = RegExp(
    r'^((25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$',
  );
  return ipRegex.hasMatch(ip);
}

/// Function to check server availability
Future<bool> _checkServerAvailability(String serverIp) async {
  try {
    final WebSocketChannel channel = IOWebSocketChannel.connect(
        'ws://$serverIp:$port'); // Replace PORT with your WebSocket server port

    channel.sink
        .add(jsonEncode({'action': 'heartbeat'})); // Send a heartbeat message
    final response = await channel.stream.first.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        channel.sink.close();
        return null;
      },
    );

    if (response != null) {
      final data = jsonDecode(response);
      if (data['action'] == 'heartbeatAck') {
        channel.sink.close();
        return true; // Server is online
      }
    }
    channel.sink.close();
    return false;
  } catch (e) {
    return false;
  }
}
