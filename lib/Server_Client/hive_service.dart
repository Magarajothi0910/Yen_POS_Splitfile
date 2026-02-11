import 'dart:convert';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';

Future<List<Map<String, dynamic>>> loadInvoicesFromHive() async {
  try {
    final box = await HiveManager.invoiceBox;
    print('🔍 invoiceBox length: ${box.length}');

    final List<Map<String, dynamic>> invoices = [];

    for (var key in box.keys) {
      final value = box.get(key);
      if (value is Map<String, dynamic>) {
        final invoice = Map<String, dynamic>.from(value);
        invoice['hiveInvoiceId'] = key
            .toString(); // useful for dedup & frontend
        invoices.add(invoice);
      }
    }

    print('📤 Loaded ${invoices.length} regular invoices from Hive');
    return invoices;
  } catch (e, st) {
    print('❌ loadInvoicesFromHive failed: $e\n$st');
    return [];
  }
}

/// Save POS sale order using the 'saleOrderBox'
Future<void> savePosSaleOrderToHive(
  Map<String, dynamic> saleOrder,
  Box saleOrderBox,
) async {
  print("\n💾 [SAVE TO HIVE - PRIMARY] --- START ---");

  try {
    saleOrderBox = await Hive.openBox('saleOrderBox');
    print("📦 Hive Box opened: ${saleOrderBox.name}");

    final String shortId = generateShortHiveInvoiceId();
    saleOrder['hiveId'] = shortId;
    saleOrder['sync'] = 'No';
    saleOrder['edit'] = 'No';

    print("🧾 Generated Hive Short ID: $shortId");
    print("📝 Writing to Hive...");

    await saleOrderBox.put(shortId, saleOrder);
    print("✅ Saved order with ID: $shortId");

    final savedData = saleOrderBox.get(shortId);
    print("🔍 Data verification successful. Keys: ${savedData?.keys.toList()}");
  } catch (e, st) {
    print("❌ [SAVE TO HIVE - PRIMARY] Exception: $e");
    print("🧾 StackTrace:\n$st");
  }

  print("💾 [SAVE TO HIVE - PRIMARY] --- END ---\n");
}

Future<void> savePosInvoiceOrderToHive(
  Map<String, dynamic> saleOrder,
  Box saleOrderBox,
) async {
  var invoiceBox = await Hive.openBox('invoices');
  final String shortId = generateShortHiveInvoiceId();
  saleOrder['hiveId'] = shortId;
  await invoiceBox.put(shortId, saleOrder);
}

String generateShortHiveInvoiceId() {
  final random = Random();
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(
    6,
  ); // Shortened timestamp
  const characters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ0122345689'; // Alphanumeric characters
  final randomId =
      List<int>.generate(6, (_) => random.nextInt(characters.length))
          .map((index) => characters[index])
          .join(); // Generate a 6-character random ID
  return '$timestamp-$randomId'; // Combines timestamp and random alphanumeric ID
} // Load Pre-Invoices from Hive

/// Save printer details to Hive using the 'printerData' box
Future<void> savePrinterDetailsToHive(Map<String, dynamic> data) async {
  var printerBox = Hive.box('printerData');
  final printerName = data['name'];
  await printerBox.put(printerName, data);
}

Future<void> saveKotInvoiceToHive(Map<String, dynamic> invoice) async {
  // ✅ Check if invoice is nested under salesOrderId
  if (invoice.containsKey('salesOrderId') && invoice['salesOrderId'] is Map) {
    invoice = Map<String, dynamic>.from(invoice['salesOrderId']);
  }

  final invoiceBox = await HiveManager.invoiceBox;

  // ✅ Normalize invoiceDate
  final rawDate = invoice['invoiceDate'];
  if (rawDate == null) {
    // Missing → use today
    final today = DateFormat('dd-MM-yyyy').format(DateTime.now());
    invoice['invoiceDate'] = today;
  } else if (rawDate is DateTime) {
    // DateTime → format
    final formattedDate = DateFormat('dd-MM-yyyy').format(rawDate);
    invoice['invoiceDate'] = formattedDate;
  } else if (rawDate is String) {
    try {
      // Try parsing the string first
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        final formattedDate = DateFormat('dd-MM-yyyy').format(parsed);
        invoice['invoiceDate'] = formattedDate;
      } else {
        // Keep as is (already a string but unrecognized format)
      }
    } catch (e) {}
  } else {}

  // ✅ Save
  final key = await invoiceBox.add(invoice);

  final savedInvoice = invoiceBox.get(key);
  savePosInvoiceToHive(savedInvoice);
}

// Future<void> savePosInvoiceToHive(Map<String, dynamic> posInvoice) async {
//   print("🟢 [savePosInvoiceToHive] STARTED");
//   print("🟢 Invoice data to save: $posInvoice");

//   try {
//     // Step 1: Open the Hive box
//     var posInvoiceBox = await HiveManager.invoiceBox;
//     print("🟢 Hive box opened successfully");

//     // Step 2: Save the invoice to Hive
//     final key = await posInvoiceBox.add(posInvoice);
//     print("✅ Invoice saved successfully with key: $key");

//     // Step 3: Debug: Current count of invoices in Hive
//     final count = posInvoiceBox.length;
//     print("🟢 Current total invoices in Hive: $count");

//     // Optional: Log the last saved invoice
//     final lastInvoice = posInvoiceBox.getAt(count - 1);
//     print("🟢 Last saved invoice in Hive: $lastInvoice");
//   } catch (e, st) {
//     print("❌ Error saving invoice to Hive: $e");
//     print("❌ StackTrace: $st");
//   }

//   print("🟢 [savePosInvoiceToHive] FINISHED");
// }

// Future<void> savePosInvoiceToHive(Map<String, dynamic> posInvoice) async {
//   print("🟢 [savePosInvoiceToHive] STARTED");
//   print("🟢 Full invoice data received: $posInvoice");

//   try {
//     // 🔥 Extract ONLY the salesOrderId object
//     final Map<String, dynamic> invoiceToSave = posInvoice["salesOrderId"];
//     print("🟢 Extracted invoice to save: $invoiceToSave");

//     // Step 1: Open the Hive box
//     var posInvoiceBox = await HiveManager.invoiceBox;
//     print("🟢 Hive box opened successfully");

//     // Step 2: Save ONLY the extracted part
//     final key = await posInvoiceBox.add(invoiceToSave);
//     print("✅ Invoice saved successfully with key: $key");

//     // Step 3: Debug: Current count of invoices in Hive
//     final count = posInvoiceBox.length;
//     print("🟢 Current total invoices in Hive: $count");

//     // Optional: Log the last saved invoice
//     final lastInvoice = posInvoiceBox.getAt(count - 1);
//     print("🟢 Last saved invoice in Hive: $lastInvoice");
//   } catch (e, st) {
//     print("❌ Error saving invoice to Hive: $e");
//     print("❌ StackTrace: $st");
//   }

//   print("🟢 [savePosInvoiceToHive] FINISHED");
// }

Future<void> savePosInvoiceToHive(Map<String, dynamic> message) async {
  try {
    final salesOrder = message['salesOrderId'];
    if (salesOrder is! Map<String, dynamic>) return;

    final String? invoiceNo = salesOrder['invoiceNo']?.toString();
    if (invoiceNo == null || invoiceNo.isEmpty) {
      print("Missing invoiceNo → skip save");
      return;
    }

    final box = HiveManager.invoiceBox;

    // PREVENT DUPLICATES — Critical!
    if (box.containsKey(invoiceNo)) {
      print("Invoice $invoiceNo already exists locally → skip");
      return;
    }

    // Save the actual sales order (clean data)
    await box.put(invoiceNo, salesOrder);
    print("Invoice saved locally → $invoiceNo");
  } catch (e, st) {
    print("Error in savePosInvoiceToHive: $e\n$st");
  }
}

/// Save hold order using the 'holdOrders' box
// -------------------- SERVER HANDLER -------------------- //
Future<void> saveHoldOrderToHive(
  Map<String, dynamic> data,
  Box holdOrderBox,
) async {
  holdOrderBox = HiveManager.holdOrderBox;
  holdOrderBox.add(data);
}

/// Save sales approval order using the 'salesApprovalOrder' box
Future<void> saveSalesApprovalOrderToHive(Map<String, dynamic> data) async {
  var salesApprovalOrdersBox = Hive.box('salesApprovalOrder');
  await salesApprovalOrdersBox.add(data);
}

/// Save modify order using the 'saleOrderModifyOrders' box
Future<void> saveModifyOrderToHive(Map<String, dynamic> data) async {
  var modifyOrdersBox = Hive.box('saleOrderModifyOrders');
  await modifyOrdersBox.add(data);
}

Future<void> initHiveInBackground() async {
  await Hive.initFlutter();

  // Open only what background tasks need
  await Future.wait([
    Hive.openBox('invoices'),

    Hive.openBox('userBox'),
    Hive.openBox('holdOrders'),
    Hive.openBox('pendingPrintOrders'),
    Hive.openBox('deviceData'),
    Hive.openBox('branchData'),
    Hive.openBox('tableStatus'),
    Hive.openBox('openOrderBox'),
    Hive.openBox('opensaleOrders'),
    Hive.openBox('cartBox'),
    Hive.openBox('imagesBox'),
    Hive.openBox('salesOrders'),
    Hive.openBox('invoices'),
    Hive.openBox('imagesBox'),
    Hive.openBox("salesOrderNumberBox"),
    Hive.openBox('salesOrders'),
    Hive.openBox('openOrderBox'),
    Hive.openBox('opensaleOrders'),

    Hive.openBox('logo'),
    Hive.openBox('customerBox'),
  ]);
}
