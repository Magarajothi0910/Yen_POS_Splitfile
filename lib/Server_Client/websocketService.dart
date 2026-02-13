// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:hive/hive.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:yen_pos/Global/globals_data.dart' as globals;
// import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
// import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
// import 'package:yen_pos/Server_Client/handlers/message_Router.dart';

// class WebSocketService with ChangeNotifier {
//   static WebSocketService? _instance;

//   final CustomerScreenProvider customerProvider;
//   final SalesInvoiceReceiptPrinter receiptPrinter;

//   WebSocketService._(this.customerProvider, this.receiptPrinter);

//   static WebSocketService get instance {
//     if (_instance == null) {
//       throw StateError('WebSocketService not initialized.');
//     }
//     return _instance!;
//   }

//   static void init(
//     CustomerScreenProvider customerProvider,
//     SalesInvoiceReceiptPrinter receiptPrinter,
//   ) {
//     _instance ??= WebSocketService._(customerProvider, receiptPrinter);
//   }

//   WebSocketChannel? channel;
//   StreamSubscription? _subscription;
//   bool _isConnected = false;
//   bool _isConnecting = false;

//   final String deviceName = globals.deviceName ?? 'POS1';
//   final String clientId = DateTime.now().millisecondsSinceEpoch.toString();

//   // ✅ CONNECT
//   void connect() {
//     if (_isConnected || _isConnecting) {
//       return;
//     }

//     _isConnecting = true;
//     final uri = 'ws://${globals.serverip}:${globals.port}';

//     try {
//       channel = IOWebSocketChannel.connect(uri);

//       _subscription = channel!.stream.listen(
//         (message) => _handleIncoming(message),
//         onError: (err) {
//           _handleDisconnect();
//         },
//         onDone: () {
//           _handleDisconnect();
//         },
//         cancelOnError: true,
//       );

//       _isConnected = true;
//       _isConnecting = false;

//       _send({
//         'action': 'newClientConnected',
//         'deviceName': deviceName,
//         'clientId': clientId,
//         'message': 'client_register',
//       });
//     } catch (e, st) {
//       _isConnected = false;
//       _isConnecting = false;
//     }
//   }

//   // ✅ DISCONNECT
//   void _handleDisconnect() {
//     _isConnected = false;
//     _isConnecting = false;
//     try {
//       _subscription?.cancel();
//       channel?.sink.close();
//     } catch (_) {}
//     _subscription = null;
//     channel = null;
//   }

//   void disconnect() {
//     _handleDisconnect();
//   }

//   Future<void> reconnect() async {
//     disconnect();
//     connect();
//   }

//   // ✅ SEND
//   void _send(Map<String, dynamic> data) {
//     if (!_isConnected || channel == null) {
//       return;
//     }
//     try {
//       final msg = jsonEncode(data);
//       channel!.sink.add(msg);
//     } catch (e) {
//     }
//   }

//   void sendMessage(Map<String, dynamic> data) => _send(data);

//   // ✅ RECEIVE
//   Future<void> _handleIncoming(dynamic message) async {
//     try {
//       final msgStr = message.toString();
//       await MessageRouter.handle(
//         msgStr,
//         customerProvider,
//         receiptPrinter,
//         this,
//       );
//     } catch (e, st) {
//     }
//   }

//   String _shorten(String s, [int limit = 200]) =>
//       s.length <= limit ? s : '${s.substring(0, limit)}...';
// }

// unified_websocket_service.dart
// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';

// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:http/http.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:provider/provider.dart';
// import 'package:yen_pos/Global/get_device_info.dart';

// // --- Your project imports (adjust paths as necessary) ---
// import 'package:yen_pos/Global/globals_data.dart' as globals;
// import 'package:yen_pos/Global/globals_data.dart';
// import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
// import 'package:yen_pos/Server_Client/handlers/message_Router.dart';
// import 'package:yen_pos/Server_Client/handlers/websocket_handler.dart';
// import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
// import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
// import 'package:yen_pos/Server_Client/handlers/message_Router.dart';
// import 'package:yen_pos/Server_Client/sendDataToClients.dart'; // sendDataToClientsKOT
// import 'package:yen_pos/Server_Client/serverreachable.dart';
// import 'package:yen_pos/kotpreinvoice/handlers/updateTopPriorityHandlers.dart';
// import 'package:yen_pos/kotpreinvoice/models/printer.dart';
// import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';
// import 'package:yen_pos/kotpreinvoice/providers/order_type_provider.dart';
// import 'package:yen_pos/kotpreinvoice/providers/printer_provider.dart';
// import 'package:yen_pos/kotpreinvoice/providers/upi_provider.dart';
// import 'package:yen_pos/kotpreinvoice/services/sendDataToClients.dart';
// import 'package:yen_pos/loginPage/provider/loginPageProvider.dart';
// import 'package:yen_pos/main.dart';

// // -----------------------------------------------------
// // Unified WebSocket Service - supports server & client
// // -----------------------------------------------------
// class WebSocketService with ChangeNotifier {
//   // SINGLETON (optional) - comment out if you prefer multiple instances
//   static WebSocketService? _instance;
//   static WebSocketService get instance {
//     if (_instance == null) {
//       throw StateError(
//         'UnifiedWebSocketService not initialized. Call init(...) first.',
//       );
//     }
//     return _instance!;
//   }

//   static void init({
//     required OrderProvider orderProvider,
//     required PrinterProviderDine printerProvider,
//     required OrderTypeProviderDine orderTypeProvider,
//     required LoginProvider loginProvider,
//     required UpiProviderDine upiProvider,
//     required CustomerScreenProvider customerProvider,
//     required SalesInvoiceReceiptPrinter receiptPrinter,
//   }) {
//     _instance ??= WebSocketService._(
//       orderProvider: orderProvider,
//       printerProvider: printerProvider,
//       orderTypeProvider: orderTypeProvider,
//       loginProvider: loginProvider,
//       upiProvider: upiProvider,
//       customerProvider: customerProvider,
//       receiptPrinter: receiptPrinter,
//     );
//   }

//   // --- Dependencies ---
//   final OrderProvider orderProvider;
//   final PrinterProviderDine printerProvider;
//   final OrderTypeProviderDine orderTypeProvider;
//   final LoginProvider loginProvider;
//   final UpiProviderDine upiProvider;
//   final CustomerScreenProvider customerProvider;
//   final SalesInvoiceReceiptPrinter receiptPrinter;

//   WebSocketService._({
//     required this.orderProvider,
//     required this.printerProvider,
//     required this.orderTypeProvider,
//     required this.loginProvider,
//     required this.upiProvider,
//     required this.customerProvider,
//     required this.receiptPrinter,
//   }) {
//     initializeHiveAndStart();
//   }

//   // --- State ---
//   WebSocketChannel? channel;
//   StreamSubscription? _subscription;
//   bool _isConnected = false;
//   bool _isConnecting = false;

//   HttpServer? _wsServer;
//   final List<WebSocketChannel> _clients =
//       []; // local connected clients (server mode)
//   final Map<String, String> _itemPrinterIpCache = {};

//   Timer? _heartbeatTimer;
//   Timer? _reconnectTimer;
//   Timer? _deviceInfoTimer;

//   bool _dialogShown = false;

//   bool get isConnected => _isConnected;
//   List<Map<String, dynamic>> _receivedActions = [];
//   List<Map<String, dynamic>> _receivedOrders = [];

//   List<Map<String, dynamic>> get receivedActions => _receivedActions;
//   List<Map<String, dynamic>> get receivedOrders => _receivedOrders;

//   // --- Initialization ---
//   Future<void> initializeHiveAndStart() async {
//     try {
//       // open serverBox if not already open (your previous code used this)
//       if (!Hive.isBoxOpen('serverBox')) {
//         await Hive.openBox('serverBox');
//       }
//       // print some debug
//       debugPrint(
//         'UnifiedWebSocketService: serverip=${globals.serverip}, appType=${globals.appType}',
//       );
//       if (globals.appType == 'server') {
//         await _startLocalWebSocketServer();
//         debugPrint(
//           'UnifiedWebSocketService: server mode - local WebSocket server started.',
//         );
//       } else {
//         // only start client logic; actual connect may be triggered later by UI
//         debugPrint('UnifiedWebSocketService: client mode - ready to connect.');
//         // optionally auto-connect:
//         // connect();
//       }
//     } catch (e, st) {
//       debugPrint('Error during initializeHiveAndStart: $e\n$st');
//     }
//   }

//   void _startDeviceInfoHeartbeat() {
//     _deviceInfoTimer?.cancel();

//     _deviceInfoTimer = Timer.periodic(const Duration(minutes: 1), (
//       timer,
//     ) async {
//       try {
//         if (!_isConnected) {
//           debugPrint("⚠️ Device info heartbeat skipped (not connected)");
//           return;
//         }
//         final localIP = await getLocalIp();
//         await collectAndSendDeviceInfo(globals.appType, localIP ?? '0.0.0.0');

//         debugPrint("📡 Device info sent successfully");
//       } catch (e) {
//         debugPrint("❌ Failed to send device info: $e");
//       }
//     });
//   }

//   void _stopDeviceInfoHeartbeat() {
//     _deviceInfoTimer?.cancel();
//     _deviceInfoTimer = null;
//   }

//   void sendMessage(Map<String, dynamic> data) => _sendClient(data);

//   // -------------------------
//   // Local WebSocket SERVER
//   // -------------------------
//   Future<void> _startLocalWebSocketServer() async {
//     if (_wsServer != null) {
//       debugPrint('WebSocket server already running.');
//       return;
//     }

//     final int port = globals.port ?? 8080;

//     try {
//       _wsServer = await HttpServer.bind(
//         InternetAddress.anyIPv4,
//         port,
//         shared: true,
//       );

//       _wsServer!
//           .transform(WebSocketTransformer())
//           .listen(
//             (WebSocket socket) {
//               final channel = IOWebSocketChannel(socket);
//               _clients.add(channel);
//               debugPrint(
//                 'New client connected (local server). total clients=${_clients.length}',
//               );

//               // optional: notify new client that server is ready
//               try {
//                 channel.sink.add(
//                   jsonEncode({
//                     'action': 'server_connected',
//                     'message': 'Welcome client',
//                     'serverTime': DateTime.now().toIso8601String(),
//                   }),
//                 );
//               } catch (_) {}

//               // setup message handling for this client
//               channel.stream.listen(
//                 (data) {
//                   try {
//                     // router in your original server handled Map or String - we reuse _handleIncomingMessage
//                     _handleIncomingMessage(data, channel: channel);
//                   } catch (e, st) {
//                     debugPrint('Error handling message from client: $e\n$st');
//                   }
//                 },
//                 onError: (err) {
//                   debugPrint('Local client error: $err');

//                 },
//                 onDone: () {
//                   debugPrint('Local client disconnected.');
//                   _clients.remove(channel);
//                 },
//                 cancelOnError: true,
//               );
//             },
//             onError: (err) async {
//               debugPrint('Local WebSocket server listen error: $err');
//               final ip = await getLocalIp();
//               // removeDisconnectedDevice(ip!);
//             },
//           );

//       debugPrint('Local WebSocket server started on port $port');
//     } catch (e, st) {
//       debugPrint('Failed to start local WebSocket server: $e\n$st');
//       _wsServer = null;
//     }
//   }

//   // Broadcast helper for server mode
//   void _broadcastToLocalClients(Map<String, dynamic> data) {
//     final msg = jsonEncode(data);
//     for (final c in List<WebSocketChannel>.from(_clients)) {
//       try {
//         c.sink.add(msg);
//       } catch (e) {
//         debugPrint('Failed to send to a local client, removing: $e');
//         try {
//           c.sink.close();
//         } catch (_) {}
//         _clients.remove(c);
//       }
//     }
//   }

//   // -------------------------
//   // WebSocket CLIENT
//   // -------------------------
//   Future<void> connect() async {
//     if (_isConnected || _isConnecting) {
//       debugPrint('connect: already connected/connecting -> skip');
//       return;
//     }

//     final serverip = globals.serverip;
//     final port = globals.port;
//     if (serverip == null || serverip.isEmpty) {
//       debugPrint('connect: serverip not set');
//       return;
//     }

//     _isConnecting = true;
//     final uri = 'ws://$serverip:$port';
//     try {
//       debugPrint('connect: connecting to $uri');
//       channel = IOWebSocketChannel.connect(
//         uri,
//         // optional connect timeout is currently not exposed by IOWebSocketChannel.connect
//       );

//       _subscription = channel!.stream.listen(
//         (message) {
//           _handleIncomingMessage(message);
//         },
//         onError: (err) {
//           debugPrint('Client WebSocket error: $err');
//           _handleDisconnect();
//         },
//         onDone: () {
//           debugPrint('Client WebSocket done');
//           _handleDisconnect();
//         },
//         cancelOnError: true,
//       );

//       _isConnected = true;
//       _isConnecting = false;

//       _startHeartbeatClient();
//       _startDeviceInfoHeartbeat();

//       // register client on server
//       _sendClient({
//         'action': 'newClientConnected',
//         'deviceName': globals.deviceName ?? 'POS',
//         'clientId': DateTime.now().millisecondsSinceEpoch.toString(),
//         'message': 'client_register',
//       });
//       debugPrint('connect: connected and registered');
//       notifyListeners();
//     } catch (e, st) {
//       debugPrint('connect error: $e\n$st');
//       _isConnected = false;
//       _isConnecting = false;
//       _showConnectionLostDialog();
//       _scheduleReconnect();
//       notifyListeners();
//     }
//   }

//   void disconnect() {
//     try {
//       _subscription?.cancel();
//       channel?.sink.close();
//     } catch (_) {}
//     _subscription = null;
//     channel = null;
//     _isConnected = false;
//     _isConnecting = false;
//     _stopHeartbeatClient();
//     _stopDeviceInfoHeartbeat();
//     notifyListeners();
//   }

//   Future<void> reconnect() async {
//     disconnect();
//     await connect();
//   }

//   void _sendClient(Map<String, dynamic> data) {
//     if (!_isConnected || channel == null) {
//       debugPrint('_sendClient: not connected');
//       return;
//     }
//     try {
//       final msg = jsonEncode(data);
//       channel!.sink.add(msg);
//     } catch (e) {
//       debugPrint('_sendClient error: $e');
//       _handleDisconnect();
//     }
//   }

//   // -------------------------
//   // Heartbeat + Reconnect (client)
//   // -------------------------
//   void _startHeartbeatClient() {
//     _heartbeatTimer?.cancel();
//     _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (t) {
//       if (!_isConnected) {
//         debugPrint('Heartbeat: disconnected state detected');
//         _handleDisconnect();
//         return;
//       }
//       try {
//         channel!.sink.add(jsonEncode({'action': 'heartbeat'}));
//       } catch (e) {
//         debugPrint('Heartbeat send failed: $e');
//         _handleDisconnect();
//       }
//     });
//   }

//   void _stopHeartbeatClient() {
//     _heartbeatTimer?.cancel();
//     _heartbeatTimer = null;
//   }

//   void _scheduleReconnect() {
//     if (_reconnectTimer != null) {
//       debugPrint('Reconnect timer already running.');
//       return;
//     }

//     int retryCount = 0;
//     const int maxRetries = 5;

//     _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
//       try {
//         final navigatorState = navigatorKey.currentState;
//         final isOnLoginScreen = navigatorState?.canPop() == false;

//         if (!_isConnected &&
//             !_isConnecting &&
//             !isOnLoginScreen &&
//             retryCount < maxRetries) {
//           debugPrint('Reconnect attempt ${retryCount + 1}/$maxRetries');
//           await connect();
//           retryCount++;
//           if (_isConnected) {
//             debugPrint('Reconnected successfully');
//             _reconnectTimer?.cancel();
//             _reconnectTimer = null;
//           }
//         } else {
//           _reconnectTimer?.cancel();
//           _reconnectTimer = null;
//           if (!_isConnected && !isOnLoginScreen && navigatorState != null) {
//             WidgetsBinding.instance.addPostFrameCallback((_) {
//               try {
//                 _showConnectionLostDialog();
//                 showDialog(
//                   context: navigatorState.context,
//                   builder: (ctx) {
//                     return AlertDialog(
//                       title: const Text('Connection Lost'),
//                       content: const Text('Failed to reconnect to server.'),
//                       actions: [
//                         TextButton(
//                           onPressed: () {
//                             Navigator.of(ctx).pop();
//                             reconnect();
//                           },
//                           child: const Text('Retry'),
//                         ),
//                       ],
//                     );
//                   },
//                 );
//               } catch (e, st) {
//                 debugPrint('Exception while showing reconnect UI: $e\n$st');
//               }
//             });
//           }
//         }
//       } catch (e, st) {
//         debugPrint('Exception in reconnect timer: $e\n$st');
//         _reconnectTimer?.cancel();
//         _reconnectTimer = null;
//       }
//     });
//   }

//   void _handleDisconnect() {
//     _isConnected = false;
//     _isConnecting = false;
//     _stopHeartbeatClient();
//     _stopDeviceInfoHeartbeat();

//     _subscription?.cancel();
//     _subscription = null;
//     channel = null;
//     debugPrint('Client disconnected, scheduling reconnect');
//     _showConnectionLostDialog();
//     _scheduleReconnect();
//     notifyListeners();
//   }

//   void sendUpiState(bool isEnabled) {
//     if (globals.appType == 'server') {
//       _handleLocalUpiUpdate(isEnabled);
//       sendDataToClients({
//         'action': 'updateUpiState',
//         'isUpiEnabled': isEnabled,
//       }, globals.clients);
//       return;
//     }

//     if (!_isConnected) {
//       reconnect();
//       return;
//     }

//     try {
//       final data = {'action': 'updateUpiState', 'isUpiEnabled': isEnabled};
//       channel?.sink.add(jsonEncode(data));
//     } catch (e) {
//       _handleDisconnect();
//     }
//   }

//   void _handleLocalUpiUpdate(bool isEnabled) {
//     try {
//       final context = navigatorKey.currentContext;
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

//   // -------------------------
//   // Incoming message handler (shared)
//   // -------------------------
//   /// [message] may be a String or Map or data from a server/client socket
//   /// if [channel] is provided (non-null) this came from a local connected client (server mode)
//   void _handleIncomingMessage(dynamic message, {WebSocketChannel? channel}) {
//     try {
//       Map<String, dynamic> jsonData;

//       if (message is String && message.trim().isNotEmpty) {
//         // some of your code used replaceAll("'", '"') - we attempt safe decode
//         final str = message.trim();
//         try {
//           jsonData = jsonDecode(str);
//         } catch (_) {
//           // try relaxed decode replacing single quotes -> double (last resort)
//           jsonData = jsonDecode(str.replaceAll("'", '"'));
//         }
//       } else if (message is Map<String, dynamic>) {
//         jsonData = message;
//       } else if (message is List || message is Map) {
//         // convert to Map if possible
//         jsonData = jsonDecode(jsonEncode(message)) as Map<String, dynamic>;
//       } else {
//         debugPrint('Invalid message type: ${message.runtimeType}');
//         return;
//       }

//       // If it's an order (table + items), add to orders list
//       if (jsonData.containsKey('table') && jsonData.containsKey('items')) {
//         if (!jsonData.containsKey('orderSource')) {
//           jsonData['orderSource'] = orderProvider.orderSource;
//         }
//         _receivedOrders.add(jsonData);
//         // If this arrived at server, optionally broadcast to other clients
//         if (globals.appType == 'server') {
//           _broadcastToLocalClients(jsonData);
//         }
//       } else {
//         _receivedActions.add(jsonData);
//         // Save action to Hive (non-blocking)
//         saveActionToHive(jsonData);
//       }

//       // Handle printer actions, UPI, seat_transfer, seat_returned, etc.
//       final action = jsonData['action'];
//       if (action == 'printerDetails' ||
//           action == 'updatePrinterItems' ||
//           action == 'removePrinter') {
//         sendPrinterDetails(jsonData as Printer);
//       }

//       if (action == 'seat_returned') {
//         _receivedActions.removeWhere(
//           (actionMap) =>
//               actionMap['action'] == 'seat_tapped' &&
//               actionMap['tableNumber'] == jsonData['tableNumber'] &&
//               actionMap['seat'] == jsonData['seat'],
//         );
//       }

//       if (action == 'seat_transfer') {
//         _handleSeatTransferAction(jsonData);
//       }

//       if (action == 'updateUpiState') {
//         final bool isUpiEnabled = jsonData['isUpiEnabled'] ?? false;
//         try {
//           upiProvider.setUpiState(isUpiEnabled);
//         } catch (e) {
//           debugPrint('Failed to update upiProvider: $e');
//         }
//       }

//       // If message should be routed to the message router (printing/receipt)
//       // Reuse your MessageRouter.handle if appropriate
//       try {
//         // MessageRouter expects a String; pass JSON string
//         MessageRouter.handle(
//           jsonEncode(jsonData),
//           customerProvider,
//           receiptPrinter,
//           this,
//         );
//       } catch (e) {
//         // Some messages may be handled elsewhere; ignore if router not suitable
//       }

//       // If this message was received by the server from one client and the server should relay to others:
//       // (we already broadcast order messages above)
//       notifyListeners();
//     } catch (e, st) {
//       debugPrint('Error decoding/handling message: $e\n$st');
//     }
//   }

//   void sendRemovePrinter(String printerName) {
//     if (globals.appType == 'server') {
//       printerProvider.removePrinterByName(printerName);
//       sendDataToClients({
//         'action': 'removePrinter',
//         'printerName': printerName,
//         'orderSource': orderProvider.orderSource,
//       }, globals.clients);
//       return;
//     }
//     if (!_isConnected) {
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
//     } catch (e) {
//       _handleDisconnect();
//     }
//   }

//   void _handleSeatTransferAction(Map<String, dynamic> jsonData) {
//     final String orderId = jsonData['seathiveOrderId']?.toString() ?? '';
//     final String targetTable = jsonData['targetTable']?.toString() ?? '';
//     final String targetSeat = jsonData['targetSeat']?.toString() ?? '';

//     var updated = false;
//     for (int i = 0; i < _receivedOrders.length; i++) {
//       final order = _receivedOrders[i];
//       if ((order['seathiveOrderId']?.toString() ?? '') == orderId ||
//           (order['id']?.toString() ?? '') == orderId) {
//         order['table'] = targetTable;
//         order['seat'] = targetSeat;
//         updated = true;
//         saveOrderToHive(order);
//         debugPrint(
//           'Updated order $orderId to table $targetTable seat $targetSeat',
//         );
//         break;
//       }
//     }
//     if (!updated) debugPrint('Order not found for seat transfer: $orderId');

//     // Remove conflicting seat_tapped actions
//     _receivedActions.removeWhere(
//       (action) =>
//           action['action'] == 'seat_tapped' &&
//           action['tableNumber'] == jsonData['currentTable'] &&
//           action['seat'] == jsonData['currentSeat'],
//     );
//   }

//   // -------------------------
//   // Printer update handling
//   // -------------------------
//   void sendPrinterDetails(Printer printer) {
//     if (globals.appType == 'server') {
//       _handleLocalPrinterUpdate(printer);
//       sendDataToClients({
//         'action': 'updatePrinterItems',
//         'printer': printer.toJson(),
//         'orderSource': orderProvider.orderSource,
//       }, globals.clients);
//       return;
//     }
//     if (!_isConnected) {
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
//     } catch (e) {
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
//     sendDataToClients({
//       'action': 'updatePrinterItems',
//       'printer': printer.toJson(),
//       'orderSource': orderProvider.orderSource,
//     }, globals.clients);
//   }

//   // -------------------------
//   // Hive helpers
//   // -------------------------
//   Future<void> saveActionToHive(Map<String, dynamic> action) async {
//     try {
//       if (!Hive.isBoxOpen('actions')) await Hive.openBox('actions');
//       final box = Hive.box('actions');
//       await box.add(action);
//     } catch (e) {
//       debugPrint('Error saving action to Hive: $e');
//     }
//   }

//   Future<void> saveOrderToHive(Map<String, dynamic> order) async {
//     try {
//       if (!Hive.isBoxOpen('ordersBox')) await Hive.openBox('ordersBox');
//       final box = Hive.box('ordersBox');
//       await box.add(order);
//     } catch (e) {
//       debugPrint('Error saving order to Hive: $e');
//     }
//   }

//   // -------------------------
//   // UI dialogs
//   // -------------------------
//   void _showConnectionLostDialog() {
//     if (_dialogShown) return;
//     final context = navigatorKey.currentState?.overlay?.context;
//     if (context == null || !context.mounted) return;
//     _dialogShown = true;

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (ctx) => AlertDialog(
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
//               Navigator.of(ctx, rootNavigator: true).pop();
//               _dialogShown = false;
//               reconnect();
//             },
//             child: const Text('Retry'),
//           ),
//         ],
//       ),
//     ).then((_) {
//       _dialogShown = false;
//     });
//   }

//   void _hideConnectionLostDialog() {
//     final context = navigatorKey.currentState?.overlay?.context;
//     if (context != null && context.mounted) {
//       Navigator.of(
//         context,
//         rootNavigator: true,
//       ).popUntil((route) => route.isFirst);
//     }
//     _dialogShown = false;
//   }

//   // -------------------------
//   // Utility - expose send methods
//   // -------------------------
//   /// Send a raw map to server (client mode) or broadcast locally (server mode)
//   void sendRaw(Map<String, dynamic> data, {bool broadcastToLocal = true}) {
//     if (globals.appType == 'server') {
//       // process locally first
//       _handleIncomingMessage(data);
//       if (broadcastToLocal) _broadcastToLocalClients(data);
//       // optionally call global helper sendDataToClientsKOT (if you use it)
//       try {
//         sendDataToClients(
//           data,
//           globals.clients,
//         ); // your global function that notifies other subsystems
//       } catch (_) {}
//       return;
//     }

//     // client mode: send to server
//     if (!_isConnected) {
//       debugPrint('sendRaw: not connected -> attempting connect');
//       connect();
//       // also attempt send later or fail silently; we attempt immediate send if connected
//     }
//     _sendClient(data);
//   }

//   /// convenience to send device code (client mode)
//   void sendDeviceCode(String deviceCode) {
//     if (globals.appType == 'server') {
//       // on server, treat as local register
//       debugPrint(
//         'sendDeviceCode called on server mode -> no-op or local handling',
//       );
//       return;
//     }
//     if (!_isConnected) {
//       reconnect();
//       return;
//     }
//     _sendClient({'action': 'newClientConnected', 'deviceCode': deviceCode});
//   }

//   /// seat transfer helper
//  Future<bool> sendSeatTransfer({
//     required String currentTable,
//     required String currentSeat,
//     required String targetTable,
//     required String targetSeat,
//     required String seathiveOrderId,
//   }) async {
//     final data = {
//       'action': 'seat_transfer',
//       'currentTable': currentTable,
//       'currentSeat': currentSeat,
//       'targetTable': targetTable,
//       'targetSeat': targetSeat,
//       'seathiveOrderId': seathiveOrderId,
//       'orderSource': orderProvider.orderSource,
//     };

//     // if (globals.appType == 'server') {
//     //   _handleIncomingMessage(data);
//     //   // if you want to notify connected clients
//     //   _broadcastToLocalClients(data);
//     //   sendataToServer(data);
//     //   return true;
//     // }
//     sendataToServer(data);

//     if (!_isConnected) {
//       await connect();
//       if (!_isConnected) {
//         debugPrint('Cannot send seat transfer: not connected');
//         return false;
//       }
//     }

//     try {
//       _sendClient(data);
//       debugPrint('Sent seat transfer: $data');
//       return true;
//     } catch (e) {
//       debugPrint('Failed to send seat transfer: $e');
//       _handleDisconnect();
//       return false;
//     }
//   }

//   // -------------------------
//   // Dispose / cleanup
//   // -------------------------
//   @override
//   void dispose() {
//     try {
//       _heartbeatTimer?.cancel();
//       _reconnectTimer?.cancel();
//       _subscription?.cancel();
//       channel?.sink.close();
//       for (final c in _clients) {
//         try {
//           c.sink.close();
//         } catch (_) {}
//       }
//       _clients.clear();
//       _wsServer?.close(force: true);
//     } catch (_) {}
//     super.dispose();
//   }

//   // -------------------------
//   // Convenience debug helpers
//   // -------------------------
//   String _shorten(String s, [int limit = 200]) =>
//       s.length <= limit ? s : '${s.substring(0, limit)}...';
// }

// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:hive/hive.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:yen_pos/Global/globals_data.dart' as globals;
// import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
// import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
// import 'package:yen_pos/Server_Client/handlers/message_Router.dart';

// class WebSocketService with ChangeNotifier {
//   static WebSocketService? _instance;

//   final CustomerScreenProvider customerProvider;
//   final SalesInvoiceReceiptPrinter receiptPrinter;

//   WebSocketService._(this.customerProvider, this.receiptPrinter);

//   static WebSocketService get instance {
//     if (_instance == null) {
//       throw StateError('WebSocketService not initialized.');
//     }
//     return _instance!;
//   }

//   static void init(
//     CustomerScreenProvider customerProvider,
//     SalesInvoiceReceiptPrinter receiptPrinter,
//   ) {
//     _instance ??= WebSocketService._(customerProvider, receiptPrinter);
//   }

//   WebSocketChannel? channel;
//   StreamSubscription? _subscription;
//   bool _isConnected = false;
//   bool _isConnecting = false;

//   final String deviceName = globals.deviceName ?? 'POS1';
//   final String clientId = DateTime.now().millisecondsSinceEpoch.toString();

//   // ✅ CONNECT
//   void connect() {
//     if (_isConnected || _isConnecting) {
//       return;
//     }

//     _isConnecting = true;
//     final uri = 'ws://${globals.serverip}:${globals.port}';

//     try {
//       channel = IOWebSocketChannel.connect(uri);

//       _subscription = channel!.stream.listen(
//         (message) => _handleIncoming(message),
//         onError: (err) {
//           _handleDisconnect();
//         },
//         onDone: () {
//           _handleDisconnect();
//         },
//         cancelOnError: true,
//       );

//       _isConnected = true;
//       _isConnecting = false;

//       _send({
//         'action': 'newClientConnected',
//         'deviceName': deviceName,
//         'clientId': clientId,
//         'message': 'client_register',
//       });
//     } catch (e, st) {
//       _isConnected = false;
//       _isConnecting = false;
//     }
//   }

//   // ✅ DISCONNECT
//   void _handleDisconnect() {
//     _isConnected = false;
//     _isConnecting = false;
//     try {
//       _subscription?.cancel();
//       channel?.sink.close();
//     } catch (_) {}
//     _subscription = null;
//     channel = null;
//   }

//   void disconnect() {
//     _handleDisconnect();
//   }

//   Future<void> reconnect() async {
//     disconnect();
//     connect();
//   }

//   // ✅ SEND
//   void _send(Map<String, dynamic> data) {
//     if (!_isConnected || channel == null) {
//       return;
//     }
//     try {
//       final msg = jsonEncode(data);
//       channel!.sink.add(msg);
//     } catch (e) {
//     }
//   }

//   void sendMessage(Map<String, dynamic> data) => _send(data);

//   // ✅ RECEIVE
//   Future<void> _handleIncoming(dynamic message) async {
//     try {
//       final msgStr = message.toString();
//       await MessageRouter.handle(
//         msgStr,
//         customerProvider,
//         receiptPrinter,
//         this,
//       );
//     } catch (e, st) {
//     }
//   }

//   String _shorten(String s, [int limit = 200]) =>
//       s.length <= limit ? s : '${s.substring(0, limit)}...';
// }

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart';
import 'package:udp/udp.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:provider/provider.dart';
import 'package:yen_pos/Global/get_device_info.dart';

// --- Your project imports (adjust paths as necessary) ---
import 'package:yen_pos/Global/globals_data.dart' as globals;
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Sale_order/Widgets/Send_data_to_server.dart';
import 'package:yen_pos/Server_Client/handlers/message_Router.dart';
import 'package:yen_pos/Server_Client/handlers/websocket_handler.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Server_Client/handlers/message_Router.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart'; // sendDataToClientsKOT
import 'package:yen_pos/Server_Client/serverreachable.dart';
import 'package:yen_pos/Server_Client/startServers.dart';
import 'package:yen_pos/Server_Client/wifi_change_manager.dart';
import 'package:yen_pos/background_task/flutter_foreground_task.dart';
import 'package:yen_pos/kotpreinvoice/models/printer.dart';
import 'package:yen_pos/kotpreinvoice/providers/order_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/order_type_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/printer_provider.dart';
import 'package:yen_pos/kotpreinvoice/providers/upi_provider.dart';
import 'package:yen_pos/kotpreinvoice/services/sendDataToClients.dart';
import 'package:yen_pos/loginPage/provider/loginPageProvider.dart';
import 'package:yen_pos/main.dart';

// -----------------------------------------------------
// Unified WebSocket Service - supports server & client
// -----------------------------------------------------
class WebSocketService with ChangeNotifier {
  // SINGLETON (optional) - comment out if you prefer multiple instances
  static WebSocketService? _instance;
  // Future<void> Function()? onDiscoverServer;
  static WebSocketService get instance {
    if (_instance == null) {
      throw StateError(
        'UnifiedWebSocketService not initialized. Call init(...) first.',
      );
    }
    return _instance!;
  }

  static void init({
    required OrderProvider orderProvider,
    required PrinterProviderDine printerProvider,
    required OrderTypeProviderDine orderTypeProvider,
    required LoginProvider loginProvider,
    required UpiProviderDine upiProvider,
    required CustomerScreenProvider customerProvider,
    required SalesInvoiceReceiptPrinter receiptPrinter,
  }) {
    _instance ??= WebSocketService._(
      orderProvider: orderProvider,
      printerProvider: printerProvider,
      orderTypeProvider: orderTypeProvider,
      loginProvider: loginProvider,
      upiProvider: upiProvider,
      customerProvider: customerProvider,
      receiptPrinter: receiptPrinter,
    );
  }

  // --- Dependencies ---
  final OrderProvider orderProvider;
  final PrinterProviderDine printerProvider;
  final OrderTypeProviderDine orderTypeProvider;
  final LoginProvider loginProvider;
  final UpiProviderDine upiProvider;
  final CustomerScreenProvider customerProvider;
  final SalesInvoiceReceiptPrinter receiptPrinter;

  WebSocketService._({
    required this.orderProvider,
    required this.printerProvider,
    required this.orderTypeProvider,
    required this.loginProvider,
    required this.upiProvider,
    required this.customerProvider,
    required this.receiptPrinter,
  }) {
    initializeHiveAndStart();
  }

  // --- State ---
  WebSocketChannel? channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _isConnecting = false;

  HttpServer? _wsServer;
  final List<WebSocketChannel> _clients =
      []; // local connected clients (server mode)
  final Map<String, String> _itemPrinterIpCache = {};

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Timer? _deviceInfoTimer;

  bool _dialogShown = false;

  bool get isConnected => _isConnected;
  List<Map<String, dynamic>> _receivedActions = [];
  List<Map<String, dynamic>> _receivedOrders = [];

  List<Map<String, dynamic>> get receivedActions => _receivedActions;
  List<Map<String, dynamic>> get receivedOrders => _receivedOrders;

  // --- Initialization ---
  Future<void> initializeHiveAndStart() async {
    try {
      // open serverBox if not already open (your previous code used this)
      if (!Hive.isBoxOpen('serverBox')) {
        await Hive.openBox('serverBox');
      }
      // print some debug
      debugPrint(
        'UnifiedWebSocketService: serverip=${globals.serverip}, appType=${globals.appType}',
      );
      if (globals.appType == 'server') {
        await _startLocalWebSocketServer();
        debugPrint(
          'UnifiedWebSocketService: server mode - local WebSocket server started.',
        );
      } else {
        // only start client logic; actual connect may be triggered later by UI
        debugPrint('UnifiedWebSocketService: client mode - ready to connect.');
        // optionally auto-connect:
        // connect();
      }
    } catch (e, st) {
      debugPrint('Error during initializeHiveAndStart: $e\n$st');
    }
  }

  void _startDeviceInfoHeartbeat() {
    _deviceInfoTimer?.cancel();

    _deviceInfoTimer = Timer.periodic(const Duration(minutes: 1), (
      timer,
    ) async {
      try {
        if (!_isConnected) {
          debugPrint("⚠️ Device info heartbeat skipped (not connected)");
          return;
        }
        final localIP = await getLocalIp();
        await collectAndSendDeviceInfo(globals.appType, localIP ?? '0.0.0.0');

        debugPrint("📡 Device info sent successfully");
      } catch (e) {
        debugPrint("❌ Failed to send device info: $e");
      }
    });
  }

  void _stopDeviceInfoHeartbeat() {
    _deviceInfoTimer?.cancel();
    _deviceInfoTimer = null;
  }

  void sendMessage(Map<String, dynamic> data) => _sendClient(data);

  // -------------------------
  // Local WebSocket SERVER
  // -------------------------
  Future<void> _startLocalWebSocketServer() async {
    if (_wsServer != null) {
      debugPrint('WebSocket server already running.');
      return;
    }

    final int port = globals.port ?? 8080;

    try {
      _wsServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );

      _wsServer!
          .transform(WebSocketTransformer())
          .listen(
            (WebSocket socket) {
              final channel = IOWebSocketChannel(socket);
              _clients.add(channel);
              debugPrint(
                'New client connected (local server). total clients=${_clients.length}',
              );

              // optional: notify new client that server is ready
              try {
                channel.sink.add(
                  jsonEncode({
                    'action': 'server_connected',
                    'message': 'Welcome client',
                    'serverTime': DateTime.now().toIso8601String(),
                  }),
                );
              } catch (_) {}

              // setup message handling for this client
              channel.stream.listen(
                (data) {
                  try {
                    // router in your original server handled Map or String - we reuse _handleIncomingMessage
                    _handleIncomingMessage(data, channel: channel);
                  } catch (e, st) {
                    debugPrint('Error handling message from client: $e\n$st');
                  }
                },
                onError: (err) {
                  debugPrint('Local client error: $err');
                },
                onDone: () {
                  debugPrint('Local client disconnected.');
                  _clients.remove(channel);
                },
                cancelOnError: true,
              );
            },
            onError: (err) async {
              debugPrint('Local WebSocket server listen error: $err');
              final ip = await getLocalIp();
              // removeDisconnectedDevice(ip!);
            },
          );

      debugPrint('Local WebSocket server started on port $port');
    } catch (e, st) {
      debugPrint('Failed to start local WebSocket server: $e\n$st');
      _wsServer = null;
    }
  }

  // Broadcast helper for server mode
  void _broadcastToLocalClients(Map<String, dynamic> data) {
    final msg = jsonEncode(data);
    for (final c in List<WebSocketChannel>.from(_clients)) {
      try {
        c.sink.add(msg);
      } catch (e) {
        debugPrint('Failed to send to a local client, removing: $e');
        try {
          c.sink.close();
        } catch (_) {}
        _clients.remove(c);
      }
    }
  }

  Future<void> clearConnectedDevices() async {
    try {
      final connectedBox = Hive.isBoxOpen('connectedDevices')
          ? Hive.box('connectedDevices')
          : await Hive.openBox('connectedDevices');

      await connectedBox.clear();
      debugPrint("🧹 connectedDevices box cleared (server mode)");
    } catch (e, stack) {
      debugPrint("⚠️ Failed to clear connectedDevices box: $e");
      debugPrint("🧵 StackTrace:\n$stack");
    }
  }

  // Future<void> _checkAndPromoteToServerIfPriority1() async {
  //   try {
  //     final serverDataBox = Hive.box('serverData');
  //     final myPriority = serverDataBox.get('myPriority', defaultValue: 999);
  //     final myIp = (await getLocalIp()) ?? '';

  //     // Also check if server is really unreachable
  //     final oldServerIp = serverip;
  //     final isOldServerAlive = await isServerReachable(oldServerIp, port);

  //     if (isOldServerAlive) {
  //       print("→ Old server $oldServerIp still reachable → no promotion");
  //       return;
  //     }

  //     if (myPriority != 1) {
  //       print("My priority is $myPriority → I should act as CLIENT");

  //       // Get priority-1 IP from Hive
  //       final serverDataBox = Hive.box('serverData');
  //       final List devices = serverDataBox.get(
  //         'allConnectedDevices',
  //         defaultValue: [],
  //       );

  //       String priorityOneIp = '';

  //       for (final d in devices) {
  //         if (d['priority'] == 1) {
  //           priorityOneIp = d['clientIp'] ?? '';
  //           break;
  //         }
  //       }

  //       if (priorityOneIp.isEmpty) {
  //         print("⚠️ Priority-1 IP not found → cannot connect");
  //         return;
  //       }

  //       // If already connected to the same server, do nothing
  //       if (serverip == priorityOneIp && _isConnected) {
  //         print("✅ Already connected to priority-1 server: $priorityOneIp");
  //         return;
  //       }

  //       print("🔁 Connecting to priority-1 server at $priorityOneIp");

  //       serverip = priorityOneIp;

  //       // Stop any previous reconnect attempts
  //       _reconnectTimer?.cancel();
  //       _reconnectTimer = null;

  //       // Ensure we are NOT server
  //       appTypeNotifier.value = APP_CLIENT;
  //       await Hive.box('configBox').put('appType', APP_CLIENT);

  //       // Connect as client
  //       await connect();

  //       return;
  //     }

  //     print(
  //       "🚀 I am priority #1 and server is unreachable → PROMOTING MYSELF TO SERVER",
  //     );

  //     // Critical: stop trying to connect as client
  //     _reconnectTimer?.cancel();
  //     _reconnectTimer = null;
  //     channel?.sink.close();
  //     channel = null;

  //     // Update app type
  //     appTypeNotifier.value = APP_SERVER;
  //     serverip = myIp;

  //     final serverBox = Hive.box('serverBox');
  //     await serverBox.put('serverIp', myIp);
  //     await Hive.box('configBox').put('appType', APP_SERVER);

  //     // Clear client-related state
  //     _isConnected = false;
  //     _isConnecting = false;
  //     _hideConnectionLostDialog();

  //     // Start acting as server
  //     await clearConnectedDevices(); // if you have this
  //     await _startLocalWebSocketServer();
  //     final ip = await getLocalIp();
  //     if (ip == null) {
  //       throw Exception("No network connection found");
  //     }

  //     // 2️⃣ Save config
  //     // final serverBox = Hive.box('serverBox');
  //     final configBox = Hive.box('configBox');

  //     await Future.wait([
  //       serverBox.put('serverIp', ip),
  //       serverBox.put('port', port.toString()),
  //       configBox.put('appType', 'server'),
  //     ]);

  //     serverip = ip;
  //     appTypeNotifier.value = APP_SERVER;
  //     // serverFound = true;
  //     // serverFoundNotifier.value = true;

  //     // 3️⃣ Start services
  //     await Future.wait([
  //       ForegroundHelper.startIfNotRunning(appType: 'server'),
  //       startUdpResponder(serverip, udpPort),
  //       startServer(),

  //       collectAndSendDeviceInfo('server', ip),
  //     ]);
  //     // await startServer(clients);
  //     // await startUdpResponder(serverip, udpPort); // if needed
  //     // await collectAndSendDeviceInfo('server', myIp);
  //     WifiChangeManager.instance.init(
  //       mode: AppMode.server,
  //       navigatorKey: navigatorKey,
  //     );
  //     // WifiChangeManager.instance.onServerWifiChanged =
  //     //     onServerWifiChanged;

  //     // 5️⃣ Verify server
  //     final isServerAlive = await isServerReachable(serverip, port);
  //     if (!isServerAlive) {
  //       throw Exception("Server started but not reachable");
  //     }

  //     // Notify UI / providers
  //     notifyListeners();

  //     print("✅ Successfully promoted to server! New server IP = $myIp");
  //   } catch (e, st) {
  //     print("❌ Failed to promote to server: $e\n$st");
  //     // Fallback → show dialog and keep retrying as client
  //     _showConnectionLostDialog();
  //   }
  // }

  Future<void> _checkAndPromoteToServerIfPriority1() async {
    try {
      final serverDataBox = Hive.box('serverData');
      final configBox = Hive.box('configBox');
      final serverBox = Hive.box('serverBox');

      final myPriority = serverDataBox.get('myPriority', defaultValue: 999);
      final myIp = await getLocalIp();

      if (myIp == null || myIp.isEmpty) {
        debugPrint("❌ No IP found → abort promotion");
        return;
      }

      // 1️⃣ Check if old server is still alive
      final oldServerIp = serverip;
      final isOldServerAlive =
          oldServerIp.isNotEmpty && await isServerReachable(oldServerIp, port);

      if (isOldServerAlive) {
        debugPrint("✅ Old server $oldServerIp still alive → no promotion");
        return;
      }

      // 2️⃣ If I am NOT priority-1 → act as client
      if (myPriority != 1) {
        debugPrint("ℹ️ My priority=$myPriority → CLIENT mode");

        final List devices = serverDataBox.get(
          'allConnectedDevices',
          defaultValue: [],
        );

        String priorityOneIp = '';

        for (final d in devices) {
          if (d['priority'] == 1 && d['clientIp'] != null) {
            priorityOneIp = d['clientIp'];
            break;
          }
        }

        if (priorityOneIp.isEmpty) {
          debugPrint("⚠️ No priority-1 device found");
          return;
        }

        if (serverip == priorityOneIp && _isConnected) {
          debugPrint("✅ Already connected to $priorityOneIp");
          return;
        }

        // Stop server behavior if any
        _wsServer?.close(force: true);
        _wsServer = null;
        clients.clear();

        // Switch to client
        appTypeNotifier.value = APP_CLIENT;
        await configBox.put('appType', APP_CLIENT);

        serverip = priorityOneIp;

        _reconnectTimer?.cancel();
        _reconnectTimer = null;

        await connect();
        return;
      }

      // 3️⃣ I AM priority-1 → PROMOTE TO SERVER
      debugPrint("🚀 PROMOTING SELF TO SERVER");

      // 🔥 HARD RESET (THIS FIXES YOUR BUG)
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      channel?.sink.close();
      channel = null;

      _isConnected = false;
      _isConnecting = false;

      _wsServer?.close(force: true);
      _wsServer = null;

      clients.clear();

      // 4️⃣ Update role + persistence
      appTypeNotifier.value = APP_SERVER;
      serverip = myIp;

      await Future.wait([
        configBox.put('appType', APP_SERVER),
        serverBox.put('serverIp', myIp),
        serverBox.put('port', port.toString()),
      ]);

      // _hideConnectionLostDialog();
      await clearConnectedDevices();

      // 5️⃣ Start server services (ORDER MATTERS)
      await startServer(clients);
      await startUdpResponder(myIp, udpPort);
      await collectAndSendDeviceInfo('server', myIp);

      // 6️⃣ Start Wi-Fi monitoring
      WifiChangeManager.instance.init(
        mode: AppMode.server,
        navigatorKey: navigatorKey,
      );

      // 7️⃣ Verify server really works
      final alive = await isServerReachable(myIp, port);
      if (!alive) {
        throw Exception("Server started but not reachable");
      }

      notifyListeners();
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          const SnackBar(
            content: Text("You are now the server!"),
            backgroundColor: Colors.green,
          ),
        );
      }
      debugPrint("✅ SERVER PROMOTION SUCCESS → $myIp");
    } catch (e, st) {
      debugPrint("❌ Promotion failed: $e\n$st");
      _showConnectionLostDialog();
    }
  }

  Future<void> stopServer() async {
    try {
      for (final c in clients.toList()) {
        await c.sink.close();
      }

      clients.clear();

      await _wsServer?.close(force: true);
      _wsServer = null;
    } catch (_) {}
  }

  // Future<void> _checkAndPromoteToServerIfPriority1() async {
  //   try {
  //     final serverDataBox = Hive.box('serverData');
  //     final myPriority = serverDataBox.get('myPriority', defaultValue: 999);
  //     final myIp = (await getLocalIp()) ?? '';

  //     // Also check if old server is really unreachable
  //     final oldServerIp = globals.serverip;
  //     final isOldServerAlive = await isServerReachable(
  //       oldServerIp,
  //       globals.port,
  //     );

  //     if (isOldServerAlive) {
  //       debugPrint(
  //         "→ Old server $oldServerIp still reachable → no promotion needed",
  //       );
  //       return;
  //     }

  //     if (myPriority != 1) {
  //       debugPrint("My priority is $myPriority → I should remain a client");
  //       if (appTypeNotifier.value != APP_SERVER) {
  //       // await onDiscoverServer?.call();
  //       }
  //     }

  //     debugPrint(
  //       "🚀 I am priority #1 and old server is unreachable → PROMOTING MYSELF TO SERVER",
  //     );

  //     // ──────────────────────────────── CRITICAL CLEANUP ────────────────────────────────
  //     // 1. Stop all client-side reconnect attempts
  //     _reconnectTimer?.cancel();
  //     _reconnectTimer = null;

  //     // 2. Kill any existing WebSocket connection
  //     _subscription?.cancel();
  //     channel?.sink.close();
  //     channel = null;
  //     _isConnected = false;
  //     _isConnecting = false;

  //     // 3. Update global state and Hive IMMEDIATELY
  //     globals.serverip = myIp;
  //     appTypeNotifier.value = APP_SERVER;
  //     await Hive.box('serverBox').put('serverIp', myIp);
  //     await Hive.box('configBox').put('appType', 'server');

  //     // 4. Clear old client lists and connected devices
  //     globals.clients.clear();
  //     await clearConnectedDevices(); // your function that clears Hive 'connectedDevices'

  //     // 5. Start server services
  //     await _startLocalWebSocketServer(); // your local WS server method
  //     await startUdpResponder(myIp, udpPort); // your UDP responder
  //     await startServer(globals.clients); // your startServer function

  //     // 6. Force immediate UDP broadcast so clients discover me
  //     await _forceUdpBroadcast(myIp);

  //     // 7. Notify all known devices (if any) that a new server is active
  //     sendDataToClients({
  //       'action': 'server_promoted',
  //       'newServerIp': myIp,
  //       'newServerPort': globals.port,
  //     }, globals.clients);

  //     // 8. Restart WiFi manager in server mode
  //     WifiChangeManager.instance.init(
  //       mode: AppMode.server,
  //       navigatorKey: navigatorKey,
  //     );

  //     // 9. Collect and send my own device info as server
  //     await collectAndSendDeviceInfo('server', myIp);

  //     debugPrint("✅ Promotion complete! I am now server at $myIp:$port");
  //     notifyListeners();
  //     // await onDiscoverServer?.call();

  //     // Optional: show success snackbar
  //     if (navigatorKey.currentContext != null) {
  //       ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
  //         const SnackBar(
  //           content: Text("You are now the server!"),
  //           backgroundColor: Colors.green,
  //         ),
  //       );
  //     }
  //   } catch (e, stack) {
  //     debugPrint("❌ Failed to promote to server: $e");
  //     debugPrint("Stack: $stack");

  //     // Fallback: show dialog and keep trying as client
  //     if (navigatorKey.currentContext != null) {
  //       showDialog(
  //         context: navigatorKey.currentContext!,
  //         barrierDismissible: false,
  //         builder: (ctx) => AlertDialog(
  //           title: const Text("Promotion Failed"),
  //           content: Text("Could not become server: $e"),
  //           actions: [
  //             TextButton(
  //               onPressed: () {
  //                 Navigator.pop(ctx);
  //                 _scheduleReconnect(); // fall back to client mode
  //               },
  //               child: const Text("Retry as Client"),
  //             ),
  //           ],
  //         ),
  //       );
  //     }
  //   }
  // }

  Future<void> _forceUdpBroadcast(String ip) async {
    try {
      final udp = await UDP.bind(Endpoint.any(port: Port(udpPort)));
      final message = utf8.encode('SERVER:$ip:${globals.port}');

      // Send multiple times for reliability
      for (int i = 0; i < 3; i++) {
        await udp.send(message, Endpoint.broadcast(port: Port(udpPort)));
        debugPrint(
          "📡 Forced broadcast: SERVER:$ip:${globals.port} (attempt ${i + 1})",
        );
        await Future.delayed(const Duration(milliseconds: 400));
      }

      udp.close();
    } catch (e) {
      debugPrint("Forced UDP broadcast failed: $e");
    }
  }

  // -------------------------
  // WebSocket CLIENT
  // -------------------------
  Future<void> connect() async {
    if (_isConnected || _isConnecting) {
      debugPrint('connect: already connected/connecting -> skip');
      return;
    }

    final serverip = globals.serverip;
    final port = globals.port;
    if (serverip == null || serverip.isEmpty) {
      debugPrint('connect: serverip not set');
      return;
    }

    _isConnecting = true;
    final uri = 'ws://$serverip:$port';
    try {
      debugPrint('connect: connecting to $uri');
      channel = IOWebSocketChannel.connect(
        uri,
        // optional connect timeout is currently not exposed by IOWebSocketChannel.connect
      );

      _subscription = channel!.stream.listen(
        (message) {
          _handleIncomingMessage(message);
        },
        onError: (err) {
          debugPrint('Client WebSocket error: $err');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('Client WebSocket done');
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      _isConnected = true;
      _isConnecting = false;

      _startHeartbeatClient();
      _startDeviceInfoHeartbeat();

      // register client on server
      _sendClient({
        'action': 'newClientConnected',
        'deviceName': globals.deviceName ?? 'POS',
        'clientId': DateTime.now().millisecondsSinceEpoch.toString(),
        'message': 'client_register',
      });
      debugPrint('connect: connected and registered');
      final cxt = navigatorKey.currentContext!;
      final orderProv = Provider.of<OrderProvider>(cxt, listen: false);
      orderProv.initializeWebSocket();
      final data = jsonEncode({'type': 'handshake'});
      sendataToServer(jsonDecode(data));

      notifyListeners();
    } catch (e, st) {
      debugPrint('connect error: $e\n$st');
      _isConnected = false;
      _isConnecting = false;
      _showConnectionLostDialog();
      _scheduleReconnect();
      notifyListeners();
    }
  }

  void disconnect() {
    try {
      _subscription?.cancel();
      channel?.sink.close();
    } catch (_) {}
    _subscription = null;
    channel = null;
    _isConnected = false;
    _isConnecting = false;
    _stopHeartbeatClient();
    _stopDeviceInfoHeartbeat();
    notifyListeners();
  }

  Future<void> reconnect() async {
    disconnect();
    await connect();
  }

  void _sendClient(Map<String, dynamic> data) {
    if (!_isConnected || channel == null) {
      debugPrint('_sendClient: not connected');
      return;
    }
    try {
      final msg = jsonEncode(data);
      channel!.sink.add(msg);
    } catch (e) {
      debugPrint('_sendClient error: $e');
      _handleDisconnect();
    }
  }

  // -------------------------
  // Heartbeat + Reconnect (client)
  // -------------------------
  void _startHeartbeatClient() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (t) {
      if (!_isConnected) {
        debugPrint('Heartbeat: disconnected state detected');
        _handleDisconnect();
        return;
      }
      try {
        channel!.sink.add(jsonEncode({'action': 'heartbeat'}));
      } catch (e) {
        debugPrint('Heartbeat send failed: $e');
        _handleDisconnect();
      }
    });
  }

  void _stopHeartbeatClient() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) {
      debugPrint('Reconnect timer already running.');
      return;
    }

    int retryCount = 0;
    const int maxRetries = 5;

    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final navigatorState = navigatorKey.currentState;
        final isOnLoginScreen = navigatorState?.canPop() == false;

        if (!_isConnected &&
            !_isConnecting &&
            !isOnLoginScreen &&
            retryCount < maxRetries) {
          debugPrint('Reconnect attempt ${retryCount + 1}/$maxRetries');
          await connect();
          retryCount++;
          if (_isConnected) {
            debugPrint('Reconnected successfully');
            _reconnectTimer?.cancel();
            _reconnectTimer = null;
          }
        } else {
          _reconnectTimer?.cancel();
          _reconnectTimer = null;
          if (!_isConnected && !isOnLoginScreen && navigatorState != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                print("Too many failed reconnects — checking promotion again");
                _checkAndPromoteToServerIfPriority1();
                timer.cancel();
                _showConnectionLostDialog();
                showDialog(
                  context: navigatorState.context,
                  builder: (ctx) {
                    return AlertDialog(
                      title: const Text('Connection Lost'),
                      content: const Text('Failed to reconnect to server.'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            reconnect();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    );
                  },
                );
              } catch (e, st) {
                debugPrint('Exception while showing reconnect UI: $e\n$st');
              }
            });
          }
        }
      } catch (e, st) {
        debugPrint('Exception in reconnect timer: $e\n$st');
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      }
    });
  }

  void _handleDisconnect() async {
    _isConnected = false;
    _isConnecting = false;
    _stopHeartbeatClient();
    _stopDeviceInfoHeartbeat();

    _subscription?.cancel();
    _subscription = null;
    channel = null;
    debugPrint('Client disconnected, scheduling reconnect');
    await _checkAndPromoteToServerIfPriority1();

    // Only show dialog if we did NOT become server
    if (appType != APP_SERVER) {
      _showConnectionLostDialog();
    }
    // _showConnectionLostDialog();
    _scheduleReconnect();
    notifyListeners();
  }

  void sendUpiState(bool isEnabled) {
    if (globals.appType == 'server') {
      _handleLocalUpiUpdate(isEnabled);
      sendDataToClients({
        'action': 'updateUpiState',
        'isUpiEnabled': isEnabled,
      }, globals.clients);
      return;
    }

    if (!_isConnected) {
      reconnect();
      return;
    }

    try {
      final data = {'action': 'updateUpiState', 'isUpiEnabled': isEnabled};
      channel?.sink.add(jsonEncode(data));
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleLocalUpiUpdate(bool isEnabled) {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final upiProvider = Provider.of<UpiProviderDine>(
          context,
          listen: false,
        );
        upiProvider.setUpiState(isEnabled);
        debugPrint('💾 Local UPI state updated on server: $isEnabled');
      } else {
        debugPrint(
          "⚠️ Could not update UPI state — no active context available",
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to update local UPI state: $e');
    }
  }

  // -------------------------
  // Incoming message handler (shared)
  // -------------------------
  /// [message] may be a String or Map or data from a server/client socket
  /// if [channel] is provided (non-null) this came from a local connected client (server mode)
  void _handleIncomingMessage(dynamic message, {WebSocketChannel? channel}) {
    try {
      Map<String, dynamic> jsonData;

      if (message is String && message.trim().isNotEmpty) {
        // some of your code used replaceAll("'", '"') - we attempt safe decode
        final str = message.trim();
        try {
          jsonData = jsonDecode(str);
        } catch (_) {
          // try relaxed decode replacing single quotes -> double (last resort)
          jsonData = jsonDecode(str.replaceAll("'", '"'));
        }
      } else if (message is Map<String, dynamic>) {
        jsonData = message;
      } else if (message is List || message is Map) {
        // convert to Map if possible
        jsonData = jsonDecode(jsonEncode(message)) as Map<String, dynamic>;
      } else {
        debugPrint('Invalid message type: ${message.runtimeType}');
        return;
      }

      // If it's an order (table + items), add to orders list
      if (jsonData.containsKey('table') && jsonData.containsKey('items')) {
        if (!jsonData.containsKey('orderSource')) {
          jsonData['orderSource'] = orderProvider.orderSource;
        }
        _receivedOrders.add(jsonData);
        // If this arrived at server, optionally broadcast to other clients
        if (globals.appType == 'server') {
          _broadcastToLocalClients(jsonData);
        }
      } else {
        _receivedActions.add(jsonData);
        // Save action to Hive (non-blocking)
        saveActionToHive(jsonData);
      }

      // Handle printer actions, UPI, seat_transfer, seat_returned, etc.
      final action = jsonData['action'];
      if (action == 'printerDetails' ||
          action == 'updatePrinterItems' ||
          action == 'removePrinter') {
        sendPrinterDetails(jsonData as Printer);
      }

      if (action == 'seat_returned') {
        _receivedActions.removeWhere(
          (actionMap) =>
              actionMap['action'] == 'seat_tapped' &&
              actionMap['tableNumber'] == jsonData['tableNumber'] &&
              actionMap['seat'] == jsonData['seat'],
        );
      }

      if (action == 'seat_transfer') {
        _handleSeatTransferAction(jsonData);
      }

      if (action == 'updateUpiState') {
        final bool isUpiEnabled = jsonData['isUpiEnabled'] ?? false;
        try {
          upiProvider.setUpiState(isUpiEnabled);
        } catch (e) {
          debugPrint('Failed to update upiProvider: $e');
        }
      }

      // If message should be routed to the message router (printing/receipt)
      // Reuse your MessageRouter.handle if appropriate
      try {
        // MessageRouter expects a String; pass JSON string
        MessageRouter.handle(
          jsonEncode(jsonData),
          customerProvider,
          receiptPrinter,
          this,
        );
      } catch (e) {
        // Some messages may be handled elsewhere; ignore if router not suitable
      }

      // If this message was received by the server from one client and the server should relay to others:
      // (we already broadcast order messages above)
      notifyListeners();
    } catch (e, st) {
      debugPrint('Error decoding/handling message: $e\n$st');
    }
  }

  void sendRemovePrinter(String printerName) {
    if (globals.appType == 'server') {
      printerProvider.removePrinterByName(printerName);
      sendDataToClients({
        'action': 'removePrinter',
        'printerName': printerName,
        'orderSource': orderProvider.orderSource,
      }, globals.clients);
      return;
    }
    if (!_isConnected) {
      reconnect();
      return;
    }
    try {
      final data = {
        'action': 'removePrinter',
        'printerName': printerName,
        'orderSource': orderProvider.orderSource,
      };
      channel?.sink.add(jsonEncode(data));
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleSeatTransferAction(Map<String, dynamic> jsonData) {
    final String orderId = jsonData['seathiveOrderId']?.toString() ?? '';
    final String targetTable = jsonData['targetTable']?.toString() ?? '';
    final String targetSeat = jsonData['targetSeat']?.toString() ?? '';

    var updated = false;
    for (int i = 0; i < _receivedOrders.length; i++) {
      final order = _receivedOrders[i];
      if ((order['seathiveOrderId']?.toString() ?? '') == orderId ||
          (order['id']?.toString() ?? '') == orderId) {
        order['table'] = targetTable;
        order['seat'] = targetSeat;
        updated = true;
        saveOrderToHive(order);
        debugPrint(
          'Updated order $orderId to table $targetTable seat $targetSeat',
        );
        break;
      }
    }
    if (!updated) debugPrint('Order not found for seat transfer: $orderId');

    // Remove conflicting seat_tapped actions
    _receivedActions.removeWhere(
      (action) =>
          action['action'] == 'seat_tapped' &&
          action['tableNumber'] == jsonData['currentTable'] &&
          action['seat'] == jsonData['currentSeat'],
    );
  }

  // -------------------------
  // Printer update handling
  // -------------------------
  void sendPrinterDetails(Printer printer) {
    if (globals.appType == 'server') {
      _handleLocalPrinterUpdate(printer);
      sendDataToClients({
        'action': 'updatePrinterItems',
        'printer': printer.toJson(),
        'orderSource': orderProvider.orderSource,
      }, globals.clients);
      return;
    }
    if (!_isConnected) {
      reconnect();
      return;
    }
    try {
      final data = {
        'action': 'updatePrinterItems',
        'printer': printer.toJson(),
        'orderSource': orderProvider.orderSource,
      };
      channel?.sink.add(jsonEncode(data));
    } catch (e) {
      _handleDisconnect();
    }
  }

  void _handleLocalPrinterUpdate(Printer printer) {
    final existingPrinterIndex = printerProvider.printers.indexWhere(
      (p) => p.name == printer.name,
    );
    if (existingPrinterIndex != -1) {
      printerProvider.updatePrinter(existingPrinterIndex, printer);
    } else {
      printerProvider.addPrinter(printer);
    }
    sendDataToClients({
      'action': 'updatePrinterItems',
      'printer': printer.toJson(),
      'orderSource': orderProvider.orderSource,
    }, globals.clients);
  }

  // -------------------------
  // Hive helpers
  // -------------------------
  Future<void> saveActionToHive(Map<String, dynamic> action) async {
    try {
      if (!Hive.isBoxOpen('actions')) await Hive.openBox('actions');
      final box = Hive.box('actions');
      await box.add(action);
    } catch (e) {
      debugPrint('Error saving action to Hive: $e');
    }
  }

  Future<void> saveOrderToHive(Map<String, dynamic> order) async {
    try {
      if (!Hive.isBoxOpen('ordersBox')) await Hive.openBox('ordersBox');
      final box = Hive.box('ordersBox');
      await box.add(order);
    } catch (e) {
      debugPrint('Error saving order to Hive: $e');
    }
  }

  // -------------------------
  // UI dialogs
  // -------------------------
  void _showConnectionLostDialog() {
    if (_dialogShown) return;
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null || !context.mounted) return;
    _dialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Connection Lost'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 60, color: Colors.red),
            SizedBox(height: 20),
            Text(
              'Server is Offline! Please check your server device or Wifi Connection',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx, rootNavigator: true).pop();
              _dialogShown = false;
              reconnect();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    ).then((_) {
      _dialogShown = false;
    });
  }

  void _hideConnectionLostDialog() {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context != null && context.mounted) {
      Navigator.of(
        context,
        rootNavigator: true,
      ).popUntil((route) => route.isFirst);
    }
    _dialogShown = false;
  }

  // -------------------------
  // Utility - expose send methods
  // -------------------------
  /// Send a raw map to server (client mode) or broadcast locally (server mode)
  void sendRaw(Map<String, dynamic> data, {bool broadcastToLocal = true}) {
    if (globals.appType == 'server') {
      // process locally first
      _handleIncomingMessage(data);
      if (broadcastToLocal) _broadcastToLocalClients(data);
      // optionally call global helper sendDataToClientsKOT (if you use it)
      try {
        sendDataToClients(
          data,
          globals.clients,
        ); // your global function that notifies other subsystems
      } catch (_) {}
      return;
    }

    // client mode: send to server
    if (!_isConnected) {
      debugPrint('sendRaw: not connected -> attempting connect');
      connect();
      // also attempt send later or fail silently; we attempt immediate send if connected
    }
    _sendClient(data);
  }

  /// convenience to send device code (client mode)
  void sendDeviceCode(String deviceCode) {
    if (globals.appType == 'server') {
      // on server, treat as local register
      debugPrint(
        'sendDeviceCode called on server mode -> no-op or local handling',
      );
      return;
    }
    if (!_isConnected) {
      reconnect();
      return;
    }
    _sendClient({'action': 'newClientConnected', 'deviceCode': deviceCode});
  }

  /// seat transfer helper
  Future<bool> sendSeatTransfer({
    required String currentTable,
    required String currentSeat,
    required String targetTable,
    required String targetSeat,
    required String seathiveOrderId,
  }) async {
    final data = {
      'action': 'seat_transfer',
      'currentTable': currentTable,
      'currentSeat': currentSeat,
      'targetTable': targetTable,
      'targetSeat': targetSeat,
      'seathiveOrderId': seathiveOrderId,
      'orderSource': orderProvider.orderSource,
    };

    // if (globals.appType == 'server') {
    //   _handleIncomingMessage(data);
    //   // if you want to notify connected clients
    //   _broadcastToLocalClients(data);
    //   sendataToServer(data);
    //   return true;
    // }
    sendataToServer(data);

    if (!_isConnected) {
      await connect();
      if (!_isConnected) {
        debugPrint('Cannot send seat transfer: not connected');
        return false;
      }
    }

    try {
      _sendClient(data);
      debugPrint('Sent seat transfer: $data');
      return true;
    } catch (e) {
      debugPrint('Failed to send seat transfer: $e');
      _handleDisconnect();
      return false;
    }
  }

  // -------------------------
  // Dispose / cleanup
  // -------------------------
  @override
  void dispose() {
    try {
      _heartbeatTimer?.cancel();
      _reconnectTimer?.cancel();
      _subscription?.cancel();
      channel?.sink.close();
      for (final c in _clients) {
        try {
          c.sink.close();
        } catch (_) {}
      }
      _clients.clear();
      _wsServer?.close(force: true);
    } catch (_) {}
    super.dispose();
  }

  // -------------------------
  // Convenience debug helpers
  // -------------------------
  String _shorten(String s, [int limit = 200]) =>
      s.length <= limit ? s : '${s.substring(0, limit)}...';
}
