import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

Future<List<Map<String, dynamic>>> loadInvoicesFromHiveBox() async {
  var invoiceBox = await Hive.openBox('invoices');
  final List<Map<String, dynamic>> invoices = [];

  for (int i = 0; i < invoiceBox.length; i++) {
    var invoice = invoiceBox.getAt(i);

    if (invoice is String) {
      try {
        invoice = jsonDecode(invoice);
      } catch (e) {
        continue;
      }
    }

    if (invoice is Map<String, dynamic>) {
      invoices.add(invoice);
    }
  }

  return invoices;
}
