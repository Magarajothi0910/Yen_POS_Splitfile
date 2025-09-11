// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter_foreground_task/flutter_foreground_task.dart';
// import 'package:hive_flutter/hive_flutter.dart';
// import 'package:udp/udp.dart';
// import 'package:web_socket_channel/io.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import '../../screens/kot_screen/global/globals.dart';
// import '../Helper/Stock_utils.dart';
// import '../Repository/orderRepository.dart';
// import '../handlers/FullCancelOrder_Handler.dart';
// import '../handlers/ItemWiseCancel.dart';
// import '../handlers/invoice handler.dart';
// import '../handlers/orderhandlers.dart';
// import '../handlers/reverseOrder_handler.dart';
// import '../handlers/seathandler.dart';
// import '../handlers/systemStockUpdate.dart';
// import '../kotproviders/order_provider.dart';
// import '../models/globals.dart';
// import '../models/hive boxes.dart';
// import '../kotservices/Token_service.dart';
// import '../kotservices/foregroundtask_handler.dart';
// import '../kotservices/hive_service.dart';
// import '../kotservices/sendDataToClients.dart';
// import '../kotservices/serverreachable.dart';
// import '../kotservices/startServers.dart';
// import '../kotservices/sync_service.dart';
// import '../screens/table_screen.dart';
// import '../widgets/makethisdeviceas server_Dialog.dart';
// import 'package:provider/provider.dart';
// import '../Dashboard/tableDashboard.dart';
// import '../kotproviders/product_provider.dart';
// import '../kotproviders/login_provider.dart';

// class LoginScreen extends StatefulWidget {
//   @override
//   // ignore: library_private_types_in_public_api
//   _LoginScreenState createState() => _LoginScreenState();
// }

// class _LoginScreenState extends State<LoginScreen> {
//   final List<Map<String, dynamic>> _receivedData = [];
//   List<Map<String, dynamic>> _invoiceData = []; // List to store invoice data
//   final TextEditingController _userNameController = TextEditingController();
//   final TextEditingController _passwordController = TextEditingController();
//   WebSocketChannel? channel;

//   Set<WebSocketChannel> clients = {};
//   List<Map<String, dynamic>> orders = [];
//   final SyncServiceKot _syncService = SyncServiceKot();
//   Timer? _syncTimer;
//   Timer? _patchCheckTimer;
//   List<String> logs = [];
//   String serverPort = "Unknown";
//   late Box box;
//   bool serverFound = false;
//   String status = 'Searching for server...';
//   @override
//   initState() {
//     super.initState();
//     // HiveManagerKot().invoices.then((_) => _loadInvoices());
//     // HiveManagerKot().posInvoiceBox; // Just to ensure it's initialized
//     // HiveManagerKot().tableStatusBox; // Just to ensure it's initialized

//     _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
//       SyncServiceKot();
//       // _syncService.syncUnsyncedOrders();
//       // _syncService.syncUnsyncedInvoices();
//       //  _syncService.patchEditedOrders();
//     });
//     Provider.of<LoginProvider>(context, listen: false).fetchAndStoreLoginData();
//     final productProvider =
//         Provider.of<ProductProvider>(context, listen: false);
//     productProvider.fetchTablesAndSaveInHive();

//     loadOrdersFromHive().then((orders) {
//       setState(() {
//         _receivedData.addAll(orders as Iterable<Map<String, dynamic>>);
//       });
//     });
//     checkIfServerWasPreviouslyStored();

//     //_patchCheckTimer = Timer.periodic(Duration(minutes: 5), (timer) {
//     //   _syncService.patchEditedOrders();
//     // });
//   }

//   /// Sets a brand-new localStock for a given varianceCode in Hive.
//   Future<void> _setLocalStockInHive({
//     required String varianceCode,
//     required double newLocalStock,
//   }) async {
//     final box = await Hive.openBox('branchwise_items');
//     final raw = Map<String, dynamic>.from(box.get('data') as Map);
//     final itemsMap = Map<String, dynamic>.from(raw['data'] as Map);
//     final alias = aliasname;

//     itemsMap.forEach((itemKey, itemValue) {
//       final item = Map<String, dynamic>.from(itemValue as Map);
//       final variances = Map<String, dynamic>.from(item['variance'] as Map);

//       variances.forEach((varKey, varValue) {
//         final vmap = Map<String, dynamic>.from(varValue as Map);
//         if (vmap['varianceitemCode']?.toString() == varianceCode) {
//           final bw = Map<String, dynamic>.from(vmap['branchwise'] ?? {});
//           final entry = Map<String, dynamic>.from(bw[alias] ?? {});
//           entry['localStock'] = newLocalStock;
//           bw[alias] = entry;
//           vmap['branchwise'] = bw;
//           variances[varKey] = vmap;
//         }
//       });

//       item['variance'] = variances;
//       itemsMap[itemKey] = item;
//     });

//     raw['data'] = itemsMap;
//     await box.put('data', raw);
//   }

//   Future<void> checkIfServerWasPreviouslyStored() async {
//     final serverBox = HiveManagerKot().serverBox;
//     final configBox = HiveManagerKot().configBox;

//     // Force everything to String
//     final rawIp = serverBox.get('serverIp', defaultValue: '');
//     final rawPort = serverBox.get('serverPort', defaultValue: '');
//     final savedIp = rawIp?.toString() ?? '';
//     final savedPort = rawPort?.toString() ?? '';

//     if (savedIp.isNotEmpty && savedPort.isNotEmpty) {
//       final localIp = await getLocalIp();
//       serverip = savedIp;
//       serverPort = savedPort;

//       if (localIp == savedIp) {
//         appType = 'server';
//         await configBox.put('appType', 'server');
//         // restart your server…
//       } else {
//         appType = 'client';
//         await configBox.put('appType', 'client');
//       }
//       setState(() => serverFound = true);
//     } else {
//       setState(() => serverFound = false);
//       appType = 'client';
//       await configBox.put('appType', 'client');
//     }
//   }

//   void dispose() {
//     // Close all Hive boxes
//     _syncTimer?.cancel();

//     super.dispose();
//   }

//   Future<void> _loadInvoices() async {
//     var invoiceBox = await Hive.openBox('invoices');
//     final List<Map<String, dynamic>> invoices = [];
//     print("invoices   $invoices");
//     for (int i = 0; i < invoiceBox.length; i++) {
//       var invoice = invoiceBox.getAt(i);

//       if (invoice is String) {
//         try {
//           invoice = jsonDecode(invoice);
//         } catch (e) {
//           print("Error decoding invoice at index $i: $e");
//           continue;
//         }
//       }

//       if (invoice is Map<String, dynamic>) {
//         invoices.add(invoice);
//       }
//     }

//     setState(() {
//       _invoiceData = invoices;
//     });
//   }

//   void startServer(Set<WebSocketChannel> clients,
//       Function(Map<String, dynamic>) onDataReceived) async {
//     try {
//       final server = await HttpServer.bind(InternetAddress.anyIPv4, 8383);
//       print('Server running on ${server.address}:${server.port}');

//       tokenCounter = await getTokenCounterFromHive();

//       server.transform(WebSocketTransformer()).listen((WebSocket socket) {
//         handleWebSocket(socket, clients, onDataReceived);
//       });
//     } catch (e) {
//       print('Failed to start server: $e');
//     }
//   }

//   Map<String, String> seathiveOrderIds = {};

//   void handleWebSocket(WebSocket socket, Set<WebSocketChannel> clients,
//       Function(Map<String, dynamic>) onDataReceived) {
//     final channel = IOWebSocketChannel(socket);
//     clients.add(channel);

//     // Map for handling messages triggered by the 'action' field
//     final Map<String, Future<void> Function(Map<String, dynamic>)>
//         actionHandlers = {
//       'hello': (data) async {
//         channel.sink.add(jsonEncode({
//           'action': 'response',
//           'message': 'Hello Client, message received!'
//         }));
//       },

//       'requestBranchwiseItems': (data) async {
//         final box = await Hive.openBox('branchwise_items');
//         final raw = box.get('data') as Map<String, dynamic>;
//         final alias = aliasname; // "AR"
//         final enrichedData = <String, dynamic>{};

//         (raw['data'] as Map<String, dynamic>).forEach((itemKey, itemValue) {
//           final itemMap = Map<String, dynamic>.from(itemValue);
//           final variances =
//               Map<String, dynamic>.from(itemMap['variance'] ?? {});
//           final newVars = <String, dynamic>{};

//           variances.forEach((varKey, varValue) {
//             final varMap = Map<String, dynamic>.from(varValue);
//             final branchMap =
//                 Map<String, dynamic>.from(varMap['branchwise'] ?? {});

//             if (branchMap.containsKey(alias)) {
//               final entry = Map<String, dynamic>.from(branchMap[alias]);

//               branchMap[alias] = entry;
//               varMap['branchwise'] = branchMap;
//             }

//             newVars[varKey] = varMap;
//           });

//           itemMap['variance'] = newVars;
//           enrichedData[itemKey] = itemMap;
//         });

//         final payload = {
//           'categories': raw['categories'],
//           'data': enrichedData,
//         };

//         channel.sink.add(jsonEncode({
//           'action': 'branchwiseItems',
//           'data': payload,
//         }));
//       },
//       'updateLocalStock': (data) async {
//         final updates = data['updates'] as List<dynamic>;

//         for (final u in updates) {
//           final branchAlias = u['branch'] as String;
//           final varianceItemCode = u['varianceitemCode'] as String;
//           // quantity here is the amount sold; we subtract it from systemStock
//           final quantity = (u['quantity'] as num).toInt();

//           // 2) call your adjustSystemStock helper:
//           await adjustSystemStock(
//             branchAlias: branchAlias,
//             varianceItemCode: varianceItemCode,
//             delta: -quantity, // negative to reduce stock
//           );
//         }

//         // 3) optionally broadcast a confirmation back to clients:
//         sendDataToClients({
//           'action': 'stockUpdated',
//           'updates': updates,
//         }, clients);
//       },
//       'heartbeat': (data) async {
//         channel.sink.add(jsonEncode({'action': 'heartbeatAck'}));
//       }, // inside your handleWebSocket(...) where you build actionHandlers:

//       'requestAllData': (data) async {
//         print("requestDataFromServer3...");
//         await sendAllDataToClient(channel);
//         print("requestDataFromServer4...");
//       },
//       'seat_tapped': (data) async {
//         sendDataToClients(data, clients);
//       },
//       'seat_returned': (data) async {
//         sendDataToClients(data, clients);
//       }, // in handleWebSocket, inside actionHandlers:

//       'patchOrderStatusBySeathiveOrderId': (data) async {
//         print("patchOrderStatusBySeathiveOrderId Received...");
//         final seathiveOrderId = data['seathiveOrderId']?.toString() ?? '';
//         final newStatus = data['status']?.toString() ?? '';
//         final preinvoiceTime = data['preinvoiceTime']?.toString() ?? '';
//         final orderRemark = data['orderRemark']?.toString() ?? '';

//         handlePatchOrderStatusBySeathiveOrderId(
//             seathiveOrderId, newStatus, orderRemark, preinvoiceTime);
//       },
//       'seat_transfer': (data) async {
//         await handleSeatTransfer(
//           data: data,
//           receivedData: _receivedData,
//           clients: clients,
//         );
//       },
//       'newClientConnected': (data) async {
//         await handleNewClientConnected(data, channel);
//       },
//       'FullCancelOrderPatch': (data) async {
//         await OrderPatchHandler.handleFullCancelOrderPatch(data, clients);
//       },
//       'cancelOrderItem': (data) async {
//         await CancelOrderPatchHandler.patchCancelOrderItem(data, clients);
//         await applyLocalStockDelta([
//           {
//             'varianceitemCode': data['varianceitemCode'],
//             'quantityDelta':
//                 (data['cancelledQty'][data['updatedIndex']] as num).toDouble(),
//           }
//         ], clients);
//       },
//       'reverseCancelOrderItem': (data) async {
//         final hiveOrderId = data['hiveOrderId'];
//         final int updatedIndex = data['updatedIndex'];
//         final double updatedQty = (data['updatedQuantity'] as num).toDouble();
//         final double updatedCancelledQty =
//             (data['updatedCancelledQty'] as num).toDouble();
//         final double totalAmount = (data['totalAmount'] as num).toDouble();
//         final bool partiallycancelled = data['partiallycancelled'] == true;

//         print("✅ ReverseCancelOrderItem index-wise called with data: $data");

//         await patchOrderInHiveIndexWise(
//           hiveOrderId,
//           updatedIndex,
//           updatedQty,
//           updatedCancelledQty,
//           totalAmount,
//           partiallycancelled,
//         );

//         // Notify clients
//         sendDataToClients({
//           'action': 'reverseCancelOrderItem',
//           'hiveOrderId': hiveOrderId,
//           'updatedIndex': updatedIndex,
//           'updatedQuantity': updatedQty,
//           'updatedCancelledQty': updatedCancelledQty,
//           'totalAmount': totalAmount,
//           'partiallycancelled': partiallycancelled,
//         }, clients);
//         await applyLocalStockDelta([
//           {
//             'varianceitemCode': data['varianceitemCode'],
//             'quantityDelta': -(data['updatedQuantity'] as num).toDouble(),
//           }
//         ], clients);
//       },
//       'updatePrinterItems': (data) async {
//         final printer = data['printer'];
//         final printerName = printer['name'];
//         final updatedItems = printer['items'];

//         bool printerFound = false;
//         for (var entry in _receivedData) {
//           if (entry['action'] == 'printerDetails' &&
//               entry['name'] == printerName) {
//             entry['items'] =
//                 updatedItems; // Update the items for the matched printer
//             printerFound = true;
//             break;
//           }
//         }

//         if (!printerFound) {
//           _receivedData.add({
//             'action': 'printerDetails',
//             'name': printerName,
//             'ipAddress': printer['ipAddress'],
//             'type': printer['type'],
//             'items': updatedItems,
//             'orderSource': printer['orderSource'],
//           });
//         } else {
//           print(
//               'Updated items for existing printer in _receivedData: $printerName');
//         }

//         // Save the updated printer details to Hive
//         await savePrinterDetailsToHive({
//           'action': 'printerDetails',
//           'name': printerName,
//           'ipAddress': printer['ipAddress'],
//           'type': printer['type'],
//           'items': updatedItems,
//           'orderSource': printer['orderSource'],
//         });

//         // Broadcast the updated printer details to all clients
//         sendDataToClients({
//           'action': 'updatePrinterItems',
//           'printer': {
//             'name': printerName,
//             'ipAddress': printer['ipAddress'],
//             'type': printer['type'],
//             'items': updatedItems,
//           }
//         }, clients);
//       },
//       'kotTableStatusUpdated': (data) async {
//         print("kotTableStatusUpdated Received...");
//         await _syncService.saveTableStatusToHive(data);
//         await _syncService.upsertKotTableStatus(data);
//         print("kotTableStatusUpdated data: $data");
//       },
//       'printerDetails': (data) async {
//         await savePrinterDetailsToHive(data);
//         _receivedData.add(data);
//         sendDataToClients(data, clients);
//       }
//     };

//     // Map for handling messages triggered by the 'type' field
//     final Map<String, Future<void> Function(Map<String, dynamic>)>
//         typeHandlers = {
//       'order': (data) async {
//         handleOrder(data, clients);
//       },
//       'invoice': (data) async {
//         handleInvoice(data, clients);
//       },
//       'posInvoice': (data) async {
//         handleInvoice(data, clients);
//       },
//     };

//     // Listen for incoming messages from the WebSocket stream
//     channel.stream.listen((message) async {
//       try {
//         if (message is String && message.trim().isNotEmpty) {
//           String fixedMessage = message.replaceAll("'", '"');
//           var data = jsonDecode(fixedMessage);
//           print("Received data:...... $data");

//           // Special handling for heartbeat
//           if (data.containsKey('action') && data['action'] == 'heartbeat') {
//             channel.sink.add(jsonEncode({'action': 'heartbeatAck'}));
//             return;
//           }

//           // Process actions if present
//           if (data.containsKey('action') &&
//               actionHandlers.containsKey(data['action'])) {
//             await actionHandlers[data['action']]!(data);
//             return;
//           }

//           // Process types if present
//           if (data.containsKey('type') &&
//               typeHandlers.containsKey(data['type'])) {
//             await typeHandlers[data['type']]!(data);
//             return;
//           }

//           print('Unhandled message type: $data');
//         }
//       } catch (e) {
//         print('Error decoding message: $e');
//       }
//     }, onDone: () {
//       clients.remove(channel);
//     }, onError: (error) {
//       print('Error in WebSocket stream: $error');
//       clients.remove(channel);
//     });
//   }

//   Future<void> onDataReceived(Map<String, dynamic> data) async {
//     if (!mounted) return;

//     if (data != null) {
//       //for (var order in _receivedData) {}
//       if (data['action'] == 'seat_tapped') {
//         sendDataToClients(data, clients);
//       } else if (data['action'] == 'seat_returned') {
//         sendDataToClients(data, clients);
//       }
//       setState(() {
//         _receivedData.add(data);
//       });
//       // sendDataToClients(data, clients);

//       if (data['action'] == 'updatePrinterItems') {
//         // Broadcast the updated printer data to all clients
//         sendDataToClients({
//           'action': 'updatePrinterItems',
//           'printer': data['printer'],
//         }, clients);
//       }
//       if (data['action'] == 'removePrinter') {
//         handleRemovePrinter(data, clients);
//       }
//     } else {
//       print("Error: Received null data in onDataReceived");
//     }
//   }

//   // Future<void> handleSeatTransfer(Map<String, dynamic> data) async {
//   //   print("🔁 handleSeatTransfer called");

//   //   final currentTable = data['currentTable'];
//   //   final currentSeat = data['currentSeat'];
//   //   final targetTable = data['targetTable'];
//   //   final targetSeat = data['targetSeat'];
//   //   final seathiveOrderId = data['seathiveOrderId'];

//   //   print("🟡 Attempting seat transfer for: $seathiveOrderId");

//   //   bool foundInMemory = false;

//   //   // First, try to update in-memory list (_receivedData)
//   //   for (var order in _receivedData) {
//   //     if (order['seathiveOrderId'] == seathiveOrderId) {
//   //       order['table'] = targetTable;
//   //       order['seat'] = targetSeat;
//   //       order['edit'] = "Yes";
//   //       order['seat_transfer'] = true;
//   //       foundInMemory = true;
//   //       print("✅ Found in _receivedData and updated");
//   //       break;
//   //     }
//   //   }

//   //   // Now check Hive (always check — it's your source of truth)
//   //   var orderBox = await Hive.openBox('ordersBox');
//   //   bool foundInHive = false;
//   //   for (int i = 0; i < orderBox.length; i++) {
//   //     var orderData = orderBox.getAt(i);

//   //     if (orderData is String) {
//   //       orderData = jsonDecode(orderData);
//   //     }

//   //     if (orderData['seathiveOrderId'] == seathiveOrderId) {
//   //       orderData['table'] = targetTable;
//   //       orderData['seat'] = targetSeat;
//   //       orderData['edit'] = "Yes";
//   //       orderData['seat_transfer'] = true;

//   //       await orderBox.putAt(i, orderData);
//   //       print("✅ Updated order in Hive");

//   //       // Add to memory if not already there
//   //       if (!foundInMemory) {
//   //         _receivedData.add(orderData);
//   //         print("✅ Added order to _receivedData");
//   //       }

//   //       foundInHive = true;
//   //       break;
//   //     }
//   //   }

//   //   if (foundInMemory || foundInHive) {
//   //     // Notify all clients
//   //     sendDataToClients({
//   //       'action': 'seat_transfer',
//   //       'currentTable': currentTable,
//   //       'currentSeat': currentSeat,
//   //       'targetTable': targetTable,
//   //       'targetSeat': targetSeat,
//   //       'seathiveOrderId': seathiveOrderId,
//   //     }, clients);

//   //     // Patch to server
//   //     final patched = await _syncService.patchOrderTableAndSeat(
//   //       seathiveOrderId,
//   //       targetTable,
//   //       targetSeat,
//   //     );

//   //     if (patched) {
//   //       print("✅ Patched seat transfer to server");
//   //     } else {
//   //       print("⚠️ Failed to patch to server");
//   //     }
//   //   } else {
//   //     print(
//   //         "❌ Order not found in memory or Hive for seathiveOrderId: $seathiveOrderId");
//   //   }
//   // }

//   Future<void> handlePatchOrderStatusBySeathiveOrderId(String seathiveOrderId,
//       String newStatus, String orderRemark, String preinvoiceTime) async {
//     print("🔧 handlePatchOrderStatusBySeathiveOrderId $seathiveOrderId");

//     bool dataUpdated = false;

//     // First try updating in-memory _receivedData
//     for (var order in _receivedData) {
//       print("patchorderstatusbyseathiveorderid.....$_receivedData");
//       print("🔍 Comparing with: ${order['seathiveOrderId']}");
//       if (order['seathiveOrderId'] == seathiveOrderId) {
//         order['status'] = newStatus;
//         order['orderRemark'] = orderRemark;
//         order['preinvoiceTime'] = preinvoiceTime;
//         order['edit'] = "Yes";
//         order['statusEdited'] = "true";
//         dataUpdated = true;
//         print("✅ Updated in _receivedData");
//         break;
//       }
//     }
//     if (!dataUpdated) {
//       final orderBox = await Hive.openBox('ordersBox');
//       // for (int i = 0; i < orderBox.length; i++) {
//       //   var orderData = orderBox.getAt(i);

//       //   if (orderData is String) {
//       //     orderData = jsonDecode(orderData);
//       //   }

//       //   if (orderData['seathiveOrderId'] == seathiveOrderId) {
//       //     // Update the fields
//       //     orderData['status'] = newStatus;
//       //     orderData['orderRemark'] = orderRemark;
//       //     orderData['preinvoiceTime'] = preinvoiceTime;
//       //     orderData['edit'] = "Yes";
//       //     orderData['statusEdited'] = "true";

//       //     await orderBox.putAt(i, orderData);
//       //     print("✅ Updated Hive with seathiveOrderId: $seathiveOrderId");

//       //     // Also add it to memory for future access
//       //     setState(() {
//       //       _receivedData.add(orderData);
//       //     });

//       //     dataUpdated = true;
//       //     break;
//       //   }
//       // }

//       for (int i = 0; i < orderBox.length; i++) {
//         var orderData = orderBox.getAt(i);
//         if (orderData['seathiveOrderId'] == seathiveOrderId) {
//           orderData['status'] = newStatus;
//           orderData['preinvoiceTime'] = preinvoiceTime;
//           orderData['edit'] = "Yes";
//           orderData['statusEdited'] = "true";
//           await orderBox.putAt(i, orderData);
//         }
//       }
//     }

//     if (dataUpdated) {
//       sendDataToClients({
//         'action': 'updateOrderStatus',
//         'seathiveOrderId': seathiveOrderId,
//         'status': newStatus,
//         'orderRemark': orderRemark,
//         'preinvoiceTime': preinvoiceTime,
//         'statusEdited': "true",
//         'edit': "Yes",
//       }, clients);
//       print("PreinvocienewStatus..  $newStatus");
//       await _syncService.patchEditedOrders();
//     } else {
//       print(
//           "❌ No matching orders found with seathiveOrderId: $seathiveOrderId");
//     }
//   }

//   Future<void> loginUser() async {
//     final loginProvider = Provider.of<LoginProvider>(context, listen: false);
//     loginProvider.setUserNameError("");
//     loginProvider.setPasswordError("");

//     userName = _userNameController.text.trim();
//     final password = _passwordController.text.trim();

//     if (userName.isEmpty) {
//       loginProvider.setUserNameError('Please enter a username');
//     }
//     if (password.isEmpty) {
//       loginProvider.setPasswordError('Please enter a password');
//     }
//     if (serverFound) {
//       final isAlive = await isServerReachable(serverip, 8383);
//       if (isAlive) {
//         proceedToDashboard();
//       } else {
//         print("Server IP exists but not reachable. Discovering again...");
//         await discoverServerAndHandle();
//       }
//     } else {
//       await discoverServerAndHandle();
//     }

//     // Provider.of<OrderProvider>(context, listen: false).requestDataFromServer();
//     // Navigator.pushAndRemoveUntil(
//     //   context,
//     //   MaterialPageRoute(builder: (context) => const DashboardScreen()),
//     //   (Route<dynamic> route) => false, // Removes all previous routes
//     // );
//     // if (loginProvider.userNameError == null &&
//     //     loginProvider.passwordError == null) {
//     //   bool isValid =
//     //       await loginProvider.validateCredentials(userName, password);

//     //   if (isValid) {
//     //     var box = await Hive.openBox('deviceData');
//     //     String deviceCode = box.get('deviceCode') ?? '';

//     //     Provider.of<WebSocketService>(context, listen: false)
//     //         .sendDeviceCodeToServer(deviceCode);
//     //     Provider.of<OrderProvider>(context, listen: false)
//     //         .requestDataFromServer();

//     //     // ignore: use_build_context_synchronously
//     //     Navigator.pushAndRemoveUntil(
//     //       context,
//     //       MaterialPageRoute(builder: (context) => const TableScreen()),
//     //       (Route<dynamic> route) => false, // Removes all previous routes
//     //     );
//     //   } else {
//     //     loginProvider.setUserNameError('Invalid username or password');
//     //     loginProvider.setPasswordError('Invalid username or password');
//     //   }
//     // }
//   }

//   void proceedToDashboard() {
//     Provider.of<OrderProvider>(context, listen: false).requestDataFromServer();

//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(builder: (context) => const TableScreen()),
//       (Route<dynamic> route) => false,
//     );
//   }

//   Future<void> discoverServerAndHandle() async {
//     final udp = await UDP.bind(Endpoint.any());

//     udp.send(
//       utf8.encode('WHO_IS_SERVER'),
//       Endpoint.broadcast(port: const Port(45678)),
//     );

//     final serverBox = await Hive.openBox('serverBox');

//     bool found = false;

//     await for (final datagram
//         in udp.asStream(timeout: const Duration(seconds: 2))) {
//       if (datagram != null) {
//         final message = utf8.decode(datagram.data);
//         if (message.startsWith('SERVER:')) {
//           final parts = message.split(':');
//           final ip = parts[1];
//           final port = parts[2];

//           await serverBox.put('serverIp', ip);
//           await serverBox.put('serverPort', port);
//           serverip = ip;

//           setState(() {
//             serverFound = true;
//           });

//           found = true;
//           udp.close();
//           print("proceedToDashboard1.....");
//           proceedToDashboard();
//           print("proceedToDashboard1.....");

//           break;
//         }
//       }
//     }

//     if (!found) {
//       udp.close();
//       // No server found, show dialog
//       // ignore: use_build_context_synchronously
//       showDialog(
//         context: context,
//         builder: (_) => NoServerDialog(
//           onMakeServer: () async {
//             Navigator.of(context).pop(); // close dialog

//             final ip = await getLocalIp();
//             if (ip != null) {
//               final box = await Hive.openBox('serverBox');
//               await box.put('serverIp', ip);
//               await box.put('serverPort', port);
//               final configBox = HiveManagerKot().configBox;
//               appType = 'server';
//               await configBox.put('appType', 'server');

//               serverip = ip;
//               setState(() {
//                 serverFound = true;
//               });

//               await startUdpResponder(ip, udpPort);
//               startServer(clients, onDataReceived);

//               proceedToDashboard();
//             }
//           },
//         ),
//       );
//     }
//   }

//   // void startServerInBackground() async {
//   //   bool isRunning = await FlutterForegroundTask.isRunningService;
//   //   if (!isRunning) {
//   //     FlutterForegroundTask.startService(
//   //       notificationTitle: 'Server Running',
//   //       notificationText: 'Listening for clients...',
//   //       callback: startCallback,
//   //     );
//   //   }
//   // }

//   // void startCallback() {
//   //   FlutterForegroundTask.setTaskHandler(MyForegroundTaskHandler());
//   // }

//   @override
//   Widget build(BuildContext context) {
//     final loginProvider = Provider.of<LoginProvider>(context);

//     return Scaffold(
//       backgroundColor: const Color(0xFFFAF8F0),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.only(top: 20.0),
//           child: Column(
//             children: [
//               SizedBox(
//                 width: double.infinity,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.center,
//                   children: <Widget>[
//                     Image.asset(
//                       'assets/bestmummy.png',
//                       height: 150,
//                       width: 150,
//                     ),
//                     Image.asset(
//                       'assets/kotLogin.png',
//                       height: 280,
//                       width: 280,
//                     ),
//                     const SizedBox(height: 30),
//                     SizedBox(
//                       width: 280,
//                       child: TextFormField(
//                         controller: _userNameController,
//                         decoration: InputDecoration(
//                           filled: true,
//                           fillColor: const Color(0xFFE0F7FA),
//                           labelText: 'Username',
//                           errorText: loginProvider.userNameError,
//                           labelStyle: const TextStyle(
//                             fontSize: 18,
//                             color: Color(0xFF00695C),
//                           ),
//                           border: const OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide: BorderSide.none,
//                           ),
//                           prefixIcon: const Icon(
//                             Icons.account_circle,
//                             color: Color(0xFF00695C),
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                             vertical: 20,
//                             horizontal: 20,
//                           ),
//                         ),
//                       ),
//                     ),
//                     const SizedBox(height: 20),
//                     SizedBox(
//                       width: 280,
//                       child: TextFormField(
//                         controller: _passwordController,
//                         decoration: InputDecoration(
//                           filled: true,
//                           fillColor: const Color(0xFFE0F7FA),
//                           labelText: 'Password',
//                           errorText: loginProvider.passwordError,
//                           labelStyle: const TextStyle(
//                             fontSize: 18,
//                             color: Color(0xFF00695C),
//                           ),
//                           border: const OutlineInputBorder(
//                             borderRadius: BorderRadius.all(Radius.circular(12)),
//                             borderSide: BorderSide.none,
//                           ),
//                           prefixIcon: const Icon(
//                             Icons.vpn_key,
//                             color: Color(0xFF00695C),
//                           ),
//                           contentPadding: const EdgeInsets.symmetric(
//                             vertical: 20,
//                             horizontal: 20,
//                           ),
//                         ),
//                         obscureText: true,
//                       ),
//                     ),
//                     const SizedBox(height: 30),
//                     Center(
//                       child: ElevatedButton(
//                         onPressed: () {
//                           //                      Navigator.pushAndRemoveUntil(
//                           //   context,
//                           //   MaterialPageRoute(builder: (context) => TableScreen()),
//                           //   (Route<dynamic> route) => false, // Removes all previous routes
//                           // );
//                           loginUser();
//                         },
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: const Color(0xFFE0F7FA),
//                           foregroundColor: Colors.black,
//                           padding: const EdgeInsets.symmetric(
//                               horizontal: 50, vertical: 15),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                         child: const Text(
//                           'LogIn',
//                           style: TextStyle(
//                             fontSize: 18,
//                             color: Color(0xFF00695C),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
