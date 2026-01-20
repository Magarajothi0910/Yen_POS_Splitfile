import 'dart:convert';
import 'dart:math';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';

Future<List<Map<String, dynamic>>> loadInvoicesFromHive() async {
  try {
    var invoiceBox = await Hive.openBox('invoices');
    List<Map<String, dynamic>> invoices = [];
    for (int i = 0; i < invoiceBox.length; i++) {
      invoices.add(Map<String, dynamic>.from(invoiceBox.getAt(i) as Map));
    }
    return invoices;
  } catch (e) {
    return [];
  }
}

/// Save POS sale order using the 'saleOrderBox'
Future<void> savePosSaleOrderToHive(
  Map<String, dynamic> saleOrder,
  Box saleOrderBox,
) async {
  try {
    saleOrderBox = await Hive.openBox('saleOrderBox');

    final String shortId = generateShortHiveInvoiceId();
    saleOrder['hiveId'] = shortId;
    saleOrder['sync'] = 'No';
    saleOrder['edit'] = 'No';

    await saleOrderBox.put(shortId, saleOrder);

    final savedData = saleOrderBox.get(shortId);
  } catch (e, st) {}
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

Future<void> savePosInvoiceToHive(Map<String, dynamic> message) async {
  try {
    final salesOrder = message['salesOrderId'];
    if (salesOrder is! Map<String, dynamic>) return;

    final String? invoiceNo = salesOrder['invoiceNo']?.toString();
    if (invoiceNo == null || invoiceNo.isEmpty) {
      return;
    }

    final box = HiveManager.invoiceBox;

    // PREVENT DUPLICATES — Critical!
    if (box.containsKey(invoiceNo)) {
      return;
    }

    // Save the actual sales order (clean data)
    await box.put(invoiceNo, salesOrder);
  } catch (e, st) {}
}

/// Save hold order using the 'holdOrders' box
// -------------------- SERVER HANDLER -------------------- //
Future<void> saveHoldOrderToHive(
  Map<String, dynamic> data,
  Box holdOrderBox,
) async {
  await holdOrderBox.add(data);
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
