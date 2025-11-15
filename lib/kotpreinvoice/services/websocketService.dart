// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:provider/provider.dart';
// import 'package:yenpos/Server_Client/handlers/websocket_handler.dart';
// import 'package:yenpos/kotpreinvoice/models/globals.dart';
// import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
// import '../components/flushbar.dart';
// import '../providers/upi_provider.dart';
// import '../services/hive_service.dart';
// import '../services/websocket_handlers.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import '../screens/serverScreen.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import '../../main.dart';
// import '../models/printer.dart';
// import '../providers/login_provider.dart';
// import '../providers/order_provider.dart';
// import '../providers/order_type_provider.dart';
// import '../providers/printer_provider.dart';
// import 'sendDataToClients.dart'; // Import to access clients

// class WebSocketServiceDine with ChangeNotifier {
//   WebSocketChannel? channel;
//   HttpServer? _wsServer;
//   Timer? _heartbeatTimer;
//   Timer? _reconnectTimer;
//   bool _isConnected = false;
//   bool _isConnecting = false;
//   List<Map<String, dynamic>> _orders = [];
//   List<Map<String, dynamic>> _receivedActions = [];
//   List<Map<String, dynamic>> _receivedOrders = [];
//   Box<dynamic>? serverBox;
//   final Map<String, String> _itemPrinterIpCache = {};

//   bool get isConnected => _isConnected;
//   List<Map<String, dynamic>> get orders => _orders;
//   List<Map<String, dynamic>> get receivedActions => _receivedActions;
//   List<Map<String, dynamic>> get receivedOrders => _receivedOrders;

//   late OrderProvider orderProvider;
//   late PrinterProviderDine printerProvider;
//   late LoginProvider loginProvider;
//   late OrderTypeProviderDine orderTypeProvider;
//   late UpiProviderDine upiProvider;

//   bool _dialogShown = false;

//   WebSocketServiceDine(
//     this.orderProvider,
//     this.printerProvider,
//     this.orderTypeProvider,
//     this.loginProvider,
//     this.upiProvider,
//   ) {
//     initializeHive();
//   }

//   Future<void> initializeHive() async {
//     if (!Hive.isBoxOpen('serverBox')) {
//       serverBox = await Hive.openBox('serverBox');
//     }

//     print('Loaded serverip from Hive: $serverip');
//     print('Detected appType: $appType');

//     if (appType == 'server') {
//       // Start the WebSocket SERVER for clients to connect to
//       await startLocalWebSocketServer(); // You'll define this method below
//       print('✅ WebSocket server started for incoming client connections.');
//     } else {
//       startWebSocketClient();
//     }
//   }

//   Future<void> startLocalWebSocketServer() async {
//     if (_wsServer != null) {
//       print("⚠️ WebSocket server already running.");
//       return;
//     }

//     try {
//       _wsServer = await HttpServer.bind(
//         InternetAddress.anyIPv4,
//         port,
//         shared: true,
//       );
//       print("🖥️ WebSocket server bound to port $port");

//       _wsServer!
//           .transform(WebSocketTransformer())
//           .listen(
//             (WebSocket socket) {
//                 final channel = IOWebSocketChannel(socket); // ✅ FIXED HERE
//                 clients.add(channel);

//               print("📡 New client connected from ${socket.closeCode}");
//               handleWebSocket(channel, clients, (data) {
//                 try {
//                   receivedData.add(data);
//                   _handleMessage(jsonEncode(data));
//                   notifyListeners();
//                 } catch (e) {
//                   print("🚨 Error handling client message: $e");
//                 }
//               });
//             },
//             onError: (error) {
//               print("🚨 WebSocket server error: $error");
//             },
//           );

//       print("✅ WebSocket server started on port $port - ready for clients!");
//     } catch (e, st) {
//       print("🚨 Failed to start WebSocket server: $e\n$st");
//     }
//   }

//   void startWebSocketClient() {
//     if (_isConnecting || _isConnected) {
//       debugPrint(
//         "Already connecting or connected, skipping WebSocket initialization.",
//       );
//       return;
//     }
//     if (!Hive.isBoxOpen('ordersBox') || !Hive.isBoxOpen('tableStatus')) {
//       debugPrint('Required Hive boxes are not open.');
//       return;
//     }
//     connect();
//   }

//   Future<void> connect() async {
//     if (_isConnecting || _isConnected) {
//       print("⚠️ Already connecting or connected.");
//       return;
//     }
//     if (serverip.isEmpty) {
//       debugPrint("⚠️ Server IP not set.");
//       _isConnected = false;
//       notifyListeners();
//       return;
//     }

//     _isConnecting = true;
//     try {
//       print("📡 Connecting to ws://$serverip:$port");
//       channel = IOWebSocketChannel?.connect(
//         'ws://$serverip:$port',
//         connectTimeout: const Duration(seconds: 5),
//       );
//       _isConnected = true;
//       _isConnecting = false;
//       _hideConnectionLostDialog();
//       _startHeartbeat();
//       // print("📦 Fetching all product data...");
//       //           await Provider.of<ProductProvider>(
//       //             context,
//       //             listen: false,
//       //           ).fetchAllData(context);

//       //           print("📤 Requesting order data from server...");
//       //           await Provider.of<OrderProvider>(
//       //             context,
//       //             listen: false,
//       //           ).requestDataFromServer();
//       print("✅ Connected to WebSocket server kotpreinvoice!");
//       notifyListeners();

//       channel?.stream.listen(
//         _handleMessage,
//         onError: (error) {
//           print("🚨 WebSocket error: $error");
//           _handleDisconnect();
//         },
//         onDone: () {
//           print("⚠️ WebSocket connection closed.");
//           _handleDisconnect();
//         },
//         cancelOnError: true,
//       );
//     } catch (e, st) {
//       print("🚨 Error connecting to WebSocket: $e\n$st");
//       _isConnected = false;
//       _isConnecting = false;
//       _showConnectionLostDialog();
//       _scheduleReconnect();
//       notifyListeners();
//     }
//   }

//   void _handleDisconnect() {
//     _isConnected = false;
//     _isConnecting = false;
//     _stopHeartbeat();
//     print("⚠️ WebSocket disconnected. Attempting reconnect...");
//     _showConnectionLostDialog();
//     _scheduleReconnect();
//     notifyListeners();
//   }

//   void _startHeartbeat() {
//     _heartbeatTimer?.cancel();
//     _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
//       if (!_isConnected) {
//         print("⚠️ Heartbeat detected disconnected state.");
//         _handleDisconnect();
//         return;
//       }
//       try {
//         channel!.sink.add(jsonEncode({'action': 'heartbeat'}));
//         print("📡 Heartbeat sent.");
//       } catch (e) {
//         print("🚨 Failed to send heartbeat: $e");
//         _handleDisconnect();
//       }
//     });
//   }

//   void _stopHeartbeat() {
//     _heartbeatTimer?.cancel();
//     _heartbeatTimer = null;
//   }

//   void _scheduleReconnect() {
//     if (_reconnectTimer != null) {
//       print("⚠️ Reconnect timer already running, skipping.");
//       return;
//     }

//     int retryCount = 0;
//     const maxRetries = 5;

//     _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
//       try {
//         // Stop reconnect if already on login screen
//         final navigatorState = MyApp.navigatorKey.currentState;
//         final isOnLoginScreen =
//             navigatorState?.canPop() ==
//             false; // true if only login screen is active

//         if (!_isConnected &&
//             !_isConnecting &&
//             !isOnLoginScreen &&
//             retryCount < maxRetries) {
//           print("📡 Reconnect attempt ${retryCount + 1}/$maxRetries...");
//           await connect(); // auto-show dialog if still failing
//           retryCount++;

//           if (_isConnected) {
//             print("✅ Successfully reconnected on attempt $retryCount!");
//             _reconnectTimer?.cancel();
//             _reconnectTimer = null;
//           }
//         } else {
//           _reconnectTimer?.cancel();
//           _reconnectTimer = null;

//           if (!_isConnected && !isOnLoginScreen && navigatorState != null) {
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               try {
//                 print(
//                   "🚨 Failed to reconnect after $retryCount attempts. Navigating to LoginScreen.",
//                 );
//                 showCustomFlushbar(
//                   navigatorState.context,
//                   'Failed to reconnect to server.',
//                   type: FlushbarType.error,
//                 );

//                 // Delay navigation slightly to allow Flushbar to appear
//                 Future.delayed(const Duration(seconds: 2), () {
//                   navigatorState.pushAndRemoveUntil(
//                     MaterialPageRoute(builder: (_) => const LoginScreen()),
//                     (route) => false,
//                   );
//                 });
//               } catch (e, st) {
//                 print(
//                   "🚨 Exception while showing Flushbar or navigating: $e\n$st",
//                 );
//               }
//             });
//           }
//         }
//       } catch (e, st) {
//         print("🚨 Exception in _scheduleReconnect timer: $e\n$st");
//         _reconnectTimer?.cancel();
//         _reconnectTimer = null;
//       }
//     });
//   }

//   void reconnect() {
//     if (_isConnecting) return;
//     _stopHeartbeat();
//     channel?.sink.close();
//     _isConnected = false;
//     notifyListeners();
//     connect();
//   }

//   void sendDeviceCodeToServer(String deviceCode) {
//     if (!_isConnected) {
//       print(
//         "⚠️ Cannot send device code, WebSocket not connected. Reconnecting...",
//       );
//       reconnect();
//       return;
//     }
//     try {
//       channel?.sink.add(
//         jsonEncode({'action': 'newClientConnected', 'deviceCode': deviceCode}),
//       );
//       print("📤 Device code sent to server: $deviceCode");
//     } catch (e) {
//       print("🚨 Failed to send device code: $e");
//       _handleDisconnect();
//     }
//   }

//   void sendPrinterDetails(Printer printer) {
//     if (appType == 'server') {
//       _handleLocalPrinterUpdate(printer);
//       sendDataToClientsKOT({
//         'action': 'updatePrinterItems',
//         'printer': printer.toJson(),
//         'orderSource': orderProvider.orderSource,
//       });
//       return;
//     }
//     if (!_isConnected) {
//       debugPrint("Cannot send printer details: WebSocket not connected");
//       reconnect();
//       return;
//     }
//     try {
//       final data = {
//         'action': 'updatePrinterItems',
//         'printer': printer.toJson(),
//         'orderSource': orderProvider.orderSource,
//       };
//       channel?.sink.add(jsonEncode(data));
//       debugPrint("📤 Sent printer details: ${printer.name}");
//     } catch (e) {
//       debugPrint("Failed to send printer details: $e");
//       _handleDisconnect();
//     }
//   }

//   void sendAssignedItems(Printer printer) {
//     if (appType == 'server') {
//       _handleLocalPrinterUpdate(printer);
//       return;
//     }
//     if (!_isConnected) {
//       debugPrint("Cannot send assigned items: WebSocket not connected");
//       reconnect();
//       return;
//     }
//     try {
//       final data = {
//         'action': 'updatePrinterItems',
//         'printer': printer.toJson(),
//         'orderSource': orderProvider.orderSource,
//       };
//       channel?.sink.add(jsonEncode(data));
//       debugPrint("📤 Sent assigned items for printer: ${printer.name}");
//     } catch (e) {
//       debugPrint("Failed to send assigned items: $e");
//       _handleDisconnect();
//     }
//   }

//   void sendRemovePrinter(String printerName) {
//     if (appType == 'server') {
//       printerProvider.removePrinterByName(printerName);
//       sendDataToClientsKOT({
//         'action': 'removePrinter',
//         'printerName': printerName,
//         'orderSource': orderProvider.orderSource,
//       });
//       return;
//     }
//     if (!_isConnected) {
//       debugPrint("Cannot send remove printer request: WebSocket not connected");
//       reconnect();
//       return;
//     }
//     try {
//       final data = {
//         'action': 'removePrinter',
//         'printerName': printerName,
//         'orderSource': orderProvider.orderSource,
//       };
//       channel?.sink.add(jsonEncode(data));
//       debugPrint("📤 Sent remove printer: $printerName");
//     } catch (e) {
//       debugPrint("Failed to send remove printer request: $e");
//       _handleDisconnect();
//     }
//   }

//   void _handleLocalPrinterUpdate(Printer printer) {
//     final existingPrinterIndex = printerProvider.printers.indexWhere(
//       (p) => p.name == printer.name,
//     );
//     if (existingPrinterIndex != -1) {
//       printerProvider.updatePrinter(existingPrinterIndex, printer);
//     } else {
//       printerProvider.addPrinter(printer);
//     }
//     sendDataToClientsKOT({
//       'action': 'updatePrinterItems',
//       'printer': printer.toJson(),
//       'orderSource': orderProvider.orderSource,
//     });
//     debugPrint("✅ Handled local printer update: ${printer.name}");
//   }

//   void _handleMessage(dynamic message) {
//     try {
//       Map<String, dynamic> jsonData;
//       if (message is String && message.trim().isNotEmpty) {
//         jsonData = jsonDecode(message.replaceAll("'", '"'));
//       } else if (message is Map<String, dynamic>) {
//         jsonData = message;
//       } else {
//         debugPrint('Invalid message type: ${message.runtimeType}');
//         return;
//       }

//       if (jsonData.containsKey('table') && jsonData.containsKey('items')) {
//         if (!jsonData.containsKey('orderSource')) {
//           jsonData['orderSource'] = orderProvider.orderSource;
//         }
//         _receivedOrders.add(jsonData);
//       } else {
//         _receivedActions.add(jsonData);
//         saveActionToHive(jsonData);
//       }

//       // Handle printer-related actions
//       if (jsonData['action'] == 'printerDetails' ||
//           jsonData['action'] == 'updatePrinterItems' ||
//           jsonData['action'] == 'removePrinter') {
//         _updatePrinterDetails(jsonData);
//       }

//       // Handle seat return action
//       if (jsonData['action'] == 'seat_returned') {
//         _receivedActions.removeWhere(
//           (action) =>
//               action['action'] == 'seat_tapped' &&
//               action['tableNumber'] == jsonData['tableNumber'] &&
//               action['seat'] == jsonData['seat'],
//         );
//       }

//       // Handle seat transfer action
//       if (jsonData['action'] == 'seat_transfer') {
//         final String orderId = jsonData['seathiveOrderId'];
//         final String targetTable = jsonData['targetTable'];
//         final String targetSeat = jsonData['targetSeat'];

//         // Update the corresponding order in _receivedOrders
//         bool updated = false;
//         for (int i = 0; i < _receivedOrders.length; i++) {
//           final order = _receivedOrders[i];
//           if (order['seathiveOrderId'] == orderId || order['id'] == orderId) {
//             order['table'] = targetTable;
//             order['seat'] = targetSeat;
//             updated = true;
//             // Optionally save updated order to Hive here if needed
//             saveOrderToHive(order);
//             debugPrint(
//               '✅ Updated order $orderId to table $targetTable, seat $targetSeat',
//             );
//             break;
//           }
//         }

//         if (!updated) {
//           debugPrint('⚠️ Order $orderId not found for seat transfer');
//         }

//         // Optionally remove any conflicting seat_tapped actions for the old/current seat
//         _receivedActions.removeWhere(
//           (action) =>
//               action['action'] == 'seat_tapped' &&
//               action['tableNumber'] == jsonData['currentTable'] &&
//               action['seat'] == jsonData['currentSeat'],
//         );
//       }

//       // Handle UPI state update
//       if (jsonData['action'] == 'updateUpiState') {
//         final bool isUpiEnabled = jsonData['isUpiEnabled'] ?? false;
//         upiProvider.setUpiState(isUpiEnabled);
//         debugPrint('✅ Client updated UPI state: $isUpiEnabled');
//       }

//       notifyListeners();
//     } catch (e) {
//       debugPrint('Error decoding message: $e');
//     }
//   }

//   void _updatePrinterDetails(Map<String, dynamic> printerData) {
//     try {
//       print("🖨️ Incoming printer update payload: $printerData");

//       // 🗑️ Remove printer
//       if (printerData['action'] == 'removePrinter') {
//         final printerName = printerData['printerName'] ?? printerData['name'];
//         if (printerName != null && printerName.toString().isNotEmpty) {
//           printerProvider.removePrinterByName(printerName.toString());
//           printerProvider.notifyListeners();
//           print("🗑️ Removed printer: $printerName");
//         } else {
//           print(
//             "⚠️ removePrinter action received but no valid printer name found.",
//           );
//         }
//         return;
//       }

//       // 📦 Unwrap nested payload if present
//       final Map<String, dynamic> payload = printerData.containsKey('printer')
//           ? Map<String, dynamic>.from(printerData['printer'] as Map)
//           : printerData;

//       final String name = (payload['printerName'] ?? payload['name'] ?? '')
//           .toString();
//       final String ip = (payload['ipAddress'] ?? '').toString();
//       final String type = (payload['type'] ?? '').toString();

//       final List<String> items = (payload['items'] is List)
//           ? List<String>.from(payload['items'])
//           : const <String>[];

//       print(
//         "📦 Parsed printer data → name: $name, ip: $ip, type: $type, items: $items",
//       );

//       if (name.isEmpty || ip.isEmpty) {
//         debugPrint(
//           "⚠️ _updatePrinterDetails: missing name/ip in payload: $payload",
//         );
//         return;
//       }

//       final printer = Printer(
//         name: name,
//         ipAddress: ip,
//         type: type,
//         items: items,
//       );

//       final idx = printerProvider.printers.indexWhere(
//         (p) => p.name == printer.name,
//       );
//       if (idx != -1) {
//         printerProvider.updatePrinter(idx, printer);
//         print(
//           "🔄 Updated existing printer in provider: ${printer.name} @ ${printer.ipAddress}",
//         );
//       } else {
//         printerProvider.addPrinter(printer);
//         print("➕ Added new printer: ${printer.name} @ ${printer.ipAddress}");
//       }

//       // 🔁 Update cache
//       for (final v in items) {
//         _itemPrinterIpCache[v] = ip;
//         print("🧩 Cached item '$v' → $ip");
//       }

//       printerProvider.notifyListeners();
//       print(
//         "✅ Applied printer update successfully: ${printer.name} @ $ip (${items.length} items)",
//       );
//     } catch (e, st) {
//       debugPrint("❌ Exception in _updatePrinterDetails: $e\n$st");
//     }
//   }

//   void sendUpiState(bool isEnabled) {
//     if (appType == 'server') {
//       _handleLocalUpiUpdate(isEnabled);
//       sendDataToClientsKOT({
//         'action': 'updateUpiState',
//         'isUpiEnabled': isEnabled,
//       });
//       return;
//     }

//     if (!_isConnected) {
//       debugPrint("Cannot send UPI state: WebSocket not connected");
//       reconnect();
//       return;
//     }

//     try {
//       final data = {'action': 'updateUpiState', 'isUpiEnabled': isEnabled};
//       channel?.sink.add(jsonEncode(data));
//       debugPrint("📤 Sent UPI state: $isEnabled");
//     } catch (e) {
//       debugPrint("❌ Failed to send UPI state: $e");
//       _handleDisconnect();
//     }
//   }

//   void _handleLocalUpiUpdate(bool isEnabled) {
//     try {
//       final context = MyApp.navigatorKey.currentContext;
//       if (context != null) {
//         final upiProvider = Provider.of<UpiProviderDine>(
//           context,
//           listen: false,
//         );
//         upiProvider.setUpiState(isEnabled);
//         debugPrint('💾 Local UPI state updated on server: $isEnabled');
//       } else {
//         debugPrint(
//           "⚠️ Could not update UPI state — no active context available",
//         );
//       }
//     } catch (e) {
//       debugPrint('⚠️ Failed to update local UPI state: $e');
//     }
//   }

//   void _cachePrinterIps(Map<String, dynamic> orderData) {
//     List<String> varianceNames = List<String>.from(
//       orderData['varianceNames'] ?? [],
//     );
//     for (String varianceName in varianceNames) {
//       if (!_itemPrinterIpCache.containsKey(varianceName)) {
//         String? ip = printerProvider.getPrinterIpForItem(varianceName);
//         if (ip != null) {
//           _itemPrinterIpCache[varianceName] = ip;
//         }
//       }
//     }
//   }

//   void _showConnectionLostDialog() {
//     if (_dialogShown) return;
//     final context = MyApp.navigatorKey.currentState?.overlay?.context;
//     if (context == null || !context.mounted) return;

//     _dialogShown = true;

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (dialogContext) => AlertDialog(
//         backgroundColor: Colors.white,
//         title: const Text('Connection Lost'),
//         content: const Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.wifi_off, size: 60, color: Colors.red),
//             SizedBox(height: 20),
//             Text(
//               'Server is Offline! Please check your server device or Wifi Connection',
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(dialogContext, rootNavigator: true).pop();
//               _dialogShown = false;
//               reconnect();
//             },
//             child: const Text('Retry'),
//           ),
//         ],
//       ),
//     ).then((_) {
//       // reset when dialog is closed in any way
//       _dialogShown = false;
//     });
//   }

//   Future<bool> sendSeatTransfer({
//     required String currentTable,
//     required String currentSeat,
//     required String targetTable,
//     required String targetSeat,
//     required String seathiveOrderId,
//   }) async {
//     if (appType == 'server') {
//       _handleLocalSeatTransfer(
//         currentTable: currentTable,
//         currentSeat: currentSeat,
//         targetTable: targetTable,
//         targetSeat: targetSeat,
//         seathiveOrderId: seathiveOrderId,
//       );
//       return true;
//     }
//     if (!_isConnected) {
//       await connect();
//       if (!_isConnected) {
//         print("🚨 Cannot send seat transfer: WebSocket not connected");
//         return false;
//       }
//     }
//     try {
//       final data = {
//         'action': 'seat_transfer',
//         'currentTable': currentTable,
//         'currentSeat': currentSeat,
//         'targetTable': targetTable,
//         'targetSeat': targetSeat,
//         'seathiveOrderId': seathiveOrderId,
//         'orderSource': orderProvider.orderSource,
//       };
//       channel?.sink.add(jsonEncode(data));
//       print("📤 Sent seat transfer: $data");
//       return true;
//     } catch (e) {
//       print("🚨 Failed to send seat transfer: $e");
//       _handleDisconnect();
//       return false;
//     }
//   }

//   void _handleLocalSeatTransfer({
//     required String currentTable,
//     required String currentSeat,
//     required String targetTable,
//     required String targetSeat,
//     required String seathiveOrderId,
//   }) {
//     final data = {
//       'action': 'seat_transfer',
//       'currentTable': currentTable,
//       'currentSeat': currentSeat,
//       'targetTable': targetTable,
//       'targetSeat': targetSeat,
//       'seathiveOrderId': seathiveOrderId,
//       'orderSource': orderProvider.orderSource,
//     };
//     _handleMessage(data);
//     sendDataToClientsKOT(data);
//     debugPrint("✅ Handled local seat transfer: $data");
//     notifyListeners();
//   }

//   void _hideConnectionLostDialog() {
//     final context = MyApp.navigatorKey.currentState?.overlay?.context;
//     if (context != null && context.mounted) {
//       Navigator.of(
//         context,
//         rootNavigator: true,
//       ).popUntil((route) => route.isFirst);
//     }
//     _dialogShown = false;
//   }

//   Future<void> saveActionToHive(Map<String, dynamic> action) async {
//     try {
//       if (!Hive.isBoxOpen('actions')) {
//         await Hive.openBox('actions');
//       }
//       var actionsBox = Hive.box('actions');
//       await actionsBox.add(action);
//     } catch (e) {
//       debugPrint('Error saving action to Hive: $e');
//     }
//   }

//   void updateOrderProvider(OrderProvider newOrderProvider) {
//     orderProvider = newOrderProvider;
//     notifyListeners();
//   }

//   @override
//   void dispose() {
//     _heartbeatTimer?.cancel();
//     _reconnectTimer?.cancel();
//     channel?.sink.close();
//     super.dispose();
//   }
// }
