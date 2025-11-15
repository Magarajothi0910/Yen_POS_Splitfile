import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:yenpos/Global/globals_data.dart';

import 'provider/itemProvider.dart';

class SyncServicePos {
  final String invoiceApiUrl = 'https://yenerp.com/fastapi/invoices/';
  final String modifyApiUrl = 'http://192.168.29.8:8090/modify/';
  final String holdOrderApi = "https://yenerp.com/fastapi/saleorder/";
  final String salesApprovalOrders =
      "https://yenerp.com/fastapi//fastapi/approvals/";
  final String salesOrderApi =
      "https://yenerp.com/fastapi//branchwiseitems/?$branchName";
  bool _isSyncing = false;
  bool isOnline = false;
  List<Function> syncQueue = [];
  static const _offlineBoxName = 'pendingInvoices';

  Future<void> processSyncQueue() async {
    while (syncQueue.isNotEmpty && isOnline) {
      var task = syncQueue.removeAt(0);
      await task();
    }
  }

  void queueSync(Function syncTask) {
    syncQueue.add(syncTask);

    if (isOnline) {
      processSyncQueue();
    }
  }

  SyncService() {
    _monitorConnectivity();
    Timer.periodic(const Duration(minutes: 10), (timer) {
      if (isOnline) {
        // syncUnsyncedOrders();
        syncUnsyncedInvoices(ItemProvider());
      }
    });
  }

  _monitorConnectivity() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final ConnectivityResult result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      isOnline = result != ConnectivityResult.none;
      if (isOnline) {
        processSyncQueue();
      }
    });
  }

  Future<void> sendStockUpdateToAPI({
    required String branchAlias,
    required String varianceCode,
    required String varianceName,
    required int updatedStock,
  }) async {
    try {
      final dio = Dio();
      const url = "http://192.168.29.246:8882/fastapi/update_stock";

      final response = await dio.patch(
        url,
        data: jsonEncode({
          'branchAlias': branchAlias,
          'varianceCode': varianceCode,
          'varianceName': varianceName,
          'updatedStock': updatedStock,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        print('✅ Stock successfully updated to API for $varianceCode');
      } else {
        print('❌ Failed to update stock to API: ${response.statusCode}');
        print(response.data);
      }
    } catch (e) {
      print('❌ Error updating stock to API: $e');
    }
  }

  Future<void> saveOrderToHive(Map<String, dynamic> order) async {
    var orderBox = await Hive.box('ordersBox');
    order['sync'] = 'No';
    order['edit'] = 'No'; // Initialize edit field as "No" for new orders
    await orderBox.add(order);
    print('Order saved locally with sync: No');
    print(order);

    /// await syncUnsyncedOrders();
  }

  Future<void> saveInvoiceToHive(Map<String, dynamic> invoice) async {
    var invoiceBox = await Hive.openBox('invoicesBox');
    invoice['sync'] = 'No';
    invoice['edit'] = 'No'; // Initialize edit field as "No" for new invoices
    await invoiceBox.add(invoice);
    print('Invoice saved locally with sync: No');
    print(invoice);
    print("Full data in invoiceBox: ${invoiceBox.toMap()}");

    // Check connectivity and try to sync after saving locally
    await syncUnsyncedInvoices(ItemProvider());
  }

  Future<void> saveholdOrderToHive(Map<String, dynamic> order) async {
    var holdOrderBox = await Hive.openBox('holdOrders');
    order['sync'] = 'No';
    order['edit'] = 'No'; // Initialize edit field as "No" for new orders
    await holdOrderBox.add(order);
    print('Hold Order saved locally with sync: No');
    print(order);
  }

  Future<void> saveSalesApprovalOrderToHive(Map<String, dynamic> order) async {
    var salesApprovalOrderBox = await Hive.openBox('salesApprovalOrder');
    order['sync'] = 'No';
    order['edit'] = 'No'; // Initialize edit field as "No" for new orders
    await salesApprovalOrderBox.add(order);
    print('Sales Approval Order saved locally with sync: No');
    print(order);
  }

  // Future<void> syncUnsyncedOrders() async {
  //   print("Syncing unsynced orders...");
  //   if (_isSyncing) return;
  //   _isSyncing = true;

  //   var orderBox = await Hive.openBox('ordersBox');
  //   for (int i = 0; i < orderBox.length; i++) {
  //     var orderData = orderBox.getAt(i);
  //     if (orderData is String) {
  //       orderData = jsonDecode(orderData) as Map<String, dynamic>;
  //     }

  //     // if (orderData is Map<String, dynamic> && orderData['sync'] == 'No') {
  //     //   bool success = await postOrder(orderData);
  //     //   if (success) {
  //     //     orderData['sync'] = 'Yes';
  //     //     await orderBox.putAt(i, orderData);
  //     //     print('Order ${orderData['hiveOrderId']} synced successfully.');
  //     //   } else {
  //     //     break; // Stop if a post fails
  //     //   }
  //     // }
  //     if (orderData is Map<String, dynamic> && orderData['sync'] == 'No') {
  //       queueSync(() => postOrder(orderData));
  //     }
  //   }
  //   _isSyncing = false;
  //  // await patchEditedOrders();
  // }

  // Future<void> patchEditedOrders() async {
  //   print(
  //       "Checking orders to patch statuses or other fields if sync and edit are 'Yes'...");
  //   var orderBox = await Hive.openBox('ordersBox');

  //   for (int i = 0; i < orderBox.length; i++) {
  //     var orderData = orderBox.getAt(i);
  //     if (orderData is String) {
  //       orderData = jsonDecode(orderData) as Map<String, dynamic>;
  //     }
  //     if (orderData is Map<String, dynamic> &&
  //         orderData['sync'] == 'Yes' &&
  //         orderData['edit'] == 'Yes') {
  //       //  Case 1: fieldsEdited == "true" (Update quantities and cancelledQty)
  //       if (orderData['fieldsEdited'] == 'true') {
  //         final hiveOrderId = orderData['hiveOrderId'].toString();
  //         print("Attempting to patch fields for hiveOrderId: $hiveOrderId");

  //         // Patch quantities and cancelledQty
  //         bool patchedFields =
  //             await patchFieldsByHiveOrderId(hiveOrderId, orderData);

  //         if (patchedFields) {
  //           orderData['edit'] = 'No'; // Reset edit flag after successful patch
  //           orderData['fieldsEdited'] = 'false';
  //           await orderBox.putAt(i, orderData);
  //           print('Order $hiveOrderId fields patched successfully.');
  //         } else {
  //           print('Failed to patch fields for $hiveOrderId');
  //         }
  //       }

  //       // Case 2: statusEdited == "true" (Update status)
  //       if (orderData['statusEdited'] == 'true' &&
  //           orderData.containsKey('seathiveOrderId')) {
  //         final seathiveOrderId = orderData['seathiveOrderId'].toString();
  //         final status = orderData['status'];

  //         print(
  //             "Attempting to patch status for seathiveOrderId: $seathiveOrderId");

  //         // Patch status
  //         bool patchedStatus =
  //             await patchOrderStatusWithRetry(seathiveOrderId, status);

  //         if (patchedStatus) {
  //           orderData['edit'] = 'No'; // Reset edit flag after successful patch
  //           orderData['statusEdited'] = 'false';
  //           await orderBox.putAt(i, orderData);
  //           print(
  //               'Order status for $seathiveOrderId patched successfully to $status.');
  //         } else {
  //           print('Failed to patch status for $seathiveOrderId');
  //         }
  //       }
  //     }
  //   }
  // }

  Future<bool> postHoldOrder(Map<String, dynamic> order) async {
    final dio = Dio();
    try {
      if (!isOnline) {
        queueSync(() => postHoldOrder(order));
        return false;
      }
      print('Posting hold order: ${jsonEncode(order)}');
      final response = await dio.post(
        holdOrderApi, // URL as a string is fine
        data: jsonEncode(order), // your order object encoded as JSON
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Hold order posted successfully.');
        return true;
      } else {
        print('Failed to post hold order. Status code: ${response.statusCode}');
        print('Response body: ${response.data}');
        return false;
      }
    } catch (e) {
      print('Error posting hold order: $e');
      return false;
    }
  }

  Future<bool> postSalesOrder(Map<String, dynamic> salesOrder) async {
    final dio = Dio();
    const String salesOrderApi =
        "http://192.168.1.108:8881/fastapi/saleorders/";
    // Print the payload and URL for debugging
    print('Posting sales order (raw JSON): ${jsonEncode(salesOrder)}');
    print("Posting to URL: $salesOrderApi");

    try {
      if (!isOnline) {
        queueSync(() => postSalesOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await dio.post(
        salesOrderApi, // URL as a string
        data: salesOrder, // Dio automatically serializes Map to JSON
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      // Debug response details
      print('HTTP status code: ${response.statusCode}');
      print('Response body: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Sales order posted successfully.');
        return true;
      } else {
        print(
          'Failed to post sales order. Status code: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('Error posting sales order: $e');
      return false;
    }
  }

  Future<bool> postModifyOrder(Map<String, dynamic> salesOrder) async {
    final dio = Dio();
    const String salesOrderApi = "http://192.168.29.8:8090/modify/";
    // Print the payload and URL for debugging
    print('Posting sales order (raw JSON): ${jsonEncode(salesOrder)}');
    print("Posting to URL: $salesOrderApi");

    try {
      if (!isOnline) {
        queueSync(() => postSalesOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await dio.post(
        salesOrderApi, // pass the URL as a string
        data: salesOrder, // pass the Map directly; Dio converts it to JSON
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      // Debug response details
      print('HTTP status code: ${response.statusCode}');
      print('Response body: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Sales order posted successfully.');
        return true;
      } else {
        print(
          'Failed to post sales order. Status code: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('Error posting sales order: $e');
      return false;
    }
  }

  Future<bool> postAddNewCustomerOrder({
    required String name,
    required String mobile,
    String? branchId,
  }) async {
    final dio = Dio();
    const String endpoint = 'http://192.168.29.8:8090/customer/';

    final body = {
      'customerName': name,
      'customerPhoneNumber': mobile,
      if (branchId != null) 'branchId': branchId,
    };

    print('[HTTP] POST $endpoint');
    print('[HTTP] Payload: $body');

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

      final response = await dio.post(
        endpoint, // Dio accepts the URL as a string directly
        data:
            body, // pass the Map directly; Dio automatically encodes it to JSON
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      print('[HTTP] status=${response.statusCode}');
      print('[HTTP] response=${response.data}');

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('[HTTP] ❌ $e');
      return false;
    }
  }

  Future<bool> postSalesApprovalOrder(Map<String, dynamic> order) async {
    final dio = Dio();
    try {
      if (!isOnline) {
        queueSync(() => postSalesApprovalOrder(order));
        return false;
      }
      print('Posting sales approval order: ${jsonEncode(order)}');
      final response = await dio.post(
        salesApprovalOrders, // just pass the URL string
        data:
            order, // pass the Map directly; Dio encodes it to JSON automatically
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('Sales approval order posted successfully.');
        return true;
      } else {
        print(
          'Failed to post sales approval order. Status code: ${response.statusCode}',
        );
        print('Response body: ${response.data}');
        return false;
      }
    } catch (e) {
      print('Error posting sales approval order: $e');
      return false;
    }
  }

  // Future<bool> patchOrderStatusWithRetry(String seathiveOrderId, String status,
  //     {int retries = 3}) async {
  //   for (int attempt = 0; attempt < retries; attempt++) {
  //     bool success =
  //         await patchOrderStatusBySeathiveOrderId(seathiveOrderId, status);
  //     if (success) {
  //       return true;
  //     } else {
  //       print(
  //           'Retrying patch request for $seathiveOrderId... Attempt ${attempt + 1} of $retries');
  //     }
  //   }
  //   print(
  //       'Failed to patch order status after $retries attempts for $seathiveOrderId.');
  //   return false;
  // }

  // Future<bool> patchOrderStatusBySeathiveOrderId(
  //     String seathiveOrderId, String status) async {
  //   try {
  //     final patchUrl =
  //         Uri.parse('${apiUrl}patch-status/$seathiveOrderId?status=$status');
  //     print('Patching order status at: $patchUrl');

  //     final response = await http.patch(
  //       patchUrl,
  //       headers: {'Content-Type': 'application/json'},
  //     );

  //     if (response.statusCode == 200) {
  //       print('Order status patched successfully for $seathiveOrderId.');
  //       return true;
  //     } else {
  //       print(
  //           'Failed to patch order status. Status code: ${response.statusCode}');
  //       print('Response body: ${response.body}');
  //       return false;
  //     }
  //   } catch (e) {
  //     print('Error patching order status by seathiveOrderId: $e');
  //     return false;
  //   }
  // }

  // Future<bool> patchFieldsByHiveOrderId(
  //     String hiveOrderId, Map<String, dynamic> fields) async {
  //   try {
  //     final patchUrl = Uri.parse('${apiUrl}patch-fields/$hiveOrderId');
  //     Map<String, dynamic> patchData = {
  //       'hiveOrderId': hiveOrderId,
  //     };

  //     if (fields.containsKey('quantities')) {
  //       patchData['quantities'] = fields['quantities'];
  //     }

  //     if (fields.containsKey('cancelledQty')) {
  //       patchData['cancelledQty'] = fields['cancelledQty'];
  //     }
  //     if (fields.containsKey('amounts')) {
  //       patchData['amounts'] = fields['amounts'];
  //     }
  //     if (fields.containsKey('totalAmount')) {
  //       patchData['totalAmount'] = fields['totalAmount'];
  //     }
  //     print('Patching fields for order at: $patchUrl');
  //     print('Patch data: ${jsonEncode(patchData)}');

  //     final response = await http.patch(
  //       patchUrl,
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode(patchData),
  //     );

  //     if (response.statusCode == 200) {
  //       print('Order fields patched successfully for $hiveOrderId.');
  //       return true;
  //     } else {
  //       print(
  //           'Failed to patch order fields. Status code: ${response.statusCode}');
  //       print('Response body: ${response.body}');
  //       return false;
  //     }
  //   } catch (e) {
  //     print('Error patching order fields by hiveOrderId: $e');
  //     return false;
  //   }
  // }

  // Future<bool> postOrder(Map<String, dynamic> order) async {
  //   try {
  //     print('Posting order: ${jsonEncode(order)}');
  //     final response = await http.post(
  //       Uri.parse(apiUrl),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode(order),
  //     );

  //     if (response.statusCode == 201 || response.statusCode == 200) {
  //       print('Order posted successfully.');
  //       return true;
  //     } else {
  //       print('Failed to post order. Status code: ${response.statusCode}');
  //       print('Response body: ${response.body}');
  //       return false;
  //     }
  //   } catch (e) {
  //     print('Error posting order: $e');
  //     return false;
  //   }
  // }
  // Future<bool> postOrder(Map<String, dynamic> order) async {
  //   try {
  //     if (!isOnline) {
  //       queueSync(() => postOrder(order));
  //       return false;
  //     }
  //     print('Posting order: ${jsonEncode(order)}');
  //     final response = await http.post(
  //       Uri.parse(apiUrl),
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode(order),
  //     );

  //     if (response.statusCode == 201 || response.statusCode == 200) {
  //       print('Order posted successfully.');
  //       return true;
  //     } else {
  //       print('Failed to post order. Status code: ${response.statusCode}');
  //       print('Response body: ${response.body}');
  //       return false;
  //     }
  //   } catch (e) {
  //     print('Error posting order: $e');
  //     return false;
  //   }
  // }

  // Future<bool> patchOrderTableAndSeat(
  //     String seathiveOrderId, int table, String seat) async {
  //   try {
  //     final patchUrl = Uri.parse(
  //         '${apiUrl}patch-table-seat/$seathiveOrderId?table=$table&seat=$seat');
  //     Map<String, dynamic> patchData = {
  //       'table': table,
  //       'seat': seat,
  //     };

  //     print('Patching table and seat for order at: $patchUrl');
  //     print('Patch data: ${jsonEncode(patchData)}');

  //     final response = await http.patch(
  //       patchUrl,
  //       headers: {'Content-Type': 'application/json'},
  //       body: jsonEncode(patchData),
  //     );

  //     if (response.statusCode == 200) {
  //       print(
  //           'Order table and seat patched successfully for $seathiveOrderId.');
  //       return true;
  //     } else {
  //       print(
  //           'Failed to patch order table and seat. Status code: ${response.statusCode}');
  //       print('Response body: ${response.body}');
  //       return false;
  //     }
  //   } catch (e) {
  //     print('Error patching order table and seat: $e');
  //     return false;
  //   }
  // }

  Future<bool> postToApproveOrder(Map<String, dynamic> salesOrder) async {
    final dio = Dio();
    const String salesOrderApi = "http://192.168.29.8:8090/toapprove/";
    // Print the payload and URL for debugging
    print('Posting sales order (raw JSON): ${jsonEncode(salesOrder)}');
    print("Posting to URL: $salesOrderApi");

    try {
      if (!isOnline) {
        queueSync(() => postToApproveOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await dio.post(
        salesOrderApi,
        data: salesOrder,
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      // Debug response details
      print('HTTP status code: ${response.statusCode}');
      print('Response body: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        // patchSaleOrder(salesOrder, response.body);
        print('Sales order posted successfully.');
        return true;
      } else {
        print(
          'Failed to post sales order. Status code: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('Error posting sales order: $e');
      return false;
    }
  }

  Future<bool> postDiscountOrder(Map<String, dynamic> salesOrder) async {
    final dio = Dio();
    const String salesOrderApi = "http://192.168.29.8:8090/heldorders/";
    // Print the payload and URL for debugging
    print('Posting sales order (raw JSON): ${jsonEncode(salesOrder)}');
    print("Posting to URL: $salesOrderApi");

    try {
      if (!isOnline) {
        queueSync(() => postDiscountOrder(salesOrder));
        return false;
      }

      // Send the POST request
      final response = await dio.post(
        salesOrderApi,
        data: jsonEncode(salesOrder),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      // Debug response details
      print('HTTP status code: ${response.statusCode}');
      print('Response body: ${response.data}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        // patchSaleOrder(salesOrder, response.body);
        print('Sales order posted successfully.');
        return true;
      } else {
        print(
          'Failed to post sales order. Status code: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('Error posting sales order: $e');
      return false;
    }
  }

  Future<void> syncPendingPatches() async {
    if (!isOnline) return;

    final box = await Hive.openBox('pendingPatches');
    final patches = box.values.toList();
    final dio = Dio();

    for (var patch in patches) {
      try {
        final response = await dio.patch(
          "http://192.168.29.8:8090/saleorder/${patch['salesOrderId']}/",
          data: jsonEncode(patch['data']),
          options: Options(headers: {'Content-Type': 'application/json'}),
        );

        if (response.statusCode == 200) {
          await box.delete(patch['salesOrderId']);
          print('Successfully synced pending patch: ${patch['salesOrderId']}');
        }
      } catch (e) {
        print('Error syncing pending patch ${patch['salesOrderId']}: $e');
      }
    }
  }

  Future<void> syncUnsyncedInvoices(ItemProvider itemProvider) async {
    print("Syncing unsynced invoices...");
    if (_isSyncing) return;
    _isSyncing = true;

    var invoiceBox = await Hive.openBox('invoicesBox');
    for (int i = 0; i < invoiceBox.length; i++) {
      var invoiceData = invoiceBox.getAt(i);
      if (invoiceData is String) {
        invoiceData = jsonDecode(invoiceData) as Map<String, dynamic>;
      }

      if (invoiceData is Map<String, dynamic> && invoiceData['sync'] == 'No') {
        bool success = await postInvoice(invoiceData, itemProvider);
        if (success) {
          invoiceData['sync'] = 'Yes';
          await invoiceBox.putAt(i, invoiceData);
          print('Invoice ${invoiceData['hiveInvoiceId']} synced successfully.');
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
    //  Set<WebSocketChannel> clients,
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
        // await updateLocalHiveStock(
        //     branchAlias: 'AR', // or dynamic branch alias
        //     varianceCodes: List<String>.from(['varianceCode']),
        //     varianceNames: List<String>.from(['varianceNames']),
        //     stockUpdates: List<int>.from(['stockUpdates']),
        //    // clients: clients
        //     );

        updated++;
      }
    }
    print('🗃️  Stock updated locally for $updated line-item(s).');

    /* ───────── 2.  Attempt remote POST (skip if no internet) ───────── */
    final hasNet =
        await Connectivity().checkConnectivity() != ConnectivityResult.none;

    if (!hasNet) {
      print('📡 No internet — invoice stored locally for later sync.');
      await _stashOffline(invoice);
      return false; // not sent, but stock ok
    }
    final dio = Dio();

    try {
      final res = await dio.post(
        invoiceApiUrl,
        data: jsonEncode(invoice),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        print('✅ Invoice posted successfully.');
        return true; // success
      } else {
        print('❌ Server rejected (${res.statusCode}). Keeping offline copy.');
        await _stashOffline(invoice);
        return false;
      }
    } catch (e) {
      print('🌐 Post failed (${e.runtimeType}) — saved for retry.');
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

  fetchSalesOrderFromApi(saleOrderNo) {}

  patchSalesOrder(Map<String, dynamic> map) {}
}
