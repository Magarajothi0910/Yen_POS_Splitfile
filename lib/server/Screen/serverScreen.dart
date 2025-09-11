import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:udp/udp.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:yenposapp/screens/choose_mode/choose_mode_screen.dart';
import 'package:yenposapp/server/Screen/login_provider_kot.dart';
import '../../KotApp/handlers/FullCancelOrder_Handler.dart';
import '../../KotApp/handlers/ItemWiseCancel.dart';
import '../../KotApp/handlers/invoice handler.dart';
import '../../KotApp/handlers/orderhandlers.dart';
import '../../KotApp/handlers/reverseOrder_handler.dart';
import '../../KotApp/handlers/seathandler.dart';
import '../../KotApp/kotproviders/login_provider.dart';
import '../../KotApp/kotproviders/order_provider.dart';
import '../../KotApp/kotproviders/product_provider.dart';
import '../../KotApp/kotservices/sendDataToClients.dart';
import '../../KotApp/kotservices/sync_service.dart';
import '../../background_Task/background_permission_guard.dart';
import '../../background_Task/flutter_foreground_task.dart';
import '../../data/global_data_manager.dart';
import '../../screens/kot_screen/global/globals.dart';
import '../../services/branchwise_item_fetch.dart';
import '../../services/hive_manager.dart';
import '../../services/stockupdateService.dart';
import '../Service/Token_service.dart';
import '../Service/hive_service.dart';
import '../Service/makethisdeviceas server_Dialog.dart';
// import '../Service/sendDataToClients.dart';
import '../Service/serverreachable.dart';
import '../Service/startServers.dart';
import '../Service/sync_service.dart';

class LoginScreen extends StatefulWidget {
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
  final GlobalKey keyboardKey = GlobalKey();
  Set<WebSocketChannel> clients = {};
  List<Map<String, dynamic>> orders = [];
  final SyncServiceKot _syncService1 = SyncServiceKot();

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
      _syncService.syncUnsyncedOrders();
      // _syncService.syncUnsyncedInvoices(clients: clients);
      _syncService.patchEditedOrders();
    });
    Provider.of<LoginProvider>(context, listen: false).fetchAndStoreLoginData();
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    productProvider.fetchTablesAndSaveInHive();

    loadOrdersFromHive().then((orders) {
      setState(() {
        _receivedData.addAll(orders as Iterable<Map<String, dynamic>>);
      });
    });

    _approvalCheckTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      checkPendingApprovals(saleOrderBox);
      chequePendingDiscountApproval(holdOrderBox);
    });
    _syncTimer = Timer.periodic(const Duration(minutes: 10), (timer) {
      _syncService.syncUnsyncedOrders();
      // _syncService.syncUnsyncedInvoices();
      _syncService.patchEditedOrders();
      _syncService.syncPendingPatches();
    });

    loadOrdersFromHive().then((orders) {
      _receivedData.addAll(orders);
      setState(() {
        // Trigger a rebuild to reflect the loaded orders
      });
    });
    final itemProvider = Provider.of<ItemProvider>(context, listen: false);

    checkIfServerWasPreviouslyStored();

    _patchCheckTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _syncService.patchEditedOrders();
    });
  }

  Future<void> _openBoxes() async {
    invoiceBox = await Hive.openBox('invoices');
    Hive.openBox('salesOrders');
    saleOrderBox = await Hive.openBox('saleOrderBox');
    holdOrderBox = await Hive.openBox('holdOrders');
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
    // Open the Hive box for sales orders
    final salesOrderBox = await Hive.openBox('salesOrders');

    // Get the current count for the prefix or initialize it to 250000
    final currentCount = salesOrderBox.get(prefix) ?? 0000;

    // Increment to get the next count
    final nextCount = currentCount + 1;

    // Save the updated count back to Hive
    await salesOrderBox.put(prefix, nextCount);

    // Format the numeric part with leading zeros to ensure it is always six digits
    final formattedNumber = nextCount.toString().padLeft(4, '0');

    // Return the new sales order number in the format "prefix + formattedNumber"
    return '$prefix$formattedNumber';
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
    final String soNo = data['saleOrderNo'];
    final Map<String, dynamic> patchData =
        Map<String, dynamic>.from(data['data'] ?? {});
    final String? deviceName = data['deviceName'];
    final String type = data['type'] ?? 'patchSaleOrder';
    final String sync = data['sync'] ?? 'No';
    final String edit = data['edit'] ?? 'No';
    final String waitingForApprovalResult =
        data['waitingForApprovalResult'] ?? 'Yes';

    // Find target key in Hive
    String? targetKey;
    for (final entry in saleOrderBox.toMap().entries) {
      if (entry.value['data']?['saleOrderNo'] == soNo) {
        targetKey = entry.key.toString();
        break;
      }
    }

    if (targetKey == null) {
      print("❌ No matching SaleOrder found in Hive for $soNo");
      return;
    }

    // Update existing order
    final existingOrder =
        Map<String, dynamic>.from(saleOrderBox.get(targetKey));
    existingOrder['data'] = {
      ...?existingOrder['data'],
      ...patchData, // Merge patchData
    };
    existingOrder.addAll({
      'deviceName': deviceName,
      'type': type,
      'sync': sync,
      'edit': edit,
      'waitingForApprovalResult': waitingForApprovalResult,
      'saleOrderNo': soNo,
    });

    await saleOrderBox.put(targetKey, existingOrder);
    print("✅ Updated Hive order for key=$targetKey");

    // Notify clients
    sendDataToClients({
      'action': 'patchsaleorderGenerated',
      'saleOrderNo': soNo,
      'patchSaleOrder': data,
    }, clients);

    // Sync with server
    try {
      bool success = await _syncService.patchSalesOrder(soNo, {
        'data': patchData,
        'deviceName': deviceName,
        'type': type,
        'sync': sync,
        'edit': edit,
        'waitingForApprovalResult': waitingForApprovalResult,
      });

      if (success) {
        existingOrder['sync'] = true;
        await saleOrderBox.put(targetKey, existingOrder);
        print("✅ Hive updated with sync=true for $soNo");
      } else {
        print("⚠️ Patch failed, will retry later for $soNo");
      }
    } catch (e) {
      print("🔥 Error syncing patch for $soNo: $e");
    }
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

      Map<String, dynamic> updatedOrder =
          Map<String, dynamic>.from(existingOrder);

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
    debugPrint("➡️ Starting handleSaleOrder with input: $data");

    // Extract the sales order data (nested or top-level)
    final salesOrder = data['data'] ?? data;
    debugPrint("📦 Extracted salesOrder: $salesOrder");

    // Determine the prefix for the sales order number
    String prefix = salesOrder['saleOrderNo']?.toString().trim() ??
        salesOrder['branchAlias']?.toString().trim() ??
        "SOSB";
    debugPrint("🔤 Determined prefix for sales order number: $prefix");

    // Get new sales order number from API/Hive
    final newSalesOrderNo = await fetchNextSalesOrderNumberFromHive(prefix);
    if (newSalesOrderNo == null) {
      debugPrint(
        "❌ Failed to fetch a new sales order number for prefix: $prefix",
      );
      return;
    }
    debugPrint(
      "✅ Fetched new sales order number from Hive/API: $newSalesOrderNo",
    );

    // Clean and update the sales order number
    final cleanSalesOrderNo = newSalesOrderNo.replaceAll('"', '');
    salesOrder['saleOrderNo'] = cleanSalesOrderNo;
    debugPrint("🧽 Cleaned and updated saleOrderNo: $cleanSalesOrderNo");

    // Save the order locally
    await savePosSaleOrderToHive(data, saleOrderBox);
    debugPrint("💾 Saved updated sales order locally: ${data}");

    // Notify clients with updated order number
    sendDataToClients({
      'action': 'OpSalesOrderGenerated',
      'opSalesOrder': data, // now includes updated saleOrderNo
    }, clients);
    _sendDataToClientsCount++;
    debugPrint(
      "📡 Notified clients ($_sendDataToClientsCount times) with updated salesOrderNo: $cleanSalesOrderNo",
    );

    // Post to API
    debugPrint(
      "📤 Posting sales order to API: ${{
        "data": [salesOrder],
      }}",
    );
    bool success = await _syncService.postSalesOrder({
      "data": [salesOrder],
    });

    if (success) {
      debugPrint("✅ Sales order posted successfully to server.");
    } else {
      debugPrint("❌ Failed to post sales order to server.");
    }

    debugPrint(
      "🏁 handleSaleOrder completed for saleOrderNo: $cleanSalesOrderNo",
    );
  }

  Future<void> handleSaleOrder(Map<String, dynamic> data) async {
    // Extract the sales order data (nested or top-level)
    final salesOrder = data['data'] ?? data;

    // Determine the prefix for the sales order number
    String prefix = salesOrder['saleOrderNo']?.toString().trim() ??
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
      'action': 'salesOrderGenerated',
      'salesOrder': data, // now includes updated saleOrderNo
    }, clients);
    _sendDataToClientsCount++;

    // Post to API

    bool success = await _syncService.postSalesOrder({
      "data": [salesOrder]
    });

    if (success) {
    } else {}
  }

  Future<void> handleInvoiceOrder(Map<String, dynamic> data) async {
    // Extract the sales order data (nested or top-level)
    final salesOrder = data['data'] ?? data;

    // Determine the prefix for the sales order number
    String prefix = salesOrder['saleOrderNo']?.toString().trim() ??
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
      "data": [salesOrder]
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
      "data": [modifyOrder]
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
      "data": [modifyOrder]
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
      Map<String, dynamic> customerData) async {
    var customerBox = await Hive.openBox('customerBox');
    final String? mobile = customerData['mobile'];

    if (mobile == null) {
      return;
    }

    // ── Check for duplicates ───────────────────────────
    final exists = customerBox.values.any((customer) {
      final existing = Map<String, dynamic>.from(customer);
      return existing['mobile'] == mobile;
    });

    if (exists) {
      return;
    }

    // ── Save new customer ──────────────────────────────

    await customerBox.add(customerData);
  }

  void handleSalesOrderAddCustomer(Map<String, dynamic> data) async {
    // ── broadcast to clients ──────────────────────────
    sendDataToClients({
      'action': 'salesOrderAddCustomerGenerated',
      'salesOrderAddCustomer': data,
    }, clients);

    // ── Save locally (with duplicate check) ────────────
    await saveSalesOrderAddCustomerToHive(data);

    // ── Extract fields for API sync ────────────────────
    final String? name = data['name'] as String?;
    final String? mobile = data['mobile'] as String?;
    final String? branch = data['branchId'] as String?;

    if (name == null || mobile == null) {
      return;
    }

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
      "data": [modifyOrder]
    });

    if (success) {
    } else {}
  }

  void handleHoldOrder(Map<String, dynamic> data) async {
    // Notify connected clients about the new sales order.

    // Save the sales order locally.
    await saveToApproveOrderToHive(data);

    // If the sales order data contains a nested "data" key,
    // extract it. Otherwise, fallback to the original data.
    final modifyOrder = data['data'] ?? data;

    sendDataToClients({
      'action': 'holdOrderGenerated',
      'holdOrder': data,
    }, clients);

    // Post the flattened sales order to the FastAPI endpoint.
    bool success = await _syncService.postToApproveOrder({
      "data": [modifyOrder]
    });

    if (success) {
      // _syncService.patchSaleOrder();
    } else {}
  }

  void handleSalesApprovalOrder(Map<String, dynamic> data) async {
    final salesOrder = data['data'] ?? data;
    await saveSalesApprovalOrderToHive(data);
    sendDataToClients({
      'action': 'salesApprovalOrderGenerated',
      'salesApprovalOrder': data,
    }, clients);
    bool success = await _syncService.postDiscountOrder({
      "data": [salesOrder]
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

        Provider.of<ItemProvider>(context, listen: false)
            .fetchDataIfNeeded(branchAlias: 'AR');
      } else {
        appType = 'client';
        await configBox.put('appType', 'client');

        final orderProvider =
            Provider.of<OrderProvider>(context, listen: false);
        await orderProvider.initializeWebSocket(); // Ensure it's open
        orderProvider.channel!.sink
            .add(jsonEncode({'action': 'requestBranchwiseItems'}));
      }
      setState(() => serverFound = true);
    }
    // else {
    //   setState(() => serverFound = false);
    //   appType = 'client';
    //   await configBox.put('appType', 'client');
    // }
  }

  void dispose() {
    // Close all Hive boxes
    _syncTimer?.cancel();

    super.dispose();
  }

  Future<void> _loadInvoices() async {
    var invoiceBox = await Hive.openBox('invoices');
    final List<Map<String, dynamic>> invoices = [];
    for (int i = 0; i < invoiceBox.length; i++) {
      var invoice = invoiceBox.getAt(i);

      if (invoice is String) {
        try {
          invoice = jsonDecode(invoice);
        } catch (e) {
          continue;
        }
      }

      if (invoice is Map<String, dynamic>) {
        invoices.add(invoice);
      }
    }

    setState(() {
      _invoiceData = invoices;
    });
  }

  void startServer(Set<WebSocketChannel> clients,
      Function(Map<String, dynamic>) onDataReceived) async {
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 8383);

      tokenCounter = await getTokenCounterFromHive();

      server.transform(WebSocketTransformer()).listen((WebSocket socket) {
        handleWebSocket(socket, clients, onDataReceived);
      });
    } catch (e) {}
  }

  Map<String, String> seathiveOrderIds = {};

  void handleWebSocket(WebSocket socket, Set<WebSocketChannel> clients,
      Function(Map<String, dynamic>) onDataReceived) {
    this.channel = IOWebSocketChannel(socket);
    clients.add(this.channel!);
    // final itemProvider = Provider.of<ItemProvider>(context, listen: false);
    // Map for handling messages triggered by the 'action' field
    final Map<String, Future<void> Function(Map<String, dynamic>)>
        actionHandlers = {
      'hello': (data) async {
        channel!.sink.add(jsonEncode({
          'action': 'response',
          'message': 'Hello Client, message received!'
        }));
      },

      'requestBranchwiseItems': (data) async {
        try {
          // Get the saved branchwiseItems data from your global data manager
          final savedData = GlobalDataManager().branchwiseItems;

          if (savedData == null) {
            // No data saved yet, send an error message or empty data
            channel!.sink.add(jsonEncode({
              'action': 'branchwiseItemsError',
              'message': 'No branchwise items data available.',
            }));
            return;
          }

          // Send the raw saved data directly, no alias or filtering
          channel!.sink.add(jsonEncode({
            'action': 'branchwiseItems',
            // optionally send a timestamp or some meta info if needed
            'data': savedData,
          }));
        } catch (e) {
          channel!.sink.add(jsonEncode({
            'action': 'branchwiseItemsError',
            'message': 'Failed to send branchwise items.',
          }));
        }
        ;
      },

      'heartbeat': (data) async {
        channel!.sink.add(jsonEncode({'action': 'heartbeatAck'}));
      }, // inside your handleWebSocket(...) where you build actionHandlers:

      'requestAllData': (data) async {
        await sendAllDataToClient(channel!);
      },
      'seat_tapped': (data) async {
        sendDataToClients(data, clients);
      },
      'seat_returned': (data) async {
        sendDataToClients(data, clients);
      },

      'patchOrderStatusBySeathiveOrderId': (data) async {
        final seathiveOrderId = data['seathiveOrderId']?.toString() ?? '';
        final newStatus = data['status']?.toString() ?? '';
        final preinvoiceTime = data['preinvoiceTime']?.toString() ?? '';
        final orderRemark = data['orderRemark']?.toString() ?? '';

        handlePatchOrderStatusBySeathiveOrderId(
            seathiveOrderId, newStatus, orderRemark, preinvoiceTime);
      },
      'seat_transfer': (data) async {
        await handleSeatTransfer(
          data: data,
          receivedData: _receivedData,
          clients: clients,
        );
      },
      'deleteOrder': (data) async {
        await deleteOrderFromHive(data['hiveOrderId']);
        sendDataToClients(data, clients);
      },
      'newClientConnected': (data) async {
        await handleNewClientConnected(data, channel!);
      },
      'FullCancelOrderPatch': (data) async {
        await OrderPatchHandler.handleFullCancelOrderPatch(data, clients);
      },
      'cancelOrderItem': (data) async {
        await CancelOrderPatchHandler.patchCancelOrderItem(data, clients);
      },
      'reverseCancelOrderItem': (data) async {
        final hiveOrderId = data['hiveOrderId'];
        final int updatedIndex = data['updatedIndex'];
        final double updatedQty = (data['updatedQuantity'] as num).toDouble();
        final double updatedCancelledQty =
            (data['updatedCancelledQty'] as num).toDouble();
        final double totalAmount = (data['totalAmount'] as num).toDouble();
        final bool partiallycancelled = data['partiallycancelled'] == true;

        await patchOrderInHiveIndexWise(
          hiveOrderId,
          updatedIndex,
          updatedQty,
          updatedCancelledQty,
          totalAmount,
          partiallycancelled,
        );

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
          }
        }, clients);
      },
      'kotTableStatusUpdated': (data) async {
        await _syncService1.saveTableStatusToHive(data);
        await _syncService1.upsertKotTableStatus(data);
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
      'order': (data) async {
        handleOrder(data, clients);
      },
      'invoice': (data) async {
        handleInvoice(data, clients);
      },
      'opSalesOrder': (data) async {
        print("sent data to server");
        handleOpenSaleOrder(data);
      },
      'posInvoice': (data) async {
        print("starting pos invoice handling");
        handleInvoice(data, clients);
      },
      'salesOrder': (data) async {
        handleSaleOrder(data);
      },
      'patchSaleOrder': (data) async {
        print("patch the saleorder");
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
        sendDataToClients({
          'action': 'holdOrderGenerated',
          'holdOrder': data,
        }, clients);
        saveHoldOrderToHive(data, holdOrderBox);
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
          'message': 'Server is alive and running!'
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
          final varianceCodes =
              varianceCodesDynamic.map((e) => e.toString().trim()).toList();
          final varianceNames =
              varianceNamesDynamic.map((e) => e.toString().trim()).toList();
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
              clients: clients);
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
          final varianceCodes =
              varianceCodesDynamic.map((e) => e.toString().trim()).toList();
          final varianceNames =
              varianceNamesDynamic.map((e) => e.toString().trim()).toList();
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
              clients: clients);
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
          final varianceCodes =
              varianceCodesDynamic.map((e) => e.toString().trim()).toList();
          final varianceNames =
              varianceNamesDynamic.map((e) => e.toString().trim()).toList();
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
              clients: clients);
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
          final varianceCodes =
              varianceCodesDynamic.map((e) => e.toString().trim()).toList();
          final varianceNames =
              varianceNamesDynamic.map((e) => e.toString().trim()).toList();
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
      }
    };

    // Listen for incoming messages from the WebSocket stream
    channel!.stream.listen((message) async {
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
    }, onDone: () {
      clients.remove(channel);
    }, onError: (error) {
      clients.remove(channel);
    });
  }

  Future<void> onDataReceived(Map<String, dynamic> data) async {
    if (!mounted) return;

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

  Future<void> handlePatchOrderStatusBySeathiveOrderId(String seathiveOrderId,
      String newStatus, String orderRemark, String preinvoiceTime) async {
    bool dataUpdated = false;

    // First try updating in-memory _receivedData
    for (var order in _receivedData) {
      if (order['seathiveOrderId'] == seathiveOrderId) {
        order['status'] = newStatus;
        order['orderRemark'] = orderRemark;
        order['preinvoiceTime'] = preinvoiceTime;
        order['edit'] = "Yes";
        order['statusEdited'] = "true";
        dataUpdated = true;
        break;
      }
    }
    if (!dataUpdated) {
      final orderBox = await Hive.openBox('ordersBox');

      for (int i = 0; i < orderBox.length; i++) {
        var orderData = orderBox.getAt(i);
        if (orderData['seathiveOrderId'] == seathiveOrderId) {
          orderData['status'] = newStatus;
          orderData['preinvoiceTime'] = preinvoiceTime;
          orderData['edit'] = "Yes";
          orderData['statusEdited'] = "true";
          await orderBox.putAt(i, orderData);
        }
      }
    }

    if (dataUpdated) {
      sendDataToClients({
        'action': 'updateOrderStatus',
        'seathiveOrderId': seathiveOrderId,
        'status': newStatus,
        'orderRemark': orderRemark,
        'preinvoiceTime': preinvoiceTime,
        'statusEdited': "true",
        'edit': "Yes",
      }, clients);
      await _syncService.patchEditedOrders();
    } else {}
  }

  Future<void> loginUser() async {
    final loginProvider = Provider.of<LoginProviderKot>(context, listen: false);
    loginProvider.setUserNameError("");
    loginProvider.setPasswordError("");

    userName = _userNameController.text.trim();
    final password = _passwordController.text.trim();

    if (userName.isEmpty) {
      loginProvider.setUserNameError('Please enter a username');
    }
    if (password.isEmpty) {
      loginProvider.setPasswordError('Please enter a password');
    }
    if (serverFound) {
      final isAlive = await isServerReachable(serverip, 8383);
      if (isAlive) {
        proceedToDashboard();
      } else {
        await discoverServerAndHandle();
      }
    } else {
      await discoverServerAndHandle();
    }

    // Provider.of<OrderProvider>(context, listen: false).requestDataFromServer();
    // Navigator.pushAndRemoveUntil(
    //   context,
    //   MaterialPageRoute(builder: (context) => const DashboardScreen()),
    //   (Route<dynamic> route) => false, // Removes all previous routes
    // );
    // if (loginProvider.userNameError == null &&
    //     loginProvider.passwordError == null) {
    //   bool isValid =
    //       await loginProvider.validateCredentials(userName, password);

    //   if (isValid) {
    //     var box = await Hive.openBox('deviceData');
    //     String deviceCode = box.get('deviceCode') ?? '';

    //     Provider.of<WebSocketService>(context, listen: false)
    //         .sendDeviceCodeToServer(deviceCode);
    //     Provider.of<OrderProvider>(context, listen: false)
    //         .requestDataFromServer();

    //     // ignore: use_build_context_synchronously
    //     Navigator.pushAndRemoveUntil(
    //       context,
    //       MaterialPageRoute(builder: (context) => const TableScreen()),
    //       (Route<dynamic> route) => false, // Removes all previous routes
    //     );
    //   } else {
    //     loginProvider.setUserNameError('Invalid username or password');
    //     loginProvider.setPasswordError('Invalid username or password');
    //   }
    // }
  }

  void proceedToDashboard() {
    Provider.of<OrderProvider>(context, listen: false).requestDataFromServer();

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (context) => ChooseModePage(
                keyboardKey: keyboardKey,
              )),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> discoverServerAndHandle() async {
    final udp = await UDP.bind(Endpoint.any());

    udp.send(
      utf8.encode('WHO_IS_SERVER'),
      Endpoint.broadcast(port: const Port(45678)),
    );

    final serverBox = await Hive.openBox('serverBox');

    bool found = false;

    await for (final datagram
        in udp.asStream(timeout: const Duration(seconds: 2))) {
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
          proceedToDashboard();

          break;
        }
      }
    }

    if (!found) {
      udp.close();
      // No server found, show dialog
      // ignore: use_build_context_synchronously
      showDialog(
        context: context,
        builder: (_) => NoServerDialog(
          onMakeServer: () async {
            Navigator.of(context).pop(); // close dialog

            final ip = await getLocalIp();
            if (ip != null) {
              final box = await Hive.openBox('serverBox');
              await box.put('serverIp', ip);
              await box.put('serverPort', port);
              final configBox = HiveManager().configBox;
              appType = 'server';
              await configBox.put('appType', 'server');
              Provider.of<ItemProvider>(context, listen: false)
                  .fetchDataIfNeeded(branchAlias: 'AR');
              serverip = ip;
              setState(() {
                serverFound = true;
              });

              await startUdpResponder(ip, udpPort);
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
          final apiResponse =
              await _syncService.fetchSalesOrderFromApi(saleOrderNo);

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
              updatedOrder['data'] =
                  Map<String, dynamic>.from(updatedOrder['data'])
                    ..addAll(apiSalesOrder);
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
          final apiResponse =
              await _syncService.fetchSalesOrderFromApi(saleOrderNo);

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
              updatedOrder['data'] =
                  Map<String, dynamic>.from(updatedOrder['data'])
                    ..addAll(apiSalesOrder);
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

    final loginProvider = Provider.of<LoginProviderKot>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8F0),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Image.asset(
                      'assets/bestmummy.png',
                      height: 150,
                      width: 150,
                    ),
                    Image.asset(
                      'assets/kotLogin.png',
                      height: 280,
                      width: 280,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        controller: _userNameController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFE0F7FA),
                          labelText: 'Username',
                          errorText: loginProvider.userNameError,
                          labelStyle: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF00695C),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.account_circle,
                            color: Color(0xFF00695C),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 280,
                      child: TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFE0F7FA),
                          labelText: 'Password',
                          errorText: loginProvider.passwordError,
                          labelStyle: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF00695C),
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                            borderSide: BorderSide.none,
                          ),
                          prefixIcon: const Icon(
                            Icons.vpn_key,
                            color: Color(0xFF00695C),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 20,
                            horizontal: 20,
                          ),
                        ),
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          //                      Navigator.pushAndRemoveUntil(
                          //   context,
                          //   MaterialPageRoute(builder: (context) => TableScreen()),
                          //   (Route<dynamic> route) => false, // Removes all previous routes
                          // );
                          loginUser();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE0F7FA),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'LogIn',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF00695C),
                          ),
                        ),
                      ),
                    ),
                    Text("$serverip"),
                    Text("$appType"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
