import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/hive_manager.dart';
import './../screens/kot_screen/global/globals.dart' as globals;
import '../screens/sales_order/sales_order_print/invoicePrint.dart';
import '../screens/sales_order/sales_order_providers/customerScreen_provider.dart';
import 'package:collection/collection.dart';
import 'package:synchronized/synchronized.dart';
import 'branchwise_item_fetch.dart';
import 'stockupdateService.dart';

class PatchHandler {
  static Box<String>? _messageBox;
  static const String _boxName = 'processedMessages';
  static const Duration _messageExpiry = Duration(minutes: 30);
  static final _lock = Lock(); // Synchronization lock

  // Initialize Hive box for processed messages
  static Future<void> init() async {
    _messageBox = await Hive.openBox<String>(_boxName);
  }

  // Check if messageId has been processed
  static bool containsMessage(String messageId) {
    return _messageBox?.containsKey(messageId) ?? false;
  }

  // Mark messageId as processed with timestamp
  static void addProcessedMessage(String messageId) {
    _messageBox?.put(messageId, DateTime.now().toIso8601String());
  }

  // Remove processed message
  static void removeMessage(String messageId) {
    _messageBox?.delete(messageId);
  }

  // Clear expired messages
  static void clearExpiredMessages() {
    final now = DateTime.now();
    _messageBox?.toMap().forEach((key, value) {
      try {
        final timestamp = DateTime.parse(value);
        if (now.difference(timestamp) > _messageExpiry) {
          _messageBox?.delete(key);
        }
      } catch (e) {
        debugPrint('❌ Error parsing timestamp for message $key: $e');
      }
    });
  }
}

class WebSocketService with ChangeNotifier {
  late WebSocketChannel channel;
  static WebSocketService? _instance;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  File? img1;
  File? img2;
  int _messageReceivedCount = 0;
  final CustomerScreenProvider receiptPrinter;
  final Set<String> _processedOrders = {};
  final Set<String> _processedinvoiceOrders = {};

  final Set<String> _processedModifyOrders = {};
  final Set<String> _processedToApproveOrders = {};
  final Set<String> _processedHoldOrders = {};
  final Map<String, Timer> _debounceTimers = {};
  final SalesInvoiceReceiptPrinter saleInvoicereceiptPrinter;
  factory WebSocketService(CustomerScreenProvider receiptPrinter,
      SalesInvoiceReceiptPrinter printer) {
    return _instance ??= WebSocketService._internal(receiptPrinter, printer);
  }
  // WebSocketService(this.receiptPrinter, this.saleInvoicereceiptPrinter) {
  //   _connect();
  // }
  final Set<String> _processedMessageIds = {}; // Track processed message IDs
  // final Set<String> _processedPatchOrders = {};
  WebSocketService._internal(
      this.receiptPrinter, this.saleInvoicereceiptPrinter) {
    connect();
  }

  StreamSubscription? _subscription;

  void connect() {
    if (_isConnected || _subscription != null)
      return; // Prevent duplicate connections

    try {
      channel = IOWebSocketChannel.connect(
          'ws://${globals.serverip}:${globals.port}');
      _isConnected = true;
      WebSocketChannel? _channel;
      StreamSubscription? _sub;

      _subscription = channel.stream.listen(
        (message) {
          // print('Received raw WebSocket message: $message');
          handleMessage(message);
        },
        onError: (error) {
          // print('WebSocket error: $error');
          _isConnected = false;
          _subscription?.cancel();
          _subscription = null;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _subscription?.cancel();
          _subscription = null;
          _scheduleReconnect();
        },
      );

      sendMessage({'action': 'hello', 'message': 'Hello Server'});
      _startHeartbeat();

      // Removed unreachable shutdown() function to eliminate dead code.
    } catch (e) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    channel.sink.close();
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  final Set<String> _processedPatchOrders = {};
  List<Map<String, dynamic>> _cachedOrders = [];

  Future<void> putOrder(dynamic key, Map<String, dynamic> order) async {
    await HiveManager.salesOrderBox.put(key, order);
    await HiveManager.salesOrderBox.flush();
    await HiveManager.salesOrderBox.compact();
  }

  Future<void> handlePatchSaleOrderMessage(
      Map<String, dynamic> messageData) async {
    if (PatchHandler._messageBox == null) {
      await PatchHandler.init();
    }

    await PatchHandler._lock.synchronized(() async {
      try {
        PatchHandler.clearExpiredMessages();

        // Try fetching messageId from root or patchSaleOrder
        final messageId = messageData['messageId']?.toString() ??
            messageData['patchSaleOrder']?['messageId']?.toString();

        // Try fetching saleOrderNo from root or patchSaleOrder
        final salesOrderId = messageData['saleOrderNo']?.toString() ??
            messageData['patchSaleOrder']?['saleOrderNo']?.toString() ??
            messageData['patchSaleOrder']?['data']?['saleOrderNo']?.toString();

        if (messageId == null || salesOrderId == null || salesOrderId.isEmpty) {
          return;
        }

        if (PatchHandler.containsMessage(messageId)) {
          return;
        }

        final patchData =
            messageData['patchSaleOrder']?['data'] as Map<String, dynamic>?;
        if (patchData == null || patchData.isEmpty) {
          return;
        }

        final salesOrdersBox = HiveManager.salesOrderBox;

        final matchingEntries = salesOrdersBox.toMap().entries.where((entry) {
          final entryData = entry.value['data'] ?? entry.value;
          return entryData is Map && entryData['saleOrderNo'] == salesOrderId;
        }).toList();

        for (var entry in matchingEntries) {}

        if (matchingEntries.isEmpty) {
          return;
        }

        if (matchingEntries.length > 1) {
          matchingEntries.sort((a, b) => (b.value['lastUpdated'] ?? '')
              .compareTo(a.value['lastUpdated'] ?? ''));
          for (var entry in matchingEntries.skip(1)) {
            await salesOrdersBox.delete(entry.key);
          }
        }

        final targetEntry = matchingEntries.firstWhere(
          (entry) => entry.key == salesOrderId,
          orElse: () => matchingEntries.first,
        );

        if (targetEntry.key != salesOrderId) {
          try {
            await salesOrdersBox.put(salesOrderId, targetEntry.value);
            await salesOrdersBox.delete(targetEntry.key);
          } catch (e) {
            return;
          }
        }

        PatchHandler.addProcessedMessage(messageId);

        final updatedOrder = Map<String, dynamic>.from(targetEntry.value);
        Map<String, dynamic> orderData;
        if (updatedOrder['data'] is Map) {
          orderData = Map<String, dynamic>.from(updatedOrder['data']);
        } else {
          orderData = Map<String, dynamic>.from(updatedOrder);
          updatedOrder.clear();
          updatedOrder['data'] = orderData;
        }

        // Apply patchData
        orderData.addAll(patchData);
        updatedOrder['data'] = orderData;
        updatedOrder['lastUpdated'] = DateTime.now().toIso8601String();
        updatedOrder['patchId'] = messageId;

        try {
          await putOrder(salesOrderId, updatedOrder);

          final savedOrder = salesOrdersBox.get(salesOrderId);

          notifyListeners();
        } catch (e) {
          PatchHandler.removeMessage(messageId);
          return;
        }
      } catch (e, stackTrace) {}
    });
  }

  Future<void> _patchSaleOrder(Map<String, dynamic> patchData) async {
    final box = HiveManager.salesOrderBox;
    final newSaleOrderNo = patchData['salesOrderId'];

    int? existingKey;
    dynamic matchedOrder;

    for (var key in box.keys) {
      final value = box.get(key);
      if (value is Map &&
          (value['saleOrderNo'] == newSaleOrderNo ||
              value['id'] == patchData['id'])) {
        existingKey = key;
        matchedOrder = value;
        break;
      }
    }

    if (existingKey != null) {
      await box.put(existingKey, patchData);
    } else {
      await box.add(patchData);
    }
  }

  Future<void> _patchHoldOrder(Map<String, dynamic> patchData) async {
    final box = HiveManager.holdOrderBox;
    final newSaleOrderNo = patchData['holdOrderId'];

    dynamic existingKey; // Changed from int? to dynamic
    dynamic matchedOrder;

    for (var key in box.keys) {
      final value = box.get(key);
      if (value is Map &&
          (value['holdOrderId'] == newSaleOrderNo ||
              value['id'] == patchData['id'])) {
        existingKey = key;
        matchedOrder = value;
        break;
      }
    }

    if (existingKey != null) {
      await box.put(existingKey, patchData);
    } else {
      await box.add(patchData);
    }
  }

  Future<void> handleMessage(dynamic message) async {
    try {
      // print("📩 Message received");

      final jsonData = jsonDecode(message);
      // print('✅ Decoded JSON: $jsonData');

      final action = jsonData['action'];

      switch (action) {
        case 'invoiceGenerated':
          print("📩 Event: invoiceGenerated received");

          final invoice = jsonData['invoice'];
          print("🔎 Extracted invoice from jsonData → $invoice");

          if (invoice == null) {
            print("❌ invoice is NULL → breaking");
            break;
          }

          final salesOrder = invoice['salesOrderId'];
          print("🔎 Extracted salesOrder from invoice → $salesOrder");

          if (salesOrder != null && salesOrder is Map<String, dynamic>) {
            // Step 2: Generate unique identifier
            String generatedUniqueId =
                '${salesOrder['invoiceDate']}-${salesOrder['totalAmount']}-${salesOrder['orderInvoiceNo']}';
            print("🆕 Generated uniqueIdentifier → $generatedUniqueId");

            // Step 3: Add fields to invoice object before saving
            invoice['uniqueIdentifier'] =
                invoice['uniqueIdentifier'] ?? generatedUniqueId;
            print(
                "📦 Final invoice['uniqueIdentifier'] → ${invoice['uniqueIdentifier']}");

            // Step 4: Add metadata to salesOrder
            invoice['salesOrderId']['type'] = invoice['type'];
            invoice['salesOrderId']['sync'] = invoice['sync'];
            invoice['salesOrderId']['edit'] = invoice['edit'];

            // Step 5: Save to Hive
            try {
              print("💾 Attempting to save invoice to Hive...");
              await saveInvoiceToHive(invoice);
              print("✅ Invoice saved successfully");

              final orders = await getInvoiceOrders();
              print(
                  "📦 Retrieved all invoice orders → ${orders.length} orders found");
            } catch (e, st) {
              print("❌ Error while saving invoice: $e");
              print("📜 Stacktrace: $st");
            }
          } else {
            // salesOrder invalid or null
            if (salesOrder != null) {
              print("⚠️ salesOrder exists but is not a Map<String, dynamic>");
            } else {
              print("❌ salesOrder is NULL inside invoice");
            }
          }

          // Step 6: Update receipt printer
          print("🖨️ Updating receipt printer with salesOrder data...");
          receiptPrinter.updateInvoiceReceiptData(salesOrder);

          // Step 7: Notify listeners
          print("📢 Notifying listeners about new invoice...");
          notifyListeners();

          print("🏁 Finished processing invoiceGenerated event");
          break;
        case 'OpSalesOrderGenerated':
          final salesOrder = jsonData['opSalesOrder'];
          if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
            print("⚠️ Invalid salesOrder");
            return;
          }

          final orderData = salesOrder['data'] ?? {};
          if (orderData is! Map<String, dynamic>) {
            print("⚠️ Invalid order data");
            return;
          }

          final saleOrderNo = orderData['saleOrderNo']?.toString();
          if (saleOrderNo == null || saleOrderNo.isEmpty) {
            print("⚠️ saleOrderNo missing");
            return;
          }

          // Debounce based on saleOrderNo
          if (_debounceTimers.containsKey(saleOrderNo)) {
            print("🔄 Debouncing duplicate message for $saleOrderNo");
            return;
          }

          // Set debounce timer for this saleOrderNo
          _debounceTimers[saleOrderNo] = Timer(Duration(milliseconds: 500), () {
            _debounceTimers.remove(saleOrderNo); // Clear timer after processing
          });

          print("📝 Processing sales order $saleOrderNo...");

          // Add metadata
          orderData['type'] = 'opSalesOrder';

          // Check in-memory cache
          if (_processedOrders.contains(saleOrderNo)) {
            print("🔄 Already processed $saleOrderNo in memory");
            return;
          }

          // Check Hive storage
          final salesOrderBox = HiveManager.salesOrderBox;
          if (salesOrderBox.containsKey(saleOrderNo)) {
            print("⚠️ Order $saleOrderNo already exists in Hive, skipping");
            _processedOrders.add(saleOrderNo);
            return;
          }

          // Save to Hive
          try {
            print("📝 Saving order $saleOrderNo to Hive...");
            await salesOrderBox.put(saleOrderNo, orderData);
            _processedOrders.add(saleOrderNo);
            print("✅ Saved order: $saleOrderNo");

            print("📦 Sales order data: $salesOrder");

            // Update receipt printer
            print("🧾 Updating receipt with: $orderData");
            final orders = await getSavedSalesOrders();
            print("📦 All saved sales orders from patch: $orders");

            notifyListeners();
          } catch (e) {
            print("❌ Error saving order $saleOrderNo: $e");
            _processedOrders.remove(saleOrderNo); // Allow retry on failure
          }
          break;
        case 'salesOrderGenerated':
          final salesOrder = jsonData['salesOrder'];
          if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
            return;
          }

          // 🔍 Print audio/image1/image2 file paths
          final audioPath =
              salesOrder["data"]['audioPath'] ?? '❌ No audio path found';
          final image1Path =
              salesOrder["data"]['imagePath1'] ?? '❌ No image1 path found';
          final image2Path =
              salesOrder["data"]['imagePath2'] ?? '❌ No image2 path found';

          final orderData = salesOrder['data'] ?? {};
          if (orderData is! Map<String, dynamic>) {
            return;
          }

          final saleOrderNo = orderData['saleOrderNo']?.toString();
          if (saleOrderNo == null || saleOrderNo.isEmpty) {
            return;
          }

          // Debounce based on saleOrderNo
          if (_debounceTimers.containsKey(saleOrderNo)) {
            return;
          }

          _debounceTimers[saleOrderNo] = Timer(Duration(milliseconds: 500), () {
            _debounceTimers.remove(saleOrderNo);
          });

          // Add metadata and file paths to order data
          orderData['type'] = 'salesOrder';
          orderData['audioPath'] = audioPath;
          orderData['imagePath1'] = image1Path;
          orderData['imagePath2'] = image2Path;

          // Check in-memory cache
          if (_processedOrders.contains(saleOrderNo)) {
            return;
          }

          // Check Hive storage
          final salesOrderBox = HiveManager.salesOrderBox;
          if (salesOrderBox.containsKey(saleOrderNo)) {
            _processedOrders.add(saleOrderNo);
            return;
          }

          // Save to Hive
          try {
            await salesOrderBox.put(saleOrderNo, orderData);
            _processedOrders.add(saleOrderNo);

            final encoder = JsonEncoder.withIndent('  ');
            print("print reciept started");
            // Update receipt printer
            receiptPrinter.updateReceiptData(orderData);

            notifyListeners();
          } catch (e) {
            _processedOrders.remove(saleOrderNo); // Allow retry on failure
          }

          break;
        case 'holdOrderGenerated':
          final salesOrder = jsonData['holdOrder'];
          if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
            return;
          }

          final orderDataList = salesOrder['data'] ?? [];
          if (orderDataList is! List || orderDataList.isEmpty) {
            return;
          }

          final orderData = orderDataList[0]; // Assuming single item for now
          if (orderData is! Map<String, dynamic>) {
            return;
          }

          final saleOrderNo = orderData['holdOrderId']?.toString();
          if (saleOrderNo == null || saleOrderNo.isEmpty) {
            return;
          }

// Debounce based on saleOrderNo
          if (_debounceTimers.containsKey(saleOrderNo)) {
            return;
          }
          _debounceTimers[saleOrderNo] = Timer(Duration(milliseconds: 500), () {
            _debounceTimers.remove(saleOrderNo);
          });

// Add metadata
          orderData['type'] = 'holdOrder';

// Check in-memory cache
          if (_processedHoldOrders.contains(saleOrderNo)) {
            return;
          }

// Check Hive storage
          final salesOrderBox = HiveManager.holdOrderBox;
          if (salesOrderBox.containsKey(saleOrderNo)) {
            _processedHoldOrders.add(saleOrderNo);
            return;
          }

// Save to Hive
          try {
            await salesOrderBox.put(saleOrderNo, orderData);
            _processedHoldOrders.add(saleOrderNo);
          } catch (e) {
            _processedHoldOrders.remove(saleOrderNo);
          }

          break;

        case 'salesApprovalOrderGenerated':
          await _saveApproveOrderToHive(jsonData['salesApprovalOrder']);
          final approvalOrders = await getSavedApprovalOrder();
          break;

        case 'salesModifyOrderGenerated':
          await _saveModifyOrderToHive(jsonData['salesModifyOrder']);
          final modifyOrders = await getModifyOrder();
          break;
        case 'salesOrderAddCustomerGenerated':
          await _saveAddNewCustomerToHive(jsonData['salesOrderAddCustomer']);
          final addnewCustomer = await _getAddnewCustomer();
          break;

        case 'saleorderPatchGenerated':
          final patchOrder = jsonData['patchSaleOrder'];

          await _patchSaleOrder(patchOrder);
          final orders = await getSavedSalesOrders();
          if (orders.isNotEmpty) {
            saleInvoicereceiptPrinter.updateReceiptData(orders.last);
          } else {}
          break;
        case 'patchholdorderGenerated':
          final patchOrder = jsonData['patchHoldOrder'];

          await _patchHoldOrder(patchOrder);
          final orders = await getSavedHoldOrders();
          if (orders.isNotEmpty) {
            saleInvoicereceiptPrinter.updateReceiptData(orders.last);
          } else {}
          break;
        case 'toApproveOrderGenerated':
          final salesOrder = jsonData['toApproveOrder'];
          if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
            return;
          }

          final orderData = salesOrder['data'] ?? {};
          if (orderData is! Map<String, dynamic>) {
            return;
          }

          final saleOrderNo = orderData['saleOrderNo']?.toString();
          if (saleOrderNo == null || saleOrderNo.isEmpty) {
            return;
          }

          // Debounce based on saleOrderNo
          if (_debounceTimers.containsKey(saleOrderNo)) {
            return;
          }

          // Set debounce timer for this saleOrderNo
          _debounceTimers[saleOrderNo] = Timer(Duration(milliseconds: 500), () {
            _debounceTimers.remove(saleOrderNo); // Clear timer after processing
          });

          // Add metadata
          orderData['type'] = 'postToApprove';

          // Check in-memory cache
          if (_processedToApproveOrders.contains(saleOrderNo)) {
            return;
          }

          // Check Hive storage
          final salesOrderBox = HiveManager.toApproveOrderBox;
          if (salesOrderBox.containsKey(saleOrderNo)) {
            _processedToApproveOrders.add(saleOrderNo);
            return;
          }

          // Save to Hive
          try {
            await salesOrderBox.put(saleOrderNo, orderData);
            _processedToApproveOrders.add(saleOrderNo);
          } catch (e) {
            _processedToApproveOrders
                .remove(saleOrderNo); // Allow retry on failure
          }
          break;
        case 'modifyOrderGenerated':
          final salesOrder = jsonData['modifyOrder'];
          if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
            return;
          }

          final orderData = salesOrder['data'] ?? {};
          if (orderData is! Map<String, dynamic>) {
            return;
          }

          final saleOrderNo = orderData['saleOrderNo']?.toString();
          if (saleOrderNo == null || saleOrderNo.isEmpty) {
            return;
          }

          // Debounce based on saleOrderNo
          if (_debounceTimers.containsKey(saleOrderNo)) {
            return;
          }

          // Set debounce timer for this saleOrderNo
          _debounceTimers[saleOrderNo] = Timer(Duration(milliseconds: 500), () {
            _debounceTimers.remove(saleOrderNo); // Clear timer after processing
          });

          // Add metadata
          orderData['type'] = 'salesOrder';

          // Check in-memory cache
          if (_processedModifyOrders.contains(saleOrderNo)) {
            return;
          }

          // Check Hive storage
          final salesOrderBox = HiveManager.modifyOrderBox;
          if (salesOrderBox.containsKey(saleOrderNo)) {
            _processedModifyOrders.add(saleOrderNo);
            return;
          }

          // Save to Hive
          try {
            await salesOrderBox.put(saleOrderNo, orderData);
            _processedModifyOrders.add(saleOrderNo);
          } catch (e) {
            _processedModifyOrders
                .remove(saleOrderNo); // Allow retry on failure
          }
          break;
        case 'patchsaleorderGenerated':
          await handlePatchSaleOrderMessage(jsonData);
          final orders = await getSavedSalesOrders();

          break;

        default:
          // print("⚠️ Unrecognized action: $action");
          // break;
          return;
        // print("⚠️ Unrecognized action: $action");
      }
    } catch (e) {}
  }

  /// Save the full invoice (not only salesOrderId) into Hive
  Future<void> saveInvoiceToHive(Map<String, dynamic> invoiceData) async {
    print("🚀 [saveInvoiceToHive] Called with invoiceData: $invoiceData");

    try {
      var invoiceBox = HiveManager.invoiceBox;
      print("📂 [saveInvoiceToHive] Hive box 'invoices' opened");

      // Extract orderInvoiceNo safely
      final salesOrder = invoiceData['salesOrderId'];
      if (salesOrder == null || salesOrder is! Map<String, dynamic>) {
        print("❌ [saveInvoiceToHive] Invalid salesOrderId → cannot save");
        return;
      }

      final orderInvoiceNo = salesOrder['orderInvoiceNo'];
      if (orderInvoiceNo == null || orderInvoiceNo.toString().isEmpty) {
        print("❌ [saveInvoiceToHive] Missing orderInvoiceNo → cannot save");
        return;
      }

      // 🔑 Step: Save with orderInvoiceNo as key (will overwrite if already exists)
      await invoiceBox.put(orderInvoiceNo, invoiceData);
      print(
          "✅ [saveInvoiceToHive] Invoice saved/updated with key = $orderInvoiceNo");
    } catch (e, st) {
      print("❌ [saveInvoiceToHive] Error: $e");
      print("🛑 Stacktrace: $st");
    }
  }

  Future<void> _saveApproveOrderToHive(Map<String, dynamic> salesOrder) async {
    // Step 1: Open Hive box
    var approveOrderBox = await Hive.openBox('salesApprovalOrder');

    // Step 2: Extract and clean order data
    Map<String, dynamic> orderToSave = salesOrder;

    if (salesOrder.containsKey('data') &&
        salesOrder['data'] is List &&
        (salesOrder['data'] as List).isNotEmpty) {
      orderToSave =
          Map<String, dynamic>.from((salesOrder['data'] as List).first);
    } else {}

    // Step 3: Validate and extract saleOrderNo
    final saleOrderNo = orderToSave['saleOrderNo']?.toString();
    if (saleOrderNo == null) {
      return;
    }

    // Step 4: Check for duplicates
    final exists = approveOrderBox.values.any((storedOrder) {
      if (storedOrder is Map<String, dynamic>) {
        return storedOrder['saleOrderNo']?.toString() == saleOrderNo;
      }
      return false;
    });

    // Step 5: Save or skip
    if (!exists) {
      await approveOrderBox.add(orderToSave);
    } else {}
  }

  Future<void> _saveAddNewCustomerToHive(
      Map<String, dynamic> customerData) async {
    var customerBox = await Hive.openBox('customerBox');

    final newMobile = customerData['mobileNo']?.toString() ?? '';

    // 🔎 Check if mobile number already exists in Hive
    bool exists = customerBox.values.any((customer) {
      final existingMobile = customer['mobileNo']?.toString() ?? '';
      return existingMobile == newMobile;
    });

    if (exists) {
    } else {
      await customerBox.add(customerData);
    }
  }

  Future<List<Map<String, dynamic>>> _getAddnewCustomer() async {
    var customerBox = await Hive.openBox('customerBox');
    return customerBox.values
        .map((customer) => Map<String, dynamic>.from(customer))
        .toList();
  }

  Future<void> _saveModifyOrderToHive(Map<String, dynamic> salesOrder) async {
    var approveOrderBox = HiveManager.modifyOrderBox;
    Map<String, dynamic> orderToSave = salesOrder;
    // If the salesOrder has a nested 'data' key with a list, use its first element.
    if (salesOrder.containsKey('data') &&
        salesOrder['data'] is List &&
        (salesOrder['data'] as List).isNotEmpty) {
      orderToSave = Map<String, dynamic>.from(
        (salesOrder['data'] as List).first,
      );
    }
    await approveOrderBox.add(orderToSave);
  }

  Map<String, int> saleOrderNoCounts = {};

  Future<List<Map<String, dynamic>>> getSavedSalesOrders() async {
    try {
      final saleOrderBox = HiveManager.salesOrderBox;

      final seenSaleOrderNos = <String>{};
      final uniqueOrders = <Map<String, dynamic>>[];
      final keysToDelete = <dynamic>[];

      final allEntries = saleOrderBox.toMap();

      // Strict pattern for valid sales order number: e.g., SOAR250001
      final validPattern = RegExp(r'^SO[A-Z]{2}\d{6}$');

      for (var entry in allEntries.entries) {
        final key = entry.key;
        final order = entry.value;

        if (order is Map) {
          final orderMap = Map<String, dynamic>.from(order);
          final dataMap = orderMap['data'] is Map
              ? Map<String, dynamic>.from(orderMap['data'])
              : orderMap;

          final saleOrderNo = dataMap['saleOrderNo']?.toString();

          if (saleOrderNo != null && saleOrderNo.trim().isNotEmpty) {
            if (!validPattern.hasMatch(saleOrderNo)) {
              // Invalid format → delete or skip
              keysToDelete.add(key);

              continue;
            }

            if (!seenSaleOrderNos.contains(saleOrderNo)) {
              seenSaleOrderNos.add(saleOrderNo);
              uniqueOrders.add(orderMap);
            } else {
              keysToDelete.add(key);
            }
          } else {}
        } else {}
      }

      if (keysToDelete.isNotEmpty) {
        await saleOrderBox.deleteAll(keysToDelete);
      } else {}

      return uniqueOrders;
    } catch (e) {
      rethrow;
    }
  }

  // Future<List<Map<String, dynamic>>> getInvoiceOrders() async {
  //   try {

  //     final invoiceBox = HiveManager.invoiceBox;
  //     final seenSaleOrderNos = <String>{};
  //     final uniqueOrders = <Map<String, dynamic>>[];
  //     final keysToDelete = <dynamic>[];

  //     final allEntries = invoiceBox.toMap();

  //     // Strict pattern for valid sales order number: e.g., SOAR250001
  //     final validPattern = RegExp(r'^SO[A-Z]{2}\d{6}$');

  //     for (var entry in allEntries.entries) {
  //       final key = entry.key;
  //       final order = entry.value;

  //       if (order is Map) {
  //         final orderMap = Map<String, dynamic>.from(order);
  //         final dataMap = orderMap['data'] is Map
  //             ? Map<String, dynamic>.from(orderMap['data'])
  //             : orderMap;

  //         final saleOrderNo = dataMap['saleOrderNo']?.toString();

  //         if (saleOrderNo != null && saleOrderNo.trim().isNotEmpty) {
  //           if (!validPattern.hasMatch(saleOrderNo)) {
  //             // Invalid format → delete or skip
  //             keysToDelete.add(key);

  //             continue;
  //           }

  //           if (!seenSaleOrderNos.contains(saleOrderNo)) {
  //             seenSaleOrderNos.add(saleOrderNo);
  //             uniqueOrders.add(orderMap);
  //           } else {
  //             keysToDelete.add(key);
  //           }
  //         } else {}
  //       } else {}
  //     }

  //     if (keysToDelete.isNotEmpty) {
  //       await invoiceBox.deleteAll(keysToDelete);
  //     } else {}

  //     return uniqueOrders;
  //   } catch (e) {
  //     rethrow;
  //   }
  // }

  Future<List<Map<String, dynamic>>> getSavedHoldOrders() async {
    try {
      final saleOrderBox = HiveManager.holdOrderBox;

      final seenSaleOrderNos = <String>{};
      final uniqueOrders = <Map<String, dynamic>>[];
      final keysToDelete = <dynamic>[];

      for (var entry in saleOrderBox.toMap().entries) {
        final key = entry.key;
        final order = entry.value;

        if (order is Map) {
          final orderMap = Map<String, dynamic>.from(order);
          // Check for saleOrderNo in the nested data map
          final dataMap = orderMap['data'] is Map
              ? Map<String, dynamic>.from(orderMap['data'])
              : orderMap;
          final saleOrderNo = dataMap['holdOrderId'] as String?;

          if (saleOrderNo != null) {
            if (!seenSaleOrderNos.contains(saleOrderNo)) {
              seenSaleOrderNos.add(saleOrderNo);
              uniqueOrders.add(orderMap);
            } else {
              keysToDelete.add(key);
            }
          }
        }
      }

      await saleOrderBox.deleteAll(keysToDelete);
      return uniqueOrders;
    } catch (e) {
      rethrow;
    }
  }

// 3. Update getInvoiceOrders to work with new structure
  Future<List<Map<String, dynamic>>> getInvoiceOrders() async {
    print("🚀 [getInvoiceOrders] Fetching invoices from Hive...");

    try {
      final invoiceBox = HiveManager.invoiceBox;

      // Extract all stored invoices that are Map<String, dynamic>
      final invoices = invoiceBox.values
          .whereType<Map<String, dynamic>>()
          .map((invoice) => Map<String, dynamic>.from(invoice))
          .toList();

      print("📦 [getInvoiceOrders] Found ${invoices.length} invoices.");
      return invoices;
    } catch (e, st) {
      print("❌ [getInvoiceOrders] Error while fetching invoices: $e");
      print("🛑 Stacktrace: $st");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getSavedHoldOrder() async {
    // var holdOrderBox = await Hive.openBox('holdSalesOrderBox');
    try {
      var holdOrderBox = HiveManager.holdOrderBox;

      final seenHoldOrderNos = <String>{};
      final uniqueOrders = <Map<String, dynamic>>[];
      final keysToDelete = <dynamic>[];

      for (var entry in holdOrderBox.toMap().entries) {
        final key = entry.key;
        final order = entry.value;

        if (order is Map) {
          final orderMap = Map<String, dynamic>.from(order);
          // Check for saleOrderNo in the nested data map
          final dataMap = orderMap['data'] is Map
              ? Map<String, dynamic>.from(orderMap['data'])
              : orderMap;
          final saleOrderNo = dataMap['holdOrderId'] as String?;

          if (saleOrderNo != null) {
            if (!seenHoldOrderNos.contains(saleOrderNo)) {
              seenHoldOrderNos.add(saleOrderNo);
              uniqueOrders.add(orderMap);
            } else {
              keysToDelete.add(key);
            }
          }
        }
      }

      await holdOrderBox.deleteAll(keysToDelete);
      return uniqueOrders;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSavedApprovalOrder() async {
    // Step 1: Open the Hive box
    var approvalOrderBox = await Hive.openBox('salesApprovalOrder');

    // Step 2: Check if the box is empty
    if (approvalOrderBox.isEmpty) {
      return [];
    }

    // Step 3: Iterate and log each record before converting
    approvalOrderBox.toMap().forEach((key, value) {});

    // Step 4: Convert each value to a Map<String, dynamic>
    final List<Map<String, dynamic>> approvalOrders =
        approvalOrderBox.values.map((order) {
      final convertedOrder = Map<String, dynamic>.from(order);
      return convertedOrder;
    }).toList();

    // Step 5: Return the result
    return approvalOrders;
  }

  Future<List<Map<String, dynamic>>> getModifyOrder() async {
    try {
      // var modifyOrderBox = await Hive.openBox('modifyOrderBox');

      final modifyOrderBox = HiveManager.modifyOrderBox;
      final seenSaleOrderNos = <String>{};
      final uniqueOrders = <Map<String, dynamic>>[];

      for (var order in modifyOrderBox.values) {
        if (order is Map) {
          final orderMap = Map<String, dynamic>.from(order);
          final saleOrderNo = orderMap['saleOrderNo'] as String?;

          if (saleOrderNo != null && !seenSaleOrderNos.contains(saleOrderNo)) {
            seenSaleOrderNos.add(saleOrderNo);
            uniqueOrders.add(orderMap);
          }
        }
      }

      return uniqueOrders;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getToApproveOrder() async {
    try {
      final modifyOrderBox = HiveManager.toApproveOrderBox;
      final seenSaleOrderNos = <String>{};
      final uniqueOrders = <Map<String, dynamic>>[];
      for (var order in modifyOrderBox.values) {
        if (order is Map) {
          final orderMap = Map<String, dynamic>.from(order);
          final saleOrderNo = orderMap['saleOrderNo'] as String?;

          if (saleOrderNo != null && !seenSaleOrderNos.contains(saleOrderNo)) {
            seenSaleOrderNos.add(saleOrderNo);
            uniqueOrders.add(orderMap);
          }
        }
      }

      return uniqueOrders;
    } catch (e) {
      rethrow;
    }
  }

  void sendMessage(Map<String, dynamic> data) {
    if (_isConnected) {
      try {
        final encodedMessage = jsonEncode(data);
        channel.sink.add(encodedMessage);
        // print('Message sent: $encodedMessage');
      } catch (e) {}
    } else {}
  }

  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isConnected) {
        sendMessage({'action': 'heartbeat'});
      }
    });
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null) return; // Prevent multiple timers
    _reconnectTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!_isConnected) {
        connect();
      } else {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      }
    });
  }

  void closeConnection() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    channel.sink.close();
  }
}
