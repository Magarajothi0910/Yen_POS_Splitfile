import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dio/dio.dart';
import '../../services/branchwise_item_fetch.dart';
import '../../services/stockupdateService.dart';

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
        syncUnsyncedOrders();
        syncUnsyncedSaleOrders();
        syncUnsyncedInvoices(ItemProvider());
      } else {
        debugPrint("⚠️ Device is offline → skipping scheduled sync");
      }
    });
  }

  /// Process all queued sync tasks when online
  Future<void> processSyncQueue() async {
    while (syncQueue.isNotEmpty && isOnline) {
      var task = syncQueue.removeAt(0);
      try {
        await task();
      } catch (e, stack) {
        debugPrint("❌ Task failed with error: $e");
        debugPrint("🪲 Stack trace: $stack");
      }
    }
    debugPrint("📭 Queue processing finished.");
  }

  /// Add a task to the queue
  void queueSync(Function syncTask) {
    syncQueue.add(syncTask);

    if (isOnline) {
      processSyncQueue();
    } else {
      debugPrint("⚠️ Offline → Task queued, will run when back online.");
    }
  }

  /// Monitor network connectivity
  void _monitorConnectivity() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final ConnectivityResult result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;

      isOnline = result != ConnectivityResult.none;

      if (isOnline) {
        processSyncQueue();
      } else {
        debugPrint("🔌 Offline detected → Queue will wait.");
      }
    });
  }

  Future<void> saveOrderToHive(Map<String, dynamic> order) async {
    var orderBox = await Hive.openBox('ordersBox');
    order['sync'] = 'No';
    order['edit'] = 'No'; // Initialize edit field as "No" for new orders
    await orderBox.add(order);

    await syncUnsyncedOrders();
  }

  Future<void> saveInvoiceToHive(Map<String, dynamic> invoice) async {
    var invoiceBox = await Hive.openBox('invoicesBox');
    invoice['sync'] = 'No';
    invoice['edit'] = 'No'; // Initialize edit field as "No" for new invoices
    await invoiceBox.add(invoice);

    // Check connectivity and try to sync after saving locally
    await syncUnsyncedInvoices(ItemProvider());
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

  Future<void> syncUnsyncedOrders() async {
    if (_isSyncing) return;
    _isSyncing = true;

    var orderBox = await Hive.openBox('ordersBox');
    for (int i = 0; i < orderBox.length; i++) {
      var orderData = orderBox.getAt(i);
      if (orderData is String) {
        orderData = jsonDecode(orderData) as Map<String, dynamic>;
      }

      if (orderData is Map<String, dynamic> && orderData['sync'] == 'No') {
        queueSync(() => postOrder(orderData));
      }
    }
    _isSyncing = false;
    await patchEditedOrders();
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

  Future<void> patchEditedOrders() async {
    var orderBox = await Hive.openBox('ordersBox');

    for (int i = 0; i < orderBox.length; i++) {
      var orderData = orderBox.getAt(i);
      if (orderData is String) {
        orderData = jsonDecode(orderData) as Map<String, dynamic>;
      }
      if (orderData is Map<String, dynamic> &&
          orderData['sync'] == 'Yes' &&
          orderData['edit'] == 'Yes') {
        //  Case 1: fieldsEdited == "true" (Update quantities and cancelledQty)
        if (orderData['fieldsEdited'] == 'true') {
          final hiveOrderId = orderData['hiveOrderId'].toString();

          // Patch quantities and cancelledQty
          bool patchedFields =
              await patchFieldsByHiveOrderId(hiveOrderId, orderData);

          if (patchedFields) {
            orderData['edit'] = 'No'; // Reset edit flag after successful patch
            orderData['fieldsEdited'] = 'false';
            await orderBox.putAt(i, orderData);
          } else {}
        }

        // Case 2: statusEdited == "true" (Update status)
        if (orderData['statusEdited'] == 'true' &&
            orderData.containsKey('seathiveOrderId')) {
          final seathiveOrderId = orderData['seathiveOrderId'].toString();
          final status = orderData['status'];

          // Patch status
          bool patchedStatus =
              await patchOrderStatusWithRetry(seathiveOrderId, status);

          if (patchedStatus) {
            orderData['edit'] = 'No'; // Reset edit flag after successful patch
            orderData['statusEdited'] = 'false';
            await orderBox.putAt(i, orderData);
          } else {}
        }
      }
    }
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
        queueSync(() => postAddNewCustomerOrder(
              name: name,
              mobile: mobile,
              branchId: branchId,
            ));
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

  Future<bool> patchOrderStatusWithRetry(String seathiveOrderId, String status,
      {int retries = 3}) async {
    for (int attempt = 0; attempt < retries; attempt++) {
      bool success =
          await patchOrderStatusBySeathiveOrderId(seathiveOrderId, status);
      if (success) {
        return true;
      } else {}
    }
    return false;
  }

  Future<bool> patchOrderStatusBySeathiveOrderId(
      String seathiveOrderId, String status) async {
    try {
      final patchUrl =
          Uri.parse('${apiUrl}patch-status/$seathiveOrderId?status=$status');

      final response = await http.patch(
        patchUrl,
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> patchFieldsByHiveOrderId(
      String hiveOrderId, Map<String, dynamic> fields) async {
    try {
      final patchUrl = Uri.parse('${apiUrl}patch-fields/$hiveOrderId');
      Map<String, dynamic> patchData = {
        'hiveOrderId': hiveOrderId,
      };

      if (fields.containsKey('quantities')) {
        patchData['quantities'] = fields['quantities'];
      }

      if (fields.containsKey('cancelledQty')) {
        patchData['cancelledQty'] = fields['cancelledQty'];
      }
      if (fields.containsKey('amounts')) {
        patchData['amounts'] = fields['amounts'];
      }
      if (fields.containsKey('totalAmount')) {
        patchData['totalAmount'] = fields['totalAmount'];
      }

      final response = await http.patch(
        patchUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(patchData),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> postOrder(Map<String, dynamic> order) async {
    try {
      if (!isOnline) {
        queueSync(() => postOrder(order));
        return false;
      }
      final response = await http.post(
        Uri.parse(apiUrl),
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

  Future<bool> patchOrderTableAndSeat(
      String seathiveOrderId, int table, String seat) async {
    try {
      final patchUrl = Uri.parse(
          '${apiUrl}patch-table-seat/$seathiveOrderId?table=$table&seat=$seat');
      Map<String, dynamic> patchData = {
        'table': table,
        'seat': seat,
      };

      final response = await http.patch(
        patchUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(patchData),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<bool> postToApproveOrder(Map<String, dynamic> salesOrder) async {
    final String salesOrderApi = "https://yenerp.com/fastapi/toapprove/";
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
              "https://yenerp.com/fastapi/salesorders/${patch['salesOrderId']}/"),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(patch['data']),
        );

        if (response.statusCode == 200) {
          await box.delete(patch['salesOrderId']);
        }
      } catch (e) {}
    }
  }

  Future<void> syncUnsyncedInvoices(ItemProvider itemProvider) async {
    if (_isSyncing) return;
    _isSyncing = true;

    var invoiceBox = await Hive.openBox('invoicesBox');
    for (int i = 0; i < invoiceBox.length; i++) {
      var invoiceData = invoiceBox.getAt(i);
      if (invoiceData is String) {
        invoiceData = jsonDecode(invoiceData) as Map<String, dynamic>;
      }

      if (invoiceData is Map<String, dynamic> && invoiceData['sync'] == 'No') {
        bool success =
            await postInvoice(invoiceData, itemProvider, <WebSocketChannel>{});
        if (success) {
          invoiceData['sync'] = 'Yes';
          // await invoiceBox.putAt(i, invoiceData);
        } else {
          break; // Stop if a post fails
        }
      }
    }
    _isSyncing = false;
  }

  Future<bool> postInvoice(
    Map<String, dynamic> invoice,
    ItemProvider itemProvider,
    Set<WebSocketChannel> clients,
  ) async {
    /* ───────── 0. Normalise payment fields (kept from your code) ───────── */
    invoice['cash'] = int.tryParse(invoice['cash']?.toString() ?? '') ?? 0;
    invoice['card'] = int.tryParse(invoice['card']?.toString() ?? '') ?? 0;
    invoice['upi'] = int.tryParse(invoice['upi']?.toString() ?? '') ?? 0;

    /* ───────── 1.  LOCAL STOCK UPDATE — always runs ───────── */
    final so = Map<String, dynamic>.from(invoice['salesOrderId'] ?? {});
    final vn = List<dynamic>.from(so['varianceName'] ?? const []);
    final qt = List<dynamic>.from(so['qty'] ?? const []);
    final ic = List<dynamic>.from(so['itemCode'] ?? const []);

    final branchAlias = invoice['branchAlias']?.toString() ?? 'AR';

    int updated = 0;
    for (int i = 0; i < vn.length; i++) {
      final qty = (i < qt.length ? (qt[i] as num?)?.toInt() : 0) ?? 0;
      String? code = (i < ic.length && (ic[i]?.toString().isNotEmpty ?? false))
          ? ic[i].toString()
          : itemProvider.varianceCodeForName(vn[i]?.toString() ?? '');

      if (code != null && qty > 0) {
        await updateLocalHiveStock(
            branchAlias: 'AR', // or dynamic branch alias
            varianceCodes: List<String>.from(['varianceCode']),
            varianceNames: List<String>.from(['varianceNames']),
            stockUpdates: List<int>.from(['stockUpdates']),
            clients: clients);

        updated++;
      }
    }

    /* ───────── 2.  Attempt remote POST (skip if no internet) ───────── */
    final hasNet =
        await Connectivity().checkConnectivity() != ConnectivityResult.none;

    if (!hasNet) {
      await _stashOffline(invoice);
      return false; // not sent, but stock ok
    }

    try {
      final res = await http.post(
        Uri.parse(invoiceApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(invoice),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        return true; // success
      } else {
        await _stashOffline(invoice);
        return false;
      }
    } catch (e) {
      await _stashOffline(invoice);
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
      String saleOrderNo, Map<String, dynamic> fullOrderData) async {
    final Map<String, dynamic> finalPayload =
        Map<String, dynamic>.from(fullOrderData['data'] ?? {});

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
        'https://yenerp.com/fastapi/salesorders/by-saleorderno/$saleOrderNo');

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
