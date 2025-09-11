// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

// import '../modelss/globals.dart';

// // class WebSocketProvider with ChangeNotifier {
// //   late WebSocketChannel _channel;
// //   Timer? _heartbeatTimer;
// //   List<Map<String, dynamic>> _receivedActions = [];

// //   List<Map<String, dynamic>> get receivedActions => _receivedActions;

// //   WebSocketProvider(String serverIp) {
// //     _startWebSocketClient(serverIp);
// //   }

// //   void _startWebSocketClient(String serverIp) {
// //     _channel = IOWebSocketChannel.connect('ws://$serverip:7070');

// //     _channel.stream.listen((message) {
// //       var jsonData = jsonDecode(message);
// //       print('Received data from server: $jsonData');
// //       _receivedActions.add(jsonData);
// //       notifyListeners();
// //     });

// //     _startHeartbeat();
// //   }

// //   void _startHeartbeat() {
// //     _heartbeatTimer = Timer.periodic(Duration(seconds: 10), (timer) {
// //       _channel.sink.add(jsonEncode({'action': 'heartbeat'}));
// //     });
// //   }

// //   void sendMessage(Map<String, dynamic> data) {
// //     _channel.sink.add(jsonEncode(data));
// //   }

// //   @override
// //   void dispose() {
// //     _heartbeatTimer?.cancel();
// //     _channel.sink.close();
// //     super.dispose();
// //   }
// // }

// class WebSocketService extends ChangeNotifier {
//   late WebSocketChannel channel;
//   Timer? _heartbeatTimer;
//   List<Map<String, dynamic>> _receivedActions = [];

//   List<Map<String, dynamic>> get receivedActions => _receivedActions;

//   WebSocketService() {
//     startWebSocketClient();
//   }

//   void startWebSocketClient() {
//     channel = IOWebSocketChannel.connect('ws://${serverip}:$port');

//     channel.stream.listen((message) {
//       var jsonData = jsonDecode(message);
//       print('Received data from server: $jsonData');

//       if (jsonData['clientId'] != clientId) {
//         _receivedActions.add(jsonData);
//         notifyListeners();
//         saveActionToHive(jsonData);
//       }
//     });

//     _startHeartbeat();
//   }

//   void _startHeartbeat() {
//     _heartbeatTimer = Timer.periodic(Duration(seconds: 10), (timer) {
//       channel.sink
//           .add(jsonEncode({'action': 'heartbeat', 'clientId': clientId}));
//     });
//   }

//   @override
//   void dispose() {
//     _heartbeatTimer?.cancel();
//     channel.sink.close();
//     super.dispose();
//   }

//   Future<void> saveActionToHive(Map<String, dynamic> action) async {
//     try {
//       var actionsBox = await Hive.openBox('actions');
//       await actionsBox.add(action);
//       print('Action saved to Hive: $action');
//     } catch (e) {
//       print('Error saving action to Hive: $e');
//     }
//   }

//   Future<void> loadActionsFromHive() async {
//     try {
//       var actionsBox = await Hive.openBox('actions');
//       List<Map<String, dynamic>> actions = [];
//       for (int i = 0; i < actionsBox.length; i++) {
//         actions.add(Map<String, dynamic>.from(actionsBox.getAt(i) as Map));
//       }
//       _receivedActions = actions;
//       notifyListeners();
//     } catch (e) {
//       print('Error loading actions from Hive: $e');
//     }
//   }
// }
