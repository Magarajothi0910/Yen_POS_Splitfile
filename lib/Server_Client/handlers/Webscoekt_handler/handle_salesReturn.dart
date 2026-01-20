import 'dart:convert';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' hide Text;
import 'package:yenpos/Hive_Manager/hive_manager_saleOrder.dart';
import 'package:yenpos/Sale_order/Print_Receipt/invoicePrint.dart';
import '../../hive_service.dart';
import 'package:flutter/material.dart';

Future<void> handleSalesReturn(Map<String, dynamic> jsonData) async {

  // Step 1: Extract invoice
  final salesReturn = jsonData['returnData'];
  final salesReturnNo = jsonData['salesReturnNo'];
  if (salesReturn == null) {
    return;
  }


  if (salesReturnNo == null || salesReturnNo.isEmpty) {
    return;
  }

  // Step 4: Check if invoice already exists in Hive
  final salesReturnBox = await Hive.openBox("salesReturns");
  if (salesReturnBox.containsKey(salesReturnNo)) {
    return;
  }

  // Step 5: Save invoice to Hive
  try {

    salesReturnBox.put(salesReturnNo, salesReturn);

    // Step 6: Update printer with receipt data
    //printer.updateReceiptData(salesOrder);
  } catch (e, st) {
  }

}
