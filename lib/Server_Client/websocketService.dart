// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/foundation.dart';
// import 'package:hive/hive.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:yenpos/Global/globals_data.dart' as globals;
// import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
// import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
// import 'package:yenpos/Server_Client/handlers/message_Router.dart';


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
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:provider/provider.dart';

// --- Your project imports (adjust paths as necessary) ---
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Server_Client/handlers/message_Router.dart';
import 'package:yenpos/Server_Client/handlers/websocket_handler.dart';
import 'package:yenpos/kotpreinvoice/models/globals.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yenpos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yenpos/Server_Client/handlers/message_Router.dart';
import 'package:yenpos/kotpreinvoice/models/globals.dart' as kotGlobals;
import 'package:yenpos/Server_Client/sendDataToClients.dart'; // sendDataToClientsKOT
import 'package:yenpos/kotpreinvoice/models/printer.dart' show Printer;
import 'package:yenpos/kotpreinvoice/providers/order_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/order_type_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/printer_provider.dart';
import 'package:yenpos/kotpreinvoice/providers/upi_provider.dart';
import 'package:yenpos/kotpreinvoice/services/sendDataToClients.dart';
import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
import 'package:yenpos/main.dart';

// -----------------------------------------------------
// Unified WebSocket Service - supports server & client
// -----------------------------------------------------
class WebSocketService with ChangeNotifier {
  // SINGLETON (optional) - comment out if you prefer multiple instances
  static WebSocketService? _instance;
  static WebSocketService get instance {
    if (_instance == null) {
      throw StateError('UnifiedWebSocketService not initialized. Call init(...) first.');
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
  final List<WebSocketChannel> _clients = []; // local connected clients (server mode)
  final Map<String, String> _itemPrinterIpCache = {};

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
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
      debugPrint('UnifiedWebSocketService: serverip=${globals.serverip}, appType=${globals.appType}');
      if (globals.appType == 'server') {
        await _startLocalWebSocketServer();
        debugPrint('UnifiedWebSocketService: server mode - local WebSocket server started.');
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
          .listen((WebSocket socket) {
        final channel = IOWebSocketChannel(socket);
        _clients.add(channel);
        debugPrint('New client connected (local server). total clients=${_clients.length}');

        // optional: notify new client that server is ready
        try {
          channel.sink.add(jsonEncode({
            'action': 'server_connected',
            'message': 'Welcome client',
            'serverTime': DateTime.now().toIso8601String(),
          }));
        } catch (_) {}

        // setup message handling for this client
        channel.stream.listen((data) {
          try {
            // router in your original server handled Map or String - we reuse _handleIncomingMessage
            _handleIncomingMessage(data, channel: channel);
          } catch (e, st) {
            debugPrint('Error handling message from client: $e\n$st');
          }
        }, onError: (err) {
          debugPrint('Local client error: $err');
        }, onDone: () {
          debugPrint('Local client disconnected.');
          _clients.remove(channel);
        }, cancelOnError: true);
      }, onError: (err) {
        debugPrint('Local WebSocket server listen error: $err');
      });

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

      // register client on server
      _sendClient({
        'action': 'newClientConnected',
        'deviceName': globals.deviceName ?? 'POS',
        'clientId': DateTime.now().millisecondsSinceEpoch.toString(),
        'message': 'client_register',
      });
      debugPrint('connect: connected and registered');
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
        channel?.sink.add(jsonEncode({'action': 'heartbeat'}));
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
        final navigatorState = MyApp.navigatorKey.currentState;
        final isOnLoginScreen = navigatorState?.canPop() == false;

        if (!_isConnected && !_isConnecting && !isOnLoginScreen && retryCount < maxRetries) {
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
                    });
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

  void _handleDisconnect() {
    _isConnected = false;
    _isConnecting = false;
    _stopHeartbeatClient();
    _subscription?.cancel();
    _subscription = null;
    channel = null;
    debugPrint('Client disconnected, scheduling reconnect');
    _showConnectionLostDialog();
    _scheduleReconnect();
    notifyListeners();
  }

    void sendUpiState(bool isEnabled) {
    if (globals.appType == 'server') {
      _handleLocalUpiUpdate(isEnabled);
      sendDataToClientsKOT({
        'action': 'updateUpiState',
        'isUpiEnabled': isEnabled,
      });
      return;
    }

    if (!_isConnected) {
      debugPrint("Cannot send UPI state: WebSocket not connected");
      reconnect();
      return;
    }

    try {
      final data = {'action': 'updateUpiState', 'isUpiEnabled': isEnabled};
      channel?.sink.add(jsonEncode(data));
      debugPrint("📤 Sent UPI state: $isEnabled");
    } catch (e) {
      debugPrint("❌ Failed to send UPI state: $e");
      _handleDisconnect();
    }
  }

  void _handleLocalUpiUpdate(bool isEnabled) {
    try {
      final context = MyApp.navigatorKey.currentContext;
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
        _receivedActions.removeWhere((actionMap) =>
            actionMap['action'] == 'seat_tapped' &&
            actionMap['tableNumber'] == jsonData['tableNumber'] &&
            actionMap['seat'] == jsonData['seat']);
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
        MessageRouter.handle(jsonEncode(jsonData), customerProvider, receiptPrinter, this);
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
      sendDataToClientsKOT({
        'action': 'removePrinter',
        'printerName': printerName,
        'orderSource': orderProvider.orderSource,
      });
      return;
    }
    if (!_isConnected) {
      debugPrint("Cannot send remove printer request: WebSocket not connected");
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
      debugPrint("📤 Sent remove printer: $printerName");
    } catch (e) {
      debugPrint("Failed to send remove printer request: $e");
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
        debugPrint('Updated order $orderId to table $targetTable seat $targetSeat');
        break;
      }
    }
    if (!updated) debugPrint('Order not found for seat transfer: $orderId');

    // Remove conflicting seat_tapped actions
    _receivedActions.removeWhere((action) =>
        action['action'] == 'seat_tapped' &&
        action['tableNumber'] == jsonData['currentTable'] &&
        action['seat'] == jsonData['currentSeat']);
  }

  // -------------------------
  // Printer update handling
  // -------------------------
   void sendPrinterDetails(Printer printer) {
    if (globals.appType == 'server') {
      _handleLocalPrinterUpdate(printer);
      sendDataToClientsKOT({
        'action': 'updatePrinterItems',
        'printer': printer.toJson(),
        'orderSource': orderProvider.orderSource,
      });
      return;
    }
    if (!_isConnected) {
      debugPrint("Cannot send printer details: WebSocket not connected");
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
      debugPrint("📤 Sent printer details: ${printer.name}");
    } catch (e) {
      debugPrint("Failed to send printer details: $e");
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
    sendDataToClientsKOT({
      'action': 'updatePrinterItems',
      'printer': printer.toJson(),
      'orderSource': orderProvider.orderSource,
    });
    debugPrint("✅ Handled local printer update: ${printer.name}");
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
    final context = MyApp.navigatorKey.currentState?.overlay?.context;
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
            Text('Server is Offline! Please check your server device or Wifi Connection', textAlign: TextAlign.center),
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
    final context = MyApp.navigatorKey.currentState?.overlay?.context;
    if (context != null && context.mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
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
        sendDataToClientsKOT(data); // your global function that notifies other subsystems
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
      debugPrint('sendDeviceCode called on server mode -> no-op or local handling');
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

    if (globals.appType == 'server') {
      _handleIncomingMessage(data);
      // if you want to notify connected clients
      _broadcastToLocalClients(data);
      sendDataToClientsKOT(data);
      return true;
    }

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
  String _shorten(String s, [int limit = 200]) => s.length <= limit ? s : '${s.substring(0, limit)}...';
}

