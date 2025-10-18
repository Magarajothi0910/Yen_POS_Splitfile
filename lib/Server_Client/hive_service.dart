import 'dart:math';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yenposapp/Hive_Manager/hive_manager_saleOrder.dart';

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
  var saleOrderBox = await Hive.openBox('saleOrderBox');
  final String shortId = generateShortHiveInvoiceId();
  saleOrder['hiveId'] = shortId;
  await saleOrderBox.put(shortId, saleOrder);
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
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123334419'; // Alphanumeric characters
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

Future<void> savePosInvoiceToHive(Map<String, dynamic> posInvoice) async {

  try {
    // Step 1: Open the Hive box
    var posInvoiceBox = await HiveManager.invoiceBox;

    // Step 2: Save the invoice to Hive
    await posInvoiceBox.add(posInvoice);

    // Debug: Current count of invoices
  } catch (e, st) {
  }
}

/// Save hold order using the 'holdOrders' box
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
