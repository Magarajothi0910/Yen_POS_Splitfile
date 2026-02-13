// import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
// import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
// import 'package:yen_pos/Server_Client/handlers/webscoket_messgae_handler.dart';

// // Future<void> handleInvoice(
// //   Map<String, dynamic> jsonData,
// //   SalesInvoiceReceiptPrinter printer,
// // ) async {
// //   print("🚀 [handleInvoice] Function called");

// //   // Step 1: Extract invoice
// //   final invoice = jsonData['invoice'];
// //   print("json data:$jsonData ");
// //   if (invoice == null) {
// //     print("❌ [handleInvoice] No 'invoice' field found in JSON data");
// //     return;
// //   }
// //   print("📥 [handleInvoice] Invoice data found");

// //   // Step 2: Extract sales order from invoice
// //   final salesOrder = invoice['salesOrderId'];
// //   if (salesOrder == null) {
// //     print("❌ [handleInvoice] No 'salesOrderId' found in invoice");
// //     return;
// //   }
// //   print(
// //     "🧾 [handleInvoice] Sales order extracted: ${salesOrder['invoiceNo'] ?? 'Unknown InvoiceNo'}",
// //   );

// //   // Step 3: Get order invoice number correctly
// //   final orderInvoiceNo = salesOrder['invoiceNo']?.toString();
// //   if (orderInvoiceNo == null || orderInvoiceNo.isEmpty) {
// //     print("❌ [handleInvoice] Invalid or empty 'invoiceNo' in sales order");
// //     return;
// //   }
// //   print("🔢 [handleInvoice] Order Invoice No: $orderInvoiceNo");

// //   // // Step 4: Check if invoice already exists in Hive
// //   // final box = HiveManager.invoiceBox;
// //   // if (box.containsKey(orderInvoiceNo)) {
// //   //   print(
// //   //     "⚠️ [handleInvoice] Invoice already exists in Hive: $orderInvoiceNo → Skipping save",
// //   //   );
// //   //   return;
// //   // }
// //   // print("✅ [handleInvoice] Invoice does not exist in Hive. Proceeding to save");

// //   // Step 5: Save invoice to Hive
// //   try {
// //     await saveInvoiceToHive(invoice);
// //     print(
// //       "💾 [handleInvoice] Invoice saved successfully in Hive: $orderInvoiceNo",
// //     );

// //     // Step 6: Update printer with receipt data
// //     printer.updateReceiptData(salesOrder);
// //     print(
// //       "🖨️ [handleInvoice] Receipt printer updated for Invoice No: $orderInvoiceNo",
// //     );
// //   } catch (e, st) {
// //     print(
// //       "🔥 [handleInvoice] Exception while saving invoice or updating printer: $e",
// //     );
// //     print("📄 StackTrace: $st");
// //   }

// //   print(
// //     "🏁 [handleInvoice] Function execution completed for Invoice No: $orderInvoiceNo",
// //   );
// // }
// import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
// import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
// import '../../hive_service.dart';

// Future<void> handleInvoice(
//   Map<String, dynamic> jsonData,
//   SalesInvoiceReceiptPrinter printer,
// ) async {

//   // Step 1: Extract invoice
//   final invoice = jsonData['invoice'];
//   if (invoice == null) {
//     return;
//   }

//   // Step 2: Extract sales order from invoice
//   final salesOrder = invoice['salesOrderId'];
//   if (salesOrder == null) {
//     return;
//   }

//   // Step 3: Get order invoice number
//   final orderInvoiceNo = salesOrder['invoiceNo']?.toString();
//   if (orderInvoiceNo == null || orderInvoiceNo.isEmpty) {
//     return;
//   }

//   // Step 4: Check if invoice already exists in Hive
//   final box = await HiveManager.invoiceBox;
//   if (box.containsKey(orderInvoiceNo)) {
//     return;
//   }

//   // Step 5: Save invoice to Hive
//   try {
//     await savePosInvoiceToHive(invoice);

//     // Step 6: Update printer with receipt data
//     //printer.updateReceiptData(salesOrder);
//   } catch (e, st) {
//   }

// }

import 'package:flutter/rendering.dart';
import 'package:hive/hive.dart';
import 'package:image_v3/image_v3.dart';
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
import 'package:yen_pos/Server_Client/handlers/webscoket_messgae_handler.dart';

// Future<void> handleInvoice(
//   Map<String, dynamic> jsonData,
//   SalesInvoiceReceiptPrinter printer,
// ) async {
//   print("🚀 [handleInvoice] Function called");

//   // Step 1: Extract invoice
//   final invoice = jsonData['invoice'];
//   print("json data:$jsonData ");
//   if (invoice == null) {
//     print("❌ [handleInvoice] No 'invoice' field found in JSON data");
//     return;
//   }
//   print("📥 [handleInvoice] Invoice data found");

//   // Step 2: Extract sales order from invoice
//   final salesOrder = invoice['salesOrderId'];
//   if (salesOrder == null) {
//     print("❌ [handleInvoice] No 'salesOrderId' found in invoice");
//     return;
//   }
//   print(
//     "🧾 [handleInvoice] Sales order extracted: ${salesOrder['invoiceNo'] ?? 'Unknown InvoiceNo'}",
//   );

//   // Step 3: Get order invoice number correctly
//   final orderInvoiceNo = salesOrder['invoiceNo']?.toString();
//   if (orderInvoiceNo == null || orderInvoiceNo.isEmpty) {
//     print("❌ [handleInvoice] Invalid or empty 'invoiceNo' in sales order");
//     return;
//   }
//   print("🔢 [handleInvoice] Order Invoice No: $orderInvoiceNo");

//   // // Step 4: Check if invoice already exists in Hive
//   // final box = HiveManager.invoiceBox;
//   // if (box.containsKey(orderInvoiceNo)) {
//   //   print(
//   //     "⚠️ [handleInvoice] Invoice already exists in Hive: $orderInvoiceNo → Skipping save",
//   //   );
//   //   return;
//   // }
//   // print("✅ [handleInvoice] Invoice does not exist in Hive. Proceeding to save");

//   // Step 5: Save invoice to Hive
//   try {
//     await saveInvoiceToHive(invoice);
//     print(
//       "💾 [handleInvoice] Invoice saved successfully in Hive: $orderInvoiceNo",
//     );

//     // Step 6: Update printer with receipt data
//     printer.updateReceiptData(salesOrder);
//     print(
//       "🖨️ [handleInvoice] Receipt printer updated for Invoice No: $orderInvoiceNo",
//     );
//   } catch (e, st) {
//     print(
//       "🔥 [handleInvoice] Exception while saving invoice or updating printer: $e",
//     );
//     print("📄 StackTrace: $st");
//   }

//   print(
//     "🏁 [handleInvoice] Function execution completed for Invoice No: $orderInvoiceNo",
//   );
// }
import 'package:yen_pos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yen_pos/Sale_order/Print_Receipt/invoicePrint.dart';
import '../../hive_service.dart';

Future<void> handleInvoice(
  Map<String, dynamic> jsonData,
  SalesInvoiceReceiptPrinter printer,
) async {
  try {
    print("🟢 [handleInvoice] STARTED");
    print("🟢 Incoming JSON data: $jsonData");

    // Step 1: Extract invoice
    final invoice = jsonData['invoice'];

    if (invoice == null) {
      print("⚠️ No invoice found in JSON data");
      return;
    }
    print("🟢 Invoice extracted: $invoice");

    // Step 2: Extract sales order from invoice
    final salesOrder = invoice['salesOrderId'];
    if (salesOrder == null) {
      print("⚠️ No salesOrderId found in invoice");
      return;
    }
    print("🟢 Sales Order extracted: $salesOrder");

    // Step 3: Get order invoice number
    final orderInvoiceNo = salesOrder['invoiceNo']?.toString();
    if (orderInvoiceNo == null || orderInvoiceNo.isEmpty) {
      print("⚠️ Invalid or missing orderInvoiceNo in sales order");
      return;
    }
    print("🟢 Order Invoice No: $orderInvoiceNo");

    // Step 4: Check if invoice already exists in Hive
    final box = await HiveManager.invoiceBox;
    if (box.containsKey(orderInvoiceNo)) {
      print(
        "⚠️ Invoice already exists in Hive for orderInvoiceNo: $orderInvoiceNo",
      );
      return;
    }

    print("🟢 Invoice not found in Hive, ready to save");

    // Step 5: Save invoice to Hive
    try {
      print("🟢 Saving invoice to Hive...");
      await savePosInvoiceToHive(invoice);
      print("✅ Invoice saved to Hive successfully");

      // Step 6: Update printer with receipt data
      print("🟢 Updating printer with sales order data...");
      //printer.updateReceiptData(salesOrder);
      print("✅ Receipt printed for invoice $orderInvoiceNo");
    } catch (e, st) {
      print("❌ Error occurred while saving invoice or printing: $e");
      print("❌ StackTrace: $st");
    }

    print("🟢 [handleInvoice] FINISHED for orderInvoiceNo: $orderInvoiceNo");
  } catch (e, st) {
    print("❌ [handleInvoice] Exception: $e");
    print("❌ StackTrace: $st");
  }
}

Future<void> handleInvoices(
  Map<String, dynamic> jsonData,
  SalesInvoiceReceiptPrinter printer,
) async {
  try {
    print("🟢 handleInvoices START");

    List<Map<String, dynamic>> _invoices = [];

    final data = jsonData;
    debugPrint("invoices in payload $data");

    if (data.containsKey('invoices')) {
      final List<Map<String, dynamic>> invoices =
          List<Map<String, dynamic>>.from(data['invoices']);

      await _saveToHiveBox(invoices);

      _invoices = invoices;
      debugPrint('✅ Invoices data received and saved');
    }
    _saveToHiveBox(_invoices);
  } catch (e, st) {
    print("❌ handleInvoices crashed: $e\n$st");
  }
}

// Future<void> _saveToHiveBox(List<Map<String, dynamic>> data) async {
//   print("handleInvoices _saveToHiveBox  $data");
//   final box = await Hive.openBox('invoices');
//   if (box == null) return;

//   // ✅ Do NOT clear if incoming data is empty
//   if (data.isNotEmpty) {
//     await box.clear();
//   }

//   for (final item in data) {
//     await box.add(item);
//   }

//   // debugPrint('✅ [$boxName] Saved ${data.length} records to Hive.');
// }

Future<void> _saveToHiveBox(List<Map<String, dynamic>> data) async {
  print("handleInvoices _saveToHiveBox $data");

  final box = await Hive.openBox('invoices');

  if (data.isEmpty) return;

  // 🔹 Collect existing invoiceNos from Hive
  final Set<String> existingInvoiceNos = box.values
      .whereType<Map>()
      .map((e) => e['invoiceNo']?.toString())
      .where((e) => e != null && e.isNotEmpty)
      .cast<String>()
      .toSet();

  int inserted = 0;

  for (final item in data) {
    final invoiceNo = item['invoiceNo']?.toString();

    // ❌ Skip if invoiceNo missing
    if (invoiceNo == null || invoiceNo.isEmpty) continue;

    // ❌ Skip duplicates
    if (existingInvoiceNos.contains(invoiceNo)) continue;

    await box.add(item);
    existingInvoiceNos.add(invoiceNo); // prevent duplicates within same batch
    inserted++;
  }

  print("✅ Hive invoices inserted: $inserted");
}
