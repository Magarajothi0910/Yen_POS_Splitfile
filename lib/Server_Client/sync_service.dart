import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import 'package:yenpos/Global/Provider/branchwise_item_fetch.dart';
import 'package:yenpos/Server_Client/stockupdateService.dart';

class SyncService {
  // ====== API URLs ======
  final String apiUrl = 'https://yenerp.com/orders/';
  final String invoiceApiUrl = 'https://yenerp.com/fastapi/invoices/';
  final String modifyApiUrl = 'https://yenerp.com/fastapi/modify/';
  final String holdOrderApi = "https://yenerp.com/fastapi/salesorders/";
  final String salesApprovalOrders = "https://yenerp.com/fastapi/approvals/";
  static const String salesOrderApi = "https://yenerp.com/fastapi/salesorders/";

  // ====== Hive Box Names ======
  static const String salesOrdersBoxName =
      'saleOrderBox'; // (sales orders only)
  static const _offlineBoxName = 'pendingInvoices';

  bool _isSyncing = false;
  bool isOnline = false;

  List<Function> syncQueue = [];

  SyncService() {
    _monitorConnectivity();

    Timer.periodic(const Duration(minutes: 10), (timer) {
      if (isOnline) {
        syncUnsyncedSaleOrders();
        syncUnsyncedInvoices();
        syncUnsyncedHoldOrders();
      } else {}
    });
  }

  /// Process all queued sync tasks when online
  Future<void> processSyncQueue() async {
    while (syncQueue.isNotEmpty && isOnline) {
      var task = syncQueue.removeAt(0);
      try {
        await task();
      } catch (e, stack) {}
    }
  }

  /// Add a task to the queue
  void queueSync(Function syncTask) {
    syncQueue.add(syncTask);

    if (isOnline) {
      processSyncQueue();
    } else {}
  }

  /// Monitor network connectivity
  void _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final ConnectivityResult result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;

      isOnline = result != ConnectivityResult.none;

      if (isOnline) {
        processSyncQueue();
      } else {}
    });
  }

  Future<void> saveKotInvoiceToHive(Map<String, dynamic> invoice) async {
    // Step 1: Open Hive box
    final invoiceBox = await Hive.openBox('invoices');

    // Step 2: Add sync/edit flags
    invoice['sync'] = 'No';
    invoice['edit'] = 'No';

    // Step 3: Handle invoiceDate
    if (invoice['invoiceDate'] is DateTime) {
      final originalDate = invoice['invoiceDate'];
      final formattedDate = DateFormat('dd-MM-yyyy').format(originalDate);
      invoice['invoiceDate'] = formattedDate;
    } else if (invoice['invoiceDate'] == null ||
        invoice['invoiceDate'] is! String) {
      final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      invoice['invoiceDate'] = today;
    } else {}

    // Step 4: Save to Hive
    final key = await invoiceBox.add(invoice);

    // Step 5: Verify saved data
    final savedInvoice = invoiceBox.get(key);

    // Step 6: Sync unsynced invoices
    await syncUnsyncedInvoices();
  }

  Future<void> savePosInvoiceToHive(Map<String, dynamic> invoice) async {
    var invoiceBox = await Hive.openBox('invoices');

    invoice['sync'] = 'No';
    invoice['edit'] = 'No'; // Initialize edit field

    await invoiceBox.add(invoice);

    // Check connectivity and try to sync after saving locally
    await syncUnsyncedInvoices();
  }

  Future<void> saveHoldToHive(
    Map<String, dynamic> data,
    Box holdOrderBox,
  ) async {
    var holdOrderBox = await Hive.openBox('holdOrders');

    data['sync'] = 'No';
    data['edit'] = 'No'; // Initialize edit field

    await holdOrderBox.add(data);

    // Check connectivity and try to sync after saving locally
    await syncUnsyncedHoldOrders();
  }

  Future<void> saveInvoiceToHive(Map<String, dynamic> invoice) async {
    var invoiceBox = await Hive.openBox('invoicesBox');
    invoice['sync'] = 'No';
    invoice['edit'] = 'No'; // Initialize edit field as "No" for new invoices
    await invoiceBox.add(invoice);

    // Check connectivity and try to sync after saving locally
    await syncUnsyncedInvoices();
  }

  Future<void> saveholdOrderToHive(Map<String, dynamic> order) async {
    var holdOrderBox = await Hive.openBox('holdOrders');
    order['sync'] = 'No';
    order['edit'] = 'No'; // Initialize edit field as "No" for new orders
    await holdOrderBox.add(order);
  }

  Future<void> saveSalesApprovalOrderToHive(Map<String, dynamic> order) async {
    var salesApprovalOrderBox = await Hive.openBox('salesApprovalOrder');
    order['sync'] = 'No';
    order['edit'] = 'No'; // Initialize edit field as "No" for new orders
    await salesApprovalOrderBox.add(order);
  }

  Future<void> syncUnsyncedSaleOrders() async {
    if (_isSyncing) return;
    _isSyncing = true;

    var orderBox = await Hive.openBox('saleOrderBox');
    for (int i = 0; i < orderBox.length; i++) {
      var orderData = orderBox.getAt(i);
      if (orderData is String) {
        orderData = jsonDecode(orderData) as Map<String, dynamic>;
      }

      if (orderData is Map<String, dynamic> && orderData['sync'] == 'No') {
        queueSync(() => postSalesOrder(orderData));
      }
    }
    _isSyncing = false;
  }

  Future<bool> postHoldOrder(Map<String, dynamic> order) async {
    try {
      if (!isOnline) {
        queueSync(() => postHoldOrder(order));
        return false;
      }
      final response = await http.post(
        Uri.parse(holdOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(order),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> savePosSaleorderToHive(Map<String, dynamic> invoice) async {
    var invoiceBox = await Hive.openBox('saleOrderBox');

    invoice['sync'] = 'No';
    invoice['edit'] = 'No'; // Initialize edit field

    await invoiceBox.add(invoice);

    // Check connectivity and try to sync after saving locally
    await syncUnsyncedSaleOrders();
  }

  Future<bool> postSalesOrder(Map<String, dynamic> salesOrder) async {
    const String salesOrderApi = "https://yenerp.com/fastapi/salesorders/";
    // Print the payload and URL for debugging

    try {
      if (!isOnline) {
        queueSync(() => postSalesOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      // Debug response details

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> postInvoiceOrder(Map<String, dynamic> salesOrder) async {
    const String salesOrderApi = "https://yenerp.com/fastapi/invoices/";
    // Print the payload and URL for debugging

    try {
      if (!isOnline) {
        queueSync(() => postInvoiceOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      // Debug response details

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> postModifyOrder(Map<String, dynamic> salesOrder) async {
    final String salesOrderApi = "https://yenerp.com/fastapi/modify/";
    // Print the payload and URL for debugging

    try {
      if (!isOnline) {
        queueSync(() => postSalesOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      // Debug response details

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> postAddNewCustomerOrder({
    required String name,
    required String mobile,
    String? branchId,
  }) async {
    const String endpoint = 'https://yenerp.com/fastapi/customers/';

    final body = {
      'customerName': name,
      'customerPhoneNumber': mobile,
      if (branchId != null) 'branchId': branchId,
    };

    try {
      if (!isOnline) {
        queueSync(
          () => postAddNewCustomerOrder(
            name: name,
            mobile: mobile,
            branchId: branchId,
          ),
        );
        return false;
      }

      final res = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      return res.statusCode == 200 || res.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> postSalesApprovalOrder(Map<String, dynamic> order) async {
    try {
      if (!isOnline) {
        queueSync(() => postSalesApprovalOrder(order));
        return false;
      }
      final response = await http.post(
        Uri.parse(salesApprovalOrders),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(order),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> postToApproveOrder(Map<String, dynamic> salesOrder) async {
    final String salesOrderApi = "https://yenerp.com/fastapi/heldorders/";
    // Print the payload and URL for debugging

    try {
      if (!isOnline) {
        queueSync(() => postToApproveOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      // Debug response details

      if (response.statusCode == 201 || response.statusCode == 200) {
        // patchSaleOrder(salesOrder, response.body);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> postToHoldOrder(Map<String, dynamic> salesOrder) async {
    final String salesOrderApi = "https://yenerp.com/fastapi/heldorders/";
    // Print the payload and URL for debugging

    try {
      if (!isOnline) {
        queueSync(() => postToHoldOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      // Debug response details

      if (response.statusCode == 201 || response.statusCode == 200) {
        // patchSaleOrder(salesOrder, response.body);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> postDiscountOrder(Map<String, dynamic> salesOrder) async {
    final String salesOrderApi = "https://yenerp.com/fastapi/heldorders/";
    // Print the payload and URL for debugging

    try {
      if (!isOnline) {
        queueSync(() => postDiscountOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await http.post(
        Uri.parse(salesOrderApi),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(salesOrder),
      );

      // Debug response details

      if (response.statusCode == 201 || response.statusCode == 200) {
        // patchSaleOrder(salesOrder, response.body);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> syncPendingPatches() async {
    if (!isOnline) return;

    final box = await Hive.openBox('pendingPatches');
    final patches = box.values.toList();

    for (var patch in patches) {
      try {
        final response = await http.patch(
          Uri.parse(
            "https://yenerp.com/fastapi/salesorders/${patch['salesOrderId']}/",
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(patch['data']),
        );

        if (response.statusCode == 200) {
          await box.delete(patch['salesOrderId']);
        }
      } catch (e) {}
    }
  }

  Future<void> syncUnsyncedInvoices() async {
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;

    try {
      var invoiceBox = await Hive.openBox('invoices');

      for (int i = 0; i < invoiceBox.length; i++) {
        var invoiceData = invoiceBox.getAt(i);

        // Decode if string
        if (invoiceData is String) {
          invoiceData = jsonDecode(invoiceData);
        }

        if (invoiceData is Map<String, dynamic> &&
            invoiceData['sync'] == 'No') {
          // 🩹 FIX: If the actual data is inside 'salesOrderId', extract it
          if (invoiceData.containsKey('salesOrderId') &&
              invoiceData['salesOrderId'] is Map<String, dynamic>) {
            invoiceData = invoiceData['salesOrderId'];
          }

          bool success = await postInvoice(invoiceData);
          if (success) {
            invoiceData['sync'] = 'Yes';
            // await invoiceBox.putAt(i, invoiceData);
          } else {
            break;
          }
        } else {}
      }
    } catch (e, st) {
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> syncUnsyncedHoldOrders() async {

    // Prevent multiple syncs at the same time
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;

    try {
      // -------------------- Step 1: Open Hive Box --------------------
      final Box holdOrderBox = await Hive.openBox('holdOrderBox');

      int syncedCount = 0;
      int failedCount = 0;

      // -------------------- Step 2: Loop through all entries --------------------
      for (int i = 0; i < holdOrderBox.length; i++) {
        dynamic holdOrderData = holdOrderBox.getAt(i);

        // Decode JSON string if necessary
        if (holdOrderData is String) {
          try {
            holdOrderData = jsonDecode(holdOrderData);
          } catch (e) {
            continue;
          }
        }

        // Validate data type
        if (holdOrderData is! Map<String, dynamic>) {
          continue;
        }

        // Check sync status
        if (holdOrderData['sync'] == 'Yes') {
          continue;
        }


        // Handle nested data if needed
        final dataToSend = holdOrderData['data'] ?? holdOrderData;

        // -------------------- Step 3: Sync with API --------------------
        try {
          bool success = await postToHoldOrder({
            "data": [dataToSend],
          });

          if (success) {
            holdOrderData['sync'] = 'Yes';

            // Replace the existing record
            await holdOrderBox.putAt(i, holdOrderData);
            syncedCount++;
          } else {
            failedCount++;
            break; // Stop sync if API fails
          }
        } catch (e, st) {
          failedCount++;
        }
      }

    } catch (e, st) {
    } finally {
      _isSyncing = false;
    }
  }

  Future<bool> postInvoice(Map<String, dynamic> invoice) async {
    try {
      // Convert payment values safely
      invoice['cash'] = int.tryParse(invoice['cash']?.toString() ?? '') ?? 0;
      invoice['card'] = int.tryParse(invoice['card']?.toString() ?? '') ?? 0;
      invoice['upi'] = int.tryParse(invoice['upi']?.toString() ?? '') ?? 0;

      final response = await http.post(
        Uri.parse(invoiceApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(invoice),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /* ───────── Helper: append unsent invoice to Hive list ───────── */
  Future<void> _stashOffline(Map<String, dynamic> inv) async {
    final box = await Hive.openBox<List>(_offlineBoxName);
    final pending = List<Map<String, dynamic>>.from(box.get('list') ?? []);
    pending.add(inv);
    await box.put('list', pending);
  }

  Future<bool> patchSalesOrder(
    String saleOrderNo,
    Map<String, dynamic> fullOrderData,
  ) async {
    final Map<String, dynamic> finalPayload = Map<String, dynamic>.from(
      fullOrderData['data'] ?? {},
    );

    // Fix advancePaymentType
    if (finalPayload['advancePaymentType'] != null) {
      finalPayload['advancePaymentType'] =
          (finalPayload['advancePaymentType'] as List)
              .map((x) => (x as List).map((y) => y.toString()).toList())
              .toList();
    }

    // Fix modeWiseAmount
    if (finalPayload['modeWiseAmount'] != null) {
      finalPayload['modeWiseAmount'] = (finalPayload['modeWiseAmount'] as List)
          .map((x) => (x as List).map((y) => (y as num).toDouble()).toList())
          .toList();
    }

    // Fix advanceAmount
    if (finalPayload['advanceAmount'] != null) {
      finalPayload['advanceAmount'] = (finalPayload['advanceAmount'] as List)
          .map((e) => (e as num).toDouble())
          .toList();
    }

    // Patch request
    final url = Uri.parse(
      'https://yenerp.com/fastapi/salesorders/by-saleorderno/$saleOrderNo',
    );

    try {
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(finalPayload),
      );

      return response.statusCode == 200;
    } catch (e, st) {
      return false;
    } finally {}
  }

  Future fetchSalesOrderFromApi(saleOrderNo) async {}
}
