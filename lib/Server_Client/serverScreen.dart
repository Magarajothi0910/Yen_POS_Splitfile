import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:udp/udp.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';

import 'package:yenpos/Global/global_data_manager.dart';
import 'package:yenpos/Global/globals_data.dart';
import 'package:yenpos/Global/globals_data.dart' as globals;
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Mode_page/choose_mode_screen.dart';
import 'package:yenpos/Server_Client/handlers/invoice_handler.dart';
import 'package:yenpos/Server_Client/hive_service.dart';
import 'package:yenpos/Server_Client/makethisdeviceas%20server_Dialog.dart';
import 'package:yenpos/Server_Client/sendDataToClients.dart';
import 'package:yenpos/Server_Client/serverreachable.dart';
import 'package:yenpos/Server_Client/startServers.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart';
import 'package:yenpos/Server_Client/sync_service.dart';
import 'package:yenpos/background_task/background_permission_guard.dart';
import 'package:yenpos/background_task/flutter_foreground_task.dart';

import 'package:yenpos/loginPage/provider/loginPageProvider.dart';
import 'package:yenpos/shift_managment_page/openshift/open_shift.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final List<Map<String, dynamic>> _receivedData = [];
  List<Map<String, dynamic>> _invoiceData = []; // List to store invoice data
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  WebSocketChannel? channel;
  Set<WebSocketChannel> clients = {};
  List<Map<String, dynamic>> orders = [];
  final SyncService _syncService1 = SyncService();
  Set<String> sentPatchOrders = {};
  final SyncService _syncService = SyncService();
  Timer? _syncTimer;
  Timer? _patchCheckTimer;
  List<String> logs = [];
  String serverPort = "Unknown";
  late Box box;
  bool serverFound = false;
  String status = 'Searching for server...';
  //saleorders

  late Box saleOrderBox;
  late Box saleOrderNumber;

  late Box invoiceBox;

  late Box holdOrderBox;
  Timer? _approvalCheckTimer;
  Map<String, dynamic>? paymentDetails;
  int _sendDataToClientsCount = 0;
  final TextEditingController _advanceController = TextEditingController();
  bool placeOrderCliked = false;
  bool showPaymentScreen = false;
  final Set<String> _processedMessageIds = {};
  //saleorder
  @override
  initState() {
    super.initState();
    // HiveManager().invoices.then((_) => _loadInvoices());
    // HiveManager().posInvoiceBox; // Just to ensure it's initialized
    // HiveManager().tableStatusBox; // Just to ensure it's initialized
    _openBoxes();
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      SyncService();
      _syncService.syncUnsyncedSaleOrders();
      // _syncService.syncUnsyncedInvoices(clients: clients);
      _syncService.syncUnsyncedInvoices();

      _syncService.syncUnsyncedHoldOrders();
    });
    // Provider.of<LoginProvider>(context, listen: false).fetchAndStoreLoginData();

    _approvalCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      checkPendingApprovals(saleOrderBox);
      chequePendingDiscountApproval(holdOrderBox);
    });
    _syncTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _syncService.syncUnsyncedSaleOrders();
      // _syncService.syncUnsyncedInvoices();
      _syncService.syncUnsyncedInvoices();
      _syncService.syncPendingPatches();
      _syncService.syncUnsyncedHoldOrders();
    });

    checkIfServerWasPreviouslyStored();
    // discoverServerAndHandle();
  }

  Future<void> _openBoxes() async {
    invoiceBox = await Hive.openBox('invoices');
    Hive.openBox('salesOrders');
    saleOrderBox = await Hive.openBox('saleOrderBox');
    saleOrderNumber = await Hive.openBox("salesOrderNumberBox");
    holdOrderBox = await Hive.openBox('holdOrders');
    await Hive.openBox('salesOrderNumberBox');
    await Hive.openBox('holdOrders');

    Hive.openBox('salesApprovalOrder');
    Hive.openBox('saleOrderModifyOrders');

    setState(() {});
  }

  String generateSalesOrderId(String branchCode, int sequenceNumber) {
    final yearSuffix = DateFormat('yy').format(DateTime.now());
    final sequenceStr = sequenceNumber.toString().padLeft(4, '0');
    return 'SO$branchCode$yearSuffix$sequenceStr';
  }

  Future<String?> fetchNextSalesOrderNumberFromHive(String prefix) async {
    // Open Hive box
    final saleOrderNumberBox = await Hive.openBox('salesOrderNumberBox');

    // Get all stored numbers
    final List<String> allNumbers = saleOrderNumberBox.values
        .expand((e) => e is List ? e.map((x) => x.toString()) : [e.toString()])
        .toList();

    // If no existing numbers, start fresh
    if (allNumbers.isEmpty) {
      final newNumber = '${prefix}0001';
      await saleOrderNumberBox.add(newNumber);
      return newNumber;
    }

    // Get the last stored number
    final String lastOrderNumber = allNumbers.last;

    // Extract numeric part correctly (ignore extra prefix inside number)
    String numericPart = '';
    if (lastOrderNumber.startsWith(prefix)) {
      numericPart = lastOrderNumber.substring(prefix.length);
    } else {
      // fallback: extract last numeric sequence
      final match = RegExp(r'(\d+)$').firstMatch(lastOrderNumber);
      numericPart = match?.group(1) ?? '0';
    }

    // Convert to int and increment
    final int lastCount = int.tryParse(numericPart) ?? 0;
    final int nextCount = lastCount + 1;

    // Pad to 4 digits
    final String formattedNumber = nextCount.toString().padLeft(4, '0');

    // ✅ Correct format: prefix + 4-digit count
    final String newOrderNumber = '$prefix$formattedNumber';

    // Save in Hive
    await saleOrderNumberBox.add(newOrderNumber);

    return newOrderNumber;
  }

  Future<String?> fetchNextInvoiceOrderNumberFromHive(String prefix) async {
    // Open the Hive box for sales orders
    final invoiceBox = await Hive.openBox('invoices');

    // Get the current count for the prefix or initialize it to 250000
    final currentCount = invoiceBox.get(prefix) ?? 0000;

    // Increment to get the next count
    final nextCount = currentCount + 1;

    // Save the updated count back to Hive
    await invoiceBox.put(prefix, nextCount);

    // Format the numeric part with leading zeros to ensure it is always six digits
    final formattedNumber = nextCount.toString().padLeft(4, '0');

    // Return the new sales order number in the format "prefix + formattedNumber"
    return '$prefix$formattedNumber';
  }

  int sendDataToClientsCallCount = 0;

  Future<void> handlePatchSaleOrder(Map<String, dynamic> data) async {
    final String soNo = data['saleOrderNo'] ?? '';

    // Open Hive Box
    var saleOrderBox = await Hive.openBox('saleOrderBox');

    // Find matching entry in Hive
    String? targetKey;
    Map<String, dynamic>? existingData;
    for (final entry in saleOrderBox.toMap().entries) {
      final orderData = entry.value['data'];
      if (orderData is Map && orderData['saleOrderNo'] == soNo) {
        targetKey = entry.key.toString();
        existingData = Map<String, dynamic>.from(entry.value);
        break;
      }
    }

    if (targetKey == null || existingData == null) {
      return;
    }

    // Merge patchData into existingData
    final Map<String, dynamic> patchData = Map<String, dynamic>.from(
      data['data'] ?? {},
    );
    final Map<String, dynamic> existingOrderData = Map<String, dynamic>.from(
      existingData['data'] ?? {},
    );

    existingOrderData.addAll(patchData);
    existingData['data'] = existingOrderData;

    await saleOrderBox.put(targetKey, existingData);

    sendDataToClients({
      'action': 'patchsaleorderGenerated',
      'saleOrderNo': soNo,
      'patchSaleOrder': existingData,
    }, clients);

    sendDataToClientsCallCount++;

    try {
      bool success = await _syncService.patchSalesOrder(soNo, existingData);

      if (success) {
        existingData['sync'] = "Yes";
        await saleOrderBox.put(targetKey, existingData);
      } else {}
    } catch (e) {}
  }

  Future<void> handlePatchHoldOrder(Map<String, dynamic> data) async {
    final salesOrderId = data['holdOrderId'];
    final patchData = data['data'];
    final deviceName = data['deviceName'];
    final type = data['type'];
    final sync = data['sync'];
    final edit = data['edit'];
    final waitingForApprovalResult = data['waitingForApprovalResult'];
    String soNo = data['holdOrderId'];

    dynamic targetKey;

    for (final entry in holdOrderBox.toMap().entries) {
      dynamic orderData;
      if (entry.value is Map) {
        final mapValue = entry.value as Map;
        if (mapValue.containsKey('data')) {
          orderData = mapValue['data'];
        } else if (mapValue.containsKey('holdOrderId')) {
          orderData = mapValue;
        }
      } else if (entry.value is List) {
        if (entry.value.isNotEmpty && entry.value[0] is Map) {
          orderData = entry.value[0];
        }
      }

      if (orderData != null) {
        if (orderData is Map && orderData['holdOrderId'] != null) {
          if (orderData['holdOrderId'].toString() == soNo.toString()) {
            targetKey = entry.key;
            break;
          }
        } else if (orderData is List &&
            orderData.isNotEmpty &&
            orderData[0] is Map &&
            orderData[0]['holdOrderId'] != null) {
          if (orderData[0]['holdOrderId'].toString() == soNo.toString()) {
            targetKey = entry.key;
            break;
          }
        }
      }
    }

    if (targetKey == null) {
      for (final entry in holdOrderBox.toMap().entries) {
        dynamic orderData;
        if (entry.value is Map) {
          final mapValue = entry.value as Map;
          if (mapValue.containsKey('data')) {
            orderData = mapValue['data'];
          } else if (mapValue.containsKey('holdOrderId')) {
            orderData = mapValue;
          }
        } else if (entry.value is List && entry.value.isNotEmpty) {
          orderData = entry.value[0];
        }
        if (orderData != null) {
          if (orderData is Map && orderData.containsKey('holdOrderId')) {
          } else if (orderData is List &&
              orderData.isNotEmpty &&
              orderData[0] is Map &&
              orderData[0].containsKey('holdOrderId')) {}
        }
      }
      return;
    }

    try {
      final existingOrder = holdOrderBox.get(targetKey);
      if (existingOrder == null) {
        return;
      }

      Map<String, dynamic> updatedOrder = Map<String, dynamic>.from(
        existingOrder,
      );

      if (updatedOrder.containsKey('data')) {
        if (updatedOrder['data'] is List && updatedOrder['data'].isNotEmpty) {
          List<dynamic> dataList = List.from(updatedOrder['data']);
          if (dataList[0] is Map) {
            Map<String, dynamic> orderData = Map.from(dataList[0]);
            orderData.addAll(patchData);
            dataList[0] = orderData;
            updatedOrder['data'] = dataList;
          }
        } else if (updatedOrder['data'] is Map) {
          Map<String, dynamic> orderData = Map.from(updatedOrder['data']);
          orderData.addAll(patchData);
          updatedOrder['data'] = orderData;
        }
      } else {
        updatedOrder.addAll(patchData);
      }

      updatedOrder.addAll({
        'deviceName': deviceName,
        'type': type,
        'sync': sync,
        'edit': edit,
        'waitingForApprovalResult': waitingForApprovalResult ?? 'Yes',
        'saleOrderNo': soNo,
      });

      await holdOrderBox.put(targetKey, updatedOrder);

      sendDataToClients({
        'action': 'patchholdorderGenerated',
        'patchHoldOrder': data,
      }, clients);

      sendDataToClientsCallCount++;

      try {
        bool success = await _syncService.patchSalesOrder(
          salesOrderId, // 🔹 first argument (String)
          {
            'data': patchData,
            'deviceName': deviceName,
            'type': type,
            'sync': sync,
            'edit': edit,
            'waitingForApprovalResult': waitingForApprovalResult,
          }, // 🔹 second argument (Map)
        );

        if (success) {
          updatedOrder['sync'] = true;
          await holdOrderBox.put(targetKey, updatedOrder);
        } else {}
      } catch (e) {}
    } catch (e) {
      rethrow;
    }
  }

  // Helper function to debug Hive box structure
  void debugHiveBoxStructure() {
    final boxMap = holdOrderBox.toMap();

    boxMap.entries.forEach((entry) {
      if (entry.value is Map) {
        final map = entry.value as Map;

        if (map.containsKey('data')) {
          if (map['data'] is List) {}
        }
      }
    });
  }

  Future<void> handleOpenSaleOrder(Map<String, dynamic> data) async {
    // Extract the sales order data (nested or top-level)
    final salesOrder = data['data'] ?? data;

    // Determine the prefix for the sales order number
    String prefix =
        salesOrder['saleOrderNo']?.toString().trim() ??
        salesOrder['branchAlias']?.toString().trim() ??
        "SOSB";

    // Get new sales order number from API/Hive
    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);
    if (newSalesOrderNo == null) {
      return;
    }

    // Clean and update the sales order number
    final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
    salesOrder['saleOrderNo'] = cleanSalesOrderNo;

    // Save the order locally
    await savePosSaleOrderToHive(data, saleOrderBox);

    // Notify clients with updated order number
    sendDataToClients({
      'action': 'OpSalesOrderGenerated',
      'opSalesOrder': data, // now includes updated saleOrderNo
    }, clients);
    _sendDataToClientsCount++;

    // Post to API

    bool success = await _syncService.postSalesOrder({
      "data": [salesOrder],
    });

    if (success) {
    } else {}
  }

  Future<void> handleSaleOrder(Map<String, dynamic> data) async {
    // Extract the sales order data (nested or top-level)
    final salesOrder = data['data'] ?? data;

    // Determine the prefix for the sales order number
    String prefix =
        salesOrder['saleOrderNo']?.toString().trim() ??
        salesOrder['aliasName']?.toString().trim() ??
        "SOSB";

    // Get new sales order number from API/Hive
    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);

    if (newSalesOrderNo == null) {
      return;
    }

    // Clean and update the sales order number
    final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
    salesOrder['saleOrderNo'] = cleanSalesOrderNo;

    // Save the order locally (initial save as unsynced)
    await savePosSaleOrderToHive(data, saleOrderBox);

    // Notify clients with updated order number
    sendDataToClients({
      'action': 'salesOrderGenerated',
      'salesOrder': data, // now includes updated saleOrderNo
    }, clients);
    _sendDataToClientsCount++;

    // Post to API
    bool success = await _syncService.postSalesOrder({
      "data": [salesOrder],
    });

    if (success) {
      // ✅ Mark this order as synced in Hive
      data["sync"] = "Yes"; // add sync flag
      await saleOrderBox.put(cleanSalesOrderNo, data);
    } else {}
  }

  Future<void> handleInvoiceOrder(Map<String, dynamic> data) async {
    // Extract the sales order data (nested or top-level)
    final salesOrder = data['data'] ?? data;

    // Determine the prefix for the sales order number
    String prefix =
        salesOrder['saleOrderNo']?.toString().trim() ??
        salesOrder['branchAlias']?.toString().trim() ??
        "SOSB";

    // Get new sales order number from API/Hive
    final newSalesOrderNo = await fetchNextInvoiceOrderNumberFromHive(prefix);
    if (newSalesOrderNo == null) {
      return;
    }

    // Clean and update the sales order number
    final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
    salesOrder['saleOrderNo'] = cleanSalesOrderNo;

    // Save the order locally
    await savePosInvoiceOrderToHive(data, saleOrderBox);

    // Notify clients with updated order number
    sendDataToClients({
      'action': 'invoiceGenerated',
      'invoice': data, // now includes updated saleOrderNo
    }, clients);
    _sendDataToClientsCount++;

    // Post to API

    bool success = await _syncService.postInvoiceOrder({
      "data": [salesOrder],
    });

    if (success) {
    } else {}
  }

  void handleModifyOrder(Map<String, dynamic> data) async {
    // Notify connected clients about the new sales order.
    sendDataToClients({
      'action': 'modifyOrderGenerated',
      'modifyOrder': data,
    }, clients);

    // Save the sales order locally.
    await saveModifyOrderToHive(data);

    // If the sales order data contains a nested "data" key,
    // extract it. Otherwise, fallback to the original data.
    final modifyOrder = data['data'] ?? data;

    // Post the flattened sales order to the FastAPI endpoint.
    bool success = await _syncService.postModifyOrder({
      "data": [modifyOrder],
    });

    if (success) {
    } else {}
  }

  void handleDiscountApprovalOrder(Map<String, dynamic> data) async {
    // Notify connected clients about the new sales order.
    sendDataToClients({
      'action': 'modifyOrderGenerated',
      'modifyOrder': data,
    }, clients);

    // Save the sales order locally.
    await saveModifyOrderToHive(data);

    // If the sales order data contains a nested "data" key,
    // extract it. Otherwise, fallback to the original data.
    final modifyOrder = data['data'] ?? data;

    // Post the flattened sales order to the FastAPI endpoint.
    bool success = await _syncService.postModifyOrder({
      "data": [modifyOrder],
    });

    if (success) {
    } else {}
  }

  Future<void> saveToApproveOrderToHive(Map<String, dynamic> data) async {
    // Save the sales approval order to the Hive database
    var modifyOrdersBox = await Hive.openBox('salesOrderToApprove');
    await modifyOrdersBox.add(data);
  }

  // Define a method to handle adding a customer to a sales order.
  Future<void> saveSalesOrderAddCustomerToHive(
    Map<String, dynamic> customerData,
  ) async {
    var customerBox = await Hive.openBox('customerBox');
    final String? mobile = customerData['mobile'];

    if (mobile == null) {
      return;
    }

    // ── Check for duplicates ──
    final exists = customerBox.values.any((customer) {
      final existing = Map<String, dynamic>.from(customer);
      return existing['mobile'] == mobile;
    });

    if (exists) {
      return;
    }

    // ── Save new customer ──
    await customerBox.add(customerData);
  }

  void handleSalesOrderAddCustomer(Map<String, dynamic> data) async {
    // ── Save locally (with duplicate check)
    await saveSalesOrderAddCustomerToHive(data);

    // ── Extract fields for API sync
    final String? name = data['name'] as String?;
    final String? mobile = data['mobile'] as String?;
    final String? branch = data['branchId'] as String?;

    if (name == null || mobile == null) {
      return;
    }

    // ── broadcast to clients
    sendDataToClients({
      'action': 'salesOrderAddCustomerGenerated',
      'salesOrderAddCustomer': data,
    }, clients);

    final success = await _syncService.postAddNewCustomerOrder(
      name: name,
      mobile: mobile,
      branchId: branch,
    );

    if (success) {
    } else {}
  }

  void handleToApproveOrder(Map<String, dynamic> data) async {
    // Notify connected clients about the new sales order.

    // Save the sales order locally.
    await saveToApproveOrderToHive(data);

    // If the sales order data contains a nested "data" key,
    // extract it. Otherwise, fallback to the original data.
    final modifyOrder = data['data'] ?? data;

    sendDataToClients({
      'action': 'toApproveOrderGenerated',
      'toApproveOrder': data,
    }, clients);

    // Post the flattened sales order to the FastAPI endpoint.
    bool success = await _syncService.postToApproveOrder({
      "data": [modifyOrder],
    });

    if (success) {
    } else {}
  }

  Future<void> handleHoldOrder(Map<String, dynamic> data) async {
    print('🟢 handleHoldOrder() triggered...');

    try {
      if (data.isEmpty) {
        print('⚠️ Received empty hold order data.');
        return;
      }

      // Step 1: Extract holdOrderId safely
      String cleanHoldOrderId = 'UNKNOWN_HOLD_ORDER';
      if (data['data'] != null &&
          data['data'] is List &&
          data['data'].isNotEmpty) {
        cleanHoldOrderId =
            data['data'][0]['holdOrderId'] ?? 'UNKNOWN_HOLD_ORDER';
      } else if (data['holdOrderId'] != null) {
        cleanHoldOrderId = data['holdOrderId'];
      }
      print('🆔 Processing Hold Order ID: $cleanHoldOrderId');

      // Step 2: Save to Hive
      print('💾 Saving Hold Order to Hive...');
      await saveHoldOrderToHive(data, holdOrderBox);
      print('✅ Hold Order saved successfully in Hive.');
      _syncService.saveHoldToHive(data, holdOrderBox);

      // Step 3: Extract first hold order map
      final holdOrder =
          (data['data'] != null &&
              data['data'] is List &&
              data['data'].isNotEmpty)
          ? data['data'][0]
          : data;
      print('📦 Extracted hold order payload: ${holdOrder.toString()}');

      // Step 4: Notify clients
      print('📡 Broadcasting hold order to connected clients...');
      sendDataToClients({
        'action': 'holdOrderGenerated',
        'holdOrder': data,
      }, clients);
      print('✅ holdOrderGenerated event sent to clients.');

      // Step 5: Post to FastAPI
      print('🚀 Sending Hold Order to FastAPI for sync...');
      bool success = await _syncService.postToHoldOrder({
        "data": [holdOrder],
      });

      // Step 6: Update Sync Status
      if (success) {
        print('✅ Hold Order synced successfully with FastAPI.');
        data["sync"] = "Yes";
        await holdOrderBox.put(cleanHoldOrderId, data);
        print('💾 Hive updated: Hold Order marked as synced.');
      } else {
        print('❌ Failed to sync Hold Order with FastAPI.');
      }
    } catch (e, st) {
      print('❌ Error in handleHoldOrder(): $e');
      print(st);
    } finally {
      print('🏁 handleHoldOrder() completed.\n');
    }
  }

  void handleSalesApprovalOrder(Map<String, dynamic> data) async {
    final salesOrder = data['data'] ?? data;
    await saveSalesApprovalOrderToHive(data);
    sendDataToClients({
      'action': 'salesApprovalOrderGenerated',
      'salesApprovalOrder': data,
    }, clients);
    bool success = await _syncService.postDiscountOrder({
      "data": [salesOrder],
    });

    if (success) {
    } else {}
  }

  Future<void> saveSalesApprovalOrderToHive(Map<String, dynamic> data) async {
    var box = await Hive.openBox('salesApprovalOrder');
    await box.add(data);
  }

  Future<void> checkIfServerWasPreviouslyStored() async {
    final serverBox = HiveManager().serverBox;
    final configBox = HiveManager().configBox;

    // Force everything to String
    final rawIp = serverBox?.get('serverIp', defaultValue: '');
    final rawPort = serverBox?.get('serverPort', defaultValue: '');
    final savedIp = rawIp?.toString() ?? '';
    final savedPort = rawPort?.toString() ?? '';

    if (savedIp.isNotEmpty && savedPort.isNotEmpty) {
      final localIp = await getLocalIp();
      serverip = savedIp;
      serverPort = savedPort;

      if (localIp == savedIp) {
        appType = 'server';
        await configBox.put('appType', 'server');

        Provider.of<ItemProvider>(
          context,
          listen: false,
        ).fetchDataIfNeeded(branchAlias: 'AR');
      } else {
        appType = 'client';
        await configBox.put('appType', 'client');
      }
      setState(() => serverFound = true);
    }
    // else {
    //   setState(() => serverFound = false);
    //   appType = 'client';
    //   await configBox.put('appType', 'client');
    // }
  }

  void startServer(
    Set<WebSocketChannel> clients,
    Function(Map<String, dynamic>) onDataReceived,
  ) async {
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 8383);

      server.transform(WebSocketTransformer()).listen((WebSocket socket) {
        handleWebSocket(socket, clients, onDataReceived);
      });
    } catch (e) {}
  }

  Map<String, String> seathiveOrderIds = {};

  void handleWebSocket(
    WebSocket socket,
    Set<WebSocketChannel> clients,
    Function(Map<String, dynamic>) onDataReceived,
  ) {
    this.channel = IOWebSocketChannel(socket);
    clients.add(this.channel!);
    // final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    // Map for handling messages triggered by the 'action' field
    final Map<String, Future<void> Function(Map<String, dynamic>)>
    actionHandlers = {
      'hello': (data) async {
        channel!.sink.add(
          jsonEncode({
            'action': 'response',
            'message': 'Hello Client, message received!',
          }),
        );
      },

      'requestBranchwiseItems': (data) async {
        try {
          // Get the saved branchwiseItems data from your global data manager
          final savedData = GlobalDataManager().branchwiseItems;

          if (savedData == null) {
            // No data saved yet, send an error message or empty data
            channel!.sink.add(
              jsonEncode({
                'action': 'branchwiseItemsError',
                'message': 'No branchwise items data available.',
              }),
            );
            return;
          }

          // Send the raw saved data directly, no alias or filtering
          channel!.sink.add(
            jsonEncode({
              'action': 'branchwiseItems',
              // optionally send a timestamp or some meta info if needed
              'data': savedData,
            }),
          );
        } catch (e) {
          channel!.sink.add(
            jsonEncode({
              'action': 'branchwiseItemsError',
              'message': 'Failed to send branchwise items.',
            }),
          );
        }
        ;
      },

      'heartbeat': (data) async {
        channel!.sink.add(jsonEncode({'action': 'heartbeatAck'}));
      }, // inside your handleWebSocket(...) where you build actionHandlers:

      'seat_tapped': (data) async {
        sendDataToClients(data, clients);
      },
      'seat_returned': (data) async {
        sendDataToClients(data, clients);
      },

      'newClientConnected': (data) async {
        await handleNewClientConnected(data, channel!);
      },

      'reverseCancelOrderItem': (data) async {
        final hiveOrderId = data['hiveOrderId'];
        final int updatedIndex = data['updatedIndex'];
        final double updatedQty = (data['updatedQuantity'] as num).toDouble();
        final double updatedCancelledQty = (data['updatedCancelledQty'] as num)
            .toDouble();
        final double totalAmount = (data['totalAmount'] as num).toDouble();
        final bool partiallycancelled = data['partiallycancelled'] == true;

        // Notify clients
        sendDataToClients({
          'action': 'reverseCancelOrderItem',
          'hiveOrderId': hiveOrderId,
          'updatedIndex': updatedIndex,
          'updatedQuantity': updatedQty,
          'updatedCancelledQty': updatedCancelledQty,
          'totalAmount': totalAmount,
          'partiallycancelled': partiallycancelled,
        }, clients);
      },
      'updatePrinterItems': (data) async {
        final printer = data['printer'];
        final printerName = printer['name'];
        final updatedItems = printer['items'];

        bool printerFound = false;
        for (var entry in _receivedData) {
          if (entry['action'] == 'printerDetails' &&
              entry['name'] == printerName) {
            entry['items'] =
                updatedItems; // Update the items for the matched printer
            printerFound = true;
            break;
          }
        }

        if (!printerFound) {
          _receivedData.add({
            'action': 'printerDetails',
            'name': printerName,
            'ipAddress': printer['ipAddress'],
            'type': printer['type'],
            'items': updatedItems,
            'orderSource': printer['orderSource'],
          });
        } else {}

        // Save the updated printer details to Hive
        await savePrinterDetailsToHive({
          'action': 'printerDetails',
          'name': printerName,
          'ipAddress': printer['ipAddress'],
          'type': printer['type'],
          'items': updatedItems,
          'orderSource': printer['orderSource'],
        });

        // Broadcast the updated printer details to all clients
        sendDataToClients({
          'action': 'updatePrinterItems',
          'printer': {
            'name': printerName,
            'ipAddress': printer['ipAddress'],
            'type': printer['type'],
            'items': updatedItems,
          },
        }, clients);
      },

      'printerDetails': (data) async {
        await savePrinterDetailsToHive(data);
        _receivedData.add(data);
        sendDataToClients(data, clients);
      },
    };

    // Map for handling messages triggered by the 'type' field
    final Map<String, Future<void> Function(Map<String, dynamic>)>
    typeHandlers = {
      'invoice': (data) async {
        handleInvoice(data, clients);
      },
      'opSalesOrder': (data) async {
        handleOpenSaleOrder(data);
      },
      'posInvoice': (data) async {
        handleInvoice(data, clients);
      },
      'salesOrder': (data) async {
        handleSaleOrder(data);
      },
      'patchSaleOrder': (data) async {
        handlePatchSaleOrder(data);
      },
      'patchHoldOrder': (data) async {
        handlePatchHoldOrder(data);
      },
      'postToApprove': (data) async {
        handleToApproveOrder(data);
      },
      'modifySaleOrder': (data) async {
        handleModifyOrder(data);
      },
      'cancelOrder': (data) async {
        handlePatchSaleOrder(data);
      },
      'holdOrder': (data) async {
        print("hold order data: $data");
        handleHoldOrder(data);
      },
      'salesApprovalOrder': (data) async {
        handleSalesApprovalOrder(data);
      },
      'newCustomer': (data) async {
        handleSalesOrderAddCustomer(data);
      },
      'paymentDetails': (data) async {
        paymentDetails = data;
        _advanceController.text = data['advance'].toString();
        // notifyListeners(); // Notify listeners about the state change
      },
      'placeOrderCliked': (data) async {
        showPaymentScreen = true;
        // notifyListeners(); // Notify listeners about the state change
      },
      'serverAliveRequest': (data) async {
        final payload = {
          'action': 'serverAliveResponse',
          'message': 'Server is alive and running!',
        };
        channel!.sink.add(jsonEncode(payload));
      },
      'stockFromDispatch': (data) async {
        try {
          // Extract branch alias with fallback default
          final branchAlias = (data['branches'] as String?)?.trim() ?? 'AR';
          if (branchAlias.isEmpty) {
            return;
          }

          // Extract dynamic lists safely
          final varianceCodesDynamic = data['varianceCode'] as List<dynamic>?;
          final varianceNamesDynamic = data['varianceNames'] as List<dynamic>?;
          final stockUpdatesDynamic = data['stockUpdates'] as List<dynamic>?;

          // Validate all required fields are present
          if (varianceCodesDynamic == null ||
              varianceNamesDynamic == null ||
              stockUpdatesDynamic == null) {
            return;
          }

          // Validate equal length
          final len = varianceCodesDynamic.length;
          if (varianceNamesDynamic.length != len ||
              stockUpdatesDynamic.length != len) {
            return;
          }

          // Convert to typed lists with trimming
          final varianceCodes = varianceCodesDynamic
              .map((e) => e.toString().trim())
              .toList();
          final varianceNames = varianceNamesDynamic
              .map((e) => e.toString().trim())
              .toList();
          final stockUpdates = stockUpdatesDynamic.map((e) {
            final qty = int.tryParse(e.toString());
            return qty ?? 0;
          }).toList();

          // Validate stockUpdates values are positive integers
          for (int i = 0; i < stockUpdates.length; i++) {
            if (stockUpdates[i] <= 0) {
              return;
            }
          }

          // Debug print all inputs before update

          // Call your stock update method
          await updateLocalHiveStock(
            branchAlias: branchAlias,
            varianceCodes: varianceCodes,
            varianceNames: varianceNames,
            stockUpdates: stockUpdates,
            clients: clients,
          );
        } catch (e, st) {}
      }, //
      'stockUpdateFromKot': (data) async {
        try {
          // Extract branch alias with fallback default
          final branchAlias = (data['branchAlias'] as String?)?.trim() ?? 'AR';
          if (branchAlias.isEmpty) {
            return;
          }

          // Extract dynamic lists safely
          final varianceCodesDynamic = data['varianceCode'] as List<dynamic>?;
          final varianceNamesDynamic = data['varianceNames'] as List<dynamic>?;
          final stockUpdatesDynamic = data['stockUpdates'] as List<dynamic>?;

          // Validate all required fields are present
          if (varianceCodesDynamic == null ||
              varianceNamesDynamic == null ||
              stockUpdatesDynamic == null) {
            return;
          }

          // Validate equal length
          final len = varianceCodesDynamic.length;
          if (varianceNamesDynamic.length != len ||
              stockUpdatesDynamic.length != len) {
            return;
          }

          // Convert to typed lists with trimming
          final varianceCodes = varianceCodesDynamic
              .map((e) => e.toString().trim())
              .toList();
          final varianceNames = varianceNamesDynamic
              .map((e) => e.toString().trim())
              .toList();
          final stockUpdates = stockUpdatesDynamic.map((e) {
            final qty = int.tryParse(e.toString());
            return qty ?? 0;
          }).toList();

          // Validate stockUpdates values are positive integers
          for (int i = 0; i < stockUpdates.length; i++) {
            if (stockUpdates[i] <= 0) {
              return;
            }
          }

          // Debug print all inputs before update

          // Call your stock update method
          await updateLocalHiveStock(
            branchAlias: branchAlias,
            varianceCodes: varianceCodes,
            varianceNames: varianceNames,
            stockUpdates: stockUpdates,
            clients: clients,
          );
        } catch (e, st) {}
      },
      'addStockUpdateFromKot': (data) async {
        try {
          // Extract branch alias with fallback default
          final branchAlias = (data['branchAlias'] as String?)?.trim() ?? 'AR';
          if (branchAlias.isEmpty) {
            return;
          }

          // Extract dynamic lists safely
          final varianceCodesDynamic = data['varianceCode'] as List<dynamic>?;
          final varianceNamesDynamic = data['varianceNames'] as List<dynamic>?;
          final stockUpdatesDynamic = data['stockUpdates'] as List<dynamic>?;

          // Validate all required fields are present
          if (varianceCodesDynamic == null ||
              varianceNamesDynamic == null ||
              stockUpdatesDynamic == null) {
            return;
          }

          // Validate equal length
          final len = varianceCodesDynamic.length;
          if (varianceNamesDynamic.length != len ||
              stockUpdatesDynamic.length != len) {
            return;
          }

          // Convert to typed lists with trimming
          final varianceCodes = varianceCodesDynamic
              .map((e) => e.toString().trim())
              .toList();
          final varianceNames = varianceNamesDynamic
              .map((e) => e.toString().trim())
              .toList();
          final stockUpdates = stockUpdatesDynamic.map((e) {
            final qty = int.tryParse(e.toString());
            return qty ?? 0;
          }).toList();

          // Validate stockUpdates values are positive integers
          for (int i = 0; i < stockUpdates.length; i++) {
            if (stockUpdates[i] <= 0) {
              return;
            }
          }

          // Debug print all inputs before update

          // Call your stock update method
          await updateLocalHiveStock(
            branchAlias: branchAlias,
            varianceCodes: varianceCodes,
            varianceNames: varianceNames,
            stockUpdates: stockUpdates,
            clients: clients,
          );
        } catch (e, st) {}
      },
      'decreaseStockUpdateFromKot': (data) async {
        try {
          // Extract branch alias with fallback default
          final branchAlias = (data['branchAlias'] as String?)?.trim() ?? 'AR';
          if (branchAlias.isEmpty) {
            return;
          }

          // Extract dynamic lists safely
          final varianceCodesDynamic = data['varianceCode'] as List<dynamic>?;
          final varianceNamesDynamic = data['varianceNames'] as List<dynamic>?;
          final stockUpdatesDynamic = data['stockUpdates'] as List<dynamic>?;

          // Validate all required fields are present
          if (varianceCodesDynamic == null ||
              varianceNamesDynamic == null ||
              stockUpdatesDynamic == null) {
            return;
          }

          // Validate equal length
          final len = varianceCodesDynamic.length;
          if (varianceNamesDynamic.length != len ||
              stockUpdatesDynamic.length != len) {
            return;
          }

          // Convert to typed lists with trimming
          final varianceCodes = varianceCodesDynamic
              .map((e) => e.toString().trim())
              .toList();
          final varianceNames = varianceNamesDynamic
              .map((e) => e.toString().trim())
              .toList();
          final stockUpdates = stockUpdatesDynamic.map((e) {
            final qty = int.tryParse(e.toString());
            return qty ?? 0;
          }).toList();

          // Validate stockUpdates values are positive integers
          for (int i = 0; i < stockUpdates.length; i++) {
            if (stockUpdates[i] <= 0) {
              return;
            }
          }

          // Debug print all inputs before update

          // Call your stock update method
          await decreaseLocalHiveStock(
            branchAlias: branchAlias,
            varianceCodes: varianceCodes,
            varianceNames: varianceNames,
            stockUpdates: stockUpdates,
            clients: clients,
          );
        } catch (e, st) {}
      },
      'sentIp': (data) async {
        // Retrieve the current device's WiFi IP using network_info_plus.
        final info = NetworkInfo();
        final myIp = await info.getWifiIP();

        // Compare the received IP with the current device IP.
        bool isSame = (data['ip'] == myIp);

        // Optionally, show a dialog with the details.

        // Send the current device IP, the received data, and the match result to the clients.
        sendDataToClients({
          'action': 'deviceIpGenerated',
          'data': data,
          'deviceIp': myIp,
          'isSame': isSame,
        }, clients);
      },
    };

    // Listen for incoming messages from the WebSocket stream
    channel!.stream.listen(
      (message) async {
        try {
          if (message is String && message.trim().isNotEmpty) {
            String fixedMessage = message.replaceAll("'", '"');
            var data = jsonDecode(fixedMessage);

            // Special handling for heartbeat
            if (data.containsKey('action') && data['action'] == 'heartbeat') {
              channel!.sink.add(jsonEncode({'action': 'heartbeatAck'}));
              return;
            }

            // Process actions if present
            if (data.containsKey('action') &&
                actionHandlers.containsKey(data['action'])) {
              await actionHandlers[data['action']]!(data);
              return;
            }

            // Process types if present
            if (data.containsKey('type') &&
                typeHandlers.containsKey(data['type'])) {
              await typeHandlers[data['type']]!(data);
              return;
            }
          }
        } catch (e) {}
      },
      onDone: () {
        clients.remove(channel);
      },
      onError: (error) {
        clients.remove(channel);
      },
    );
  }

  Future<void> onDataReceived(Map<String, dynamic> data) async {
    if (data != null) {
      //for (var order in _receivedData) {}
      if (data['action'] == 'seat_tapped') {
        sendDataToClients(data, clients);
      } else if (data['action'] == 'seat_returned') {
        sendDataToClients(data, clients);
      }
      setState(() {
        _receivedData.add(data);
      });
      // sendDataToClients(data, clients);

      if (data['action'] == 'updatePrinterItems') {
        // Broadcast the updated printer data to all clients
        sendDataToClients({
          'action': 'updatePrinterItems',
          'printer': data['printer'],
        }, clients);
      }
      if (data['action'] == 'removePrinter') {
        handleRemovePrinter(data, clients);
      }
    } else {}
  }

  bool employeeIdVerified = false; // To track if the employee ID is correct

  Future<void> proceedToDashboard() async {
    // Step 0: Widget mount check
    if (!mounted) {
      return;
    }

    // Step 1: Alias name validation
    if (globals.aliasname == null || globals.aliasname!.trim().isEmpty) {
      return;
    }

    // Step 2: Initialize ItemProvider
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);

    // Step 3: Fetch branch name from alias
    final branchName = await itemProvider.getBranchNameFromAlias(
      globals.aliasname,
    );

    if (!mounted) {
      return;
    }

    // // Fetch additional data if needed
    // await itemProvider.fetchDataIfNeeded(branchAlias: globals.aliasname);

    // Step 4: Validate fetched branch name
    if (branchName == null || branchName == 'Branch Not Found') {
      return;
    }

    // Step 5: Set global variable
    globals.branchName = branchName;

    // Step 6: Proceed to shift check
    final url = Uri.parse(
      'https://yenerp.com/fastapi/shifts/check-open-shift?branch_name=${globals.branchName}',
    );

    final client = http.Client();

    try {
      final response = await client.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        globals.shiftId.value = data['shiftId']?.toString() ?? '0';
        globals.shiftNumber.value = data['shiftNumber']?.toString() ?? '0';

        int shiftNumberInt = int.tryParse(globals.shiftNumber.value) ?? 0;
        if (shiftNumberInt != 0) {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => ChooseModePage()),
              );
            });
          }
        } else {
          if (mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('No open shift found for today.'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => OpenShift()),
              );
            });
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to fetch shift data.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      client.close();
    }
  }

  Future<void> discoverServerAndHandle() async {
    final udp = await UDP.bind(Endpoint.any());

    udp.send(
      utf8.encode('WHO_IS_SERVER'),
      Endpoint.broadcast(port: const Port(33441)),
    );

    final serverBox = await Hive.openBox('serverBox');
    bool found = false;

    try {
      await for (final datagram in udp.asStream(
        timeout: const Duration(seconds: 2),
      )) {
        if (datagram != null) {
          final message = utf8.decode(datagram.data);

          if (message.startsWith('SERVER:')) {
            final parts = message.split(':');
            final ip = parts[1];
            final port = parts[2];

            await serverBox.put('serverIp', ip);
            await serverBox.put('serverPort', port);
            serverip = ip;

            setState(() {
              serverFound = true;
            });

            found = true;
            udp.close();

            // Navigate safely
            await proceedToDashboard();
            break;
          }
        }
      }
    } catch (e) {}

    if (!found && mounted) {
      udp.close();

      showDialog(
        context: context,
        builder: (_) => NoServerDialog(
          onMakeServer: () async {
            final ip = await getLocalIp();
            if (ip != null) {
              final box = await Hive.openBox('serverBox');
              await box.put('serverIp', ip);
              await box.put('serverPort', port);
              final configBox = HiveManager().configBox;
              appType = 'server';
              await configBox.put('appType', 'server');
              Provider.of<ItemProvider>(
                context,
                listen: false,
              ).fetchDataIfNeeded(branchAlias: 'AR');
              serverip = ip;
              setState(() {
                serverFound = true;
              });

              startUdpResponder(ip, udpPort);
              startServer(clients, onDataReceived);

              proceedToDashboard();
            }
          },
        ),
      );
    }
  }

  Future<void> checkPendingApprovals(salesOrdersBox) async {
    salesOrdersBox.toMap().forEach((key, value) {});

    salesOrdersBox.toMap().forEach((key, value) {
      if (value is Map && value.containsKey('waitingForApprovalResult')) {
      } else {}
    });

    for (final entry in salesOrdersBox.toMap().entries) {
      final order = entry.value;
      final orderData = order['data'];

      if (order['waitingForApprovalResult'] == 'Yes' &&
          orderData is Map &&
          orderData.containsKey('saleOrderNo')) {
        final saleOrderNo = orderData['saleOrderNo'];

        // Check approvalStatus in approvalDetails list
        dynamic approvalStatus;
        if (orderData.containsKey('approvalDetails') &&
            orderData['approvalDetails'] is List &&
            orderData['approvalDetails'].isNotEmpty) {
          final approvalDetails = orderData['approvalDetails'];
          approvalStatus = approvalDetails.last['approvalStatus'];
        } else {}

        if (approvalStatus != null) {
          continue;
        }

        try {
          final apiResponse = await _syncService.fetchSalesOrderFromApi(
            saleOrderNo,
          );

          dynamic apiSalesOrder = apiResponse;

          // Check if API response has valid approvalDetails with approvalStatus
          dynamic apiApprovalStatus;
          if (apiSalesOrder != null &&
              apiSalesOrder is Map<String, dynamic> &&
              apiSalesOrder.containsKey('approvalDetails') &&
              apiSalesOrder['approvalDetails'] is List &&
              apiSalesOrder['approvalDetails'].isNotEmpty) {
            apiApprovalStatus =
                apiSalesOrder['approvalDetails'].last['approvalStatus'];
          }

          if (apiApprovalStatus != null) {
            final updatedOrder = Map<String, dynamic>.from(order);

            // Merge API data into existing 'data' field
            if (updatedOrder['data'] is Map) {
              updatedOrder['data'] = Map<String, dynamic>.from(
                updatedOrder['data'],
              )..addAll(apiSalesOrder);
            } else {
              updatedOrder['data'] = apiSalesOrder;
            }

            updatedOrder['waitingForApprovalResult'] = 'No';
            await salesOrdersBox.put(entry.key, updatedOrder);

            sendDataToClients({
              'action': 'patchsaleorderGenerated',
              'saleOrderNo': saleOrderNo,
              'patchSaleOrder': updatedOrder,
            }, clients);
          } else {
            continue; // Skip if approvalStatus is missing or null
          }
        } catch (e) {}
      } else {}
    }

    salesOrdersBox.toMap().forEach((key, value) {});
  }

  Future<void> chequePendingDiscountApproval(holdOrderBox) async {
    holdOrderBox.toMap().forEach((key, value) {});

    holdOrderBox.toMap().forEach((key, value) {
      if (value is Map && value.containsKey('waitingForApprovalResult')) {
      } else {}
    });

    for (final entry in holdOrderBox.toMap().entries) {
      final order = entry.value;
      final orderData = order['data'];

      if (order['waitingForApprovalResult'] == 'Yes' &&
          orderData is Map &&
          orderData.containsKey('saleOrderNo')) {
        final saleOrderNo = orderData['saleOrderNo'];

        // Check approvalStatus in approvalDetails list
        dynamic approvalStatus;
        if (orderData.containsKey('approvalDetails') &&
            orderData['approvalDetails'] is List &&
            orderData['approvalDetails'].isNotEmpty) {
          final approvalDetails = orderData['approvalDetails'];
          approvalStatus = approvalDetails.last['approvalStatus'];
        } else {}

        if (approvalStatus != null) {
          continue;
        }

        try {
          final apiResponse = await _syncService.fetchSalesOrderFromApi(
            saleOrderNo,
          );

          dynamic apiSalesOrder = apiResponse;

          // Check if API response has valid approvalDetails with approvalStatus
          dynamic apiApprovalStatus;
          if (apiSalesOrder != null &&
              apiSalesOrder is Map<String, dynamic> &&
              apiSalesOrder.containsKey('approvalDetails') &&
              apiSalesOrder['approvalDetails'] is List &&
              apiSalesOrder['approvalDetails'].isNotEmpty) {
            apiApprovalStatus =
                apiSalesOrder['approvalDetails'].last['approvalStatus'];
          }

          if (apiApprovalStatus != null) {
            final updatedOrder = Map<String, dynamic>.from(order);

            // Merge API data into existing 'data' field
            if (updatedOrder['data'] is Map) {
              updatedOrder['data'] = Map<String, dynamic>.from(
                updatedOrder['data'],
              )..addAll(apiSalesOrder);
            } else {
              updatedOrder['data'] = apiSalesOrder;
            }

            updatedOrder['waitingForApprovalResult'] = 'No';
            await holdOrderBox.put(entry.key, updatedOrder);

            sendDataToClients({
              'action': 'patchsaleorderGenerated',
              'saleOrderNo': saleOrderNo,
              'patchSaleOrder': updatedOrder,
            }, clients);
          } else {
            continue; // Skip if approvalStatus is missing or null
          }
        } catch (e) {}
      } else {}
    }

    holdOrderBox.toMap().forEach((key, value) {});
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1) Ask the user to allow background
      await BackgroundPermissionGuard.askIfNeeded(context);

      // 2) Start your foreground service at the very first run (if you want)
      await ForegroundHelper.init();
      await ForegroundHelper.startIfNotRunning();
    });

    final loginProvider = Provider.of<LoginProvider>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 40.0,
              vertical: 60.0,
            ),
            child: Row(
              children: [
                // Left side: Text + Card
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // POS Title + Logo Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Bestmummy Logo
                            Image.asset(
                              'assets/bestmummy.png', // make sure this file exists in assets folder
                              height: 150,
                            ),
                            const SizedBox(width: 16),
                            // POS Title and Description
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'POS',
                                  style: TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Fast, simple POS for billing',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade700,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Login Card
                        Card(
                          elevation: 8,
                          color: Colors.white,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(28.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 25),

                                // Username
                                TextFormField(
                                  controller: loginProvider
                                      .userNameController, // ← Added controller
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    labelText: 'Username',
                                    labelStyle: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.person,
                                      color: Colors.black54,
                                    ),
                                    errorText: loginProvider
                                        .userNameError, // ✅ show error
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Password
                                TextFormField(
                                  controller: loginProvider
                                      .passwordController, // ← Added controller
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    labelText: 'Password',
                                    labelStyle: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.black54,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.lock,
                                      color: Colors.black54,
                                    ),
                                    errorText: loginProvider
                                        .passwordError, // ✅ show error
                                  ),
                                ),
                                const SizedBox(height: 25),

                                // Login button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: loginProvider.isSigningIn
                                        ? null
                                        : () async {
                                            bool loginSuccess =
                                                await loginProvider.loginUser(
                                                  context,
                                                );

                                            if (loginSuccess) {
                                              if (serverFound) {
                                                bool isAlive =
                                                    await isServerReachable(
                                                      serverip,
                                                      8383,
                                                    );
                                                if (isAlive) {
                                                  await proceedToDashboard();
                                                } else {
                                                  await discoverServerAndHandle();
                                                }
                                              } else {
                                                await discoverServerAndHandle();
                                              }
                                            } else {}
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue.shade800,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 6,
                                      shadowColor: Colors.black26,
                                    ),
                                    child: const Text(
                                      'Log in',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 25),

                                Divider(
                                  color: Colors.grey.shade300,
                                  thickness: 1,
                                ),
                                const SizedBox(height: 10),

                                // Server & App Type Info
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Server Type
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.cloud_outlined,
                                          color: Colors.blue.shade700,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Server: $serverip',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // App Type
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.apps_rounded,
                                          color: Colors.blue.shade700,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'App Type: $appType',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right side: Image
                Expanded(
                  flex: 1,
                  child: Image.asset(
                    'assets/posbilling.png',
                    height: 650,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
