import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' hide Text;
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import '../../hive_service.dart';
import 'package:flutter/material.dart';

Future<void> handleSalesReturn(Map<String, dynamic> jsonData) async {
  print("🟢 [handlesalesReturn] STARTED");
  print("🟢 Incoming JSON data: $jsonData");

  // Step 1: Extract invoice
  final salesReturn = jsonData['returnData'];
  final salesReturnNo = jsonData['salesReturnNo'];
  if (salesReturn == null) {
    print("⚠️ No salesReturn found in JSON data");
    return;
  }
  print("🟢 salesReturn extracted: $salesReturn");

  print("🟢 salesReturn extracted: $salesReturnNo");

  if (salesReturnNo == null || salesReturnNo.isEmpty) {
    print("⚠️ Invalid or missing orderInvoiceNo in salesReturn");
    return;
  }
  print("🟢 Order salesReturn No: $salesReturnNo");

  // Step 4: Check if invoice already exists in Hive
  final salesReturnBox = await Hive.openBox("salesReturns");
  if (salesReturnBox.containsKey(salesReturnNo)) {
    print(
      "⚠️ salesReturn already exists in Hive for salesReturnNo: $salesReturnNo",
    );
    return;
  }
  print("🟢 salesReturn not found in Hive, ready to save");

  // Step 5: Save invoice to Hive
  try {
    print("🟢 Saving salesReturn to Hive...");

    salesReturnBox.put(salesReturnNo, salesReturn);
    debugPrint("Sales Return HIVE SUCCESSFUL!");
    debugPrint("Sales Return saved to Hive: $salesReturnNo");
    print("✅ salesReturn saved to Hive successfully");

    // Step 6: Update printer with receipt data
    print("🟢 Updating printer with sales order data...");
    //printer.updateReceiptData(salesOrder);
    print("✅ Receipt printed for salesReturn $salesReturnNo");
  } catch (e, st) {
    print("❌ Error occurred while saving salesReturn or printing: $e");
    print("❌ StackTrace: $st");
  }

  print("🟢 [handlesalesReturn] FINISHED for ordersalesReturn: $salesReturnNo");
}
