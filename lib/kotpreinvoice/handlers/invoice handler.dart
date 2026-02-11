// // import 'package:flutter/material.dart';
// // import 'package:yen_pos/Global/globals_data.dart';
// // import 'package:yen_pos/Server_Client/sendDataToClients.dart';
// // import 'package:yen_pos/invoice_pay_and_print_page.dart/widgets/invoiceNumberGenerator.dart';

// // import '../services/Token_service.dart';
// // import '../services/sendDataToClients.dart';
// // import '../services/hive_service.dart';
// // import '../services/sync_service.dart';

// // // ignore: non_constant_identifier_names
// // final SyncServiceKot _SyncServiceKot = SyncServiceKot();

// // Future<void> handleInvoiceKOT(
// //   Map<String, dynamic> data,
// //   // Set<WebSocketChannel> clients,
// // ) async {
// //   print("validateInvoiceData: $data");
// //   final branchName = data['branchName'];
// //   final date = data['invoiceDate'];
// //   final time = data['invoiceTime'];

// //   if (branchName != null && date != null && time != null) {
// //     // data['hiveInvoiceId'] = await generatehiveInvoiceId(branchName);

// //     // final invoiceNumberGenerator = InvoiceNumberGenerator.instance;
// //     // //String hiveInvoiceId = _invoiceService.generateShortHiveInvoiceId();
// //     // final hiveInvoiceId = await invoiceNumberGenerator.generateInvoiceNumber();
// //     // data['invoiceNo'] = hiveInvoiceId;
// //     // print("Generated Hive Invoice ID: $hiveInvoiceId");
// //   }
// //   debugPrint("Generated hiveInvoiceId: ${data['hiveInvoiceId']}");
// //   sendDataToClients({
// //     'action': 'invoiceGeneratedKOT',
// //     'invoiceKOT': data,
// //   }, clients);
// //   debugPrint("Invoice data sent to clients: $data");
// //   // await saveKotInvoiceToHive(data);
// //   await _SyncServiceKot.saveKotInvoiceToHive(data);
// // }

// import 'package:flutter/material.dart';
// import 'package:yen_pos/Global/globals_data.dart';
// import 'package:yen_pos/Server_Client/sendDataToClients.dart';

// import '../services/Token_service.dart';
// import '../services/sendDataToClients.dart';
// import '../services/sync_service.dart';

// // ignore: non_constant_identifier_names
// final SyncServiceKot _SyncServiceKot = SyncServiceKot();

// Map<String, dynamic> sanitizeInvoiceByQty(Map<String, dynamic> data) {
//   // Extract lists safely
//   final List<dynamic> varianceNames = List.from(data['varianceName'] ?? []);
//   final List<dynamic> itemNames = List.from(data['itemName'] ?? []);
//   final List<dynamic> varianceCodes = List.from(data['varianceitemCode'] ?? []);
//   final List<dynamic> prices = List.from(data['price'] ?? []);
//   final List<dynamic> sellingPrices = List.from(data['sellingPrice'] ?? []);
//   final List<dynamic> qtys = List.from(data['qty'] ?? []);
//   final List<dynamic> weights = List.from(data['weight'] ?? []);
//   final List<dynamic> amounts = List.from(data['amount'] ?? []);
//   final List<dynamic> sellingAmounts = List.from(data['sellingAmount'] ?? []);
//   final List<dynamic> taxes = List.from(data['tax'] ?? []);
//   final List<dynamic> uoms = List.from(data['uom'] ?? []);

//   final List<Map<String, dynamic>> kotAddOns =
//       (data['kotaddOns'] as List? ?? [])
//           .map((e) => Map<String, dynamic>.from(e))
//           .toList();

//   // New filtered lists
//   final List<String> fVarianceNames = [];
//   final List<String> fItemNames = [];
//   final List<String> fVarianceCodes = [];
//   final List<double> fPrices = [];
//   final List<double> fSellingPrices = [];
//   final List<double> fQtys = [];
//   final List<double> fWeights = [];
//   final List<double> fAmounts = [];
//   final List<double> fSellingAmounts = [];
//   final List<double> fTaxes = [];
//   final List<String> fUoms = [];

//   double newTotal = 0.0;

//   for (int i = 0; i < qtys.length; i++) {
//     final double qty = (qtys[i] as num?)?.toDouble() ?? 0.0;
//     final double weight = (weights[i] as num?)?.toDouble() ?? 0.0;

//     if (qty <= 0 && weight <= 0) {
//       continue; // ❌ remove item
//     }

//     fVarianceNames.add(varianceNames[i].toString());
//     fItemNames.add(itemNames[i].toString());
//     fVarianceCodes.add(varianceCodes[i].toString());
//     fPrices.add((prices[i] as num).toDouble());
//     fSellingPrices.add((sellingPrices[i] as num).toDouble());
//     fQtys.add(qty);
//     fWeights.add((weights[i] as num?)?.toDouble() ?? 0.0);
//     fAmounts.add((amounts[i] as num).toDouble());
//     fSellingAmounts.add((sellingAmounts[i] as num).toDouble());
//     fTaxes.add((taxes[i] as num).toDouble());
//     fUoms.add(uoms[i].toString());

//     newTotal += (amounts[i] as num).toDouble();
//   }

//   // Filter kotAddOns to only remaining varianceNames
//   final filteredAddOns = kotAddOns
//       .where((a) => fVarianceNames.contains(a['varianceName']))
//       .toList();

//   // Update invoice data
//   data['varianceName'] = fVarianceNames;
//   data['itemName'] = fItemNames;
//   data['varianceitemCode'] = fVarianceCodes;
//   data['price'] = fPrices;
//   data['sellingPrice'] = fSellingPrices;
//   data['qty'] = fQtys;
//   data['weight'] = fWeights;
//   data['amount'] = fAmounts;
//   data['sellingAmount'] = fSellingAmounts;
//   data['tax'] = fTaxes;
//   data['uom'] = fUoms;
//   data['kotaddOns'] = filteredAddOns;
//   data['totalAmount'] = newTotal;

//   return data;
// }

// Future<void> handleInvoiceKOT(
//   Map<String, dynamic> data,
//   // Set<WebSocketChannel> clients,
// ) async {
//   debugPrint("Raw invoice data: $data");

//   // ✅ REMOVE CANCELLED ITEMS
//   final sanitizedInvoice = sanitizeInvoiceByQty(data);
//   debugPrint("Sanitized invoice data: $sanitizedInvoice");

//   final branchName = sanitizedInvoice['branchName'];
//   final date = sanitizedInvoice['invoiceDateTime'];

//   if (branchName != null && date != null) {
//     sanitizedInvoice['hiveInvoiceId'] = await generatehiveInvoiceId(branchName);
//   }

//   debugPrint("Final invoice after removing cancelled items: $sanitizedInvoice");

//   // 🔔 Send to clients
//   sendDataToClients({
//     'action': 'invoiceGeneratedKOT',
//     'invoiceKOT': sanitizedInvoice,
//   }, clients);

//   // 💾 Save locally
//   await _SyncServiceKot.saveKotInvoiceToHive(sanitizedInvoice);
// }

import 'package:flutter/material.dart';
import 'package:yen_pos/Global/globals_data.dart';
import 'package:yen_pos/Server_Client/sendDataToClients.dart';

import '../services/Token_service.dart';
import '../services/sendDataToClients.dart';
import '../services/sync_service.dart';

// ignore: non_constant_identifier_names
final SyncServiceKot _SyncServiceKot = SyncServiceKot();

Map<String, dynamic> sanitizeInvoiceByQty(Map<String, dynamic> data) {
  // Extract lists safely
  final List<dynamic> varianceNames = List.from(data['varianceName'] ?? []);
  final List<dynamic> itemNames = List.from(data['itemName'] ?? []);
  final List<dynamic> varianceCodes = List.from(data['varianceitemCode'] ?? []);
  final List<dynamic> prices = List.from(data['price'] ?? []);
  final List<dynamic> sellingPrices = List.from(data['sellingPrice'] ?? []);
  final List<dynamic> qtys = List.from(data['qty'] ?? []);
  final List<dynamic> weights = List.from(data['weight'] ?? []);
  final List<dynamic> amounts = List.from(data['amount'] ?? []);
  final List<dynamic> sellingAmounts = List.from(data['sellingAmount'] ?? []);
  final List<dynamic> taxes = List.from(data['tax'] ?? []);
  final List<dynamic> uoms = List.from(data['uom'] ?? []);

  final List<Map<String, dynamic>> kotAddOns =
      (data['kotaddOns'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

  // New filtered lists
  final List<String> fVarianceNames = [];
  final List<String> fItemNames = [];
  final List<String> fVarianceCodes = [];
  final List<double> fPrices = [];
  final List<double> fSellingPrices = [];
  final List<double> fQtys = [];
  final List<double> fWeights = [];
  final List<double> fAmounts = [];
  final List<double> fSellingAmounts = [];
  final List<double> fTaxes = [];
  final List<String> fUoms = [];

  double newTotal = 0.0;

  for (int i = 0; i < qtys.length; i++) {
    final double qty = (qtys[i] as num?)?.toDouble() ?? 0.0;
    final double weight = (weights[i] as num?)?.toDouble() ?? 0.0;

    if (qty <= 0 && weight <= 0) {
      continue; // ❌ remove item
    }

    fVarianceNames.add(varianceNames[i].toString());
    fItemNames.add(itemNames[i].toString());
    fVarianceCodes.add(varianceCodes[i].toString());
    fPrices.add((prices[i] as num).toDouble());
    fSellingPrices.add((sellingPrices[i] as num).toDouble());
    fQtys.add(qty);
    fWeights.add((weights[i] as num?)?.toDouble() ?? 0.0);
    fAmounts.add((amounts[i] as num).toDouble());
    fSellingAmounts.add((sellingAmounts[i] as num).toDouble());
    fTaxes.add((taxes[i] as num).toDouble());
    fUoms.add(uoms[i].toString());

    newTotal += (amounts[i] as num).toDouble();
  }

  // Filter kotAddOns to only remaining varianceNames
  final filteredAddOns = kotAddOns
      .where((a) => fVarianceNames.contains(a['varianceName']))
      .toList();

  // Update invoice data
  data['varianceName'] = fVarianceNames;
  data['itemName'] = fItemNames;
  data['varianceitemCode'] = fVarianceCodes;
  data['price'] = fPrices;
  data['sellingPrice'] = fSellingPrices;
  data['qty'] = fQtys;
  data['weight'] = fWeights;
  data['amount'] = fAmounts;
  data['sellingAmount'] = fSellingAmounts;
  data['tax'] = fTaxes;
  data['uom'] = fUoms;
  data['kotaddOns'] = filteredAddOns;
  data['totalAmount'] = newTotal;

  return data;
}

Future<void> handleInvoiceKOT(Map<String, dynamic> data) async {
  debugPrint("Raw invoice data: $data");

  // ✅ REMOVE CANCELLED ITEMS
  final sanitizedInvoice = sanitizeInvoiceByQty(data);
  debugPrint("Sanitized invoice data: $sanitizedInvoice");

  final branchName = sanitizedInvoice['branchName'];
  final date = sanitizedInvoice['invoiceDateTime'];

  if (branchName != null && date != null) {
    sanitizedInvoice['hiveInvoiceId'] = await generatehiveInvoiceId(branchName);
  }

  debugPrint("Final invoice after removing cancelled items: $sanitizedInvoice");

  // 🔔 Send to clients
  sendDataToClients({
    'action': 'invoiceGeneratedKOT',
    'invoiceKOT': sanitizedInvoice,
  }, clients);

  // 💾 Save locally
  await _SyncServiceKot.saveKotInvoiceToHive(sanitizedInvoice);
}
