// import 'dart:io';

// import 'package:flutter/material.dart';
// import '/providers/order_type_provider.dart';
// import 'package:provider/provider.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'dart:async';
// import 'dart:convert';
// import 'package:hive/hive.dart';
// import '../modelss/globals.dart';
// import '../modelss/printer.dart';
// import '../providers/order_provider.dart';
// import '../providers/printer_provider.dart';
// import 'printer_services.dart';

// class WebSocketService with ChangeNotifier {
//   late WebSocketChannel channel;
//   Timer? _heartbeatTimer;
//   Timer? _reconnectTimer;
//   bool _isConnected = false;

//   List<Map<String, dynamic>> _receivedActions = [];
//   List<Map<String, dynamic>> _receivedOrders = [];
//   late OrderProvider orderProvider;
//   late PrinterProvider printerProvider;
//   late OrderTypeProvider orderTypeProvider;

//   List<Map<String, dynamic>> get receivedActions => _receivedActions;
//   List<Map<String, dynamic>> get receivedOrders => _receivedOrders;

//   WebSocketService(
//       this.orderProvider, this.printerProvider, this.orderTypeProvider) {
//     startWebSocketClient();
//     _connect();
//   }

//   void startWebSocketClient() {
//     try {
//       channel = IOWebSocketChannel.connect('ws://$serverip:$port');

//       channel.stream.listen(
//         (message) {
//           print('Received WebSocket message: $message');
//           var jsonData = jsonDecode(message);

//           // Add more logging here if needed to check if the same message is received twice

//           handleServerUpdate(jsonData);

//           if (jsonData.containsKey('table') && jsonData.containsKey('seat')) {
//             _receivedOrders.add(jsonData);
//             notifyListeners();
//             saveOrderToHive(jsonData);

//             orderProvider.processIncomingOrder(jsonData);
//           } else {
//             _receivedActions.add(jsonData);
//             notifyListeners();
//             saveActionToHive(jsonData);
//           }
//           if (jsonData['action'] == 'printerItemsUpdated') {
//             final updatedPrinter = Printer.fromJson(jsonData['printer']);
//             printerProvider.updatePrinter(updatedPrinter);
//             notifyListeners(); // Ensure the UI is updated
//           }

//           if (jsonData['action'] == 'printerDetails' ||
//               jsonData['action'] == 'items' ||
//               jsonData['action'] == 'removePrinter') {
//             _updatePrinterDetails(jsonData);
//             notifyListeners(); // Ensure the UI is updated
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

//   Set<String> processedOrders = {};
//   Set<String> processedOverallPrints = {};

//   bool isPrinting = false; // To avoid overlapping prints

//   Future<void> saveOrderToHive(Map<String, dynamic> order) async {
//     try {
//       var ordersBox = await Hive.openBox('orders');
//       final String hiveOrderId = order['hiveOrderId'];

//       // Ensure the data is saved as a Map with the hiveOrderId as the key
//       if (!ordersBox.containsKey(hiveOrderId)) {
//         await ordersBox.put(hiveOrderId, order); // Save order as a Map
//         print('Order saved to Hive: $order');
//       } else {
//         print('Order $hiveOrderId is already saved in Hive, skipping.');
//       }
//     } catch (e) {
//       print('Error saving order to Hive: $e');
//     }
//   }

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
//       print('Action saved to Hive: $action');
//     } catch (e) {
//       print('Error saving action to Hive: $e');
//     }
//   }

//   // Future<void> saveOrderToHive(Map<String, dynamic> order) async {
//   //   try {
//   //     var ordersBox = await Hive.openBox('orders');
//   //     await ordersBox.add(order);
//   //     print('Order saved to Hive: $order');
//   //   } catch (e) {
//   //     print('Error saving order to Hive: $e');
//   //   }
//   // }

//   // Future<void> loadOrdersFromHive() async {
//   //   try {
//   //     var ordersBox = await Hive.openBox('orders');
//   //     List<Map<String, dynamic>> orders = [];
//   //     for (int i = 0; i < ordersBox.length; i++) {
//   //       orders.add(Map<String, dynamic>.from(ordersBox.getAt(i) as Map));
//   //     }

//   //     _receivedOrders = orders;
//   //     print("_receivedOrders...33");
//   //     print(_receivedOrders);
//   //     notifyListeners();
//   //   } catch (e) {
//   //     print('Error loading orders from Hive: $e');
//   //   }
//   // }

//   Future<List<Map<String, dynamic>>> loadOrdersFromHive() async {
//     try {
//       var ordersBox = await Hive.openBox('orders');
//       List<Map<String, dynamic>> orders = [];
//       print("loadOrdersFromHive");
//       print(orders);
//       // Iterate over each entry in the Hive box and cast it to Map<String, dynamic>
//       ordersBox.toMap().forEach((key, value) {
//         if (value is Map) {
//           orders.add(Map<String, dynamic>.from(value)); // Ensure it's a Map
//         } else {
//           print('Unexpected data format for order: $value');
//         }
//       });

//       print('Orders loaded from Hive: $orders');
//       return orders;
//     } catch (e) {
//       print('Error loading orders from Hive: $e');
//       return [];
//     }
//   }

//   void _connect() {
//     try {
//       channel = IOWebSocketChannel.connect('ws://$serverip:$port');
//       _isConnected = true;

//       channel.stream.listen(
//         (message) {
//           _handleMessage(message);
//         },
//         onError: (error) {
//           print('WebSocket error: $error');
//           _isConnected = false;
//           _scheduleReconnect();
//         },
//         onDone: () {
//           print('WebSocket closed');
//           _isConnected = false;
//           _scheduleReconnect();
//         },
//       );

//       _startHeartbeat();
//     } catch (e) {
//       print('Error connecting to WebSocket: $e');
//       _isConnected = false;
//       _scheduleReconnect();
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
//   }

//   void _printOrder(Map<String, dynamic> orderData) async {
//     final String tokenNo = orderData['tokenNo'].toString(); // Convert to String

//     // Extract the items from the various lists in orderData
//     List<Map<String, dynamic>> seatOrders = [];
//     List<String> itemNames = List<String>.from(orderData['itemNames'] ?? []);
//     List<String> varianceNames =
//         List<String>.from(orderData['varianceNames'] ?? []);
//     List<double> prices = List<double>.from(orderData['prices'] ?? []);
//     List<double> quantities = List<double>.from(orderData['quantities'] ?? []);
//     List<double> weights = List<double>.from(orderData['weights'] ?? []);
//     List<double> amounts = List<double>.from(orderData['amounts'] ?? []);

//     for (int i = 0; i < itemNames.length; i++) {
//       seatOrders.add({
//         'itemName': itemNames[i],
//         'varianceName': varianceNames.length > i ? varianceNames[i] : '',
//         'price': prices.length > i ? prices[i] : 0.0,
//         'quantity': quantities.length > i ? quantities[i] : 0.0,
//         'weight': weights.length > i ? weights[i] : 0.0,
//         'amount': amounts.length > i ? amounts[i] : 0.0,
//       });
//     }

//     // Check if overall printer IP is available
//     String? overallPrinterIp = printerProvider.getOverallPrinterIp();
//     if (overallPrinterIp != null) {
//       await PrinterService.printReceipt(
//         ipAddress: overallPrinterIp,
//         tableNumber: int.tryParse(orderData['table']?.toString() ?? '0') ??
//             0, // Convert table number to int
//         seat: orderData['seat']?.toString() ?? '', // Convert seat to String
//         date: orderData['date']?.toString() ?? '', // Ensure date is a string
//         time: orderData['time']?.toString() ?? '', // Ensure time is a string
//         total: double.tryParse(orderData['totalAmount']?.toString() ?? '0') ??
//             0.0, // Ensure total is a double
//         seatOrders: seatOrders, // Pass the constructed seatOrders
//         tokenNumber: tokenNo,
//         isOverall: true,
//         orderType:
//             orderData['orderType']?.toString() ?? '', // Convert to String
//       );
//     }

//     // Group items by printer IP
//     Map<String, List<Map<String, dynamic>>> groupedItemsByPrinter = {};

//     for (var item in seatOrders) {
//       final String? itemPrinterIp = printerProvider
//           .getPrinterIpForItem(item['varianceName']?.toString() ?? '');

//       if (itemPrinterIp != null) {
//         if (!groupedItemsByPrinter.containsKey(itemPrinterIp)) {
//           groupedItemsByPrinter[itemPrinterIp] = [];
//         }
//         groupedItemsByPrinter[itemPrinterIp]!.add(item);
//       }
//     }

//     // Print items for each unique IP address
//     for (String ip in groupedItemsByPrinter.keys) {
//       await PrinterService.printReceipt(
//         ipAddress: ip,
//         tableNumber: int.tryParse(orderData['table']?.toString() ?? '0') ??
//             0, // Convert to int
//         seat: orderData['seat']?.toString() ?? '', // Convert seat to String
//         date: orderData['date']?.toString() ?? '',
//         time: orderData['time']?.toString() ?? '',
//         total:
//             double.tryParse(orderData['totalAmount']?.toString() ?? '0') ?? 0.0,
//         seatOrders: groupedItemsByPrinter[
//             ip]!, // Pass all items for this printer in a single call
//         tokenNumber: tokenNo,
//         isOverall: false,
//         orderType: orderData['orderType']?.toString() ?? '',
//       );
//     }
//   }

//   void _scheduleReconnect() {
//     if (_reconnectTimer != null) return; // Avoid multiple timers
//     _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
//       if (!_isConnected) {
//         print('Attempting to reconnect...');
//         _connect();
//       } else {
//         _reconnectTimer?.cancel();
//         _reconnectTimer = null;
//       }
//     });
//   }

//   void reconnect() {
//     if (channel != null) {
//       channel.sink.close();
//     }
//     _connect();
//   }

//   void sendDeviceCodeToServer(String deviceCode) {
//     final channel = IOWebSocketChannel.connect(
//         'ws://$serverip:$port'); // Server WebSocket URL

//     final message = jsonEncode({
//       'action': 'newClientConnected',
//       'deviceCode': deviceCode,
//     });

//     channel.sink.add(message);
//     channel.stream.listen((message) {
//       var data = jsonDecode(message);
//       print("Data received from server: $data");

//       // Handle received data (for orders, preInvoice, invoice, etc.)
//       orderProvider.handleServerData(data);
//     }, onError: (error) {
//       print("WebSocket Error: $error");
//     });
//     print('Device code $deviceCode sent to server');
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
//     print('Printer details sent to server: $data');
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
//     print('Remove printer sent to server: $data');
//   }

//   void _updatePrinterDetails(Map<String, dynamic> printerData) {
//     try {
//       if (printerData['action'] == 'removePrinter') {
//         final printerName = printerData['printerName'];
//         printerProvider.removePrinterByName(printerName);
//       } else {
//         final printer = Printer(
//           name: printerData['printerName'] ?? printerData['name'] ?? 'Unknown',
//           ipAddress: printerData['ipAddress'] ?? 'Unknown',
//           type: printerData['type'] ?? 'Unknown',
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
//     } catch (e) {
//       print('Error updating printer details: $e');
//     }
//   }

//   void removeseatAction(int tableNumber, String seat) {
//     _receivedActions.removeWhere((action) =>
//         action['tableNumber'] == tableNumber && action['seat'] == seat);
//     notifyListeners();
//   }

//   void handleServerUpdate(Map<String, dynamic> updateData) {
//     final tokenNo = updateData['tokenNo'];
//     final action = updateData['action'];

//     if (action == 'edit' || action == 'cancelItem') {
//       final updatedItem = updateData['item'];
//       // Find and update the item in local state
//       orderProvider.orders
//           .where((order) => order['tokenNo'] == tokenNo)
//           .forEach((order) {
//         final item =
//             order['items'].firstWhere((i) => i['id'] == updatedItem['id']);
//         item.updateAll((key, value) => updatedItem[key] ?? value);
//       });
//     } else if (action == 'cancelOrder') {
//       // Find and cancel the entire order in local state
//       orderProvider.orders
//           .where((order) => order['tokenNo'] == tokenNo)
//           .forEach((order) {
//         order['isCanceled'] = true;
//       });
//     }
//     orderProvider.notifyListeners();
//     _printOrder(updateData);
//   }
// }
