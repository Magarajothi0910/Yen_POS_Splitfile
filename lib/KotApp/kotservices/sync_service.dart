import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
// ignore: depend_on_referenced_packages
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';

class SyncServiceKot {
  final String apiUrl = 'https://yenerp.com/fastapi/orders/';
  final String invoiceApiUrl = 'https://yenerp.com/fastapi/invoices/';
  final String kotTableStatusUrl = 'https://yenerp.com/fastapi/kottablesstatus';

  var client = http.Client(); // Create an HTTP client

  bool _isSyncing = false;
  bool isOnline = false;
  List<Function> syncQueue = [];

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
        syncUnsyncedOrders();
        syncUnsyncedInvoices();
      }
    });
  }

  void _monitorConnectivity() {
    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final ConnectivityResult result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      isOnline = result != ConnectivityResult.none;
      if (isOnline) {
        processSyncQueue();
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
    print("🚀 [savePosInvoiceToHive] Called with invoice: $invoice");

    var invoiceBox = await Hive.openBox('invoices');
    print("📂 [savePosInvoiceToHive] Opened Hive box: invoices");

    invoice['sync'] = 'No';
    invoice['edit'] = 'No'; // Initialize edit field
    print(
        "📝 [savePosInvoiceToHive] Added sync=No & edit=No flags to invoice.");

    await invoiceBox.add(invoice);
    print("💾 [savePosInvoiceToHive] Invoice saved locally in Hive.");

    // Check connectivity and try to sync after saving locally
    print("🔄 [savePosInvoiceToHive] Triggering syncUnsyncedInvoices...");
    await syncUnsyncedInvoices();
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
        bool success = await postOrder(orderData);
        if (success) {
          orderData['sync'] = 'Yes';
          await orderBox.putAt(i, orderData);
        } else {
          break; // Stop if a post fails
        }
      }
      // if (orderData is Map<String, dynamic> && orderData['sync'] == 'No') {
      //   queueSync(() => postOrder(orderData));
      // }
    }
    _isSyncing = false;
    await patchEditedOrders();
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

  Future<void> syncUnsyncedInvoices() async {
    print("🚀 [syncUnsyncedInvoices] Called");

    // Step 1: Prevent parallel syncing
    if (_isSyncing) {
      print("⚠️ [syncUnsyncedInvoices] Sync already in progress. Skipping...");
      return;
    }
    _isSyncing = true;

    try {
      // Step 2: Open Hive box
      var invoiceBox = await Hive.openBox('invoices');
      print("📂 [syncUnsyncedInvoices] Opened Hive box: invoices");

      // Step 3: Iterate invoices
      for (int i = 0; i < invoiceBox.length; i++) {
        var invoiceData = invoiceBox.getAt(i);
        print(
            "🔎 [syncUnsyncedInvoices] Checking invoice at index $i: $invoiceData");

        // Decode if string
        if (invoiceData is String) {
          invoiceData = jsonDecode(invoiceData) as Map<String, dynamic>;
          print("📦 [syncUnsyncedInvoices] Decoded string invoice into Map.");
        }

        // Step 4: Process only unsynced invoices
        if (invoiceData is Map<String, dynamic> &&
            invoiceData['sync'] == 'No') {
          print(
              "📡 [syncUnsyncedInvoices] Found unsynced invoice: $invoiceData");

          // Try posting
          bool success = await postInvoice(invoiceData);
          if (success) {
            print("✅ [syncUnsyncedInvoices] Invoice synced successfully.");

            invoiceData['sync'] = 'Yes';
            // await invoiceBox.putAt(i, invoiceData);
            print(
                "💾 [syncUnsyncedInvoices] Updated invoice sync status in Hive.");
          } else {
            print(
                "❌ [syncUnsyncedInvoices] Failed to sync invoice. Stopping loop.");
            break; // Stop sync loop if failure
          }
        } else {
          print("ℹ️ [syncUnsyncedInvoices] Invoice already synced or invalid.");
        }
      }
    } catch (e, st) {
      print("❌ [syncUnsyncedInvoices] Error: $e");
      print("🛑 Stacktrace: $st");
    } finally {
      _isSyncing = false;
      print("🏁 [syncUnsyncedInvoices] Sync process completed.");
    }
  }

  Future<bool> postInvoice(Map<String, dynamic> invoice) async {
    print("🚀 [postInvoice] Called with invoice: $invoice");

    try {
      // Convert payment values safely
      invoice['cash'] = int.tryParse(invoice['cash']?.toString() ?? '') ?? 0;
      invoice['card'] = int.tryParse(invoice['card']?.toString() ?? '') ?? 0;
      invoice['upi'] = int.tryParse(invoice['upi']?.toString() ?? '') ?? 0;

      print(
          "💰 [postInvoice] Normalized payments → cash: ${invoice['cash']}, card: ${invoice['card']}, upi: ${invoice['upi']}");

      final response = await http.post(
        Uri.parse(invoiceApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(invoice),
      );

      print(
          "📡 [postInvoice] Sent POST request → Status: ${response.statusCode}, Body: ${response.body}");

      if (response.statusCode == 201 || response.statusCode == 200) {
        print("✅ [postInvoice] Invoice posted successfully.");
        return true;
      } else {
        print(
            "❌ [postInvoice] Invoice post failed. Status: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("❌ [postInvoice] Exception while posting invoice: $e");
      return false;
    }
  }

  Future<void> saveTableStatusToHive(Map<String, dynamic> data) async {
    try {
      var box = Hive.box('tableStatus');
      await box.put('kotTableStatus', data);
    } catch (e) {}
  }

  Future<void> upsertKotTableStatus(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$kotTableStatusUrl/upsert'); // Correct endpoint

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      //  client.close();
      if (response.statusCode == 200 || response.statusCode == 201) {
      } else {}
    } catch (e) {}
  }
}
