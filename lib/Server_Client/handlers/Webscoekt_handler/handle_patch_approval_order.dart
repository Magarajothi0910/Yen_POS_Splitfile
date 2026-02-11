import 'package:flutter/material.dart';
import 'package:yen_pos/Sale_order/Provider/customerScreen_provider.dart';
import 'package:yen_pos/Server_Client/handlers/webscoket_messgae_handler.dart';

Future<void> handlePatchSalesApprovalOrder(
  Map<String, dynamic> jsonData,
  CustomerScreenProvider customerProvider,
) async {
  print('\n============== HANDLE PATCH SALES APPROVAL ORDER ==============');
  print('📥 Incoming JSON Data: $jsonData');

  // Extract Sale Order Number
  final soNo = jsonData['saleOrderNo']?.toString() ?? '';
  print('🔍 Extracted saleOrderNo: $soNo');

  if (soNo.isEmpty) {
    print('⚠️ No saleOrderNo found. Stopping process.');
    return;
  }

  try {
    print('\n----------- STEP 1: HANDLE PATCH MESSAGE UPDATE -----------');
    print('🛠️ Calling handlePatchSaleOrderMessage() with data...');
    await handlePatchSaleApprovalOrderMessage(jsonData);
    print('✅ Patch message handled successfully');

    print('\n----------- STEP 2: FETCH SAVED SALES ORDERS -----------');
    final orders = await getSavedApprovalOrder();
    print('📦 Saved Sales Orders Count: ${orders.length}');
    print('📄 Saved Orders: $orders');

    if (orders.isEmpty) {
      print('⚠️ No saved orders found. Stopping process.');
      return;
    }

    print('\n----------- STEP 3: FIND MATCHED ORDER -----------');
    print('🔎 Searching for order with saleOrderNo = $soNo');

    final matchedOrder = orders.firstWhere(
      (order) =>
          (order['data']?['saleOrderNo']?.toString() == soNo) ||
          (order['saleOrderNo']?.toString() == soNo),
      orElse: () => {},
    );

    print('🟦 Matched Order: $matchedOrder');

    if (matchedOrder.isEmpty) {
      print('❌ No matching order found in saved orders.');
      return;
    }

    print('✅ Matching approval order found successfully.');

    print('\n============== END PATCH SALES APPROVAL ==============\n');
  } catch (e, st) {
    print('🚨 ERROR in handlePatchSalesApprovalOrder: $e');
    print('📌 Stacktrace: $st');
  }
}
