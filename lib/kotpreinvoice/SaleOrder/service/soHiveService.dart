import 'dart:math';
import 'package:hive/hive.dart';

// Save invoice using the 'invoices' box
Future<void> saveInvoiceToHive(Map<String, dynamic> invoice) async {
  var invoiceBox = Hive.box('invoices');
  await invoiceBox.add(invoice);
  print('Invoice stored in Hive with ID: ${invoice['invoiceId']}');
}

/// Save POS invoice using the 'posInvoiceBox'
Future<void> savePosInvoiceToHive(Map<String, dynamic> posInvoice) async {
  var posInvoiceBox = Hive.box('posInvoiceBox');
  await posInvoiceBox.add(posInvoice);
  print("POS Invoice saved: ${posInvoice['hiveInvoiceId']}");
}

/// Save POS sale order using the 'saleOrderBox'
Future<void> savePosSaleOrderToHive(Map<String, dynamic> saleOrder, Box saleOrderBox) async {
  print("savePosInvoiceToHive 3");
  var saleOrderBox = await Hive.openBox('saleOrderBox');
  final String shortId = generateShortHiveInvoiceId();
  saleOrder['hiveId'] = shortId;
  await saleOrderBox.put(shortId, saleOrder);
  print("POS salesOrder saved: $saleOrder");
}

Future<Map<String, dynamic>?> _getSaleOrderFromHive(String saleOrderNo) async {
  final saleOrderBox = await Hive.openBox('saleOrderBox');
  for (var key in saleOrderBox.keys) {
    final order = saleOrderBox.get(key) as Map<String, dynamic>?;
    if (order?['saleOrderNo'] == saleOrderNo) {
      return order;
    }
  }
  return null;
}

String generateShortHiveInvoiceId() {
  final random = Random();
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(6); // Shortened timestamp
  const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123445569'; // Alphanumeric characters
  final randomId = List<int>.generate(6, (_) => random.nextInt(characters.length)).map((index) => characters[index]).join(); // Generate a 6-character random ID
  return '$timestamp-$randomId'; // Combines timestamp and random alphanumeric ID
} // Load Pre-Invoices from Hive

/// Save hold order using the 'holdOrders' box
Future<void> saveHoldOrderToHive(Map<String, dynamic> data, Box holdOrderBox) async {
  var holdOrdersBox = Hive.box('holdOrders');
  await holdOrdersBox.add(data);
  print('Hold order saved to Hive: $data');
}

/// Save modify order using the 'saleOrderModifyOrders' box
Future<void> saveModifyOrderToHive(Map<String, dynamic> data) async {
  var modifyOrdersBox = Hive.box('saleOrderModifyOrders');
  await modifyOrdersBox.add(data);
  print('Modified order saved to Hive: $data');
}
