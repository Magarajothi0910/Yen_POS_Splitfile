import 'dart:convert';
import 'dart:math';

import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

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
    var preInvoiceBox = await Hive.openBox('preInvoicesBox');
    await preInvoiceBox.add(jsonData);

    // Print the contents of the box to verify
    for (int i = 0; i < preInvoiceBox.length; i++) {}
  } catch (e) {}
}

// Load Invoices from Hive
Future<List<Map<String, dynamic>>> loadInvoicesFromHive() async {
  try {
    var invoiceBox = await Hive.openBox('invoicesBox');
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
    var orderBox = Hive.box('ordersBox');
    List<Map<String, dynamic>> orders = [];
    for (int i = 0; i < orderBox.length; i++) {
      var orderData = orderBox.getAt(i);
      // If stored data is a JSON string, decode it
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
    var preInvoiceBox = await Hive.openBox('preInvoicesBox');
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

/// Delete an order from Hive by hiveOrderId
Future<void> deleteOrderFromHive(String hiveOrderId) async {
  var orderBox = Hive.box('ordersBox');
  for (int i = 0; i < orderBox.length; i++) {
    var orderData = orderBox.getAt(i);
    if (orderData is String) {
      orderData = jsonDecode(orderData) as Map<String, dynamic>;
    }
    if (orderData['hiveOrderId'] == hiveOrderId) {
      await orderBox.deleteAt(i);
      break;
    }
  }
}

/// Save POS sale order using the 'saleOrderBox'
Future<void> savePosSaleOrderToHive(
    Map<String, dynamic> saleOrder, Box saleOrderBox) async {
  var saleOrderBox = await Hive.openBox('saleOrderBox');
  final String shortId = generateShortHiveInvoiceId();
  saleOrder['hiveId'] = shortId;
  await saleOrderBox.put(shortId, saleOrder);
}

Future<void> savePosInvoiceOrderToHive(
    Map<String, dynamic> saleOrder, Box saleOrderBox) async {
  var invoiceBox = await Hive.openBox('invoices');
  final String shortId = generateShortHiveInvoiceId();
  saleOrder['hiveId'] = shortId;
  await invoiceBox.put(shortId, saleOrder);
}

String generateShortHiveInvoiceId() {
  final random = Random();
  final timestamp = DateTime.now()
      .millisecondsSinceEpoch
      .toString()
      .substring(6); // Shortened timestamp
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

/// Save hold order using the 'holdOrders' box
Future<void> saveHoldOrderToHive(
    Map<String, dynamic> data, Box holdOrderBox) async {
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
