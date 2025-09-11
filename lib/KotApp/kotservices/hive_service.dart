import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:yenposapp/services/hive_manager.dart';

void saveOrderToHive(Map<String, dynamic> order) async {
  try {
    var orderBox = await Hive.openBox(
        'ordersBox'); // Ensure you use 'ordersBox' consistently

    // Convert date fields to strings before saving if necessary
    if (order.containsKey('date') && order['date'] is DateTime) {
      order['date'] = DateFormat('dd-MM-yyyy').format(order['date']);
    }

    // Save the order as a JSON-encoded string
    await orderBox.add(jsonEncode(order));
  } catch (e) {}
}

// Save Pre-Invoice to Hive
Future<void> savePreInvoiceToHive(Map<String, dynamic> jsonData) async {
  try {
    var preInvoiceBox = await Hive.openBox('preinvoices');
    await preInvoiceBox.add(jsonData);

    // Print the contents of the box to verify
    for (int i = 0; i < preInvoiceBox.length; i++) {}
  } catch (e) {}
}

// Load Invoices from Hive
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

Future<List<Map<String, dynamic>>> loadOrdersFromHive() async {
  try {
    var orderBox = await Hive.openBox(
        'ordersBox'); // Ensure you use 'ordersBox' consistently
    List<Map<String, dynamic>> orders = [];

    for (int i = 0; i < orderBox.length; i++) {
      var orderData = orderBox.getAt(i);

      // If the stored data is a string, decode it into a map
      if (orderData is String) {
        orderData = jsonDecode(orderData) as Map<String, dynamic>;
      }

      orders.add(Map<String, dynamic>.from(orderData));
    }
    return orders;
  } catch (e) {
    return [];
  }
}

// Load Pre-Invoices from Hive
Future<List<Map<String, dynamic>>> loadPreInvoicesFromHive() async {
  try {
    var preInvoiceBox = await Hive.openBox('preinvoices');
    List<Map<String, dynamic>> preInvoices = [];
    for (int i = 0; i < preInvoiceBox.length; i++) {
      preInvoices.add(Map<String, dynamic>.from(preInvoiceBox.getAt(i) as Map));
    }
    return preInvoices;
  } catch (e) {
    return [];
  }
}

Future<void> saveTransferToHive(Map<String, dynamic> transferData) async {
  try {
    var transferBox = await Hive.openBox('seatTransfers');
    await transferBox.add(transferData);
  } catch (e) {}
}

Future<void> deleteOrderFromHive(String hiveOrderId) async {
  var orderBox =
      await Hive.openBox('ordersBox'); // Ensure the box name is correct

  // Loop through all stored orders and delete the one with the matching hiveOrderId
  for (int i = 0; i < orderBox.length; i++) {
    var orderData = orderBox.getAt(i);

    // If the stored data is a string, decode it into a map
    if (orderData is String) {
      orderData = jsonDecode(orderData) as Map<String, dynamic>;
    }

    if (orderData['hiveOrderId'] == hiveOrderId) {
      await orderBox.deleteAt(i); // Delete the order at this index
      break;
    }
  }
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
  print("🚀 [savePosInvoiceToHive] Called with posInvoice: $posInvoice");

  try {
    // Step 1: Open the Hive box
    print("📂 [savePosInvoiceToHive] Opening Hive box: 'invoices'...");
    var posInvoiceBox = await HiveManager.invoiceBox;
    print("✅ [savePosInvoiceToHive] Hive box 'invoices' opened successfully.");

    // Step 2: Save the invoice to Hive
    print("💾 [savePosInvoiceToHive] Saving invoice into Hive box...");
    await posInvoiceBox.add(posInvoice);
    print("🎉 [savePosInvoiceToHive] Invoice saved successfully to Hive.");

    // Debug: Current count of invoices
    print(
        "📊 [savePosInvoiceToHive] Total invoices stored in Hive: ${posInvoiceBox.length}");
  } catch (e, st) {
    print("❌ [savePosInvoiceToHive] Error while saving invoice: $e");
    print("🛑 Stacktrace: $st");
  }
}

Future<void> savePrinterDetailsToHive(Map<String, dynamic> data) async {
  var printerBox = await Hive.openBox('printerData');
  final printerName = data['name'];
  await printerBox.put(printerName, data);
}
