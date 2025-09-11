// import 'package:another_flushbar/flushbar.dart';
// import 'package:flutter/material.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:provider/provider.dart';
// import 'package:udp/udp.dart';
// import '../Helper/ServerElectionProcess.dart';
// import '../main.dart';
// import '../models/hive boxes.dart';
// import '../screens/loginScreen.dart';
// import '../screens/serverScreen.dart';
// import '/providers/order_type_provider.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'dart:async';
// import 'dart:convert';
// // ignore: depend_on_referenced_packages
// import 'package:hive/hive.dart';
// import '../models/globals.dart';
// import '../models/printer.dart';
// import '../providers/login_provider.dart';
// import '../providers/order_provider.dart';
// import '../providers/printer_provider.dart';
// import 'printer_services.dart';
// import 'serverreachable.dart';
// import 'startServers.dart';

// class WebSocketService with ChangeNotifier {
//   late WebSocketChannel channel;
//   Timer? _heartbeatTimer;
//   Timer? _reconnectTimer;
//   bool _isConnected = false;
//   List<Map<String, dynamic>> _orders = [];
//   bool get isConnected =>
//       _isConnected; // 🔴 Public getter for connection status
//   Box<dynamic>?
//       settingsBox; // Add this line to declare the Hive box for settings

//   final List<Map<String, dynamic>> _receivedActions = [];
//   List<Map<String, dynamic>> _receivedOrders = [];
//   late OrderProvider orderProvider;
//   late PrinterProvider printerProvider;
//   late LoginProvider
//       loginProvider; // Add this line to declare the LoginProvider field

//   late OrderTypeProvider orderTypeProvider;
//   List<Map<String, dynamic>> get orders => _orders;

//   List<Map<String, dynamic>> get receivedActions => _receivedActions;
//   List<Map<String, dynamic>> get receivedOrders => _receivedOrders;

//   bool print2 = false;
//   Map<String, String> _itemPrinterIpCache = {};

//   WebSocketService(
//     this.orderProvider,
//     this.printerProvider,
//     this.orderTypeProvider,
//     this.loginProvider, // Add LoginProvider to the constructor parameters
//   ) {
//     print2 = false;
//     //startWebSocketClient();
//     initializeHive();

//     _connect();
//   }
//   void initializeHive() async {
//     Hive.initFlutter(); // Ensure Hive is initialized (if not already done)
//     settingsBox = await Hive.openBox('settings'); // Open the settings box
//     // Read server IP and other initializations can be done here after box is opened
//     startWebSocketClient();
//   }

//   Set<String> processedOrderIds = {}; // Global set to track processed orders

//   void startWebSocketClient() {
//     const Text("startWebSocketClient3...");
//     try {
//       print('Attempting to connect to WebSocket ws://$serverip:$port');

//       channel = IOWebSocketChannel.connect('ws://$serverip:$port');
//       print("startWebSocketClient33 $serverip");

//       channel.stream.listen(
//         (message) {
//           var jsonData = jsonDecode(message);
//           print("kot orders3  $jsonData");
//           // if (jsonData['type'] == 'order') {
//           //   print("kot orders from server ${jsonData['type']}");
//           //   _receivedOrders.add(jsonData);
//           //   print(_receivedOrders);
//           //   orderProvider.processIncomingOrder(jsonData);

//           //   _cachePrinterIps(jsonData);

//           //   print("jsonData['hiveOrderId']...${jsonData['hiveOrderId']}");
//           //   print("call the print order method1 ..");
//           //   if (count == 0) {
//           //     count++;
//           //     if (appType == 'server') {
//           //       _printOrder(jsonData);
//           //     }
//           //   }
//           //   print("call the print order method2 ..");

//           //   notifyListeners();
//           // }

//           if (jsonData['type'] == 'order') {
//             _receivedOrders.add(jsonData);
//             orderProvider.processIncomingOrder(jsonData);
//             _cachePrinterIps(jsonData);

//             final hiveOrderId = jsonData['hiveOrderId']?.toString() ?? '';

//             if (appType == 'server' &&
//                 hiveOrderId.isNotEmpty &&
//                 !processedOrderIds.contains(hiveOrderId)) {
//               processedOrderIds.add(hiveOrderId);
//               _printOrder(jsonData);
//             }

//             notifyListeners();
//           } else if (jsonData['action'] == 'seat_tapped') {
//             print("jsonData['action'] seat");
//             print(jsonData['action']);
//             _receivedActions.add(jsonData);
//             notifyListeners(); // Update UI
//           } else if (jsonData['action'] == 'updatePrinterItems') {
//             print("test44444");
//             final updatedPrinter = Printer.fromJson(jsonData['printer']);
//             printerProvider.updatePrinter(updatedPrinter);
//             notifyListeners(); // Ensure the UI is updated
//             print("test55555");
//           } else if (jsonData['action'] == 'printerDetails' ||
//               jsonData['action'] == 'items' ||
//               jsonData['action'] == 'removePrinter') {
//             _updatePrinterDetails(jsonData);
//             notifyListeners(); // Ensure the UI is updated
//           } else {
//             _receivedActions.add(jsonData);
//             notifyListeners();
//             saveActionToHive(jsonData);
//           }
//         },
//         onError: (error) {
//           print('WebSocket error: $error');
//         },
//         onDone: () {
//           print('WebSocket closed');
//         },
//       );

//       _startHeartbeat();
//     } catch (e) {
//       print('Error connecting to WebSocket: $e');
//     }
//   }

//   void updateOrderProvider(OrderProvider newOrderProvider) {
//     orderProvider = newOrderProvider;
//   }

//   void _cachePrinterIps(Map<String, dynamic> orderData) {
//     List<String> varianceNames =
//         List<String>.from(orderData['varianceNames'] ?? []);

//     for (String varianceName in varianceNames) {
//       if (!_itemPrinterIpCache.containsKey(varianceName)) {
//         String? ip = printerProvider.getPrinterIpForItem(varianceName);
//         if (ip != null) {
//           _itemPrinterIpCache[varianceName] = ip;
//         }
//       }
//     }
//   }

//   Set<String> processedOrders = {};
//   Set<String> processedOverallPrints = {};

//   bool isPrinting = false;

//   void _startHeartbeat() {
//     _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
//       channel.sink.add(jsonEncode({
//         'action': 'heartbeat',
//       }));
//     });
//   }

//   Future<void> saveActionToHive(Map<String, dynamic> action) async {
//     try {
//       var actionsBox = await Hive.openBox('actions');
//       await actionsBox.add(action);
//     } catch (e) {}
//   }

//   Future<void> loadOrdersFromHive() async {
//     try {
//       var orderBox = await HiveManager().ordersBox;

//       final data = orderBox.get('data');
//       if (data != null && data is List) {
//         _orders = List<Map<String, dynamic>>.from(
//           data.map((e) => Map<String, dynamic>.from(e)),
//         );
//         _receivedOrders = _orders; // Ensure orders are loaded to receivedOrders
//         notifyListeners();
//       }
//     } catch (e) {
//       print('Error loading orders from Hive: $e');
//     }
//   }

//   // void _connect() {
//   //   try {
//   //     channel = IOWebSocketChannel.connect('ws://$serverip:$port');
//   //     _isConnected = true;
//   //     notifyListeners(); // ✅ Notify listeners

//   //     // ✅ Hide dialog if connection is restored
//   //     _hideConnectionLostDialog();

//   //     channel.stream.listen(
//   //       (message) {
//   //         _handleMessage(message);
//   //       },
//   //       onError: (error) {
//   //         print('WebSocket error: $error');
//   //         _isConnected = false;
//   //         notifyListeners();
//   //        // _showConnectionLostDialog(); // ✅ Show dialog on error
//   //         _scheduleReconnect();
//   //       },
//   //       onDone: () {
//   //         print('WebSocket closed');
//   //         _isConnected = false;
//   //         notifyListeners();
//   //        // _showConnectionLostDialog(); // ✅ Show dialog on disconnect
//   //         _scheduleReconnect();
//   //       },
//   //     );

//   //     _startHeartbeat();
//   //   } catch (e) {
//   //     print('Error connecting to WebSocket: $e');
//   //     _isConnected = false;
//   //     notifyListeners();
//   //    // _showConnectionLostDialog(); // ✅ Show dialog if connection fails
//   //     _scheduleReconnect();
//   //   }
//   // }

//   void _connect() async {
//     try {
//       channel = IOWebSocketChannel.connect('ws://$serverip:$port');
//       _isConnected = true;
//       notifyListeners();
//       _hideConnectionLostDialog();
//       channel.sink.add(jsonEncode({
//         'action': 'requestAllData',
//       }));
//       channel.stream.listen(
//         (message) {
//           _handleMessage(message);
//         },
//         onError: (error) async {
//           print('WebSocket error: $error');
//           _isConnected = false;
//           notifyListeners();

//           bool foundServer = await _discoverServerAndReconnect();
//           if (!foundServer) {
//             print("No server found. Starting Election...");
//             await _startElectionProcess();
//           }
//         },
//         onDone: () async {
//           print('WebSocket closed');
//           _isConnected = false;
//           notifyListeners();

//           bool foundServer = await _discoverServerAndReconnect();
//           if (!foundServer) {
//             print("No server found. Starting Election...");
//             await _startElectionProcess();
//           }
//         },
//       );

//       _startHeartbeat();
//     } catch (e) {
//       print('Error connecting to WebSocket: $e');
//       _isConnected = false;
//       notifyListeners();

//       bool foundServer = await _discoverServerAndReconnect();
//       if (!foundServer) {
//         print("No server found. Starting Election...");
//         await _startElectionProcess();
//       }
//     }
//   }

//   Future<void> _startElectionProcess() async {
//     await ServerElectionManager().startElection(() async {
//       final ip = await getLocalIp();
//       if (ip != null) {
//         print("✅ Election won. Promoting to Server with IP: $ip");

//         final box = await Hive.openBox('serverBox');
//         await box.put('serverIp', ip);
//         await box.put('serverPort', port);
//         final configBox = HiveManager().configBox;
//         appType = 'server';
//         await configBox.put('appType', 'server');

//         serverip = ip;

//         _reconnectTimer?.cancel();
//         _reconnectTimer = null;

//         Navigator.pushAndRemoveUntil(
//           MyApp.navigatorKey.currentContext!,
//           MaterialPageRoute(builder: (context) => ServerScreen()),
//           (Route<dynamic> route) => false,
//         );
//       }
//     });
//   }

//   void reconnectWithNewIP(String newIp) {
//     serverip = newIp; // ✅ Update global server IP
//     channel.sink.close(); // ✅ Close the existing WebSocket connection
//     _connect(); // ✅ Start a new connection
//     notifyListeners(); // ✅ Notify UI about the change
//   }

//   Future<bool> _checkServerAvailability(String serverIp) async {
//     try {
//       final WebSocketChannel channel = IOWebSocketChannel.connect(
//           'ws://$serverIp:$port'); // Replace PORT with your WebSocket server port

//       channel.sink
//           .add(jsonEncode({'action': 'heartbeat'})); // Send a heartbeat message
//       final response = await channel.stream.first.timeout(
//         const Duration(seconds: 3),
//         onTimeout: () {
//           channel.sink.close();
//           return null;
//         },
//       );

//       if (response != null) {
//         final data = jsonDecode(response);
//         if (data['action'] == 'heartbeatAck') {
//           channel.sink.close();
//           return true; // Server is online
//         }
//       }
//       channel.sink.close();
//       return false;
//     } catch (e) {
//       return false;
//     }
//   }

//   void _showConnectionLostDialog() {
//     final context = MyApp.navigatorKey.currentState?.overlay?.context;
//     if (context == null) return;

//     TextEditingController ipController = TextEditingController(text: serverip);
//     bool isInvalidIP = false;

//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return StatefulBuilder(
//           builder: (context, setState) {
//             return AlertDialog(
//               title: const Text('Connection Lost'),
//               content: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   const Icon(Icons.wifi_off, size: 60, color: Colors.red),
//                   const SizedBox(height: 20),
//                   const Text(
//                     'Please enter a new Server IP if your current server is down,otherwise reconnect or check your connection',
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 10),
//                   TextField(
//                     controller: ipController,
//                     keyboardType: TextInputType.number,
//                     decoration: InputDecoration(
//                       hintText: "e.g., 192.168.1.100",
//                       border: const OutlineInputBorder(),
//                       errorText: isInvalidIP ? "Invalid IP Address" : null,
//                     ),
//                   ),
//                 ],
//               ),
//               actions: [
//                 ElevatedButton(
//                   onPressed: () async {
//                     // String newIp = ipController.text.trim();

//                     // if (_validateIpAddress(newIp)) {
//                     //   var box = await Hive.openBox('settings');
//                     //   await box.put('serverip', newIp);

//                     //   WebSocketService webSocketService =
//                     //       Provider.of<WebSocketService>(context, listen: false);
//                     //   webSocketService.reconnectWithNewIP(newIp);

//                     //   Navigator.of(context).pop();
//                     //   ScaffoldMessenger.of(context).showSnackBar(
//                     //     const SnackBar(
//                     //         content:
//                     //             Text("Server IP updated! Reconnecting...")),
//                     //   );
//                     // } else {
//                     //   setState(() {
//                     //     isInvalidIP = true;
//                     //   });
//                     // }
//                     final enteredIp = ipController.text.trim();

//                     if (enteredIp.isNotEmpty && _validateIpAddress(enteredIp)) {
//                       bool isServerOnline =
//                           await _checkServerAvailability(enteredIp);
//                       setState(() {}); // Refresh the UI

//                       if (!isServerOnline) {
//                         // ignore: use_build_context_synchronously
//                         Flushbar(
//                           message:
//                               'Server is offline. Please check the IP and try again..',
//                           duration: const Duration(seconds: 2),
//                           backgroundColor: Colors.red[600] ?? Colors.red,
//                           flushbarPosition: FlushbarPosition.BOTTOM,
//                           margin: const EdgeInsets.all(8),
//                           borderRadius: BorderRadius.circular(20),
//                         ).show(context);
//                         return;
//                       }

//                       try {
//                         await settingsBox!
//                             .put('serverip', enteredIp); // Use settingsBox here

//                         // ✅ NEW: Restart WebSocket Connection with new IP
//                         WebSocketService webSocketService =
//                             // ignore: use_build_context_synchronously
//                             Provider.of<WebSocketService>(context,
//                                 listen: false);
//                         webSocketService.reconnectWithNewIP(enteredIp);

//                         Navigator.of(context).pop();
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(content: Text('Server IP updated!')),
//                         );

//                         // ✅ Navigate to LoginScreen only if the server is online
//                         // ignore: use_build_context_synchronously
//                         Navigator.pushAndRemoveUntil(
//                           context,
//                           MaterialPageRoute(
//                               builder: (context) => ServerScreen()),
//                           (Route<dynamic> route) => false,
//                         );
//                       } catch (e) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           const SnackBar(
//                             content: Text(
//                                 "Failed to connect to the server. Please check the IP address."),
//                           ),
//                         );
//                       }
//                     } else {
//                       ScaffoldMessenger.of(context).showSnackBar(
//                         const SnackBar(content: Text('Invalid IP address!')),
//                       );
//                     }
//                   },
//                   style:
//                       ElevatedButton.styleFrom(backgroundColor: Colors.green),
//                   child: const Text("Reconnect",
//                       style: TextStyle(color: Colors.white)),
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   bool _validateIpAddress(String ip) {
//     final RegExp ipRegex = RegExp(
//       r'^((25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[0-1]?[0-9][0-9]?)$',
//     );
//     return ipRegex.hasMatch(ip);
//   }

//   void _hideConnectionLostDialog() {
//     final context = MyApp.navigatorKey.currentState?.overlay?.context;
//     if (context != null) {
//       Navigator.of(context, rootNavigator: true)
//           .popUntil((route) => route.isFirst);
//     }
//   }

//   void _handleMessage(dynamic message) {
//     var jsonData = jsonDecode(message);
//     print('Received data from server: $jsonData');

//     if (jsonData.containsKey('table') && jsonData.containsKey('items')) {
//       if (!jsonData.containsKey('orderSource')) {
//         jsonData['orderSource'] = orderProvider.orderSource;
//       }
//     } else {
//       _receivedActions.add(jsonData);
//       notifyListeners();
//       saveActionToHive(jsonData);
//     }

//     if (jsonData['action'] == 'printerDetails' ||
//         jsonData['action'] == 'items' ||
//         jsonData['action'] == 'removePrinter') {
//       _updatePrinterDetails(jsonData);
//     }
//     if (jsonData['action'] == 'seat_returned') {
//       // Remove the seat returned status from the _receivedActions list
//       _receivedActions.removeWhere((action) =>
//           action['action'] == 'seat_tapped' &&
//           action['tableNumber'] == jsonData['tableNumber'] &&
//           action['seat'] == jsonData['seat']);
//       notifyListeners(); // Update UI to remove red indicator
//     }
//   }

//   bool isPrintOrder = false;
//   void _printOrder(Map<String, dynamic> orderData) async {
//     print("kot........1");

//     final String hiveOrderId = orderData['hiveOrderId']?.toString() ?? "";
//     if (hiveOrderId.isEmpty) {
//       print('Error: hiveOrderId is null or empty');
//       return;
//     }
//     List<String> itemNames = List<String>.from(orderData['itemNames'] ?? []);
//     List<String> varianceNames =
//         List<String>.from(orderData['varianceNames'] ?? []);
//     List<double> prices = List<double>.from(orderData['prices'] ?? []);
//     List<double> quantities = List<double>.from(orderData['quantities'] ?? []);
//     List<double> weights = List<double>.from(orderData['weights'] ?? []);
//     List<double> amounts = List<double>.from(orderData['amounts'] ?? []);
//     List<Map<String, dynamic>> addOns =
//         List<Map<String, dynamic>>.from(orderData['addOns'] ?? []);
//     List<Map<String, dynamic>> config =
//         List<Map<String, dynamic>>.from(orderData['config'] ?? []);
//     int tokenNo = orderData['tokenNo'] ?? 0;
//     String? overallPrinterIp = printerProvider.getOverallPrinterIp();
//     final userName = loginProvider.loggedInUserName ?? "";
//     String tableNumber = orderData['table'];
//     String seat = orderData['seat']?.toString() ?? '';
//     String date = orderData['date']?.toString() ?? '';
//     String time = orderData['time']?.toString() ?? '';
//     String waiter = orderData['waiter']?.toString() ?? '';
//     double totalAmount =
//         double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0;
//     String orderType = orderData['orderType']?.toString() ?? '';

//     List<Map<String, dynamic>> seatOrders = [];
//     Map<String, List<Map<String, dynamic>>> groupedAddOns = {};
//     for (var addOn in addOns) {
//       String varianceName = addOn['varianceName'] ?? '';
//       groupedAddOns.putIfAbsent(varianceName, () => []).add(addOn);
//     }
//     final stopwatch = Stopwatch()..start();
//     // Group add-ons by varianceName
//     try {
//       // var ordersBox = await Hive.openBox('orders');
//       // var savedOrder = ordersBox.get(hiveOrderId);

//       // Extracting order data with safe default values

//       // Process main items and add-ons
//       for (int i = 0; i < itemNames.length; i++) {
//         String varianceName = varianceNames.length > i ? varianceNames[i] : '';
//         double itemQuantity = quantities.length > i ? quantities[i] : 0.0;

//         // Add-ons processing
//         if (groupedAddOns.containsKey(varianceName)) {
//           for (var addOn in groupedAddOns[varianceName]!) {
//             seatOrders.add({
//               'itemName': '$varianceName(${addOn['addOnName']})',
//               'varianceName': '',
//               'price': addOn['price'] ?? 0.0,
//               'quantity': addOn['quantity'] ?? 0.0,
//               'weights': addOn['weights'] ?? 0.0,
//               'amount': (addOn['price'] ?? 0.0) * (addOn['quantity'] ?? 1.0),
//               'config': config
//                   .where((c) => c['varianceName'] == varianceName)
//                   .toList()
//             });
//             itemQuantity -= addOn['quantity'] ?? 0.0;
//           }
//         }

//         if (itemQuantity > 0) {
//           seatOrders.add({
//             'itemName': varianceName,
//             'varianceName': varianceName,
//             'price': prices.length > i ? prices[i] : 0.0,
//             'quantity': itemQuantity,
//             'weights': weights.length > i ? weights[i] : 0.0,
//             'amount': amounts.length > i ? amounts[i] : 0.0,
//             'config':
//                 config.where((c) => c['varianceName'] == varianceName).toList(),
//           });
//         }
//       }

//       print('Final seatOrders: $seatOrders');

//       Map<String, List<Map<String, dynamic>>> groupedItemsByPrinter = {};
//       for (var item in seatOrders) {
//         String? itemPrinterIp = _itemPrinterIpCache[item['itemName']];

//         if (itemPrinterIp != null) {
//           groupedItemsByPrinter.putIfAbsent(itemPrinterIp, () => []).add(item);
//         }
//       }

//       print('Grouped Items by Printer (cached): $groupedItemsByPrinter');

//       print('Grouped Items by Printer: $groupedItemsByPrinter');

//       if (count2 == 0) {
//         count2++;
//         await Future.wait(groupedItemsByPrinter.keys.map((ip) {
//           return _printReceipt(
//               ip,
//               groupedItemsByPrinter[ip]!,
//               tableNumber,
//               seat,
//               date,
//               time,
//               waiter,
//               totalAmount,
//               tokenNo,
//               userName,
//               orderType);
//         }));
//       }
//       if (overallPrinterIp != null && count3 == 0) {
//         count3++;
//         // ignore: use_build_context_synchronously
//         await _printReceipt(
//           overallPrinterIp,
//           seatOrders,
//           tableNumber,
//           seat,
//           date,
//           time,
//           waiter,
//           totalAmount,
//           tokenNo,
//           userName,
//           orderType,
//           isOverall: true,
//         );
//       }
//       // await ordersBox.put(hiveOrderId, savedOrder); // Mark order as printed
//       // print("Order $hiveOrderId marked as printed.");
//       stopwatch.stop();
//       print("Total Execution Time: ${stopwatch.elapsedMilliseconds} ms");
//     } catch (e) {
//       print("Error in _printOrder: $e");
//     }
//   }

//   Future<void> _printReceipt(
//     String ipAddress,
//     List<Map<String, dynamic>> seatOrders,
//     String tableNumber,
//     String seat,
//     String date,
//     String time,
//     String waiter,
//     double totalAmount,
//     int tokenNo,
//     String userName,
//     String orderType, {
//     bool isOverall = false,
//   }) async {
//     print(
//         "Sending print request to printer: $ipAddress with payload: $seatOrders");
//     await PrinterService.printReceipt(
//       ipAddress: ipAddress,
//       tableNumber: tableNumber,
//       seat: seat,
//       date: date,
//       time: time,
//       waiter: waiter,
//       total: totalAmount,
//       seatOrders: seatOrders,
//       tokenNumber: tokenNo.toString(),
//       isOverall: isOverall,
//       userName: userName,
//       orderType: orderType,
//     );
//   }

//   // void _scheduleReconnect() {
//   //   if (_reconnectTimer != null) return; // Avoid multiple timers
//   //   _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
//   //     if (!_isConnected) {
//   //       try {
//   //         print("Trying to reconnect to WebSocket...");
//   //         _connect();
//   //       } catch (e) {
//   //         print("Reconnect failed. Trying UDP discovery...");

//   //         // ⚡ ADD this:
//   //         await _discoverServerAndReconnect();
//   //       }
//   //     } else {
//   //       _reconnectTimer?.cancel();
//   //       _reconnectTimer = null;
//   //     }
//   //   });
//   // }
//   void _scheduleReconnect() {
//     if (_reconnectTimer != null) return; // Avoid multiple timers

//     _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
//       if (!_isConnected) {
//         print("Trying to reconnect to WebSocket...");

//         try {
//           _connect(); // Try normal reconnect
//         } catch (e) {
//           print("Reconnect failed. Trying UDP discovery...");
//           bool foundServer = await _discoverServerAndReconnect();

//           if (!foundServer) {
//             print("No server found. Starting Election...");

//             await ServerElectionManager().startElection(() async {
//               final ip = await getLocalIp();
//               if (ip != null) {
//                 print("✅ Election won. Promoting to Server with IP: $ip");
//                 final box = await Hive.openBox('serverBox');
//                 await box.put('serverIp', ip);
//                 await box.put('serverPort', port);
//                 final configBox = HiveManager().configBox;
//                 appType = 'server';
//                 await configBox.put('appType', 'server');

//                 serverip = ip;

//                 _reconnectTimer?.cancel();
//                 _reconnectTimer = null;

//                 // 🚀 Now navigate to ServerScreen
//                 Navigator.pushAndRemoveUntil(
//                   MyApp.navigatorKey.currentContext!,
//                   MaterialPageRoute(builder: (context) => ServerScreen()),
//                   (Route<dynamic> route) => false,
//                 );
//               }
//             });
//           }
//         }
//       } else {
//         _reconnectTimer?.cancel();
//         _reconnectTimer = null;
//       }
//     });
//   }

//   Future<bool> _discoverServerAndReconnect() async {
//     try {
//       final udp = await UDP.bind(Endpoint.any());
//       udp.send(
//         utf8.encode('WHO_IS_SERVER'),
//         Endpoint.broadcast(port: const Port(45678)),
//       );

//       await for (final datagram
//           in udp.asStream(timeout: const Duration(seconds: 3))) {
//         if (datagram != null) {
//           final message = utf8.decode(datagram.data);
//           if (message.startsWith('SERVER:')) {
//             final parts = message.split(':');
//             final ip = parts[1];
//             final port = parts[2];

//             serverip = ip;
//             notifyListeners();
//             udp.close();
//             reconnectWithNewIP(ip);
//             print("✅ Found new server at $ip:$port and reconnected");
//             return true; // 🚨 SERVER FOUND
//           }
//         }
//       }
//       udp.close();
//       print("❌ No server found in UDP discovery.");
//       return false; // 🚨 SERVER NOT FOUND
//     } catch (e) {
//       print("Error in UDP discovery: $e");
//       return false;
//     }
//   }

//   void reconnect() {
//     channel.sink.close();
//     _connect();
//   }

//   sendDeviceCodeToServer(String deviceCode) {
//     final channel = IOWebSocketChannel.connect(
//         'ws://$serverip:$port'); // Server WebSocket URL
//     final message = jsonEncode({
//       'action': 'newClientConnected',
//       'deviceCode': deviceCode,
//     });

//     channel.sink.add(message);
//     channel.stream.listen((message) {
//       var data = jsonDecode(message);

//       // Handle received data (for orders, preInvoice, invoice, etc.)
//       orderProvider.handleServerData(data);
//     }, onError: (error) {
//       print("WebSocket Error: $error");
//     });
//   }

//   @override
//   void dispose() {
//     _heartbeatTimer?.cancel();
//     _reconnectTimer?.cancel();
//     channel.sink.close();
//     super.dispose();
//   }

//   void sendPrinterDetails(Printer printer) {
//     final data = {
//       'action': 'printerDetails',
//       'name': printer.name,
//       'ipAddress': printer.ipAddress,
//       'type': printer.type,
//       'items': printer.items,
//       'orderSource': orderProvider.orderSource,
//     };

//     channel.sink.add(jsonEncode(data));
//   }

//   void sendAssignedItems(Printer printer) {
//     final data = {
//       'action': 'updatePrinterItems',
//       'printer': printer.toJson(), // Ensure printer is converted to JSON
//     };
//     channel.sink.add(jsonEncode(data));
//   }

//   void sendRemovePrinter(String printerName) {
//     final data = {
//       'action': 'removePrinter',
//       'printerName': printerName,
//       'orderSource': orderProvider.orderSource,
//     };

//     channel.sink.add(jsonEncode(data));
//   }

//   void _updatePrinterDetails(Map<String, dynamic> printerData) {
//     try {
//       if (printerData['action'] == 'removePrinter') {
//         final printerName = printerData['printerName'];
//         printerProvider.removePrinterByName(printerName);
//       } else {
//         final printer = Printer(
//           name: printerData['printerName'] ?? printerData['name'] ?? '',
//           ipAddress: printerData['ipAddress'] ?? '',
//           type: printerData['type'] ?? '',
//           items: List<String>.from(
//               printerData['items'] ?? printerData['assignedItems'] ?? []),
//         );

//         final existingPrinterIndex =
//             printerProvider.printers.indexWhere((p) => p.name == printer.name);

//         if (existingPrinterIndex != -1) {
//           printerProvider.updatePrinter(printer);
//         } else {
//           printerProvider.addPrinter(printer);
//         }
//       }

//       printerProvider.notifyListeners();
//     } catch (e) {}
//   }
// }
