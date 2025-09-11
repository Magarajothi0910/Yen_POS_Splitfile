// import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';

// class PreInvoiceProvider with ChangeNotifier {
//   final Box _box = Hive.box('unprintedPreInvoices');

//   List<Map> _unprintedInvoices = [];

//   List<Map> get unprintedInvoices => _unprintedInvoices;

//   PreInvoiceProvider() {
//     _loadUnprintedInvoices();
//   }

//   /// **Load unprinted invoices from Hive**
//   Future<void> _loadUnprintedInvoices() async {
//     _unprintedInvoices =
//         _box.values.map((e) => Map<String, dynamic>.from(e)).toList();
//         print("_unprintedInvoices.length  ")
//     print("_unprintedInvoices $_unprintedInvoices");
//     notifyListeners();
//   }

//   /// **Store an unprinted pre-invoice in Hive**
//   Future<void> storeUnprintedPreInvoice(Map<String, dynamic> invoice) async {
//     await _box.add(invoice);
//     _loadUnprintedInvoices();
//   }

//   /// **Delete an invoice after successful printing**
//   Future<void> removePrintedInvoice(int index) async {
//     await _box.deleteAt(index);
//     _loadUnprintedInvoices();
//   }
// }
